import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../app_providers.dart';
import '../db/app_database.dart';
import '../network/pos_dtos.dart';
import '../util/phone_normalizer.dart';
import '../network/seller_api.dart';
import '../telemetry/telemetry.dart';
import '../storage/secure_storage.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(sellerApiProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  return SyncService(db: db, sellerApi: api, secureStorage: secureStorage);
});

const _uuid = Uuid();

class SyncService {
  SyncService({
    required this.db,
    required this.sellerApi,
    required this.secureStorage,
  });

  final AppDatabase db;
  final SellerApi sellerApi;
  final SecureStorage secureStorage;

  final _syncStatusController = StreamController<String>.broadcast();
  Stream<String> get syncStatusStream => _syncStatusController.stream;
  StreamSubscription<dynamic>? _connectivitySub;
  Timer? _retryTimer;
  bool _isPumping = false;
  bool _pumpQueued = false;
  Future<void>? _pullInFlight;
  static const _contactsSyncKey = 'device_contacts_synced_at';
  static const _contactsSyncInterval = Duration(hours: 12);

  void start() {
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen(
      (_) => _pump(),
    );
    _retryTimer ??= Timer.periodic(const Duration(minutes: 5), (_) => _pump());
    
    // Check if we need initial data - if no items, do full resync from epoch
    unawaited(_ensureInitialDataLoaded());
  }

  Future<void> _ensureInitialDataLoaded() async {
    final items = await db.getAllItems();
    if (items.isEmpty) {
      print('[SyncService] No items in DB - triggering full resync from epoch...');
      await forceFullResync();
    } else {
      print('[SyncService] Have ${items.length} items in DB - normal sync');
      await _pump();
    }
  }

  Future<void> syncNow() => _pump();

  /// Force a complete resync by clearing all sync cursors and pulling from epoch.
  /// This is useful when the initial sync failed or products are missing.
  Future<void> forceFullResync() async {
    print('[SyncService] Starting FULL RESYNC from epoch...');
    
    // Clear all sync cursors
    await db.customStatement('DELETE FROM sync_cursors');
    print('[SyncService] Cleared all sync cursors');
    
    // Now pull will use epoch as the since timestamp
    await pullPosDelta();
  }

