import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../app_providers.dart';
import '../db/app_database.dart';
import '../network/pos_dtos.dart';
import '../network/seller_api.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(sellerApiProvider);
  return SyncService(db: db, sellerApi: api);
});

class SyncService {
  SyncService({required this.db, required this.sellerApi});

  final AppDatabase db;
  final SellerApi sellerApi;
  StreamSubscription<dynamic>? _connectivitySub;
  Timer? _retryTimer;
  bool _isPumping = false;
  bool _pumpQueued = false;
  Future<void>? _pullInFlight;

  void start() {
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((_) => _pump());
    _retryTimer ??= Timer.periodic(const Duration(minutes: 5), (_) => _pump());
  }

  Future<void> syncNow() => _pump();

  Future<void> primeOfflineData() async {
    await pullPosDelta();
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
      final List<ConnectivityResult> list = await Connectivity().checkConnectivity();
      final online =
          list.contains(ConnectivityResult.mobile) || list.contains(ConnectivityResult.wifi);
      if (!online) return;

      final queue = await db.pendingSyncOps();
      for (final op in queue) {
        if (!_isDue(op)) continue;
        try {
          await _dispatch(op);
          await db.markSynced(op.id);
        } catch (_) {
          await db.markSyncFailed(op.id, retryCount: op.retryCount + 1);
        }
      }

      // After pushing, pull server deltas for reconciliation.
      try {
        await pullPosDelta();
      } catch (_) {
        // Best effort: next pump will retry.
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

  Future<void> _dispatch(SyncOp op) async {
    final payload = jsonDecode(op.payload) as Map<String, dynamic>;
    switch (op.opType) {
      case 'item_create':
      case 'item_update':
        final localId = payload['local_id'] as String?;
        if (op.opType == 'item_create') {
          await sellerApi.createProduct(payload);
        } else {
          final productId = payload['remote_id']?.toString() ?? payload['local_id']?.toString() ?? '';
          await sellerApi.updateProduct(productId, payload);
        }
        if (localId != null) {
          await db.markItemSynced(localId);
        }
        break;
      case 'item_delete':
        final productId = payload['remote_id']?.toString() ?? payload['product_id']?.toString() ?? '';
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
          final serviceId = payload['remote_id']?.toString() ?? payload['local_id']?.toString() ?? '';
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
        final key = payload['idempotency_key']?.toString() ?? payload['entry_id']?.toString() ?? '';
        final res = await sellerApi.pushLedgerEntry(payload, idempotencyKey: key);
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
          await db.markLedgerSynced(entryId, jsonEncode({
            'server_entry_id': ack.serverEntryId,
            'idempotency_key': ack.idempotencyKey,
            'received_at': ack.receivedAt.toIso8601String(),
          }));
        }
        break;
      case 'stock_adjust':
        await sellerApi.updateProduct(payload['product_id'].toString(), payload);
        break;
      case 'cash_movement_push':
        final key = payload['idempotency_key']?.toString() ?? payload['movement_id']?.toString() ?? '';
        if (key.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing idempotency_key for cash movement',
          );
        }
        final body = Map<String, dynamic>.from(payload)..remove('idempotency_key');
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
        final body = Map<String, dynamic>.from(payload)..remove('idempotency_key');
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
    final productsSince = await db.getLastPulledAt('products');
    final servicesSince = await db.getLastPulledAt('services');
    final customersSince = await db.getLastPulledAt('customers');
    final configSince = await db.getLastPulledAt('config');

    DateTime since = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final cursors = [productsSince, servicesSince, customersSince, configSince];
    if (cursors.every((c) => c != null)) {
      since = cursors.cast<DateTime>().reduce((a, b) => a.isBefore(b) ? a : b);
    }

    final res = await sellerApi.pullPosSync(since: since);
    if (res.data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: res.requestOptions,
        error: 'Invalid sync pull response shape',
      );
    }

    final pull = PosSyncPullResponse.fromJson(res.data as Map<String, dynamic>);

    for (final p in pull.products) {
      if (p.id.isEmpty) continue;
      await db.upsertItem(
        ItemsCompanion.insert(
          id: drift.Value(p.id),
          name: p.name.isEmpty ? 'Product' : p.name,
          price: p.unitPrice,
          stockQty: drift.Value(p.currentStock),
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
          publishedOnline: drift.Value(s.published),
          updatedAt: drift.Value(s.updatedAt ?? DateTime.now().toUtc()),
          synced: const drift.Value(true),
        ),
      );
    }

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

    await Future.wait([
      db.setLastPulledAt('products', pull.receivedAt),
      db.setLastPulledAt('services', pull.receivedAt),
      db.setLastPulledAt('customers', pull.receivedAt),
      db.setLastPulledAt('config', pull.receivedAt),
    ]);
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

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    _retryTimer?.cancel();
  }
}
