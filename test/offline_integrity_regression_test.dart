import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soko_seller_terminal/src/core/db/app_database.dart';
import 'package:soko_seller_terminal/src/core/sync/sync_service.dart';
import 'helpers/test_helpers.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());
  setUpAll(() {
    registerFallbackValue(DateTime(2020));
    registerFallbackValue(<String, dynamic>{});
  });

  Future<void> seedProduct() async {
    await db
        .into(db.items)
        .insert(
          ItemsCompanion.insert(
            id: const Value('local-uuid'),
            remoteId: const Value(42),
            name: 'Tea',
            price: 1000,
            stockQty: const Value(5),
            synced: const Value(true),
          ),
        );
    await db
        .into(db.itemStocks)
        .insert(
          ItemStocksCompanion.insert(
            itemId: 'local-uuid',
            variant: '',
            price: 1000,
            stockQty: const Value(5),
          ),
        );
  }

  Future<int> sell(List<int> quantities) => db.checkoutSale(
    entry: LedgerEntriesCompanion.insert(
      id: const Value('sale-1'),
      idempotencyKey: 'idem-1',
      type: 'sale',
      subtotal: const Value(2000),
      tax: const Value(360),
      total: const Value(2360),
    ),
    lines: [
      LedgerLinesCompanion.insert(
        entryId: 'sale-1',
        itemId: const Value('local-uuid'),
        title: 'Tea',
        quantity: 2,
        unitPrice: 1000,
        lineTotal: 2000,
      ),
    ],
    payments: [
      PaymentsCompanion.insert(entryId: 'sale-1', method: 'cash', amount: 2360),
    ],
    stockDeltas: quantities
        .map((q) => (itemId: 'local-uuid', quantity: q, variant: null))
        .toList(),
  );

  test(
    'sale commits default-variant stock and a tax-preserving outbox together',
    () async {
      await seedProduct();
      await sell([2]);
      expect((await db.getItemById('local-uuid'))!.stockQty, 3);
      expect((await db.select(db.itemStocks).getSingle()).stockQty, 3);
      final ops = await db.pendingSyncOps();
      expect(ops, hasLength(1));
      final payload = jsonDecode(ops.single.payload) as Map;
      expect(payload['idempotency_key'], 'idem-1');
      expect(payload['subtotal'], 2000);
      expect(payload['tax'], 360);
      expect(payload['total'], 2360);
      expect(await db.hasUnsyncedWork(), isTrue);
    },
  );

  test('repeated lines cannot jointly oversell stock', () async {
    await seedProduct();
    await expectLater(sell([3, 3]), throwsStateError);
    expect(await db.select(db.ledgerEntries).get(), isEmpty);
    expect(await db.pendingSyncOps(), isEmpty);
    expect((await db.getItemById('local-uuid'))!.stockQty, 5);
  });

  test('outbox failure rolls back receipt and stock', () async {
    await seedProduct();
    await db.customStatement(
      "CREATE TRIGGER reject_outbox BEFORE INSERT ON sync_ops BEGIN SELECT RAISE(ABORT, 'outbox unavailable'); END",
    );
    await expectLater(sell([2]), throwsA(anything));
    expect(await db.select(db.ledgerEntries).get(), isEmpty);
    expect((await db.getItemById('local-uuid'))!.stockQty, 5);
  });

  test(
    'snapshot membership uses remote ID and preserves offline-created local ID',
    () async {
      await seedProduct();
      await db.pruneSyncedRemoteItemsNotIn(['42']);
      expect(await db.getItemById('local-uuid'), isNotNull);
    },
  );

  test(
    'blocked uploads prevent destructive logout as well as pending uploads',
    () async {
      expect(await db.hasUnsyncedWork(), isFalse);
      final id = await db.enqueueSync('item_update', '{}');
      await db.markSyncBlocked(id, retryCount: 1, lastError: 'validation');
      expect(await db.hasUnsyncedWork(), isTrue);
      await db.markSynced(id);
      expect(await db.hasUnsyncedWork(), isFalse);
    },
  );

  test(
    'account cleanup includes debts, job sessions and newer tables',
    () async {
      await db
          .into(db.madeniEntries)
          .insert(
            MadeniEntriesCompanion.insert(
              customerName: 'Customer A',
              description: 'Credit sale',
              amount: 1000,
            ),
          );
      await db
          .into(db.supplierDebts)
          .insert(
            SupplierDebtsCompanion.insert(
              supplierName: 'Supplier A',
              description: 'Purchase',
              amount: 2000,
            ),
          );
      await db.clearAllData();
      for (final table in db.allTables) {
        final row = await db
            .customSelect(
              'SELECT COUNT(*) AS n FROM "${table.actualTableName}"',
            )
            .getSingle();
        expect(row.read<int>('n'), 0, reason: table.actualTableName);
      }
    },
  );

  test(
    'disposing sync waits for an in-flight pull and prevents stale account writes',
    () async {
      final api = MockSellerApi();
      final response = Completer<Response<dynamic>>();
      final requested = Completer<void>();
      when(() => api.pullPosSync(since: any(named: 'since'))).thenAnswer((_) {
        requested.complete();
        return response.future;
      });
      final service = SyncService(
        db: db,
        sellerApi: api,
        secureStorage: MockSecureStorage(),
      );
      final pull = service.pullPosDelta();
      await requested.future;
      var disposed = false;
      final disposing = service.dispose().then((_) => disposed = true);
      await Future<void>.delayed(Duration.zero);
      expect(disposed, isFalse);
      response.complete(
        Response(
          requestOptions: RequestOptions(path: '/pull'),
          data: {'received_at': '2026-09-14T10:00:00Z'},
        ),
      );
      await pull;
      await disposing;
      expect(await db.select(db.syncCursors).get(), isEmpty);
    },
  );
  test(
    'separate stock adjustments use distinct keys but retries keep the same key',
    () async {
      await seedProduct();
      final api = MockSellerApi();
      final keys = <String>[];
      when(
        () => api.upsertPosCatalogProduct(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((call) async {
        keys.add(call.namedArguments[#idempotencyKey] as String);
        return Response(
          requestOptions: RequestOptions(path: '/catalog'),
          data: {'product_id': 42},
        );
      });
      final service = SyncService(
        db: db,
        sellerApi: api,
        secureStorage: MockSecureStorage(),
      );
      await db.enqueueSync(
        'stock_adjust',
        jsonEncode({'local_id': 'local-uuid', 'current_stock': 8}),
      );
      await db.enqueueSync(
        'stock_adjust',
        jsonEncode({'local_id': 'local-uuid', 'current_stock': 12}),
      );
      final ops = await db.pendingSyncOps();
      await service.dispatchSyncOpForTest(ops[0]);
      await service.dispatchSyncOpForTest(ops[0]);
      await service.dispatchSyncOpForTest(ops[1]);
      expect(keys[0], keys[1]);
      expect(keys[2], isNot(keys[0]));
      await service.dispose();
    },
  );

  test(
    'offline expense category reaches backend and replaces its temporary row',
    () async {
      await db.upsertExpenseCategory(
        const ExpenseCategoriesCompanion(
          id: Value(-1),
          name: Value('Fuel'),
          type: Value('expense'),
        ),
      );
      final api = MockSellerApi();
      when(
        () => api.pushExpenseCategory(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/categories'),
          data: {
            'data': {'id': 17, 'name': 'Fuel', 'type': 'expense'},
          },
        ),
      );
      await db.enqueueSync(
        'expense_category_create',
        jsonEncode({'name': 'Fuel', 'idempotency_key': 'fuel-1'}),
      );
      final service = SyncService(
        db: db,
        sellerApi: api,
        secureStorage: MockSecureStorage(),
      );
      await service.dispatchSyncOpForTest((await db.pendingSyncOps()).single);
      final categories = await db.select(db.expenseCategories).get();
      expect(categories, hasLength(1));
      expect(categories.single.id, 17);
      await service.dispose();
    },
  );

  Future<void> refund(String id, int quantity) => db.refundSale(
    entry: LedgerEntriesCompanion.insert(
      id: Value(id),
      idempotencyKey: id,
      type: 'refund',
      originalEntryId: const Value('sale-1'),
      subtotal: const Value(1000),
      total: const Value(1000),
    ),
    lines: [
      LedgerLinesCompanion.insert(
        entryId: id,
        itemId: const Value('local-uuid'),
        title: 'Tea',
        quantity: quantity,
        unitPrice: 1000,
        lineTotal: 1000,
      ),
    ],
    payments: [
      PaymentsCompanion.insert(entryId: id, method: 'cash', amount: 1000),
    ],
  );

  test(
    'refund restores stock and queue atomically and rejects excess cumulative quantity',
    () async {
      await seedProduct();
      await sell([2]);
      await refund('refund-1', 1);
      expect((await db.getItemById('local-uuid'))!.stockQty, 4);
      expect((await db.select(db.itemStocks).getSingle()).stockQty, 4);
      expect(await db.pendingSyncOps(), hasLength(2));
      await expectLater(refund('refund-2', 2), throwsStateError);
      expect((await db.getItemById('local-uuid'))!.stockQty, 4);
      expect(await db.select(db.ledgerEntries).get(), hasLength(2));
    },
  );

  test(
    'refund outbox failure rolls back returned stock and refund receipt',
    () async {
      await seedProduct();
      await sell([2]);
      await db.customStatement(
        "CREATE TRIGGER reject_refund_outbox BEFORE INSERT ON sync_ops BEGIN SELECT RAISE(ABORT, 'outbox unavailable'); END",
      );
      await expectLater(refund('refund-1', 1), throwsA(anything));
      expect((await db.getItemById('local-uuid'))!.stockQty, 3);
      expect(await db.select(db.ledgerEntries).get(), hasLength(1));
    },
  );

  test(
    'snapshot removal preserves product referenced by an offline sale',
    () async {
      await seedProduct();
      await sell([2]);
      await db.pruneSyncedRemoteItemsNotIn([]);
      expect(await db.getItemById('local-uuid'), isNotNull);
      expect(
        (await db.fetchLedgerEntryBundle('sale-1'))!.lines.single.itemId,
        'local-uuid',
      );
    },
  );

  test(
    'incremental manifest removes cloud-deleted rows without a full download',
    () async {
      await seedProduct();
      final api = MockSellerApi();
      final storage = MockSecureStorage();
      when(() => storage.readPosSessionToken()).thenAnswer((_) async => null);
      when(() => api.pullPosSync(since: any(named: 'since'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/pull'),
          data: {
            'received_at': '2026-09-14T10:00:00Z',
            'since': '2026-09-01T00:00:00Z',
            'snapshot': {
              'full': false,
              'catalog_complete': true,
              'product_ids': [],
              'service_ids': [],
            },
            'products': [],
            'services': [],
          },
        ),
      );
      final service = SyncService(
        db: db,
        sellerApi: api,
        secureStorage: storage,
      );
      await service.pullPosDelta();
      expect(await db.getItemById('local-uuid'), isNull);
      expect(
        (await db.getLastPulledAt('products'))?.toUtc(),
        DateTime.utc(2026, 9, 14, 10),
      );
      await service.dispose();
    },
  );

  test(
    'failed cursor write rolls back applied products and preserves the last sync position',
    () async {
      await seedProduct();
      final api = MockSellerApi();
      final storage = MockSecureStorage();
      when(() => storage.readPosSessionToken()).thenAnswer((_) async => null);
      when(() => api.pullPosSync(since: any(named: 'since'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/pull'),
          data: {
            'received_at': '2026-09-14T10:00:00Z',
            'since': '2026-09-01T00:00:00Z',
            'products': [
              {
                'id': '42',
                'name': 'Changed remotely',
                'unit_price': 2000,
                'current_stock': 5,
              },
            ],
            'services': [],
          },
        ),
      );
      final oldCursor = DateTime.utc(2026, 9, 1);
      await db.setLastPulledAt('products', oldCursor);
      await db.customStatement(
        "CREATE TRIGGER reject_cursor BEFORE INSERT ON sync_cursors BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      final service = SyncService(
        db: db,
        sellerApi: api,
        secureStorage: storage,
      );
      await expectLater(service.pullPosDelta(), throwsA(anything));
      expect((await db.getItemById('local-uuid'))!.name, 'Tea');
      expect((await db.getLastPulledAt('products'))?.toUtc(), oldCursor);
      await service.dispose();
    },
  );

  test(
    '10,000-item warm catalogue requests only a delta and preserves cached rows',
    () async {
      final api = MockSellerApi();
      final storage = MockSecureStorage();
      when(() => storage.readPosSessionToken()).thenAnswer((_) async => null);
      final requestedSince = <DateTime>[];
      var warmed = false;
      when(() => api.pullPosSync(since: any(named: 'since'))).thenAnswer((
        call,
      ) async {
        requestedSince.add(call.namedArguments[#since] as DateTime);
        return Response(
          requestOptions: RequestOptions(path: '/pull'),
          data: {
            'received_at': warmed
                ? '2026-09-14T10:01:00Z'
                : '2026-09-14T10:00:00Z',
            'since': requestedSince.last.toIso8601String(),
            'products': warmed
                ? [
                    {
                      'id': '42',
                      'name': 'Updated product',
                      'unit_price': 2500,
                      'current_stock': 5,
                    },
                  ]
                : [],
            'services': [],
          },
        );
      });
      final service = SyncService(
        db: db,
        sellerApi: api,
        secureStorage: storage,
      );
      await service.pullPosDelta();
      await db.batch(
        (batch) => batch.insertAll(
          db.items,
          List.generate(
            10000,
            (i) => ItemsCompanion.insert(
              id: Value('cached-$i'),
              remoteId: Value(i),
              name: 'Product $i',
              price: 1000,
              stockQty: const Value(5),
              synced: const Value(true),
            ),
          ),
        ),
      );
      warmed = true;
      final elapsed = Stopwatch()..start();
      await service.pullPosDelta();
      elapsed.stop();
      expect(requestedSince.last, DateTime.utc(2026, 9, 14, 9, 59, 59));
      expect(await db.select(db.items).get(), hasLength(10000));
      expect((await db.getItemById('cached-42'))!.name, 'Updated product');
      expect((await db.getItemById('cached-9999'))!.name, 'Product 9999');
      // Host-side measurement, not a phone startup benchmark.
      // ignore: avoid_print
      print(
        '10,000-item warm delta applied in ${elapsed.elapsedMilliseconds} ms',
      );
      await service.dispose();
    },
  );
}