  Future<void> primeOfflineData() async {
    try {
      await pullPosDelta();
    } catch (e, st) {
      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(telemetry.recordError(e, st, hint: 'primeOfflineData'));
      }
    }
  }

  Future<void> enqueue(String type, Map<String, dynamic> payload) async {
    await db.enqueueSync(type, jsonEncode(payload));
  }

  Future<void> _pump() async {
    if (_isPumping) {
      _pumpQueued = true;
      return;
    }

    _isPumping = true;
    try {
      final List<ConnectivityResult> list = await Connectivity()
          .checkConnectivity();
      final online =
          list.contains(ConnectivityResult.mobile) ||
          list.contains(ConnectivityResult.wifi);
      if (!online) return;

      final queue = await db.pendingSyncOps();
      for (final op in queue) {
        if (!_isDue(op)) continue;
        try {
          await _dispatch(op);
          await db.markSynced(op.id);
        } catch (e) {
          final errorMsg = _formatSyncError(e);
          await db.markSyncFailed(
            op.id,
            retryCount: op.retryCount + 1,
            lastError: errorMsg,
          );
          final telemetry = Telemetry.instance;
          if (telemetry != null) {
            unawaited(
              telemetry.event(
                'sync_op_failed',
                props: {
                  'op_type': op.opType,
                  'retry_count': op.retryCount + 1,
                  'error': errorMsg,
                },
              ),
            );
          }
        }
      }

      // After pushing, pull server deltas for reconciliation.
      try {
        await pullPosDelta();
      } catch (_) {
        // Best effort: next pump will retry.
      }

      try {
        await _pushTemplates();
      } catch (_) {
        // Best effort: template push should not block.
      }

      try {
        await syncDeviceContacts();
      } catch (_) {
        // Best effort: contacts sync should not block POS sync.
      }
    } catch (e, st) {
      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(telemetry.recordError(e, st, hint: 'sync_pump'));
      }
    } finally {
      _isPumping = false;
    }

    if (_pumpQueued) {
      _pumpQueued = false;
      unawaited(_pump());
    }
  }

  bool _isDue(SyncOp op) {
    if (op.lastTriedAt == null) return true;
    final delay = _backoff(op.retryCount);
    final nextAttemptAt = op.lastTriedAt!.toUtc().add(delay);
    return DateTime.now().toUtc().isAfter(nextAttemptAt);
  }

  Duration _backoff(int retryCount) {
    const base = Duration(seconds: 5);
    const max = Duration(minutes: 5);
    final multiplier = 1 << retryCount.clamp(0, 16);
    final delay = Duration(seconds: base.inSeconds * multiplier);
    return delay > max ? max : delay;
  }

  Future<void> _pushTemplates() async {
    final unsyncedReceipts = await (db.select(db.receiptTemplates)..where((t) => t.synced.not())).get();
    final unsyncedQuotations = await (db.select(db.quotationTemplates)..where((t) => t.synced.not())).get();

    if (unsyncedReceipts.isEmpty && unsyncedQuotations.isEmpty) return;

    final receiptPayload = unsyncedReceipts.map((t) => {
      'id': t.id,
      'name': t.name,
      'style': t.style,
      'header_message': t.headerText,
      'header_color': t.colorHex,
      'footer_message': t.footerText,
      'show_logo': t.showLogo,
      'show_qr': t.showQr,
      'is_active': t.isActive,
    }).toList();

    final quotationPayload = unsyncedQuotations.map((t) => {
      'id': t.id,
      'name': t.name,
      'style': t.style,
      'header_message': t.headerText,
      'header_color': t.colorHex,
      'footer_message': t.footerText,
      'show_logo': t.showLogo,
      'show_qr': t.showQr,
      'is_active': t.isActive,
    }).toList();

    await sellerApi.batchUpsertTemplates(
      receiptTemplates: receiptPayload,
      quotationTemplates: quotationPayload,
    );
    
    // Mark synced
    for (final t in unsyncedReceipts) {
      await (db.update(db.receiptTemplates)..where((tbl) => tbl.id.equals(t.id)))
          .write(const ReceiptTemplatesCompanion(synced: drift.Value(true)));
    }
    for (final t in unsyncedQuotations) {
      await (db.update(db.quotationTemplates)..where((tbl) => tbl.id.equals(t.id)))
          .write(const QuotationTemplatesCompanion(synced: drift.Value(true)));
    }
  }

  String _formatSyncError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final path = error.requestOptions.path;
      final message =
          error.message ?? error.error?.toString() ?? 'DioException';
      final parts = <String>[
        if (status != null) 'HTTP $status',
        if (path.isNotEmpty) path,
        message,
      ];
      final out = parts.join(' • ');
      return out.length > 600 ? out.substring(0, 600) : out;
    }
    final out = error.toString();
    return out.length > 600 ? out.substring(0, 600) : out;
  }

  Future<void> _dispatch(SyncOp op) async {
    final payload = jsonDecode(op.payload) as Map<String, dynamic>;
    switch (op.opType) {
      case 'item_create':
      case 'item_update':
        final localId = payload['local_id'] as String?;
        if (op.opType == 'item_create') {
          await sellerApi.createProduct(payload);
        } else {
          final productId =
              payload['remote_id']?.toString() ??
              payload['local_id']?.toString() ??
              '';
          await sellerApi.updateProduct(productId, payload);
        }
        if (localId != null) {
          await db.markItemSynced(localId);
        }
        break;
      case 'item_delete':
        final productId =
            payload['remote_id']?.toString() ??
            payload['product_id']?.toString() ??
            '';
        if (productId.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing remote_id for item_delete',
          );
        }
        try {
          await sellerApi.deleteProduct(productId);
        } on DioException catch (e) {
          final status = e.response?.statusCode;
          if (status != null && status == 404) {
            // Treat "already deleted" as success for idempotent retry safety.
            return;
          }
          rethrow;
        }
        break;
      case 'service_create':
      case 'service_update':
        final localId = payload['local_id'] as String?;
        if (op.opType == 'service_create') {
          await sellerApi.createService(payload);
        } else {
          final serviceId =
              payload['remote_id']?.toString() ??
              payload['local_id']?.toString() ??
              '';
          await sellerApi.updateService(serviceId, payload);
        }
        if (localId != null) {
          await db.markServiceSynced(localId);
        }
        break;
      case 'transaction_push':
        await sellerApi.pushTransaction(payload);
        final txId = payload['transaction_id']?.toString();
        if (txId != null) {
          await db.markTransactionSynced(txId);
        }
        break;
      case 'ledger_push':
        final key =
            payload['idempotency_key']?.toString() ??
            payload['entry_id']?.toString() ??
            '';
        final res = await sellerApi.pushLedgerEntry(
          payload,
          idempotencyKey: key,
        );
        if (res.data is! Map<String, dynamic>) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Invalid ledger ack response shape',
          );
        }

        final ack = PosLedgerAck.fromJson(res.data as Map<String, dynamic>);
        if (ack.idempotencyKey != key) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Ledger ack idempotency mismatch',
          );
        }
        final entryId = payload['entry_id']?.toString();
        if (entryId != null) {
          await db.markLedgerSynced(
            entryId,
            jsonEncode({
              'server_entry_id': ack.serverEntryId,
              'idempotency_key': ack.idempotencyKey,
              'received_at': ack.receivedAt.toIso8601String(),
            }),
          );
        }
        break;
      case 'stock_adjust':
        await sellerApi.updateProduct(
          payload['product_id'].toString(),
          payload,
        );
        break;
      case 'cash_movement_push':
        final key =
            payload['idempotency_key']?.toString() ??
            payload['movement_id']?.toString() ??
            '';
        if (key.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing idempotency_key for cash movement',
          );
        }
        final body = Map<String, dynamic>.from(payload)
          ..remove('idempotency_key');
        final res = await sellerApi.pushCashMovement(body, idempotencyKey: key);
        if (res.data is! Map<String, dynamic>) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Invalid cash movement ack response shape',
          );
        }
        final ack = PosLedgerAck.fromJson(res.data as Map<String, dynamic>);
        if (ack.idempotencyKey != key) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Cash movement ack idempotency mismatch',
          );
        }
        break;
      case 'audit_log_push':
        final key = payload['idempotency_key']?.toString() ?? '';
        if (key.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing idempotency_key for audit log',
          );
        }
        final body = Map<String, dynamic>.from(payload)
          ..remove('idempotency_key');
        final res = await sellerApi.pushAuditLog(body, idempotencyKey: key);
        if (res.data is! Map<String, dynamic>) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Invalid audit log ack response shape',
          );
        }
        final ack = PosLedgerAck.fromJson(res.data as Map<String, dynamic>);
        if (ack.idempotencyKey != key) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Audit log ack idempotency mismatch',
          );
        }
        break;
      case 'quotation_push':
        final key =
            payload['idempotency_key']?.toString() ??
            payload['quotation_id']?.toString() ??
            '';
        if (key.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing idempotency_key for quotation',
          );
        }
        final body = Map<String, dynamic>.from(payload)
          ..remove('idempotency_key');
        await sellerApi.pushQuotation(body, idempotencyKey: key);
        break;
      case 'receipt_template_push':
      case 'receipt_template_update':
        final key =
            payload['idempotency_key']?.toString() ??
            payload['local_id']?.toString() ??
            '';
        if (key.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing idempotency_key for receipt template',
          );
        }
        await sellerApi.pushReceiptTemplate({
          'id': payload['local_id'] ?? payload['id'],
          'name': payload['name'] ?? 'Default Template',
          'style': payload['style'] ?? 'minimal',
          'header_color': payload['header_color'] ?? payload['color'],
          'footer_message': payload['footer'] ?? payload['footer_message'],
          'show_logo': payload['show_logo'] == 1 || payload['show_logo'] == true,
          'show_qr': payload['show_qr'] == 1 || payload['show_qr'] == true,
          'is_active': payload['is_active'] ?? true,
        }, idempotencyKey: key);
        break;
      case 'customer_push':
        final key =
            payload['idempotency_key']?.toString() ??
            payload['customer_id']?.toString() ??
            '';
        if (key.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing idempotency_key for customer',
          );
        }
        final body = Map<String, dynamic>.from(payload)
          ..remove('idempotency_key');
        await sellerApi.pushCustomer(body, idempotencyKey: key);
        break;
      case 'service_variant_push':
        await sellerApi.pushServiceVariant(payload);
        break;
      case 'service_variant_delete':
        final variantId = payload['variant_id']?.toString() ?? '';
        if (variantId.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing variant_id for service variant delete',
          );
        }
        await sellerApi.deleteServiceVariant(variantId);
        break;
      default:
        throw DioException(
          requestOptions: RequestOptions(path: op.opType),
          error: 'Unknown sync op ${op.opType}',
        );
    }
  }

  Future<void> pullPosDelta() {
    if (_pullInFlight != null) return _pullInFlight!;
    final future = _pullPosDeltaInternal();
    _pullInFlight = future.whenComplete(() => _pullInFlight = null);
    return _pullInFlight!;
  }

  Future<void> _pullPosDeltaInternal() async {
    try {
      final productsSince = await db.getLastPulledAt('products');
      final servicesSince = await db.getLastPulledAt('services');
      final customersSince = await db.getLastPulledAt('customers');
      final configSince = await db.getLastPulledAt('config');

      DateTime since = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final cursors = [productsSince, servicesSince, customersSince, configSince];
      if (cursors.every((c) => c != null)) {
        since = cursors.cast<DateTime>().reduce((a, b) => a.isBefore(b) ? a : b);
      }

      print('[SyncService] Pulling delta since $since'); // Debug log

      final res = await sellerApi.pullPosSync(since: since);
      if (res.data is! Map<String, dynamic>) {
        throw DioException(
          requestOptions: res.requestOptions,
          error: 'Invalid sync pull response shape (not a map)',
        );
      }

      // Handle wrapped response (e.g. {data: {...}, success: true})
      var responseData = res.data as Map<String, dynamic>;
      print('[SyncService] Wrapper keys: ${responseData.keys.toList()}');
      
      if (responseData.containsKey('data')) {
         print('[SyncService] Inner data type: ${responseData['data'].runtimeType}');
         if (responseData['data'] is Map) {
           final inner = responseData['data'] as Map;
           print('[SyncService] Inner keys: ${inner.keys.toList()}');
           responseData = responseData['data'] as Map<String, dynamic>;
         } else {
           print('[SyncService] Inner data IS NOT A MAP!');
         }
      }

      final pull = PosSyncPullResponse.fromJson(responseData);
      
      // Debug: Log what we received
      print('[SyncService] Pull received: ${pull.products.length} products, ${pull.services.length} services, ${pull.customers.length} customers, ${pull.ledgerEntries.length} txns');
      
      _syncStatusController.add('Syncing products...');
      if (pull.products.isEmpty) {
        print('[SyncService] WARNING: No products in sync response!');
      }

      for (final p in pull.products) {
        if (p.id.isEmpty) continue;
        await db.upsertItem(
          ItemsCompanion.insert(
            id: drift.Value(p.id),
            name: p.name.isEmpty ? 'Product' : p.name,
            price: p.unitPrice,
            stockQty: drift.Value(p.currentStock),
            imageUrl: drift.Value(p.imageUrl),
            publishedOnline: drift.Value(p.published),
            updatedAt: drift.Value(p.updatedAt ?? DateTime.now().toUtc()),
            synced: const drift.Value(true),
          ),
        );
      }

      for (final s in pull.services) {
        if (s.id.isEmpty) continue;
        await db.upsertService(
          ServicesCompanion.insert(
            id: drift.Value(s.id),
            title: s.title.isEmpty ? 'Service' : s.title,
            price: s.price,
            description: drift.Value(s.description),
            durationMinutes: drift.Value(s.durationMinutes),
            category: drift.Value(s.category),
            publishedOnline: drift.Value(s.published),
            updatedAt: drift.Value(s.updatedAt ?? DateTime.now().toUtc()),
            synced: const drift.Value(true),
          ),
        );
      }

      _syncStatusController.add('Syncing customers...');
      for (final c in pull.customers) {
        if (c.id.isEmpty) continue;
        await db.upsertCustomer(
          CustomersCompanion.insert(
            id: drift.Value(c.id),
            name: c.name.isEmpty ? 'Customer' : c.name,
            phone: drift.Value(c.phone),
            email: drift.Value(c.email),
            updatedAt: drift.Value(c.updatedAt ?? DateTime.now().toUtc()),
          ),
        );
      }

      final outlet = pull.outlet;
      if (outlet != null && outlet.id.isNotEmpty) {
        await db.upsertOutlet(
          OutletsCompanion.insert(
            id: drift.Value(outlet.id),
            name: outlet.name.isEmpty ? 'Default outlet' : outlet.name,
            address: drift.Value(outlet.address),
            phone: drift.Value(outlet.phone),
            updatedAt: drift.Value(outlet.updatedAt ?? DateTime.now().toUtc()),
          ),
        );
      }

      for (final t in pull.receiptTemplates) {
         await db.into(db.receiptTemplates).insertOnConflictUpdate(ReceiptTemplatesCompanion.insert(
            id: drift.Value(t.id),
            name: drift.Value(t.name),
            style: drift.Value(t.style),
            headerText: drift.Value(t.headerMessage),
            colorHex: drift.Value(t.headerColor),
            footerText: drift.Value(t.footerMessage),
            showLogo: drift.Value(t.showLogo),
            showQr: drift.Value(t.showQr),
            isActive: drift.Value(t.isActive),
            updatedAt: drift.Value(t.updatedAt),
            synced: const drift.Value(true),
         ));
      }

      for (final t in pull.quotationTemplates) {
         await db.into(db.quotationTemplates).insertOnConflictUpdate(QuotationTemplatesCompanion.insert(
            id: drift.Value(t.id),
            name: drift.Value(t.name),
            style: drift.Value(t.style),
            headerText: drift.Value(t.headerMessage), // Matches DTO 
            colorHex: drift.Value(t.headerColor),
            footerText: drift.Value(t.footerMessage),
            showLogo: drift.Value(t.showLogo),
            showQr: drift.Value(t.showQr),
            isActive: drift.Value(t.isActive),
            updatedAt: drift.Value(t.updatedAt),
            synced: const drift.Value(true),
         ));
      }

      _syncStatusController.add('Syncing transactions...');
      for (final e in pull.ledgerEntries) {
        if (e.clientEntryId.isEmpty) continue;
        
        final List<LedgerLinesCompanion> lines = e.lines.map((l) => LedgerLinesCompanion.insert(
          entryId: e.clientEntryId,
          title: l.title,
          quantity: l.quantity,
          unitPrice: l.price,
          lineTotal: l.total,
          itemId: drift.Value(l.itemId),
        )).toList();

        final List<PaymentsCompanion> payments = e.payments.map((p) => PaymentsCompanion.insert(
          entryId: e.clientEntryId,
          method: p.method,
          amount: p.amount,
        )).toList();

        await db.upsertLedgerEntryFromSync(
          entry: LedgerEntriesCompanion.insert(
            id: drift.Value(e.clientEntryId),
            idempotencyKey: e.clientEntryId, // Use client ID as idempotency key for now
            type: e.type,
            subtotal: drift.Value(e.subtotal),
            discount: drift.Value(e.discount),
            tax: drift.Value(e.tax),
            total: drift.Value(e.total),
            note: drift.Value(e.note),
            synced: const drift.Value(true),
            remoteAck: drift.Value(jsonEncode({
              'server_entry_id': e.id,
              'received_at': e.updatedAt?.toIso8601String(),
            })),
            customerId: drift.Value(e.customerId),
            createdAt: drift.Value(e.occurredAt ?? DateTime.now().toUtc()),
          ),
          lines: lines,
          payments: payments,
        );
      }

      if (pull.sellerProfile != null) {
        _syncStatusController.add('Syncing profile...');
        await secureStorage.write(key: 'seller_profile', value: jsonEncode({
          'id': pull.sellerProfile!.id,
          'name': pull.sellerProfile!.name,
          'email': pull.sellerProfile!.email,
          'phone': pull.sellerProfile!.phone,
          'business_name': pull.sellerProfile!.businessName,
        }));
      }

      await Future.wait([
        db.setLastPulledAt('products', pull.receivedAt),
        db.setLastPulledAt('services', pull.receivedAt),
        db.setLastPulledAt('customers', pull.receivedAt),
        db.setLastPulledAt('config', pull.receivedAt),
      ]);
      
      // Debug: Log total items in DB after sync
      final allItems = await db.getAllItems();
      print('[SyncService] After sync: ${allItems.length} total items in local DB');

    } catch (e, st) {
      print('[SyncService] CRITICAL ERROR in _pullPosDeltaInternal: $e');
      print(st);
      rethrow;
    }
  }

  Future<void> pullSellerProducts() async {
    await pullPosDelta();
  }

  Future<void> pullSellerServices() async {
    await pullPosDelta();
  }

  Future<void> pullCustomers() async {
    await pullPosDelta();
  }

  Future<void> pullConfig() async {
    await pullPosDelta();
  }

  Future<void> syncDeviceContacts({
    bool force = false,
    List<Contact>? contacts,
  }) async {
    final status = await Permission.contacts.status;
    if (!status.isGranted) return;

    if (!force) {
      final lastSyncRaw = await secureStorage.read(key: _contactsSyncKey);
      if (lastSyncRaw != null) {
        final lastSync = DateTime.tryParse(lastSyncRaw)?.toUtc();
        if (lastSync != null &&
            DateTime.now().toUtc().difference(lastSync) < _contactsSyncInterval) {
          return;
        }
      }
    }

    final deviceContacts = contacts ??
        await FlutterContacts.getContacts(withProperties: true);
    if (deviceContacts.isEmpty) {
      await secureStorage.write(
        key: _contactsSyncKey,
        value: DateTime.now().toUtc().toIso8601String(),
      );
      return;
    }

    _syncStatusController.add('Syncing contacts...');
    final payloads = _buildContactPayloads(deviceContacts);
    if (payloads.isEmpty) return;

    const batchSize = 200;
    for (var i = 0; i < payloads.length; i += batchSize) {
      final chunk = payloads.sublist(
        i,
        i + batchSize > payloads.length ? payloads.length : i + batchSize,
      );

      final res = await sellerApi.batchUpsertCrmContacts(chunk);
      final body = res.data;
      if (body is! Map<String, dynamic>) {
        throw DioException(
          requestOptions: res.requestOptions,
          error: 'Invalid CRM contacts response shape',
        );
      }

      final data = body['data'];
      if (data is! List) {
        throw DioException(
          requestOptions: res.requestOptions,
          error: 'Invalid CRM contacts response data',
        );
      }

      for (var j = 0; j < chunk.length && j < data.length; j++) {
        final payload = chunk[j];
        final result = data[j];
        if (result is! Map<String, dynamic>) continue;
        final contactId = result['id']?.toString() ?? '';
        if (contactId.isEmpty) continue;

        final updatedAtRaw = result['updated_at']?.toString();
        final updatedAt = updatedAtRaw != null
            ? DateTime.tryParse(updatedAtRaw)?.toUtc()
            : null;
        final phones = payload['phones'];
        final emails = payload['emails'];

        await db.upsertCustomer(
          CustomersCompanion.insert(
            id: drift.Value(contactId),
            name: payload['display_name']?.toString() ?? 'Contact',
            phone: drift.Value(_firstString(phones)),
            email: drift.Value(_firstString(emails)),
            synced: const drift.Value(true),
            updatedAt: drift.Value(updatedAt ?? DateTime.now().toUtc()),
          ),
        );
      }
    }

    await secureStorage.write(
      key: _contactsSyncKey,
      value: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    _retryTimer?.cancel();
  }

  List<Map<String, dynamic>> _buildContactPayloads(List<Contact> contacts) {
    final payloads = <Map<String, dynamic>>[];
    for (final contact in contacts) {
      final name = contact.displayName.trim();
      final phones = _uniquePhones(contact.phones);
      final emails = _uniqueEmails(contact.emails);

      if (name.isEmpty && phones.isEmpty && emails.isEmpty) {
        continue;
      }

      final displayName = name.isNotEmpty
          ? name
          : (phones.isNotEmpty ? phones.first : emails.first);

      final externalId = _truncate(contact.id, 255);

      payloads.add({
        'id': _uuid.v4(),
        'display_name': _truncate(displayName, 255),
        'phones': phones,
        'emails': emails,
        'external_source': 'device',
        'external_id': externalId,
        'source': 'device',
        'shared_with_business': true,
      });
    }
    return payloads;
  }

  List<String> _uniquePhones(List<Phone> phones) {
    final seen = <String>{};
    final out = <String>[];
    for (final phone in phones) {
      final raw = phone.number.trim();
      if (raw.isEmpty) continue;
      final normalized = _normalizePhone(raw);
      if (normalized == null) continue;
      if (seen.add(normalized)) {
        out.add(_truncate(raw, 64));
      }
    }
    return out;
  }

  List<String> _uniqueEmails(List<Email> emails) {
    final seen = <String>{};
    final out = <String>[];
    for (final email in emails) {
      final raw = email.address.trim().toLowerCase();
      if (raw.isEmpty) continue;
      if (seen.add(raw)) {
        out.add(_truncate(raw, 255));
      }
    }
    return out;
  }

  String? _normalizePhone(String input) {
    if (input.trim().isEmpty) return null;
    final normalized = normalizeUgPhone(input);
    if (normalized.isNotEmpty) {
      return '+$normalized';
    }
    return null;
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }

  String? _firstString(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return value.first?.toString();
    }
    return null;
  }
}
