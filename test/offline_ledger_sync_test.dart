import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soko_seller_terminal/src/core/db/app_database.dart';
import 'package:soko_seller_terminal/src/core/sync/sync_service.dart';
import 'package:soko_seller_terminal/src/core/util/ledger_sync_utils.dart';

import 'helpers/test_helpers.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/test'));
    registerFallbackValue(<String, dynamic>{});
  });

  group('ledger sync deduplication', () {
    late AppDatabase db;

    setUp(() async {
      db = createTestDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    test('isLedgerEntryQueued detects existing ledger_push payload', () async {
      await db.enqueueSync(
        'ledger_push',
        jsonEncode({'entry_id': 'sale-1', 'idempotency_key': 'idem-1'}),
      );
      final ops = await db.pendingSyncOps();

      expect(isLedgerEntryQueued('sale-1', ops), isTrue);
      expect(isLedgerEntryQueued('sale-2', ops), isFalse);
    });

    test('ledgerEntriesNeedingPush skips entries already queued', () async {
      const entryId = 'sale-42';
      await db.saveLedgerEntry(
        entry: LedgerEntriesCompanion.insert(
          id: const Value(entryId),
          idempotencyKey: 'idem-42',
          type: 'sale',
          total: const Value(12000),
          synced: const Value(false),
        ),
        lines: [
          LedgerLinesCompanion.insert(
            entryId: entryId,
            title: 'Soap',
            quantity: 1,
            unitPrice: 12000,
            lineTotal: 12000,
          ),
        ],
        payments: [
          PaymentsCompanion.insert(
            entryId: entryId,
            method: 'cash',
            amount: 12000,
          ),
        ],
      );
      await db.enqueueSync(
        'ledger_push',
        jsonEncode({'entry_id': entryId, 'idempotency_key': 'idem-42'}),
      );

      final unsynced = await db.pendingLedgerEntries();
      final ops = await db.pendingSyncOps();
      final needing = ledgerEntriesNeedingPush(
        unsynced: unsynced,
        syncOps: ops,
      );

      expect(needing, isEmpty);
    });

    test('buildLedgerPushPayload preserves idempotency key for server dedupe',
        () async {
      const entryId = 'sale-77';
      const idempotencyKey = 'offline-sale-77';
      await db.saveLedgerEntry(
        entry: LedgerEntriesCompanion.insert(
          id: const Value(entryId),
          idempotencyKey: idempotencyKey,
          type: 'sale',
          total: const Value(5000),
          synced: const Value(false),
        ),
        lines: [
          LedgerLinesCompanion.insert(
            entryId: entryId,
            title: 'Tea',
            quantity: 2,
            unitPrice: 2500,
            lineTotal: 5000,
          ),
        ],
        payments: [
          PaymentsCompanion.insert(
            entryId: entryId,
            method: 'cash',
            amount: 5000,
          ),
        ],
      );

      final bundle = await db.fetchLedgerEntryBundle(entryId);
      expect(bundle, isNotNull);

      final payload = buildLedgerPushPayload(bundle!);
      expect(payload['entry_id'], entryId);
      expect(payload['idempotency_key'], idempotencyKey);
      expect(payload['lines'], hasLength(1));
    });

    test('dispatchSyncOpForTest pushes ledger once with stable idempotency key',
        () async {
      final api = MockSellerApi();
      final syncService = SyncService(
        db: db,
        sellerApi: api,
        secureStorage: MockSecureStorage(),
      );

      const entryId = 'sale-88';
      const idempotencyKey = 'offline-sale-88';
      await db.into(db.items).insert(
        ItemsCompanion.insert(
          id: const Value('item-1'),
          remoteId: const Value(101),
          name: 'Soap',
          price: 5000,
        ),
      );
      await db.saveLedgerEntry(
        entry: LedgerEntriesCompanion.insert(
          id: const Value(entryId),
          idempotencyKey: idempotencyKey,
          type: 'sale',
          total: const Value(5000),
          synced: const Value(false),
        ),
        lines: [
          LedgerLinesCompanion.insert(
            entryId: entryId,
            itemId: const Value('item-1'),
            title: 'Soap',
            quantity: 1,
            unitPrice: 5000,
            lineTotal: 5000,
          ),
        ],
        payments: [
          PaymentsCompanion.insert(
            entryId: entryId,
            method: 'cash',
            amount: 5000,
          ),
        ],
      );

      var pushCount = 0;
      when(
        () => api.pushLedgerEntry(any(), idempotencyKey: any(named: 'idempotencyKey')),
      ).thenAnswer((invocation) async {
        pushCount++;
        final key = invocation.namedArguments[#idempotencyKey] as String;
        expect(key, idempotencyKey);
        return Response(
          requestOptions: RequestOptions(path: '/ledger'),
          data: {
            'server_entry_id': 'srv-1',
            'idempotency_key': key,
            'received_at': DateTime.utc(2026, 6, 9).toIso8601String(),
          },
        );
      });

      await db.enqueueSync(
        'ledger_push',
        jsonEncode({
          'entry_id': entryId,
          'idempotency_key': idempotencyKey,
          'type': 'sale',
          'total': 5000,
          'lines': [
            {
              'product_id': 'item-1',
              'name': 'Soap',
              'price': 5000,
              'quantity': 1,
              'subtotal': 5000,
            },
          ],
          'payments': [
            {'method': 'cash', 'amount': 5000},
          ],
        }),
      );

      final op = (await db.pendingSyncOps()).single;
      await syncService.dispatchSyncOpForTest(op);

      expect(pushCount, 1);

      final synced = await (db.select(db.ledgerEntries)
            ..where((tbl) => tbl.id.equals(entryId)))
          .getSingle();
      expect(synced.synced, isTrue);
      expect(synced.idempotencyKey, idempotencyKey);
    });
  });
}