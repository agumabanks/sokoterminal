import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../app_providers.dart';
import '../db/app_database.dart';
import '../media/offline_media_cache.dart';
import '../network/pos_dtos.dart';
import '../settings/business_profile_cache.dart';
import '../../features/orders/marketplace_order.dart';
import '../util/ledger_sync_utils.dart';
import '../util/phone_normalizer.dart';
import '../util/service_publish_utils.dart';
import '../util/service_pricing_utils.dart';
import '../network/seller_api.dart';
import '../telemetry/bug_logger.dart';
import '../telemetry/bug_report_sync.dart';
import '../telemetry/telemetry.dart';
import '../network/dio_auth_utils.dart';
import '../storage/secure_storage.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(sellerApiProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  final service = SyncService(db: db, sellerApi: api, secureStorage: secureStorage);
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

const _uuid = Uuid();

/// Result of an immediate catalog sync attempt.
enum CatalogSyncOutcome { synced, queuedOffline, skippedBusy }

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
  Timer? _foregroundTimer;
  bool _isPumping = false;
  bool _pumpQueued = false;
  bool _bookingsRouteAvailable = true;
  bool _wasOffline = false;
  bool _isDisposed = false;
  Future<void>? _pullInFlight;
  DateTime? _lastCatalogMutationAt;

  void _safeAddStatus(String status) {
    if (!_isDisposed && !_syncStatusController.isClosed) {
      _syncStatusController.add(status);
    }
  }
  static const _contactsSyncKey = 'device_contacts_synced_at';
  static const _contactsOptInKey = 'device_contacts_opt_in';
  static const _contactsSyncInterval = Duration(hours: 4); // reduced from 12h
  static const _contactsCountKey = 'device_contacts_last_count';
  static const _lastCrmContactsPullKey = 'last_crm_contacts_pull_at';
  static const _maxCatalogSyncAge = Duration(days: 4);
  static const List<String> _pullCursorKeys = [
    'products',
    'services',
    'customers',
    'business_profile',
    'config',
    'service_variants',
    'service_packages',
    'customer_packages',
    'package_redemptions',
    'suppliers',
    'expenses',
    'quotations',
    'shifts',
    'cash_movements',
    'settings',
    'receipt_templates',
    'quotation_templates',
    'ledger_entries',
  ];

  static const _catalogOpTypes = <String>{
    'item_create',
    'item_update',
    'item_delete',
    'service_create',
    'service_update',
    'service_delete',
    'service_variant_push',
    'service_variant_create',
    'service_variant_update',
    'service_variant_delete',
  };

  void start() {
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen(
      (results) async {
        final online = results.any((r) => r != ConnectivityResult.none);
        if (online) {
          if (_wasOffline) {
            if (kDebugMode) {
              debugPrint(
                '[SyncService] Back online — prioritizing catalog sync',
              );
            }
            unawaited(syncCatalogImmediately(notify: true));
          } else {
            _pump();
          }
        }
        _wasOffline = !online;
      },
    );
    _retryTimer ??= Timer.periodic(const Duration(minutes: 5), (_) => _pump());
    // Aggressive foreground polling for near-real-time multi-device sync.
    // The OS naturally throttles this timer when the app is backgrounded.
    _foregroundTimer ??= Timer.periodic(const Duration(seconds: 15), (_) => _pump());

    // Reconcile any ledger entries that were created offline but never got
    // a corresponding sync op enqueued (e.g., due to app crash).
    unawaited(_reconcileUnsyncedLedgerEntries());

    // Every launch should reconcile local POS data with the seller's cloud
    // account. If the catalog is stale, bootstrap again from epoch.
    unawaited(_ensureInitialDataLoaded());
  }

  Future<void> _reconcileUnsyncedLedgerEntries() async {
    try {
      final unsynced = await db.pendingLedgerEntries();
      if (unsynced.isEmpty) return;

      final allOps = await db.select(db.syncOps).get();
      final needingPush = ledgerEntriesNeedingPush(
        unsynced: unsynced,
        syncOps: allOps,
      );

      var enqueued = 0;
      for (final entry in needingPush) {
        final bundle = await db.fetchLedgerEntryBundle(entry.id);
        if (bundle == null) continue;

        await db.enqueueSync(
          'ledger_push',
          jsonEncode(buildLedgerPushPayload(bundle)),
        );
        enqueued++;
      }

      if (kDebugMode && enqueued > 0) {
        debugPrint(
          '[SyncService] Reconciled $enqueued orphaned ledger entries',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncService] Ledger reconciliation failed: $e');
      }
    }
  }

  Future<void> _ensureInitialDataLoaded() async {
    try {
      final items = await db.getAllItems();
      final services = await db.getAllServices();
      final lastCatalogSync = await _oldestLastPulledAt(_pullCursorKeys);
      final now = DateTime.now().toUtc();
      final catalogStale =
          lastCatalogSync == null ||
          now.difference(lastCatalogSync.toUtc()) > _maxCatalogSyncAge;
      final needsBootstrap = items.isEmpty && services.isEmpty;

      if (needsBootstrap || catalogStale) {
        if (kDebugMode) {
          debugPrint(
            '[SyncService] Triggering full catalog sync (needsBootstrap: $needsBootstrap, catalogStale: $catalogStale, items: ${items.length}, services: ${services.length})',
          );
        }
        await forceFullResync();
      } else {
        if (kDebugMode) {
          debugPrint(
            '[SyncService] Catalog warm start (${items.length} items, ${services.length} services) - running delta sync',
          );
        }
        await _pump();
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (DioAuthUtils.isAuthStatus(status)) {
        if (kDebugMode) {
          debugPrint(
            '[SyncService] Auth required before initial catalog load; '
            'deferring sync until login.',
          );
        }
        DioAuthUtils.notifySyncDeferred();
        return;
      }
      rethrow;
    }
  }

  Future<DateTime?> _oldestLastPulledAt(Iterable<String> keys) async {
    DateTime? oldest;
    for (final key in keys) {
      final value = await db.getLastPulledAt(key);
      if (value == null) return null;
      oldest = oldest == null || value.isBefore(oldest) ? value : oldest;
    }
    return oldest;
  }

  /// Test hook: dispatches one sync op without connectivity/rate-limit guards.
  Future<void> dispatchSyncOpForTest(SyncOp op) async {
    await _dispatch(op);
  }

  Future<void> syncNow() async {
    // Reset only stale failed/blocked sync operations — preserve backoff for
    // ops that recently failed (e.g. HTTP 429) so we don't hammer the server.
    try {
      final resetCount = await db.resetStalePendingSyncOps(
        const Duration(seconds: 30),
      );
      if (kDebugMode && resetCount > 0) {
        debugPrint(
          '[SyncService] Reset $resetCount stale sync operations for retry',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncService] Failed to reset sync ops: $e');
      }
    }
    await _pump();
  }

  /// Push catalog changes (products, services, variants) immediately.
  /// When offline, ops remain queued and fire on reconnect.
  Future<CatalogSyncOutcome> syncCatalogImmediately({bool notify = false}) async {
    final list = await Connectivity().checkConnectivity();
    final online = list.any((r) => r != ConnectivityResult.none);
    if (!online) {
      _safeAddStatus('Offline — catalog queued');
      if (notify) DioAuthUtils.notifyCatalogQueued();
      return CatalogSyncOutcome.queuedOffline;
    }

    if (_isPumping) {
      _pumpQueued = true;
      return CatalogSyncOutcome.skippedBusy;
    }

    try {
      await db.resetStalePendingSyncOps(const Duration(seconds: 5));
    } catch (_) {}

    await unblockRetriableCatalogOps();
    await _deduplicatePendingCatalogOps();
    await _pushCatalogOpsOnly();

    try {
      await pullPosDelta();
    } catch (e) {
      if (e is DioException && DioAuthUtils.isAuthError(e)) {
        DioAuthUtils.notifySyncDeferred();
      }
    }

    if (notify) DioAuthUtils.notifyCatalogSynced();
    return CatalogSyncOutcome.synced;
  }

  Future<void> _pushCatalogOpsOnly() async {
    if (_isDisposed) return;

    _isPumping = true;
    try {
      _safeAddStatus('Syncing catalog...');
      final queue = await db.pendingSyncOps(limit: 200);
      final catalogQueue =
          queue.where((op) => _catalogOpTypes.contains(op.opType)).toList();

      if (kDebugMode) {
        debugPrint(
          '[SyncService] Catalog priority push: ${catalogQueue.length} ops',
        );
      }

      for (final op in catalogQueue) {
        if (!_isDue(op)) continue;
        try {
          _safeAddStatus('Pushing ${op.opType.replaceAll('_', ' ')}...');
          await _dispatch(op);
          await db.markSynced(op.id);
          await Future.delayed(const Duration(milliseconds: 200));
        } on DioException catch (e) {
          if (DioAuthUtils.isAuthError(e)) {
            DioAuthUtils.notifySyncDeferred();
            return;
          }
          final errorMsg = _formatSyncError(e);
          final nextRetry = op.retryCount + 1;
          if (_shouldBlock(e)) {
            await db.markSyncBlocked(
              op.id,
              retryCount: nextRetry,
              lastError: errorMsg,
            );
          } else {
            await db.markSyncFailed(
              op.id,
              retryCount: nextRetry,
              lastError: errorMsg,
            );
          }
        } catch (e) {
          final errorMsg = _formatSyncError(e);
          await db.markSyncFailed(
            op.id,
            retryCount: op.retryCount + 1,
            lastError: errorMsg,
          );
        }
      }
    } finally {
      _isPumping = false;
      _safeAddStatus('Idle');
      if (_pumpQueued) {
        _pumpQueued = false;
        unawaited(_pump());
      }
    }
  }

  /// Force a complete resync by clearing all sync cursors and pulling from epoch.
  /// This is useful when the initial sync failed or products are missing.
  Future<void> forceFullResync() async {
    if (kDebugMode) {
      debugPrint('[SyncService] Starting FULL RESYNC from epoch...');
    }

    // Clear all sync cursors
    await db.delete(db.syncCursors).go();
    if (kDebugMode) {
      debugPrint('[SyncService] Cleared all sync cursors');
    }

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
    // Trigger immediate pump for sub-second multi-device visibility.
    // If already pumping, the queued flag ensures a follow-up cycle.
    if (!_isPumping) {
      unawaited(_pump());
    } else {
      _pumpQueued = true;
    }
  }

  Future<bool> isDeviceContactsOptedIn() async {
    final raw = await secureStorage.read(key: _contactsOptInKey);
    return raw == '1' || raw?.toLowerCase() == 'true';
  }

  Future<void> setDeviceContactsOptIn(bool enabled) async {
    await secureStorage.write(
      key: _contactsOptInKey,
      value: enabled ? '1' : '0',
    );
  }

  Future<DateTime?> lastCrmContactsPullAt() async {
    final raw = await secureStorage.read(key: _lastCrmContactsPullKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> setLastCrmContactsPullAt(DateTime? time) async {
    if (time == null) {
      await secureStorage.delete(key: _lastCrmContactsPullKey);
    } else {
      await secureStorage.write(
        key: _lastCrmContactsPullKey,
        value: time.toUtc().toIso8601String(),
      );
    }
  }

  Future<void> _pump() async {
    if (_isDisposed || _isPumping) {
      _pumpQueued = true;
      return;
    }

    _isPumping = true;
    try {
      _safeAddStatus('Syncing data...');
      final List<ConnectivityResult> list = await Connectivity()
          .checkConnectivity();
      final online = list.any((r) => r != ConnectivityResult.none);
      if (!online) return;

      // Automatically retry blocked catalog ops that may have failed due to
      // transient issues (duplicate SKU, temporary validation errors, etc.).
      // This prevents products from being stuck local-only forever.
      await unblockRetriableCatalogOps();

      // Deduplicate: if the same item/service has multiple pending ops,
      // keep only the newest one and discard the older redundant ops.
      await _deduplicatePendingCatalogOps();

      const batchSize = 100;
      final queue = await db.pendingSyncOps(limit: batchSize);
      if (kDebugMode) {
        debugPrint(
          '[SyncService] Sync queue: ${queue.length} pending operations',
        );
        if (queue.isNotEmpty) {
          final typeCounts = <String, int>{};
          for (final op in queue) {
            typeCounts[op.opType] = (typeCounts[op.opType] ?? 0) + 1;
          }
          debugPrint('[SyncService] Queue breakdown: $typeCounts');
        }
      }

      var processedInBatch = 0;
      for (final op in queue) {
        if (processedInBatch >= batchSize) break;
        if (!_isDue(op)) {
          if (kDebugMode) {
            debugPrint(
              '[SyncService] Skipping ${op.opType} (not due yet, retry: ${op.retryCount})',
            );
          }
          continue;
        }

        if (kDebugMode) {
          debugPrint(
            '[SyncService] Processing ${op.opType} (id: ${op.id}, retry: ${op.retryCount})',
          );
        }

        try {
          _safeAddStatus(
            'Pushing ${op.opType.replaceAll('_', ' ')}...',
          );
          await _dispatch(op);
          await db.markSynced(op.id);
          processedInBatch++;
          if (kDebugMode) {
            debugPrint('[SyncService] ✅ ${op.opType} synced successfully');
          }
          // Small delay between ops to avoid request bursts that trigger
          // server-side rate limiting (seller-write throttle = 120/min).
          if (processedInBatch < queue.length) {
            await Future.delayed(const Duration(milliseconds: 300));
          }
        } catch (e) {
          final errorMsg = _formatSyncError(e);
          final nextRetryCount = op.retryCount + 1;
          const maxRetryCount = 20;

          if (nextRetryCount > maxRetryCount) {
            final permanentError =
                'Permanently blocked after $maxRetryCount retries: $errorMsg';
            await db.markSyncBlocked(
              op.id,
              retryCount: nextRetryCount,
              lastError: permanentError,
            );
            if (kDebugMode) {
              debugPrint(
                '[SyncService] 🚫 ${op.opType} permanently blocked after $maxRetryCount retries',
              );
            }
            final telemetry = Telemetry.instance;
            if (telemetry != null) {
              unawaited(
                telemetry.event(
                  'sync_op_permanently_blocked',
                  props: {
                    'op_type': op.opType,
                    'retry_count': nextRetryCount,
                    'error': errorMsg,
                  },
                ),
              );
            }
            continue;
          }

          final blocked = _shouldBlock(e);

          if (kDebugMode) {
            debugPrint('[SyncService] ❌ ${op.opType} failed: $errorMsg');
            debugPrint(
              '[SyncService] ${blocked ? "BLOCKED" : "Will retry"} (retry: $nextRetryCount)',
            );
          }

          if (blocked) {
            await db.markSyncBlocked(
              op.id,
              retryCount: nextRetryCount,
              lastError: errorMsg,
            );
          } else {
            await db.markSyncFailed(
              op.id,
              retryCount: nextRetryCount,
              lastError: errorMsg,
            );
          }
          final telemetry = Telemetry.instance;
          if (telemetry != null) {
            unawaited(
              telemetry.event(
                blocked ? 'sync_op_blocked' : 'sync_op_failed',
                props: {
                  'op_type': op.opType,
                  'retry_count': nextRetryCount,
                  'error': errorMsg,
                },
              ),
            );
          }
          int? statusCode;
          String? endpoint;
          if (e is DioException) {
            statusCode = e.response?.statusCode;
            endpoint = e.requestOptions.path;
          }
          unawaited(
            BugLogger.instance.logSyncError(
              operation: op.opType,
              endpoint: endpoint ?? op.opType,
              error: e,
              statusCode: statusCode,
              retryCount: nextRetryCount,
            ),
          );
        }
      }

      // If we hit the batch limit, queue another pump immediately.
      if (queue.length >= batchSize) {
        _pumpQueued = true;
      }

      // After pushing, pull server deltas for reconciliation.
      try {
        await pullPosDelta();
      } catch (_) {
        // Best effort: next pump will retry.
      }

      // Keep operational queues warm (Inbox).
      try {
        await pullMarketplaceOrders();
      } catch (_) {}
      if (_bookingsRouteAvailable) {
        try {
          await pullServiceBookings();
        } catch (_) {}
      }

      try {
        await pullAvailability();
      } catch (_) {}

      try {
        await pullAvailabilityExceptions();
      } catch (_) {}

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

      try {
        await pullCrmContacts();
      } catch (_) {
        // Best effort: CRM pull should not block POS sync.
      }

      try {
        await BugReportSync.uploadPending(sellerApi);
      } catch (_) {
        // Best effort: feedback upload should not block POS sync.
      }
    } catch (e, st) {
      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(telemetry.recordError(e, st, hint: 'sync_pump'));
      }
    } finally {
      _isPumping = false;
      _safeAddStatus('Idle');
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

  /// Enforce a minimum gap between catalog mutations to avoid triggering
  /// the server's `seller-write` rate limit (120/min).
  static const _minCatalogMutationGap = Duration(milliseconds: 500);

  Future<void> _enforceCatalogRateLimit() async {
    final last = _lastCatalogMutationAt;
    if (last != null) {
      final elapsed = DateTime.now().toUtc().difference(last);
      if (elapsed < _minCatalogMutationGap) {
        final wait = _minCatalogMutationGap - elapsed;
        await Future.delayed(wait);
      }
    }
    _lastCatalogMutationAt = DateTime.now().toUtc();
  }

  /// If the same item or service has multiple pending ops in the queue,
  /// keep only the most recent one and delete the older duplicates.
  /// This prevents redundant network traffic (e.g. item_update after
  /// item_create for the same product) and reduces rate-limit pressure.
  Future<void> _deduplicatePendingCatalogOps() async {
    const catalogOps = {
      'item_create',
      'item_update',
      'service_create',
      'service_update',
    };

    try {
      final pending = await db.pendingSyncOps();
      final byLocalId = <String, List<SyncOp>>{};

      for (final op in pending) {
        if (!catalogOps.contains(op.opType)) continue;
        try {
          final payload = jsonDecode(op.payload) as Map<String, dynamic>;
          final localId = payload['local_id']?.toString();
          if (localId != null && localId.isNotEmpty) {
            byLocalId.putIfAbsent('$localId:${op.opType}', () => []).add(op);
          }
        } catch (_) {
          // Malformed payload — skip deduplication for this op.
        }
      }

      var deleted = 0;
      for (final ops in byLocalId.values) {
        if (ops.length <= 1) continue;
        // Sort by createdAt ascending; keep the newest.
        ops.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        for (final old in ops.take(ops.length - 1)) {
          await db.deleteSyncOp(old.id);
          deleted++;
        }
      }

      if (kDebugMode && deleted > 0) {
        debugPrint(
          '[SyncService] Deduplicated $deleted redundant catalog sync ops',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncService] Catalog deduplication failed: $e');
      }
    }
  }

  /// Reset blocked catalog ops (item_create, item_update, service_create,
  /// service_update) back to pending so they can be retried automatically.
  /// Ops are only unblocked if they have not exceeded [maxRetries] and are
  /// older than [minAgeSinceLastTry]. This prevents hammering the server
  /// with permanently bad payloads while fixing transient failures.
  /// Unblocks catalog sync ops that failed transiently so they can be retried
  /// automatically during the periodic sync pump.
  /// [maxRetries] and [minAgeSinceLastTry] are overridable for testing.
  Future<void> unblockRetriableCatalogOps({
    int maxRetries = 20,
    Duration minAgeSinceLastTry = const Duration(hours: 1),
  }) async {
    const catalogOps = {
      'item_create',
      'item_update',
      'service_create',
      'service_update',
    };

    try {
      final blocked = await db.blockedSyncOps();
      final now = DateTime.now().toUtc();
      var unblockedCount = 0;

      for (final op in blocked) {
        if (!catalogOps.contains(op.opType)) continue;
        if (op.retryCount >= maxRetries) continue;

        final lastTried = op.lastTriedAt;
        if (lastTried != null &&
            now.difference(lastTried) < minAgeSinceLastTry) {
          continue;
        }

        await db.setSyncOpPending(op.id);
        unblockedCount++;
        if (kDebugMode) {
          debugPrint(
            '[SyncService] ▶️ Unblocked ${op.opType} '
            '(id: ${op.id}, retry: ${op.retryCount}) for retry',
          );
        }
      }

      if (kDebugMode && unblockedCount > 0) {
        debugPrint(
          '[SyncService] Unblocked $unblockedCount catalog ops for retry',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncService] Failed to unblock catalog ops: $e');
      }
    }
  }

  Future<void> _pushTemplates() async {
    final unsyncedReceipts = await (db.select(
      db.receiptTemplates,
    )..where((t) => t.synced.not())).get();
    final unsyncedQuotations = await (db.select(
      db.quotationTemplates,
    )..where((t) => t.synced.not())).get();

    if (unsyncedReceipts.isEmpty && unsyncedQuotations.isEmpty) return;

    final receiptPayload = unsyncedReceipts
        .map(
          (t) => {
            'id': t.id,
            'name': t.name,
            'style': t.style,
            'header_message': t.headerText,
            'header_color': t.colorHex,
            'footer_message': t.footerText,
            'show_logo': t.showLogo,
            'show_qr': t.showQr,
            'is_active': t.isActive,
          },
        )
        .toList();

    final quotationPayload = unsyncedQuotations
        .map(
          (t) => {
            'id': t.id,
            'name': t.name,
            'style': t.style,
            'header_message': t.headerText,
            'header_color': t.colorHex,
            'footer_message': t.footerText,
            'show_logo': t.showLogo,
            'show_qr': t.showQr,
            'is_active': t.isActive,
          },
        )
        .toList();

    await sellerApi.batchUpsertTemplates(
      receiptTemplates: receiptPayload,
      quotationTemplates: quotationPayload,
    );

    // Mark synced
    for (final t in unsyncedReceipts) {
      await (db.update(db.receiptTemplates)
            ..where((tbl) => tbl.id.equals(t.id)))
          .write(const ReceiptTemplatesCompanion(synced: drift.Value(true)));
    }
    for (final t in unsyncedQuotations) {
      await (db.update(db.quotationTemplates)
            ..where((tbl) => tbl.id.equals(t.id)))
          .write(const QuotationTemplatesCompanion(synced: drift.Value(true)));
    }
  }

  String _formatSyncError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final path = error.requestOptions.path;
      String? serverMessage;
      final data = error.response?.data;
      if (data is Map) {
        final msg = data['message'] ?? data['error'] ?? data['detail'];
        if (msg != null) {
          serverMessage = msg.toString();
        }
        final conflicts = data['conflicts'];
        if (conflicts is List && conflicts.isNotEmpty) {
          final suffix = 'conflicts: ${conflicts.length}';
          final base = serverMessage;
          serverMessage = base == null || base.trim().isEmpty
              ? suffix
              : '$base • $suffix';
        }
      }

      final message =
          serverMessage ??
          error.message ??
          error.error?.toString() ??
          'DioException';
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

  bool _shouldBlock(Object error) {
    if (error is! DioException) return false;
    final status = error.response?.statusCode;
    if (status == null) return false;
    if (status >= 500) return false;
    if (status == 401) return false; // Auth handled by interceptor; allow retry after re-auth.
    if (status == 404) return false; // Server-side delete or missing resource; don't block forever.
    if (status == 408) return false;
    if (status == 429) return false; // Rate-limiting is transient; retry with backoff.
    if (status == 409) {
      final data = error.response?.data;
      final msg = (data is Map ? data['message']?.toString() : null) ?? '';
      final normalized = msg.toLowerCase();
      if (normalized.contains('still being processed')) return false;
      if (normalized.contains('referenced sale') &&
          normalized.contains('not found')) {
        return false;
      }
      if (normalized.contains('sync the original sale first')) return false;
      if (data is Map) {
        final conflicts = data['conflicts'];
        if (conflicts is List && conflicts.isNotEmpty) {
          return true;
        }
      }
      return true;
    }
    return true;
  }

  bool _isRetryableUploadError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 429) return true;
    if (status != null && status >= 500) return true;
    if (status == null) return true;
    final type = e.type;
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.connectionError) {
      return true;
    }
    return false;
  }

  Future<int?> _resolveRemoteProductId(dynamic raw) async {
    if (raw == null) return null;
    final asInt = _asNullableInt(raw);
    if (asInt != null) return asInt;
    final id = raw.toString().trim();
    if (id.isEmpty) return null;
    final item = await db.getItemById(id);
    final remoteId = item?.remoteId ?? _asNullableInt(id);
    if (remoteId != null || item == null) {
      return remoteId;
    }

    // Self-heal wedged ledger entries by pushing missing local catalog rows
    // before retrying the sale.
    await _enforceCatalogRateLimit();
    final res = await sellerApi.upsertPosCatalogProduct(
      _buildDeferredItemCreatePayload(item),
      idempotencyKey: item.id,
    );
    if (res.data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: res.requestOptions,
        error: 'Invalid product upsert response shape',
      );
    }
    final productId = _asNullableInt(
      (res.data as Map<String, dynamic>)['product_id'],
    );
    if (productId == null) {
      throw DioException(
        requestOptions: res.requestOptions,
        error: 'Missing product_id in product upsert response',
      );
    }
    await db.markItemSyncedWithRemoteId(item.id, productId);
    await _pushItemVariantStocks(item.id, productId);
    return productId;
  }

  Future<int?> _resolveRemoteProductIdByName(String rawName) async {
    final name = rawName.trim().toLowerCase();
    if (name.isEmpty) return null;
    final items = await db.getAllItems();
    for (final item in items) {
      if (item.name.trim().toLowerCase() != name) continue;
      if (item.remoteId != null) return item.remoteId;
      final resolved = await _resolveRemoteProductId(item.id);
      if (resolved != null) return resolved;
    }
    return null;
  }

  Future<int?> _resolveRemoteServiceId(dynamic raw) async {
    if (raw == null) return null;
    final asInt = _asNullableInt(raw);
    if (asInt != null) return asInt;
    final id = raw.toString().trim();
    if (id.isEmpty) return null;
    final service = await db.getServiceById(id);
    final remoteId = service?.remoteId ?? _asNullableInt(id);
    if (remoteId != null || service == null) {
      return remoteId;
    }

    await _enforceCatalogRateLimit();
    final res = await sellerApi.createService(
      _buildDeferredServiceCreatePayload(service),
      idempotencyKey: service.id,
    );
    if (res.data is! Map) {
      throw DioException(
        requestOptions: res.requestOptions,
        error: 'Invalid service create response shape',
      );
    }
    final body = Map<String, dynamic>.from(res.data as Map);
    final data = body['data'];
    final serviceId = data is Map
        ? _asNullableInt(data['id'])
        : _asNullableInt(body['id']);
    if (serviceId == null) {
      throw DioException(
        requestOptions: res.requestOptions,
        error: 'Missing service id in create response',
      );
    }
    await db.markServiceSyncedWithRemoteId(service.id, serviceId);
    return serviceId;
  }

  Future<int?> _resolveRemoteServiceIdByTitle(String rawTitle) async {
    final title = rawTitle.trim().toLowerCase();
    if (title.isEmpty) return null;
    final services = await db.getAllServices();
    for (final service in services) {
      if (service.title.trim().toLowerCase() != title) continue;
      if (service.remoteId != null) return service.remoteId;
      final resolved = await _resolveRemoteServiceId(service.id);
      if (resolved != null) return resolved;
    }
    return null;
  }

  Map<String, dynamic> _buildDeferredItemCreatePayload(Item item) {
    final payload = <String, dynamic>{
      'name': item.name,
      'unit_price': item.price,
      if (item.cost != null) 'purchase_price': item.cost,
      'current_stock': item.stockQty,
      'published': item.publishedOnline,
      'unit': (item.unit ?? '').trim().isEmpty ? 'pc' : item.unit,
      'min_qty': item.minPurchaseQty,
      'refundable': item.refundable,
      'cash_on_delivery': item.cashOnDelivery,
    };
    if (item.categoryId != null) {
      payload['category_id'] = item.categoryId;
    }
    if (item.brandId != null) {
      payload['brand_id'] = item.brandId;
    }
    if (item.weight != null) {
      payload['weight'] = item.weight;
    }
    if ((item.description ?? '').trim().isNotEmpty) {
      payload['description'] = item.description!.trim();
    }
    if ((item.sku ?? '').trim().isNotEmpty) {
      payload['sku'] = item.sku!.trim();
    }
    if ((item.barcode ?? '').trim().isNotEmpty) {
      payload['barcode'] = item.barcode!.trim();
    }
    if (item.discount != null) {
      payload['discount'] = item.discount;
      payload['discount_type'] = item.discountType == 'flat'
          ? 'amount'
          : 'percent';
    }
    if (item.shippingDays != null) {
      payload['est_shipping_days'] = item.shippingDays;
    }
    if (item.shippingFee != null) {
      payload['shipping_cost'] = item.shippingFee;
    }
    if (item.lowStockWarning != null) {
      payload['low_stock_quantity'] = item.lowStockWarning;
    }
    return payload;
  }

  Map<String, dynamic> _buildDeferredServiceCreatePayload(Service service) {
    final packages = _servicePackagesPayload(service);
    return {
      'title': service.title,
      if ((service.summary ?? '').trim().isNotEmpty)
        'summary': service.summary!.trim(),
      if ((service.description ?? '').trim().isNotEmpty)
        'description': service.description!.trim(),
      'base_price': service.price,
      if (service.cost != null) 'purchase_price': service.cost,
      if (service.categoryId != null) 'category_id': service.categoryId,
      if ((service.serviceType ?? '').trim().isNotEmpty)
        'service_type': service.serviceType!.trim(),
      if ((service.deliveryTimeframe ?? '').trim().isNotEmpty)
        'delivery_timeframe': service.deliveryTimeframe!.trim(),
      if (service.durationMinutes != null)
        'duration_minutes': service.durationMinutes,
      if (packages.isNotEmpty) 'packages': packages,
      'is_published': service.publishedOnline,
    };
  }

  Future<void> _applyServiceApiResponse(
    String localId,
    Map<String, dynamic> body,
  ) async {
    final data = body['data'];
    if (data is! Map) return;

    final dataMap = Map<String, dynamic>.from(data);
    final update = parseServiceModerationFromApiResponse(body);

    await db.updateServiceFields(
      localId,
      ServicesCompanion(
        moderationStatus: update.moderationStatus != null
            ? drift.Value(update.moderationStatus)
            : const drift.Value.absent(),
        publishedOnline: update.publishedOnline != null
            ? drift.Value(update.publishedOnline!)
            : const drift.Value.absent(),
        slug: dataMap['slug'] != null
            ? drift.Value(dataMap['slug'].toString())
            : const drift.Value.absent(),
        updatedAt: drift.Value(DateTime.now().toUtc()),
      ),
    );
  }

  Map<String, dynamic> _servicePackagesPayload(Service service) {
    if ((service.pricingPackages ?? '').trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(service.pricingPackages!.trim());
      if (decoded is! List) return const {};
      final tiers = decoded
          .whereType<Map>()
          .map((e) => ServicePricingTier.fromJson(Map<String, dynamic>.from(e)))
          .where((t) => t.tier.isNotEmpty)
          .toList();
      return pricingPackagesForApi(tiers);
    } catch (_) {
      return const {};
    }
  }

  String? _toApiDiscountType(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim().toLowerCase();
    if (s == 'flat' || s == 'amount') return 'amount';
    if (s == 'percent' || s == 'percentage') return 'percent';
    return null;
  }

  Future<Map<String, dynamic>> _uploadImageFile(String filePath) async {
    final path = filePath.trim();
    if (path.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: 'file/upload'),
        error: 'Missing file path for upload',
      );
    }

    final file = File(path);
    if (!file.existsSync()) {
      throw DioException(
        requestOptions: RequestOptions(path: 'file/upload'),
        error: 'File not found: $path',
      );
    }

    const maxUploadRetries = 3;
    for (var attempt = 0; attempt <= maxUploadRetries; attempt++) {
      try {
        final res = await sellerApi.uploadSellerFile(file);
        if (res.data is! Map<String, dynamic>) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Invalid upload response shape',
          );
        }
        final data = res.data as Map<String, dynamic>;
        final ok = _asBool(data['result']);
        if (!ok) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: data['message']?.toString() ?? 'Upload failed',
          );
        }
        final id = _asNullableInt(data['id']);
        final url = data['url']?.toString();
        if (id == null || url == null || url.trim().isEmpty) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Upload succeeded but missing id/url',
          );
        }
        return {'id': id, 'url': url};
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        final isRateLimited = status == 429;
        final isServerError = status != null && status >= 500;
        final isNetworkError = status == null ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;
        final shouldRetry = isRateLimited || isServerError || isNetworkError;
        if (shouldRetry && attempt < maxUploadRetries) {
          final delay = Duration(seconds: 2 * (attempt + 1));
          if (kDebugMode) {
            debugPrint(
              '[SyncService] Image upload rate-limited (attempt ${attempt + 1}/'
              '${maxUploadRetries + 1}), retrying in ${delay.inSeconds}s...',
            );
          }
          await Future.delayed(delay);
          continue;
        }
        rethrow;
      }
    }
    // Should never reach here; all retries exhausted.
    throw DioException(
      requestOptions: RequestOptions(path: 'file/upload'),
      error: 'Image upload failed after $maxUploadRetries retries',
    );
  }

  List<String> _decodeStringList(String? raw) {
    if (raw == null) return const [];
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded
            .map((e) => e?.toString() ?? '')
            .where((e) => e.trim().isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  List<int> _decodeIntList(String? raw) {
    if (raw == null) return const [];
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded
            .map((e) => int.tryParse(e?.toString() ?? ''))
            .whereType<int>()
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> _pushItemVariantStocks(
    String localId,
    int remoteProductId,
  ) async {
    final item = await db.getItemById(localId);
    if (item == null) return;

    final stocks = await db.getItemStocksForItem(localId);
    final variants = stocks.where((s) => s.variant.trim().isNotEmpty).toList();
    if (variants.isEmpty) return;

    for (final s in variants) {
      final variant = s.variant.trim();
      if (variant.isEmpty) continue;

      await _enforceCatalogRateLimit();

      int? uploadId = s.imageUploadId;
      final imagePathOrUrl = (s.imageUrl ?? '').trim();
      if (imagePathOrUrl.isNotEmpty &&
          !(imagePathOrUrl.startsWith('http://') ||
              imagePathOrUrl.startsWith('https://'))) {
        final file = File(imagePathOrUrl);
        if (file.existsSync()) {
          final uploaded = await _uploadImageFile(imagePathOrUrl);
          uploadId = uploaded['id'] as int;
          final url = uploaded['url'] as String;
          await (db.update(db.itemStocks)..where(
                (t) => t.itemId.equals(localId) & t.variant.equals(variant),
              ))
              .write(
                ItemStocksCompanion(
                  imageUploadId: drift.Value(uploadId),
                  imageUrl: drift.Value(url),
                  updatedAt: drift.Value(DateTime.now().toUtc()),
                ),
              );
        } else {
          // Drop missing local file to avoid a stuck sync loop.
          await (db.update(db.itemStocks)..where(
                (t) => t.itemId.equals(localId) & t.variant.equals(variant),
              ))
              .write(
                ItemStocksCompanion(
                  imageUploadId: drift.Value(null),
                  imageUrl: drift.Value(null),
                  updatedAt: drift.Value(DateTime.now().toUtc()),
                ),
              );
        }
      }

      final sku = (s.sku ?? '').trim();
      final payload = <String, dynamic>{
        'product_id': remoteProductId,
        'name': item.name,
        'unit_price': s.price,
        'current_stock': s.stockQty,
        'variation': variant,
        if (sku.isNotEmpty) 'sku': sku,
        if (uploadId != null) 'thumbnail_upload_id': uploadId,
      };

      final safeVariantKey = variant.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]+'),
        '-',
      );
      await sellerApi.upsertPosCatalogProduct(
        payload,
        idempotencyKey: '$localId:$safeVariantKey',
      );
    }
  }

  Future<void> _dispatch(SyncOp op) async {
    final payload = jsonDecode(op.payload) as Map<String, dynamic>;

    if (op.opType.startsWith('order_status_update:')) {
      final orderId = _asInt(payload['order_id']);
      if (orderId <= 0) {
        throw DioException(
          requestOptions: RequestOptions(path: op.opType),
          error: 'Missing order_id for order status update',
        );
      }
      final delivery = (payload['delivery_status'] ?? payload['delivery'] ?? '')
          .toString()
          .trim();
      final payment = (payload['payment_status'] ?? payload['payment'] ?? '')
          .toString()
          .trim();
      if (delivery.isNotEmpty) {
        await sellerApi.updateOrderDeliveryStatus(
          orderId: orderId,
          status: delivery,
        );
      }
      if (payment.isNotEmpty) {
        await sellerApi.updateOrderPaymentStatus(
          orderId: orderId,
          status: payment,
        );
      }
      try {
        final res = await sellerApi.fetchOrderDetails(orderId);
        final raw = res.data;
        final listRaw = raw is Map<String, dynamic> ? raw['data'] : raw;
        final first = (listRaw is List && listRaw.isNotEmpty)
            ? listRaw.first
            : null;
        if (first is Map) {
          final details = MarketplaceOrder.fromJson(
            Map<String, dynamic>.from(first),
          );
          await _upsertMergedCachedOrder(details);
        }
      } catch (_) {}
      return;
    }

    if (op.opType.startsWith('booking_action:')) {
      final bookingId = _asInt(payload['booking_id']);
      if (bookingId <= 0) {
        throw DioException(
          requestOptions: RequestOptions(path: op.opType),
          error: 'Missing booking_id for booking action',
        );
      }
      final action = (payload['action'] ?? '').toString().trim().toLowerCase();
      switch (action) {
        case 'confirm':
          await sellerApi.confirmServiceBooking(bookingId);
          break;
        case 'complete':
          await sellerApi.completeServiceBooking(bookingId);
          break;
        case 'cancel':
          await sellerApi.cancelServiceBooking(
            bookingId,
            reason: payload['reason']?.toString(),
          );
          break;
        default:
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Unknown booking action "$action"',
          );
      }
      await pullServiceBookings();
      return;
    }

    if (op.opType == 'expense_category_create') {
      await sellerApi.pushExpenseCategory(
        payload,
        idempotencyKey: op.id.toString(),
      );
      return;
    }

    switch (op.opType) {
      case 'item_create':
      case 'item_update':
        final localId = payload['local_id']?.toString() ?? '';
        if (localId.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing local_id for item sync',
          );
        }

        final item = await db.getItemById(localId);
        final remoteId =
            _asNullableInt(payload['remote_id']) ??
            item?.remoteId ??
            _asNullableInt(localId);

        final apiDiscountType = _toApiDiscountType(
          payload['discount_type'] ?? item?.discountType,
        );

        final upsertPayload = <String, dynamic>{
          if (remoteId != null) 'product_id': remoteId,
          'name': (payload['name'] ?? item?.name ?? '').toString(),
          'unit_price': _asDouble(payload['unit_price'] ?? item?.price ?? 0),
          if (payload['purchase_price'] != null || item?.cost != null)
            'purchase_price': _asDouble(
              payload['purchase_price'] ?? item?.cost ?? 0,
            ),
          'current_stock': _asInt(
            payload['current_stock'] ?? item?.stockQty ?? 0,
          ),
          'published': _asBool(
            payload['published'] ?? item?.publishedOnline ?? false,
          ),
          if (_asNullableInt(payload['category_id']) != null)
            'category_id': _asNullableInt(payload['category_id']),
          if (_asNullableInt(payload['brand_id']) != null)
            'brand_id': _asNullableInt(payload['brand_id']),
          if ((payload['unit'] ?? item?.unit) != null)
            'unit': (payload['unit'] ?? item?.unit).toString(),
          if (payload['weight'] != null || item?.weight != null)
            'weight': _asDouble(payload['weight'] ?? item?.weight ?? 0),
          if (payload['min_qty'] != null || item?.minPurchaseQty != null)
            'min_qty': _asInt(payload['min_qty'] ?? item?.minPurchaseQty ?? 1),
          if (payload['low_stock_quantity'] != null ||
              item?.lowStockWarning != null)
            'low_stock_quantity': _asInt(
              payload['low_stock_quantity'] ?? item?.lowStockWarning ?? 0,
            ),
          if (payload['discount'] != null || item?.discount != null)
            'discount': _asDouble(payload['discount'] ?? item?.discount ?? 0),
          if (apiDiscountType != null) 'discount_type': apiDiscountType,
          if (payload['shipping_cost'] != null || item?.shippingFee != null)
            'shipping_cost': _asDouble(
              payload['shipping_cost'] ?? item?.shippingFee ?? 0,
            ),
          if (payload['est_shipping_days'] != null ||
              item?.shippingDays != null)
            'est_shipping_days': _asInt(
              payload['est_shipping_days'] ?? item?.shippingDays ?? 0,
            ),
          if (payload['refundable'] != null || item?.refundable != null)
            'refundable': _asBool(
              payload['refundable'] ?? item?.refundable ?? false,
            ),
          if (payload['cash_on_delivery'] != null ||
              item?.cashOnDelivery != null)
            'cash_on_delivery': _asBool(
              payload['cash_on_delivery'] ?? item?.cashOnDelivery ?? true,
            ),
          if (payload['tags'] != null) 'tags': payload['tags'],
          if (payload['description'] != null)
            'description': payload['description'],
          if (payload['sku'] != null || item?.sku != null)
            'sku': payload['sku'] ?? item?.sku,
          if (payload['barcode'] != null || item?.barcode != null)
            'barcode': payload['barcode'] ?? item?.barcode,
        };

        // Fill category/brand from local item if missing.
        final categoryIdRaw = (payload['category_id'] ?? item?.categoryId)
            ?.toString();
        if (!upsertPayload.containsKey('category_id') &&
            categoryIdRaw != null) {
          final cat = int.tryParse(categoryIdRaw);
          if (cat != null) upsertPayload['category_id'] = cat;
        }
        final brandIdRaw = (payload['brand_id'] ?? item?.brandId)?.toString();
        if (!upsertPayload.containsKey('brand_id') && brandIdRaw != null) {
          final brand = int.tryParse(brandIdRaw);
          if (brand != null) upsertPayload['brand_id'] = brand;
        }

        // Prefer local DB tags/description if present (keeps parity when editing pulled items).
        if (!upsertPayload.containsKey('tags') && item?.tags != null) {
          upsertPayload['tags'] = item!.tags;
        }
        if (!upsertPayload.containsKey('description') &&
            item?.description != null) {
          upsertPayload['description'] = item!.description;
        }

        // Images: upload any pending local files and attach upload IDs.
        if (item != null) {
          // Thumbnail
          var thumbUploadId = item.thumbnailUploadId;
          final thumbPathOrUrl = (item.thumbnailUrl ?? item.imageUrl)?.trim();
          if ((thumbPathOrUrl ?? '').isNotEmpty &&
              !(thumbPathOrUrl!.startsWith('http://') ||
                  thumbPathOrUrl.startsWith('https://'))) {
            final file = File(thumbPathOrUrl);
            if (file.existsSync()) {
              try {
                final uploaded = await _uploadImageFile(thumbPathOrUrl);
                thumbUploadId = uploaded['id'] as int;
                final url = uploaded['url'] as String;
                await db.updateItemFields(
                  localId,
                  ItemsCompanion(
                    thumbnailUploadId: drift.Value(thumbUploadId),
                    thumbnailUrl: drift.Value(url),
                    imageUrl: drift.Value(url),
                  ),
                );
              } on DioException catch (e) {
                if (_isRetryableUploadError(e)) {
                  rethrow;
                }
                // Non-retryable upload error (e.g. 4xx validation failure).
                // Preserve the local path so the next sync cycle can retry
                // the upload; only proceed without the image this cycle.
                debugPrint(
                  '[SyncService] Thumbnail upload failed for $localId '
                  '(status ${e.response?.statusCode}): ${e.error}. '
                  'Local path preserved — will retry on next sync.',
                );
              }
            } else {
              // File was deleted externally — clear it to unblock sync.
              debugPrint(
                '[SyncService] Thumbnail file missing for $localId, clearing path.',
              );
              await db.updateItemFields(
                localId,
                ItemsCompanion(
                  thumbnailUrl: drift.Value(null),
                  imageUrl: drift.Value(null),
                ),
              );
            }
          }
          if (thumbUploadId != null) {
            upsertPayload['thumbnail_upload_id'] = thumbUploadId;
          }

          // Gallery (remote urls first, then pending local paths).
          final urlsAll = _decodeStringList(item.galleryUrls);
          final idsAll = _decodeIntList(item.galleryUploadIds);
          final remoteCount = idsAll.length < urlsAll.length
              ? idsAll.length
              : urlsAll.length;
          final remoteUrls = urlsAll.take(remoteCount).toList();
          final remoteIds = idsAll.take(remoteCount).toList();
          final pending = urlsAll
              .skip(remoteCount)
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

          if (pending.isNotEmpty) {
            final pendingQueue = List<String>.from(pending);
            var mutated = false;
            for (final path in List<String>.from(pendingQueue)) {
              if (path.startsWith('http://') || path.startsWith('https://')) {
                continue;
              }
              final file = File(path);
              if (!file.existsSync()) {
                pendingQueue.remove(path);
                mutated = true;
                continue;
              }
              try {
                final uploaded = await _uploadImageFile(path);
                remoteIds.add(uploaded['id'] as int);
                remoteUrls.add(uploaded['url'] as String);
                pendingQueue.remove(path);
                mutated = true;
                await db.updateItemFields(
                  localId,
                  ItemsCompanion(
                    galleryUrls: drift.Value(
                      jsonEncode([...remoteUrls, ...pendingQueue]),
                    ),
                    galleryUploadIds: drift.Value(jsonEncode(remoteIds)),
                  ),
                );
              } on DioException catch (e) {
                if (_isRetryableUploadError(e)) {
                  rethrow; // Let outer retry handle it
                }
                // Non-retryable: keep path in queue so the next sync can
                // retry (e.g. after a backend fix or reconnect).
                debugPrint(
                  '[SyncService] Gallery upload failed for $localId path=$path '
                  '(status ${e.response?.statusCode}): ${e.error}. Keeping for retry.',
                );
              }
            }
            if (mutated) {
              await db.updateItemFields(
                localId,
                ItemsCompanion(
                  galleryUrls: drift.Value(
                    jsonEncode([...remoteUrls, ...pendingQueue]),
                  ),
                  galleryUploadIds: drift.Value(jsonEncode(remoteIds)),
                ),
              );
            }
          }

          final hasGalleryColumns =
              item.galleryUrls != null || item.galleryUploadIds != null;
          final hasUnknownRemoteWithoutIds =
              idsAll.isEmpty &&
              pending.any(
                (p) => p.startsWith('http://') || p.startsWith('https://'),
              );
          final canReplaceGallery =
              hasGalleryColumns && !hasUnknownRemoteWithoutIds;
          if (canReplaceGallery) {
            upsertPayload['photo_upload_ids'] = remoteIds;
            upsertPayload['replace_photo_upload_ids'] = true;
          }
        }

        final res = await sellerApi.upsertPosCatalogProduct(
          upsertPayload,
          idempotencyKey: localId,
        );

        if (res.data is! Map<String, dynamic>) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Invalid product upsert response shape',
          );
        }
        final productIdRaw = (res.data as Map<String, dynamic>)['product_id'];
        final productId = _asNullableInt(productIdRaw);
        if (productId == null) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Missing product_id in product upsert response',
          );
        }
        await db.markItemSyncedWithRemoteId(localId, productId);
        await _pushItemVariantStocks(localId, productId);
        break;
      case 'item_delete':
        final productId =
            payload['remote_id']?.toString() ??
            payload['product_id']?.toString() ??
            '';
        if (productId.isEmpty) {
          // Local-only item deletion: nothing to do remotely.
          return;
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
        await _enforceCatalogRateLimit();
        final localId = payload['local_id']?.toString().trim();
        if (localId == null || localId.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing local_id for service sync op',
          );
        }

        final isCreate = op.opType == 'service_create';
        final mappedPayload = <String, dynamic>{};
        final title = (payload['title'] ?? '').toString();
        if (isCreate ||
            (payload.containsKey('title') && title.trim().isNotEmpty)) {
          mappedPayload['title'] = title;
        }
        if (payload['summary'] != null) {
          mappedPayload['summary'] = payload['summary'];
        }
        if (payload['description'] != null) {
          mappedPayload['description'] = payload['description'];
        }

        if (isCreate ||
            payload.containsKey('base_price') ||
            payload.containsKey('price')) {
          mappedPayload['base_price'] = _asDouble(
            payload['base_price'] ?? payload['price'] ?? 0,
          );
        }
        if (payload.containsKey('purchase_price')) {
          mappedPayload['purchase_price'] = _asDouble(
            payload['purchase_price'],
          );
        }
        if (payload['currency'] != null) {
          mappedPayload['currency'] = payload['currency'];
        }
        if (payload['category_id'] != null) {
          mappedPayload['category_id'] = payload['category_id'];
        }
        if (payload['service_type'] != null) {
          mappedPayload['service_type'] = payload['service_type'];
        }
        if (payload['delivery_timeframe'] != null) {
          mappedPayload['delivery_timeframe'] = payload['delivery_timeframe'];
        }
        if (payload['packages'] is Map) {
          mappedPayload['packages'] = payload['packages'];
        }

        final durationRaw = payload['duration_minutes'] ?? payload['duration'];
        if (durationRaw != null) {
          mappedPayload['duration_minutes'] = _asInt(durationRaw);
        }

        if (payload.containsKey('is_published') ||
            payload.containsKey('published')) {
          mappedPayload['is_published'] = _asBool(
            payload['is_published'] ?? payload['published'],
          );
        }

        // Upload service cover + gallery images if present and local.
        final svc = await db.getServiceById(localId);
        if (svc != null) {
          var coverUploadId = svc.coverUploadId;
          final imagePath =
              (svc.imageUrl ?? payload['image_url']?.toString())?.trim();
          if (imagePath != null &&
              imagePath.isNotEmpty &&
              !imagePath.startsWith('http')) {
            final file = File(imagePath);
            if (file.existsSync()) {
              _safeAddStatus('Uploading service photo…');
              try {
                final uploaded = await _uploadImageFile(imagePath);
                coverUploadId = uploaded['id'] as int;
                final remoteUrl = uploaded['url'] as String;
                mappedPayload['cover_image_id'] = coverUploadId;
                await db.updateServiceFields(
                  localId,
                  ServicesCompanion(
                    imageUrl: drift.Value(remoteUrl),
                    coverUploadId: drift.Value(coverUploadId),
                  ),
                );
              } on DioException catch (e) {
                if (_isRetryableUploadError(e)) {
                  rethrow;
                }
                debugPrint(
                  '[SyncService] Service image upload failed for $localId '
                  '(status ${e.response?.statusCode}): ${e.error}. '
                  'Local path preserved — will retry on next sync.',
                );
              }
            }
          } else if (coverUploadId != null) {
            mappedPayload['cover_image_id'] = coverUploadId;
          }

          final urlsAll = _decodeStringList(svc.galleryUrls);
          final idsAll = _decodeIntList(svc.galleryUploadIds);
          final remoteCount = idsAll.length < urlsAll.length
              ? idsAll.length
              : urlsAll.length;
          final remoteUrls = urlsAll.take(remoteCount).toList();
          final remoteIds = idsAll.take(remoteCount).toList();
          final pending = urlsAll
              .skip(remoteCount)
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

          if (pending.isNotEmpty) {
            final pendingQueue = List<String>.from(pending);
            var mutated = false;
            for (final path in List<String>.from(pendingQueue)) {
              if (path.startsWith('http://') || path.startsWith('https://')) {
                continue;
              }
              final file = File(path);
              if (!file.existsSync()) {
                pendingQueue.remove(path);
                mutated = true;
                continue;
              }
              try {
                final uploaded = await _uploadImageFile(path);
                remoteIds.add(uploaded['id'] as int);
                remoteUrls.add(uploaded['url'] as String);
                pendingQueue.remove(path);
                mutated = true;
                await db.updateServiceFields(
                  localId,
                  ServicesCompanion(
                    galleryUrls: drift.Value(
                      jsonEncode([...remoteUrls, ...pendingQueue]),
                    ),
                    galleryUploadIds: drift.Value(jsonEncode(remoteIds)),
                  ),
                );
              } on DioException catch (e) {
                if (_isRetryableUploadError(e)) {
                  rethrow;
                }
                debugPrint(
                  '[SyncService] Service gallery upload failed for $localId '
                  '(status ${e.response?.statusCode}): ${e.error}.',
                );
              }
            }
            if (mutated) {
              final refreshed = await db.getServiceById(localId);
              if (refreshed != null) {
                final refreshedUrls = _decodeStringList(refreshed.galleryUrls);
                final refreshedIds = _decodeIntList(refreshed.galleryUploadIds);
                final refreshedCount = refreshedIds.length < refreshedUrls.length
                    ? refreshedIds.length
                    : refreshedUrls.length;
                remoteUrls
                  ..clear()
                  ..addAll(refreshedUrls.take(refreshedCount));
                remoteIds
                  ..clear()
                  ..addAll(refreshedIds.take(refreshedCount));
              }
            }
          }

          final hasGallery =
              svc.galleryUrls != null || svc.galleryUploadIds != null;
          if (remoteIds.isNotEmpty || hasGallery) {
            mappedPayload['gallery_media'] = remoteIds;
          }
        }

        if (op.opType == 'service_create') {
          final res = await sellerApi.createService(
            mappedPayload,
            idempotencyKey: localId,
          );
          if (res.data is! Map) {
            throw DioException(
              requestOptions: res.requestOptions,
              error: 'Invalid service create response shape',
            );
          }
          final body = Map<String, dynamic>.from(res.data as Map);
          final data = body['data'];
          int? remoteId;
          if (data is Map) {
            remoteId = _asNullableInt(data['id']);
          } else {
            remoteId = _asNullableInt(body['id']);
          }
          if (remoteId == null) {
            throw DioException(
              requestOptions: res.requestOptions,
              error: 'Missing service id in create response',
            );
          }
          await db.markServiceSyncedWithRemoteId(localId, remoteId);
          await _applyServiceApiResponse(localId, body);
        } else {
          final remoteId =
              _asNullableInt(payload['remote_id']) ??
              (await db.getServiceById(localId))?.remoteId;
          if (remoteId == null) {
            throw DioException(
              requestOptions: RequestOptions(path: op.opType),
              error: 'Service not synced yet for service_update',
            );
          }
          final res = await sellerApi.updateService(
            remoteId.toString(),
            mappedPayload,
          );
          await db.markServiceSynced(localId);
          if (res.data is Map) {
            await _applyServiceApiResponse(
              localId,
              Map<String, dynamic>.from(res.data as Map),
            );
          }
        }
        break;
      case 'service_delete':
        final localId = payload['local_id']?.toString().trim();
        final remoteId =
            _asNullableInt(payload['remote_id']) ??
            _asNullableInt(payload['service_id']) ??
            (localId == null || localId.isEmpty
                ? null
                : (await db.getServiceById(localId))?.remoteId);

        if (remoteId == null) {
          // Local-only service deletion: no remote action needed.
          return;
        }
        try {
          await sellerApi.deleteService(remoteId.toString());
        } on DioException catch (e) {
          if (e.response?.statusCode == 404) {
            // Idempotent delete: treat missing remote resource as success.
            return;
          }
          rethrow;
        }
        break;
      case 'ad_media_upload':
        final filePath = payload['file_path']?.toString().trim() ?? '';
        if (filePath.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing file_path for ad media upload',
          );
        }
        await _uploadImageFile(filePath);
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
        final body = Map<String, dynamic>.from(payload);

        // Backend expects `ref_entry_id` for refunds/voids; older client payloads used
        // `original_entry_id`.
        final type = (body['type'] ?? '').toString();
        if (type == 'refund' || type == 'void') {
          body['ref_entry_id'] ??= body['original_entry_id'];
        }

        final linesRaw = body['lines'];
        if (linesRaw is List) {
          final updated = <Map<String, dynamic>>[];
          for (final raw in linesRaw) {
            if (raw is! Map) continue;
            final line = Map<String, dynamic>.from(raw);

            final productRaw = line['product_id'];
            if (productRaw != null && productRaw.toString().trim().isNotEmpty) {
              final resolved =
                  await _resolveRemoteProductId(productRaw) ??
                  await _resolveRemoteProductIdByName(
                    (line['name'] ?? line['title'] ?? '').toString(),
                  );
              if (resolved == null) {
                throw DioException(
                  requestOptions: RequestOptions(path: op.opType),
                  error: 'Product not synced yet for ledger entry',
                );
              }
              line['product_id'] = resolved;
            } else {
              line.remove('product_id');
            }

            final serviceRaw = line['service_id'];
            if (serviceRaw != null && serviceRaw.toString().trim().isNotEmpty) {
              final resolved =
                  await _resolveRemoteServiceId(serviceRaw) ??
                  await _resolveRemoteServiceIdByTitle(
                    (line['name'] ?? line['title'] ?? '').toString(),
                  );
              if (resolved == null) {
                throw DioException(
                  requestOptions: RequestOptions(path: op.opType),
                  error: 'Service not synced yet for ledger entry',
                );
              }
              line['service_id'] = resolved;
            } else {
              line.remove('service_id');
            }

            updated.add(line);
          }
          body['lines'] = updated;
        }

        final res = await sellerApi.pushLedgerEntry(body, idempotencyKey: key);
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
        final localId = payload['local_id']?.toString() ?? '';
        if (localId.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing local_id for stock_adjust',
          );
        }
        final item = await db.getItemById(localId);
        final remoteId =
            _asNullableInt(payload['product_id']) ??
            _asNullableInt(payload['remote_id']) ??
            item?.remoteId ??
            _asNullableInt(localId);
        if (remoteId == null) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing remote product id for stock_adjust',
          );
        }

        final upsertPayload = <String, dynamic>{
          'product_id': remoteId,
          'name': (item?.name ?? payload['name'] ?? '').toString(),
          'unit_price': _asDouble(item?.price ?? payload['unit_price'] ?? 0),
          'current_stock': _asInt(
            payload['current_stock'] ?? item?.stockQty ?? 0,
          ),
          'published': _asBool(
            payload['published'] ?? item?.publishedOnline ?? false,
          ),
          if (item?.sku != null) 'sku': item!.sku,
          if (item?.barcode != null) 'barcode': item!.barcode,
        };
        final variation = payload['variation']?.toString();
        if (variation != null && variation.trim().isNotEmpty) {
          upsertPayload['variation'] = variation.trim();
        }

        final res = await sellerApi.upsertPosCatalogProduct(
          upsertPayload,
          idempotencyKey: localId,
        );
        if (res.data is Map<String, dynamic>) {
          final productId = _asNullableInt(
            (res.data as Map<String, dynamic>)['product_id'],
          );
          if (productId != null) {
            await db.markItemSyncedWithRemoteId(localId, productId);
          }
        } else {
          await db.markItemSynced(localId);
        }
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
        final localMovementId = int.tryParse(
          payload['movement_id']?.toString() ?? '',
        );
        final remoteMovementId = int.tryParse(ack.serverEntryId);
        if (localMovementId != null) {
          await db.updateCashMovement(
            localMovementId,
            CashMovementsCompanion(
              remoteId: drift.Value(remoteMovementId),
              idempotencyKey: drift.Value(key),
            ),
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
      case 'expense_push':
        final key =
            payload['idempotency_key']?.toString() ??
            payload['expense_id']?.toString() ??
            '';
        if (key.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing idempotency_key for expense',
          );
        }

        final expenseId = payload['expense_id']?.toString() ?? '';
        if (expenseId.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing expense_id for expense',
          );
        }

        final body = Map<String, dynamic>.from(payload)
          ..remove('idempotency_key');
        final res = await sellerApi.pushExpense(body, idempotencyKey: key);
        if (res.data is! Map<String, dynamic>) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Invalid expense ack response shape',
          );
        }

        final ack = PosLedgerAck.fromJson(res.data as Map<String, dynamic>);
        if (ack.idempotencyKey != key) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Expense ack idempotency mismatch',
          );
        }

        final remoteId = int.tryParse(ack.serverEntryId);
        if (remoteId == null) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Invalid server_entry_id for expense',
          );
        }
        await db.markExpenseSynced(expenseId, remoteId);
        break;
      case 'grn_push':
        final key =
            payload['idempotency_key']?.toString() ??
            payload['client_grn_id']?.toString() ??
            '';
        if (key.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing idempotency_key for goods received note',
          );
        }
        final body = Map<String, dynamic>.from(payload)
          ..remove('idempotency_key');
        final linesRaw = body['lines'];
        if (linesRaw is List) {
          final updated = <Map<String, dynamic>>[];
          for (final raw in linesRaw) {
            if (raw is! Map) continue;
            final line = Map<String, dynamic>.from(raw);
            final productRaw = line['product_id'];
            if (productRaw != null && productRaw.toString().trim().isNotEmpty) {
              final resolved = await _resolveRemoteProductId(productRaw);
              if (resolved == null) {
                throw DioException(
                  requestOptions: RequestOptions(path: op.opType),
                  error: 'Product not synced yet for GRN',
                );
              }
              line['product_id'] = resolved;
            }
            updated.add(line);
          }
          body['lines'] = updated;
        }
        final res = await sellerApi.pushGoodsReceivedNote(
          body,
          idempotencyKey: key,
        );
        if (res.data is! Map<String, dynamic>) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Invalid GRN ack response shape',
          );
        }
        final ack = PosLedgerAck.fromJson(res.data as Map<String, dynamic>);
        if (ack.idempotencyKey != key) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'GRN ack idempotency mismatch',
          );
        }
        break;
      case 'sale_create':
        final txId = payload['terminal_transaction_id']?.toString() ?? '';
        if (txId.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing terminal_transaction_id for sale_create',
          );
        }

        final body = Map<String, dynamic>.from(payload);

        // Resolve product IDs
        final itemsRaw = body['items'];
        if (itemsRaw is List) {
          final updatedItems = <Map<String, dynamic>>[];
          for (final raw in itemsRaw) {
            if (raw is! Map) continue;
            final item = Map<String, dynamic>.from(raw);
            final localProductId = item['product_id'];

            // Try to resolve to remote ID if possible
            if (localProductId != null &&
                localProductId.toString().isNotEmpty) {
              final resolved = await _resolveRemoteProductId(localProductId);
              if (resolved != null) {
                item['product_id'] = resolved;
              }
              // If not resolved, we still send what we have (maybe null or local ID),
              // backend should handle or ignore.
              // Actually, let's keep it robust: if unresolved, send null or let backend handle mismatch.
              // My controller logic handles generic IDs.
            }
            updatedItems.add(item);
          }
          body['items'] = updatedItems;
        }

        final res = await sellerApi.createPosTransaction(body);
        if (res.statusCode == 200 || res.statusCode == 201) {
          await db.markTransactionSynced(txId);
        }
        break;

      case 'stocktake_push':
        final key =
            payload['idempotency_key']?.toString() ??
            payload['client_stocktake_id']?.toString() ??
            '';
        if (key.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing idempotency_key for stocktake',
          );
        }
        final body = Map<String, dynamic>.from(payload)
          ..remove('idempotency_key');
        final linesRaw = body['lines'];
        if (linesRaw is List) {
          final updated = <Map<String, dynamic>>[];
          for (final raw in linesRaw) {
            if (raw is! Map) continue;
            final line = Map<String, dynamic>.from(raw);
            final productRaw = line['product_id'];
            if (productRaw != null && productRaw.toString().trim().isNotEmpty) {
              final resolved = await _resolveRemoteProductId(productRaw);
              if (resolved == null) {
                throw DioException(
                  requestOptions: RequestOptions(path: op.opType),
                  error: 'Product not synced yet for stocktake',
                );
              }
              line['product_id'] = resolved;
            }
            updated.add(line);
          }
          body['lines'] = updated;
        }
        final res = await sellerApi.pushStocktake(body, idempotencyKey: key);
        if (res.data is! Map<String, dynamic>) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Invalid stocktake ack response shape',
          );
        }
        final ack = PosLedgerAck.fromJson(res.data as Map<String, dynamic>);
        if (ack.idempotencyKey != key) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Stocktake ack idempotency mismatch',
          );
        }
        break;
      case 'purchase_order_push':
        final key =
            payload['idempotency_key']?.toString() ??
            payload['client_po_id']?.toString() ??
            '';
        if (key.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing idempotency_key for purchase order',
          );
        }
        final body = Map<String, dynamic>.from(payload)
          ..remove('idempotency_key');
        final linesRaw = body['lines'];
        if (linesRaw is List) {
          final updated = <Map<String, dynamic>>[];
          for (final raw in linesRaw) {
            if (raw is! Map) continue;
            final line = Map<String, dynamic>.from(raw);
            final productRaw = line['product_id'];
            if (productRaw != null && productRaw.toString().trim().isNotEmpty) {
              final resolved = await _resolveRemoteProductId(productRaw);
              if (resolved == null) {
                throw DioException(
                  requestOptions: RequestOptions(path: op.opType),
                  error: 'Product not synced yet for purchase order',
                );
              }
              line['product_id'] = resolved;
            }
            updated.add(line);
          }
          body['lines'] = updated;
        }
        final res = await sellerApi.createPurchaseOrder(
          body,
          idempotencyKey: key,
        );
        if (res.data is! Map<String, dynamic>) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Invalid purchase order response',
          );
        }
        final ackKey = (res.data as Map<String, dynamic>)['idempotency_key']
            ?.toString();
        if (ackKey != key) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Purchase order ack idempotency mismatch',
          );
        }
        break;
      case 'quotation_push':
        final key =
            payload['idempotency_key']?.toString() ??
            payload['id']?.toString() ??
            payload['quotation_id']?.toString() ??
            payload['local_id']?.toString() ??
            '';
        if (key.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing idempotency_key for quotation',
          );
        }
        final rawBody = Map<String, dynamic>.from(payload)
          ..remove('idempotency_key');

        final id =
            (rawBody['id'] ??
                    rawBody['quotation_id'] ??
                    rawBody['local_id'] ??
                    rawBody['quotationId'] ??
                    rawBody['localId'])
                ?.toString()
                .trim();
        if (id == null || id.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing quotation id',
          );
        }

        final quotationNumber =
            (rawBody['quotation_number'] ??
                    rawBody['number'] ??
                    rawBody['quotationNumber'])
                ?.toString()
                .trim();
        if (quotationNumber == null || quotationNumber.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing quotation_number',
          );
        }

        var validityDays = _asInt(
          rawBody['validity_days'] ?? rawBody['validityDays'],
        );
        if (validityDays <= 0) {
          final validUntil = DateTime.tryParse(
            (rawBody['valid_until'] ?? rawBody['validUntil'] ?? '').toString(),
          );
          if (validUntil != null) {
            validityDays = validUntil.difference(DateTime.now()).inDays;
          }
        }
        if (validityDays <= 0) validityDays = 30;

        final customerId = rawBody['customer_id']?.toString();
        final notes =
            rawBody['notes']?.toString() ?? rawBody['note']?.toString();

        final lines = <Map<String, dynamic>>[];
        final rawLines = rawBody['lines'];
        if (rawLines is List) {
          for (final raw in rawLines) {
            if (raw is! Map) continue;
            final line = Map<String, dynamic>.from(raw);
            final title =
                (line['title'] ?? line['name'] ?? line['description'] ?? 'Item')
                    .toString()
                    .trim();
            final quantity = _asInt(line['quantity'] ?? line['qty'] ?? 1);
            final price = _asDouble(
              line['price'] ?? line['unit_price'] ?? line['unitPrice'] ?? 0,
            );
            final total = _asDouble(line['total']) != 0
                ? _asDouble(line['total'])
                : price * quantity;

            lines.add({
              if (line['item_id'] != null) 'item_id': line['item_id'],
              if (line['service_id'] != null) 'service_id': line['service_id'],
              'title': title.isEmpty ? 'Item' : title,
              'price': price,
              'quantity': quantity <= 0 ? 1 : quantity,
              'total': total,
            });
          }
        }
        if (lines.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Quotation must include at least one line',
          );
        }

        final body = <String, dynamic>{
          'id': id,
          'quotation_number': quotationNumber,
          'customer_id': customerId,
          'validity_days': validityDays,
          'total': _asDouble(rawBody['total']),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          'lines': lines,
        };

        await sellerApi.pushQuotation(body, idempotencyKey: key);
        final localId = id.trim();
        if (localId.isNotEmpty) {
          await (db.update(db.quotations)..where((t) => t.id.equals(localId)))
              .write(const QuotationsCompanion(synced: drift.Value(true)));
        }
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
          'show_logo':
              payload['show_logo'] == 1 || payload['show_logo'] == true,
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
        final localCustomerId =
            payload['customer_id']?.toString() ??
            payload['local_id']?.toString() ??
            '';
        final body = Map<String, dynamic>.from(payload)
          ..remove('idempotency_key');
        final res = await sellerApi.pushCustomer(body, idempotencyKey: key);
        String? remoteId;
        DateTime? updatedAt;
        if (res.data is Map) {
          final data = Map<String, dynamic>.from(res.data as Map);
          remoteId = data['contact_id']?.toString();
          updatedAt = DateTime.tryParse(
            data['updated_at']?.toString() ?? '',
          )?.toUtc();
        }
        if (localCustomerId.trim().isNotEmpty) {
          await (db.update(
            db.customers,
          )..where((t) => t.id.equals(localCustomerId.trim()))).write(
            CustomersCompanion(
              remoteId: remoteId == null
                  ? const drift.Value.absent()
                  : drift.Value(remoteId),
              synced: const drift.Value(true),
              updatedAt: drift.Value(updatedAt ?? DateTime.now().toUtc()),
            ),
          );
        }
        break;
      case 'service_variant_push':
      case 'service_variant_create':
      case 'service_variant_update':
        final variantIdRaw =
            payload['id'] ?? payload['variant_id'] ?? payload['local_id'];
        final serviceIdRaw = payload['service_id'] ?? payload['serviceId'];
        final variantId = variantIdRaw?.toString().trim() ?? '';
        final localServiceId = serviceIdRaw?.toString().trim() ?? '';
        if (variantId.isEmpty || localServiceId.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing id/service_id for service variant push',
          );
        }

        final remoteServiceId = await _resolveRemoteServiceId(localServiceId);
        if (remoteServiceId == null) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Service not synced yet for service variant push',
          );
        }

        final mapped = <String, dynamic>{
          'id': variantId,
          'service_id': remoteServiceId,
          'name': payload['name'],
          'price': payload['price'],
          'unit': payload['unit'],
          'is_default': _asBool(payload['is_default'] ?? false),
        };
        await sellerApi.pushServiceVariant(mapped);
        final localVariantId = mapped['id']?.toString();
        if (localVariantId != null && localVariantId.trim().isNotEmpty) {
          await (db.update(db.serviceVariants)
                ..where((t) => t.id.equals(localVariantId.trim())))
              .write(const ServiceVariantsCompanion(synced: drift.Value(true)));
        }
        break;
      case 'service_variant_delete':
        final variantId =
            payload['variant_id']?.toString() ??
            payload['id']?.toString() ??
            '';
        if (variantId.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing variant_id for service variant delete',
          );
        }
        await sellerApi.deleteServiceVariant(variantId);
        break;
      case 'business_profile_patch':
        await sellerApi.updatePosBusinessProfile(
          payload,
          idempotencyKey: 'syncop:${op.id}',
        );
        final existingProfile = await db.getBusinessProfile();
        if (existingProfile != null) {
          await db.upsertBusinessProfile(
            existingProfile
                .copyWith(
                  shopName:
                      payload['name']?.toString() ?? existingProfile.shopName,
                  shopAddress: payload.containsKey('address')
                      ? drift.Value(payload['address']?.toString())
                      : const drift.Value.absent(),
                  shopPhone: payload.containsKey('phone')
                      ? drift.Value(payload['phone']?.toString())
                      : const drift.Value.absent(),
                  logoUploadId: payload['logo'] is num
                      ? drift.Value((payload['logo'] as num).toInt())
                      : const drift.Value.absent(),
                  metaTitle: payload.containsKey('meta_title')
                      ? drift.Value(payload['meta_title']?.toString())
                      : const drift.Value.absent(),
                  metaDescription: payload.containsKey('meta_description')
                      ? drift.Value(payload['meta_description']?.toString())
                      : const drift.Value.absent(),
                  thermalPrinterWidth: payload['thermal_printer_width'] is num
                      ? drift.Value(
                          (payload['thermal_printer_width'] as num).toInt(),
                        )
                      : const drift.Value.absent(),
                  shippingCost: payload['shipping_cost'] is num
                      ? drift.Value(
                          (payload['shipping_cost'] as num).toDouble(),
                        )
                      : const drift.Value.absent(),
                  selfDeliveryActive:
                      payload.containsKey('self_delivery_active')
                      ? _asBool(payload['self_delivery_active'])
                      : existingProfile.selfDeliveryActive,
                  deliveryRadiusKm: payload['delivery_radius_km'] is num
                      ? drift.Value(
                          (payload['delivery_radius_km'] as num).toDouble(),
                        )
                      : const drift.Value.absent(),
                  deliveryPickupLatitude:
                      payload['delivery_pickup_latitude'] is num
                      ? drift.Value(
                          (payload['delivery_pickup_latitude'] as num)
                              .toDouble(),
                        )
                      : const drift.Value.absent(),
                  deliveryPickupLongitude:
                      payload['delivery_pickup_longitude'] is num
                      ? drift.Value(
                          (payload['delivery_pickup_longitude'] as num)
                              .toDouble(),
                        )
                      : const drift.Value.absent(),
                  cashOnDeliveryEnabled:
                      payload.containsKey('cash_on_delivery_status')
                      ? _asBool(payload['cash_on_delivery_status'])
                      : existingProfile.cashOnDeliveryEnabled,
                  bankPaymentEnabled: payload.containsKey('bank_payment_status')
                      ? _asBool(payload['bank_payment_status'])
                      : existingProfile.bankPaymentEnabled,
                  bankName: payload.containsKey('bank_name')
                      ? drift.Value(payload['bank_name']?.toString())
                      : const drift.Value.absent(),
                  bankAccName: payload.containsKey('bank_acc_name')
                      ? drift.Value(payload['bank_acc_name']?.toString())
                      : const drift.Value.absent(),
                  bankAccNo: payload.containsKey('bank_acc_no')
                      ? drift.Value(payload['bank_acc_no']?.toString())
                      : const drift.Value.absent(),
                  bankRoutingNo: payload.containsKey('bank_routing_no')
                      ? drift.Value(payload['bank_routing_no']?.toString())
                      : const drift.Value.absent(),
                  mtnMerchantCode: payload.containsKey('mtn_merchant_code')
                      ? drift.Value(payload['mtn_merchant_code']?.toString())
                      : const drift.Value.absent(),
                  airtelMerchantCode:
                      payload.containsKey('airtel_merchant_code')
                      ? drift.Value(payload['airtel_merchant_code']?.toString())
                      : const drift.Value.absent(),
                  paybillNumber: payload.containsKey('paybill_number')
                      ? drift.Value(payload['paybill_number']?.toString())
                      : const drift.Value.absent(),
                  receiptPaymentMethodsJson:
                      payload['receipt_payment_methods'] is Map
                      ? drift.Value(
                          jsonEncode(
                            Map<String, dynamic>.from(
                              payload['receipt_payment_methods'] as Map,
                            ),
                          ),
                        )
                      : const drift.Value.absent(),
                  updatedAt: DateTime.now().toUtc(),
                  synced: true,
                )
                .toCompanion(false),
          );
        }
        break;
      case 'delivery_profile_push':
        await sellerApi.upsertDeliveryProfile(payload);
        final existingProfile = await db.getBusinessProfile();
        if (existingProfile != null) {
          await db.upsertBusinessProfile(
            existingProfile
                .copyWith(
                  shippingCost: payload['base_fee'] is num
                      ? drift.Value((payload['base_fee'] as num).toDouble())
                      : const drift.Value.absent(),
                  selfDeliveryActive: payload.containsKey('enabled')
                      ? _asBool(payload['enabled'])
                      : existingProfile.selfDeliveryActive,
                  deliveryRadiusKm: payload['radius_km'] is num
                      ? drift.Value((payload['radius_km'] as num).toDouble())
                      : const drift.Value.absent(),
                  deliveryPickupLatitude: payload['origin_lat'] is num
                      ? drift.Value((payload['origin_lat'] as num).toDouble())
                      : const drift.Value.absent(),
                  deliveryPickupLongitude: payload['origin_lng'] is num
                      ? drift.Value((payload['origin_lng'] as num).toDouble())
                      : const drift.Value.absent(),
                  deliveryProfileJson: drift.Value(jsonEncode(payload)),
                  updatedAt: DateTime.now().toUtc(),
                  synced: true,
                )
                .toCompanion(false),
          );
        }
        break;
      case 'shift_push':
      case 'shift_open':
        final key =
            payload['idempotency_key']?.toString() ??
            payload['shift_id']?.toString() ??
            '';
        if (key.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing idempotency_key for shift',
          );
        }
        final body = Map<String, dynamic>.from(payload);
        await sellerApi.pushShift(body, idempotencyKey: key);
        final shiftId =
            payload['shift_id']?.toString() ?? payload['id']?.toString() ?? '';
        if (shiftId.isNotEmpty) {
          await (db.update(db.shifts)..where((t) => t.id.equals(shiftId)))
              .write(const ShiftsCompanion(synced: drift.Value(true)));
        }
        break;
      case 'shift_close':
        final key =
            payload['idempotency_key']?.toString() ??
            payload['shift_id']?.toString() ??
            '';
        if (key.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing idempotency_key for shift close',
          );
        }
        final body = Map<String, dynamic>.from(payload);
        await sellerApi.closeShift(body, idempotencyKey: key);
        final shiftId =
            payload['shift_id']?.toString() ?? payload['id']?.toString() ?? '';
        if (shiftId.isNotEmpty) {
          await (db.update(db.shifts)..where((t) => t.id.equals(shiftId)))
              .write(const ShiftsCompanion(synced: drift.Value(true)));
        }
        break;
      case 'setting_push':
      case 'settings_push':
        // Settings sync - just push to server, no local table
        final key =
            payload['idempotency_key']?.toString() ??
            payload['key']?.toString() ??
            '';
        if (key.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing key for setting',
          );
        }
        final body = <String, dynamic>{
          'key': payload['key'],
          'value': payload['value'],
        };
        await sellerApi.pushSetting(body, idempotencyKey: key);
        break;
      case 'sms_send':
        final key = payload['idempotency_key']?.toString() ?? '';
        if (key.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing idempotency_key for SMS send',
          );
        }
        final body = Map<String, dynamic>.from(payload)
          ..remove('idempotency_key');
        await sellerApi.sendSingleSms(body, idempotencyKey: key);
        break;
      case 'supplier_push':
      case 'supplier_create':
        final key =
            payload['idempotency_key']?.toString() ??
            payload['supplier_id']?.toString() ??
            '';
        if (key.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing idempotency_key for supplier',
          );
        }
        final body = Map<String, dynamic>.from(payload)
          ..remove('idempotency_key');
        await sellerApi.createSupplier(body, idempotencyKey: key);
        break;
      case 'package_purchase_push':
        final key = payload['idempotency_key']?.toString() ?? '';
        if (key.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing idempotency_key for package purchase',
          );
        }
        final body = Map<String, dynamic>.from(payload)
          ..remove('idempotency_key');
        await sellerApi.pushPackagePurchase(body, idempotencyKey: key);
        break;
      case 'package_redemption_push':
        final key = payload['idempotency_key']?.toString() ?? '';
        if (key.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing idempotency_key for redemption',
          );
        }
        final body = Map<String, dynamic>.from(payload)
          ..remove('idempotency_key');
        await sellerApi.pushPackageRedemption(body, idempotencyKey: key);
        break;
      case 'job_session_complete':
        await sellerApi.createServiceTimeLog(Map<String, dynamic>.from(payload));
        break;
      case 'booking_create':
        await sellerApi.createServiceBooking(Map<String, dynamic>.from(payload));
        break;
      case 'booking_reschedule':
        final bookingId = payload['booking_id'] as int?;
        if (bookingId == null) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing booking_id for reschedule',
          );
        }
        final body = Map<String, dynamic>.from(payload)..remove('booking_id');
        await sellerApi.rescheduleServiceBooking(bookingId, body);
        break;
      case 'availability_update':
        final schedules = payload['schedules'];
        if (schedules is! List) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing schedules for availability_update',
          );
        }
        await sellerApi.updateAvailability(
          List<Map<String, dynamic>>.from(schedules),
        );
        break;
      case 'availability_exception_create':
        await sellerApi.addAvailabilityException(Map<String, dynamic>.from(payload));
        break;
      case 'availability_exception_delete':
        final remoteId = payload['remote_id'] as int?;
        if (remoteId == null) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing remote_id for availability_exception_delete',
          );
        }
        await sellerApi.deleteAvailabilityException(remoteId);
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

  Future<void> _pullPosDeltaInternal({bool allowCatalogRepair = true}) async {
    try {
      DateTime since = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final cursors = <DateTime?>[];
      for (final key in _pullCursorKeys) {
        cursors.add(await db.getLastPulledAt(key));
      }
      if (cursors.every((c) => c != null)) {
        since = cursors.cast<DateTime>().reduce(
          (a, b) => a.isBefore(b) ? a : b,
        );
      }

      if (kDebugMode) {
        debugPrint('[SyncService] Pulling delta since $since');
      }

      final res = await sellerApi.pullPosSync(since: since);
      if (res.data is! Map<String, dynamic>) {
        throw DioException(
          requestOptions: res.requestOptions,
          error: 'Invalid sync pull response shape (not a map)',
        );
      }

      // Handle wrapped response (e.g. {data: {...}, success: true})
      var responseData = res.data as Map<String, dynamic>;
      if (kDebugMode) {
        debugPrint('[SyncService] Wrapper keys: ${responseData.keys.toList()}');
      }

      if (responseData.containsKey('data')) {
        if (kDebugMode) {
          debugPrint(
            '[SyncService] Inner data type: ${responseData['data'].runtimeType}',
          );
        }
        if (responseData['data'] is Map) {
          final inner = responseData['data'] as Map;
          if (kDebugMode) {
            debugPrint('[SyncService] Inner keys: ${inner.keys.toList()}');
          }
          responseData = responseData['data'] as Map<String, dynamic>;
        } else {
          if (kDebugMode) {
            debugPrint('[SyncService] Inner data IS NOT A MAP!');
          }
        }
      }

      final pull = PosSyncPullResponse.fromJson(responseData);

      // Debug: Log what we received
      if (kDebugMode) {
        debugPrint(
          '[SyncService] Pull received: ${pull.products.length} products, ${pull.services.length} services, ${pull.customers.length} customers, ${pull.ledgerEntries.length} txns',
        );
      }

      _safeAddStatus('Syncing products...');
      if (pull.products.isEmpty) {
        if (kDebugMode) {
          debugPrint('[SyncService] WARNING: No products in sync response!');
        }
      }

      for (final p in pull.products) {
        if (p.id.isEmpty) continue;
        final remoteId = int.tryParse(p.id);
        final existing = remoteId != null
            ? await db.getItemByRemoteId(remoteId)
            : null;
        final localId = existing?.id ?? p.id;
        final displayPrice = p.stocks.isEmpty
            ? p.unitPrice
            : p.stocks.map((s) => s.price).reduce((a, b) => a < b ? a : b);
        final displayStock = p.stocks.isEmpty
            ? p.currentStock
            : p.stocks.fold<int>(0, (sum, s) => sum + s.qty);
        final discountType = p.discountType == null
            ? null
            : (p.discountType == 'amount' ? 'flat' : p.discountType);
        await db.upsertItem(
          ItemsCompanion.insert(
            id: drift.Value(localId),
            remoteId: remoteId != null
                ? drift.Value(remoteId)
                : const drift.Value.absent(),
            name: p.name.isEmpty ? 'Product' : p.name,
            price: displayPrice,
            cost: p.purchasePrice != null
                ? drift.Value(p.purchasePrice)
                : const drift.Value.absent(),
            stockQty: drift.Value(displayStock),
            imageUrl: drift.Value(p.imageUrl),
            thumbnailUrl: (p.thumbnailUrl ?? p.imageUrl) != null
                ? drift.Value(p.thumbnailUrl ?? p.imageUrl)
                : const drift.Value.absent(),
            thumbnailUploadId: p.thumbnailUploadId != null
                ? drift.Value(p.thumbnailUploadId)
                : const drift.Value.absent(),
            galleryUrls: p.galleryUrls.isNotEmpty
                ? drift.Value(jsonEncode(p.galleryUrls))
                : const drift.Value.absent(),
            galleryUploadIds: p.photoUploadIds.isNotEmpty
                ? drift.Value(jsonEncode(p.photoUploadIds))
                : const drift.Value.absent(),
            publishedOnline: drift.Value(p.published),
            categoryId: p.categoryId != null
                ? drift.Value(p.categoryId.toString())
                : const drift.Value.absent(),
            brandId: p.brandId != null
                ? drift.Value(p.brandId.toString())
                : const drift.Value.absent(),
            unit: p.unit != null
                ? drift.Value(p.unit)
                : const drift.Value.absent(),
            weight: p.weight != null
                ? drift.Value(p.weight)
                : const drift.Value.absent(),
            minPurchaseQty: p.minQty != null
                ? drift.Value(p.minQty!)
                : const drift.Value.absent(),
            tags: p.tags != null
                ? drift.Value(p.tags)
                : const drift.Value.absent(),
            description: p.description != null
                ? drift.Value(p.description)
                : const drift.Value.absent(),
            discount: p.discount != null
                ? drift.Value(p.discount)
                : const drift.Value.absent(),
            discountType: discountType != null
                ? drift.Value(discountType)
                : const drift.Value.absent(),
            shippingDays: p.estShippingDays != null
                ? drift.Value(p.estShippingDays)
                : const drift.Value.absent(),
            shippingFee: p.shippingCost != null
                ? drift.Value(p.shippingCost)
                : const drift.Value.absent(),
            refundable: drift.Value(p.refundable ?? false),
            cashOnDelivery: drift.Value(p.cashOnDelivery ?? true),
            lowStockWarning: p.lowStockQuantity != null
                ? drift.Value(p.lowStockQuantity)
                : const drift.Value.absent(),
            barcode: p.barcode != null
                ? drift.Value(p.barcode)
                : const drift.Value.absent(),
            updatedAt: drift.Value(p.updatedAt ?? DateTime.now().toUtc()),
            synced: const drift.Value(true),
          ),
        );

        // Upsert variant stocks (product_stocks). If backend didn't send any,
        // treat the product as a single-stock item.
        final incomingStocks = p.stocks.isNotEmpty
            ? p.stocks
            : [
                PosSyncProductStock(
                  id: 0,
                  variant: '',
                  price: p.unitPrice,
                  qty: p.currentStock,
                ),
              ];

        final variants = <String>[];
        for (final s in incomingStocks) {
          final variant = s.variant;
          variants.add(variant);
          await db.upsertItemStock(
            ItemStocksCompanion.insert(
              itemId: localId,
              variant: variant,
              remoteStockId: s.id > 0
                  ? drift.Value(s.id)
                  : const drift.Value.absent(),
              price: s.price,
              stockQty: drift.Value(s.qty),
              sku: drift.Value(s.sku),
              imageUploadId: s.imageUploadId != null
                  ? drift.Value(s.imageUploadId)
                  : const drift.Value.absent(),
              imageUrl: drift.Value(s.imageUrl),
              updatedAt: drift.Value(
                s.updatedAt ?? p.updatedAt ?? DateTime.now().toUtc(),
              ),
            ),
          );

          // Keep low-stock alerts in sync even if no local inventory movements
          // occurred (e.g., after a server-side stock adjustment).
          final threshold = p.lowStockQuantity ?? 5;
          await db.upsertOrResolveStockAlert(
            itemId: localId,
            variant: variant,
            stockQty: s.qty,
            threshold: threshold,
          );
        }
        await db.deleteItemStocksNotIn(localId, variants);
      }

      for (final s in pull.services) {
        if (s.id.isEmpty) continue;
        final remoteId = int.tryParse(s.id);
        final existing = remoteId != null
            ? await db.getServiceByRemoteId(remoteId)
            : null;
        final localId = existing?.id ?? s.id;
        final pricingPackagesJson = s.pricingPackages.isNotEmpty
            ? jsonEncode(
                s.pricingPackages
                    .map(
                      (pkg) => {
                        'tier': pkg['tier'],
                        'remote_id': pkg['id'],
                        'price': pkg['price'],
                        if (pkg['delivery_days'] != null)
                          'delivery_days': pkg['delivery_days'],
                        if (pkg['revisions'] != null) 'revisions': pkg['revisions'],
                        if (pkg['description'] != null)
                          'description': pkg['description'],
                      },
                    )
                    .toList(),
              )
            : null;

        await db.upsertService(
          ServicesCompanion.insert(
            id: drift.Value(localId),
            remoteId: remoteId != null
                ? drift.Value(remoteId)
                : const drift.Value.absent(),
            title: s.title.isEmpty ? 'Service' : s.title,
            price: s.price,
            cost: s.purchasePrice != null
                ? drift.Value(s.purchasePrice)
                : const drift.Value.absent(),
            description: drift.Value(s.description),
            imageUrl: drift.Value(s.imageUrl),
            coverUploadId: s.coverUploadId != null
                ? drift.Value(s.coverUploadId)
                : const drift.Value.absent(),
            galleryUrls: s.galleryUrls.isNotEmpty
                ? drift.Value(jsonEncode(s.galleryUrls))
                : const drift.Value.absent(),
            galleryUploadIds: s.photoUploadIds.isNotEmpty
                ? drift.Value(jsonEncode(s.photoUploadIds))
                : const drift.Value.absent(),
            durationMinutes: drift.Value(s.durationMinutes),
            categoryId: s.categoryId != null
                ? drift.Value(s.categoryId)
                : const drift.Value.absent(),
            summary: drift.Value(s.summary),
            serviceType: drift.Value(s.serviceType),
            deliveryTimeframe: drift.Value(s.deliveryTimeframe),
            moderationStatus: drift.Value(s.moderationStatus),
            slug: drift.Value(s.slug),
            pricingPackages: pricingPackagesJson != null
                ? drift.Value(pricingPackagesJson)
                : const drift.Value.absent(),
            category: drift.Value(s.category),
            publishedOnline: drift.Value(s.published),
            updatedAt: drift.Value(s.updatedAt ?? DateTime.now().toUtc()),
            synced: const drift.Value(true),
          ),
        );
      }

      // Upsert service variants from pull
      for (final v in pull.serviceVariants) {
        if (v.id.isEmpty || v.serviceId.isEmpty) continue;
        await db.upsertServiceVariant(
          ServiceVariantsCompanion(
            id: drift.Value(v.id),
            serviceId: drift.Value(v.serviceId),
            name: drift.Value(v.name),
            price: drift.Value(v.price),
            unit: drift.Value(v.unit),
            isDefault: drift.Value(v.isDefault),
            updatedAt: drift.Value(v.updatedAt ?? DateTime.now().toUtc()),
            synced: const drift.Value(true),
          ),
        );
      }

      // Upsert service packages from pull
      for (final p in pull.servicePackages) {
        if (p.id.isEmpty) continue;
        await db
            .into(db.servicePackages)
            .insertOnConflictUpdate(
              ServicePackagesCompanion(
                id: drift.Value(p.id),
                serviceId: drift.Value(p.serviceId),
                name: drift.Value(p.name),
                totalSessions: drift.Value(p.totalSessions),
                price: drift.Value(p.price),
                validityDays: drift.Value(p.validityDays),
                active: drift.Value(p.active),
                updatedAt: drift.Value(p.updatedAt ?? DateTime.now().toUtc()),
                synced: const drift.Value(true),
              ),
            );
      }

      _safeAddStatus('Syncing customers...');
      for (final c in pull.customers) {
        if (c.id.isEmpty) continue;
        final existingById = await db.getCustomerById(c.id);
        final existingByRemote = existingById == null
            ? await db.getCustomerByRemoteId(c.id)
            : null;
        final localId = existingById?.id ?? existingByRemote?.id ?? c.id;

        await db.upsertCustomer(
          CustomersCompanion.insert(
            id: drift.Value(localId),
            remoteId: drift.Value(c.id),
            name: c.name.isEmpty ? 'Customer' : c.name,
            phone: drift.Value(c.phone),
            email: drift.Value(c.email),
            synced: const drift.Value(true),
            updatedAt: drift.Value(c.updatedAt ?? DateTime.now().toUtc()),
          ),
        );
      }

      _safeAddStatus('Syncing suppliers...');
      for (final s in pull.suppliers) {
        if (s.id <= 0) continue;
        await db.upsertSupplier(
          SuppliersCompanion.insert(
            id: drift.Value(s.id),
            name: s.name.isEmpty ? 'Supplier' : s.name,
            contactName: drift.Value(s.contactName),
            phone: drift.Value(s.phone),
            email: drift.Value(s.email),
            address: drift.Value(s.address),
            notes: drift.Value(s.notes),
            active: drift.Value(s.active),
            updatedAt: drift.Value(s.updatedAt ?? DateTime.now().toUtc()),
          ),
        );
      }

      _safeAddStatus('Syncing expenses...');
      // Sync expense categories if receiving full snapshot or if relevant
      try {
        final posToken = await secureStorage.readPosSessionToken();
        if (posToken != null && posToken.trim().isNotEmpty) {
          final categoriesRes = await sellerApi.fetchExpenseCategories();
          final categoriesData = categoriesRes.data;
          final categoriesList =
              (categoriesData is Map ? categoriesData['data'] : categoriesData)
                  as List?;

          if (categoriesList != null) {
            _safeAddStatus('Syncing expense categories...');
            for (final c in categoriesList) {
              if (c is! Map) continue;
              final name = c['name']?.toString() ?? '';
              if (name.isNotEmpty) {
                await db.deleteLocalTemporaryCategory(name);
              }
              await db.upsertExpenseCategory(
                ExpenseCategoriesCompanion(
                  id: drift.Value(_asInt(c['id'])),
                  name: drift.Value(name),
                  type: drift.Value(c['type']?.toString() ?? 'expense'),
                  isActive: drift.Value(_asBool(c['is_active'])),
                  updatedAt: drift.Value(DateTime.now().toUtc()),
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[SyncService] Failed to sync expense categories: $e');
        // Don't fail the whole sync for this
      }

      for (final e in pull.expenses) {
        if (e.id <= 0) continue;

        final clientId = (e.clientExpenseId ?? '').trim();
        Expense? existing;
        String localId;

        if (clientId.isNotEmpty) {
          existing = await db.getExpenseById(clientId);
          localId = existing?.id ?? clientId;
        } else {
          existing = await db.getExpenseByRemoteId(e.id);
          localId = existing?.id ?? e.id.toString();
        }

        final occurredAt =
            e.occurredAt ?? e.updatedAt ?? DateTime.now().toUtc();
        await db.upsertExpense(
          ExpensesCompanion.insert(
            id: drift.Value(localId),
            remoteId: drift.Value(e.id),
            outletId: pull.outletId.trim().isNotEmpty
                ? drift.Value(pull.outletId)
                : const drift.Value.absent(),
            staffId: const drift.Value.absent(),
            amount: e.amount,
            method: e.method.trim().isEmpty ? 'cash' : e.method.trim(),
            category: e.category.trim().isEmpty ? 'other' : e.category.trim(),
            supplierId: e.supplierId != null
                ? drift.Value(e.supplierId)
                : const drift.Value.absent(),
            note: drift.Value(e.note),
            occurredAt: drift.Value(occurredAt),
            synced: const drift.Value(true),
            updatedAt: drift.Value(e.updatedAt ?? DateTime.now().toUtc()),
          ),
        );
      }

      // Sync quotations (pulled from server)
      _safeAddStatus('Syncing quotations...');
      for (final q in pull.quotations) {
        if (q.id.isEmpty) continue;

        // Upsert quotation using insertOnConflictUpdate
        await db
            .into(db.quotations)
            .insertOnConflictUpdate(
              QuotationsCompanion(
                id: drift.Value(q.id),
                number: drift.Value(q.quotationNumber),
                customerId: drift.Value(q.customerId),
                validUntil: drift.Value(
                  DateTime.now().add(Duration(days: q.validityDays)),
                ),
                totalAmount: drift.Value(q.total),
                notes: drift.Value(q.notes),
                synced: const drift.Value(true),
              ),
            );
      }

      // Sync customer packages
      _safeAddStatus('Syncing packages...');
      for (final p in pull.customerPackages) {
        if (p.id.isEmpty) continue;
        await db
            .into(db.customerPackages)
            .insertOnConflictUpdate(
              CustomerPackagesCompanion(
                id: drift.Value(p.id),
                packageId: drift.Value(p.packageId),
                customerId: drift.Value(p.customerId),
                remainingSessions: drift.Value(p.remainingSessions),
                expiresAt: drift.Value(p.expiresAt),
                synced: const drift.Value(true),
              ),
            );
      }

      // Sync redemptions
      for (final r in pull.packageRedemptions) {
        if (r.id.isEmpty) continue;
        await db
            .into(db.packageRedemptions)
            .insertOnConflictUpdate(
              PackageRedemptionsCompanion(
                id: drift.Value(r.id),
                customerPackageId: drift.Value(r.customerPackageId),
                sessionsUsed: drift.Value(r.sessionsUsed),
                note: drift.Value(r.note),
                synced: const drift.Value(true),
              ),
            );
      }

      // Sync shifts (pulled from server)
      _safeAddStatus('Syncing shifts...');
      for (final s in pull.shifts) {
        if (s.id.isEmpty) continue;

        await db
            .into(db.shifts)
            .insertOnConflictUpdate(
              ShiftsCompanion(
                id: drift.Value(s.id),
                outletId: drift.Value(s.outletId?.toString()),
                staffId: drift.Value(s.staffId?.toString()),
                openedAt: drift.Value(s.openedAt),
                closedAt: drift.Value(s.closedAt),
                openingFloat: drift.Value(s.openingFloat),
                closingFloat: drift.Value(s.closingFloat ?? 0),
                synced: const drift.Value(true),
              ),
            );
      }

      // Sync cash movements (pulled from server)
      _safeAddStatus('Syncing cash movements...');
      for (final m in pull.cashMovements) {
        if (m.id <= 0) continue;
        final key = m.idempotencyKey.trim();
        final existingByRemote = await db.getCashMovementByRemoteId(m.id);
        if (existingByRemote != null) {
          await db.updateCashMovement(
            existingByRemote.id,
            CashMovementsCompanion(
              idempotencyKey: key.isEmpty
                  ? const drift.Value.absent()
                  : drift.Value(key),
              type: drift.Value(
                m.type.trim().isEmpty ? 'withdrawal' : m.type.trim(),
              ),
              amount: drift.Value(m.amount),
              note: drift.Value(m.note),
              createdAt: drift.Value(
                m.createdAt ?? m.updatedAt ?? DateTime.now().toUtc(),
              ),
            ),
          );
          continue;
        }

        if (key.isNotEmpty) {
          final existingByKey = await db.getCashMovementByIdempotencyKey(key);
          if (existingByKey != null) {
            await db.updateCashMovement(
              existingByKey.id,
              CashMovementsCompanion(
                remoteId: drift.Value(m.id),
                idempotencyKey: drift.Value(key),
                type: drift.Value(
                  m.type.trim().isEmpty ? 'withdrawal' : m.type.trim(),
                ),
                amount: drift.Value(m.amount),
                note: drift.Value(m.note),
                createdAt: drift.Value(
                  m.createdAt ?? m.updatedAt ?? DateTime.now().toUtc(),
                ),
              ),
            );
            continue;
          }
        }

        await db
            .into(db.cashMovements)
            .insert(
              CashMovementsCompanion.insert(
                remoteId: drift.Value(m.id),
                idempotencyKey: key.isEmpty
                    ? const drift.Value.absent()
                    : drift.Value(key),
                outletId: pull.outletId.trim().isNotEmpty
                    ? drift.Value(pull.outletId)
                    : const drift.Value.absent(),
                staffId: m.staffId != null
                    ? drift.Value(m.staffId.toString())
                    : const drift.Value.absent(),
                type: m.type.trim().isEmpty ? 'withdrawal' : m.type.trim(),
                amount: m.amount,
                note: drift.Value(m.note),
                createdAt: drift.Value(
                  m.createdAt ?? m.updatedAt ?? DateTime.now().toUtc(),
                ),
              ),
            );
      }

      _safeAddStatus('Syncing settings...');
      for (final setting in pull.settings) {
        if (setting.key.isEmpty) continue;
        await db.upsertAppSetting(
          AppSettingsCompanion.insert(
            key: setting.key,
            valueJson: drift.Value(jsonEncode(setting.value)),
            updatedAt: drift.Value(setting.updatedAt ?? DateTime.now().toUtc()),
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

      final businessProfile = pull.businessProfile;
      if (businessProfile != null && businessProfile.shopName.isNotEmpty) {
        _safeAddStatus('Syncing business profile...');
        await db.upsertBusinessProfile(
          BusinessProfilesCompanion.insert(
            id: kPrimaryBusinessProfileId,
            sellerId: drift.Value(
              businessProfile.sellerId.trim().isEmpty
                  ? null
                  : businessProfile.sellerId,
            ),
            sellerName: drift.Value(businessProfile.sellerName),
            sellerEmail: drift.Value(businessProfile.sellerEmail),
            sellerPhone: drift.Value(businessProfile.sellerPhone),
            shopId: drift.Value(businessProfile.shopId),
            shopName: businessProfile.shopName,
            shopAddress: drift.Value(businessProfile.shopAddress),
            shopPhone: drift.Value(businessProfile.shopPhone),
            logoUploadId: businessProfile.logoUploadId != null
                ? drift.Value(businessProfile.logoUploadId)
                : const drift.Value.absent(),
            logoUrl: drift.Value(businessProfile.logoUrl),
            metaTitle: drift.Value(businessProfile.metaTitle),
            metaDescription: drift.Value(businessProfile.metaDescription),
            thermalPrinterWidth: businessProfile.thermalPrinterWidth != null
                ? drift.Value(businessProfile.thermalPrinterWidth)
                : const drift.Value.absent(),
            shippingCost: businessProfile.shippingCost != null
                ? drift.Value(businessProfile.shippingCost)
                : const drift.Value.absent(),
            selfDeliveryActive: drift.Value(businessProfile.selfDeliveryActive),
            deliveryRadiusKm: businessProfile.deliveryRadiusKm != null
                ? drift.Value(businessProfile.deliveryRadiusKm)
                : const drift.Value.absent(),
            deliveryPickupLatitude:
                businessProfile.deliveryPickupLatitude != null
                ? drift.Value(businessProfile.deliveryPickupLatitude)
                : const drift.Value.absent(),
            deliveryPickupLongitude:
                businessProfile.deliveryPickupLongitude != null
                ? drift.Value(businessProfile.deliveryPickupLongitude)
                : const drift.Value.absent(),
            cashOnDeliveryEnabled: drift.Value(
              businessProfile.cashOnDeliveryEnabled,
            ),
            bankPaymentEnabled: drift.Value(businessProfile.bankPaymentEnabled),
            mobileMoneyEnabled: drift.Value(businessProfile.mobileMoneyEnabled),
            bankName: drift.Value(businessProfile.bankName),
            bankAccName: drift.Value(businessProfile.bankAccName),
            bankAccNo: drift.Value(businessProfile.bankAccNo),
            bankRoutingNo: drift.Value(businessProfile.bankRoutingNo),
            mtnMerchantCode: drift.Value(businessProfile.mtnMerchantCode),
            airtelMerchantCode: drift.Value(businessProfile.airtelMerchantCode),
            paybillNumber: drift.Value(businessProfile.paybillNumber),
            receiptPaymentMethodsJson: drift.Value(
              jsonEncode(businessProfile.receiptPaymentMethods),
            ),
            deliveryProfileJson: drift.Value(
              jsonEncode(businessProfile.deliveryProfile),
            ),
            updatedAt: drift.Value(
              businessProfile.updatedAt ?? DateTime.now().toUtc(),
            ),
            synced: const drift.Value(true),
          ),
        );
        // Cache verification status separately for easy UI access
        if (businessProfile.verificationStatus != null) {
          await db.upsertAppSetting(
            AppSettingsCompanion(
              key: const drift.Value('shop_verification_status'),
              valueJson: drift.Value(
                businessProfile.verificationStatus.toString(),
              ),
            ),
          );
        }
      }

      for (final t in pull.receiptTemplates) {
        await db
            .into(db.receiptTemplates)
            .insertOnConflictUpdate(
              ReceiptTemplatesCompanion.insert(
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
              ),
            );
      }

      for (final t in pull.quotationTemplates) {
        await db
            .into(db.quotationTemplates)
            .insertOnConflictUpdate(
              QuotationTemplatesCompanion.insert(
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
              ),
            );
      }

      _safeAddStatus('Syncing transactions...');
      for (final e in pull.ledgerEntries) {
        if (e.clientEntryId.isEmpty) continue;

        final List<LedgerLinesCompanion> lines = e.lines
            .map(
              (l) => LedgerLinesCompanion.insert(
                entryId: e.clientEntryId,
                title: l.title,
                quantity: l.quantity,
                unitPrice: l.price,
                lineTotal: l.total,
                itemId: drift.Value(l.itemId),
                serviceId: drift.Value(l.serviceId),
                variant: drift.Value(l.variation),
              ),
            )
            .toList();

        final List<PaymentsCompanion> payments = e.payments
            .map(
              (p) => PaymentsCompanion.insert(
                entryId: e.clientEntryId,
                method: p.method,
                amount: p.amount,
              ),
            )
            .toList();

        await db.upsertLedgerEntryFromSync(
          entry: LedgerEntriesCompanion.insert(
            id: drift.Value(e.clientEntryId),
            idempotencyKey:
                e.clientEntryId, // Use client ID as idempotency key for now
            type: e.type,
            subtotal: drift.Value(e.subtotal),
            discount: drift.Value(e.discount),
            tax: drift.Value(e.tax),
            total: drift.Value(e.total),
            note: drift.Value(e.note),
            synced: const drift.Value(true),
            remoteAck: drift.Value(
              jsonEncode({
                'server_entry_id': e.id,
                'received_at': e.updatedAt?.toIso8601String(),
              }),
            ),
            customerId: drift.Value(e.customerId),
            createdAt: drift.Value(e.occurredAt ?? DateTime.now().toUtc()),
          ),
          lines: lines,
          payments: payments,
        );
      }

      if (pull.sellerProfile != null) {
        _safeAddStatus('Syncing profile...');
        await secureStorage.write(
          key: 'seller_profile',
          value: jsonEncode({
            'id': pull.sellerProfile!.id,
            'name': pull.sellerProfile!.name,
            'email': pull.sellerProfile!.email,
            'phone': pull.sellerProfile!.phone,
            'business_name': pull.sellerProfile!.businessName,
          }),
        );
      }

      // Update cursors BEFORE pruning so that a crash during pruning
      // leaves cursors intact. On next restart the sync will resume
      // from a known cursor rather than doing a delta on stale cursors
      // and permanently losing items that were pruned.
      await Future.wait(
        _pullCursorKeys.map((key) => db.setLastPulledAt(key, pull.receivedAt)),
      );

      if (pull.isFullSnapshot) {
        await _applyFullSnapshotPruning(pull);
      }

      // Debug: Log total items in DB after sync
      final allItems = await db.getAllItems();
      final allServices = await db.getAllServices();
      if (kDebugMode) {
        debugPrint(
          '[SyncService] After sync: ${allItems.length} total items and ${allServices.length} total services in local DB',
        );
      }

      final shouldRepairCatalog =
          allowCatalogRepair &&
          since.millisecondsSinceEpoch != 0 &&
          _needsCatalogRepair(
            pull: pull,
            items: allItems,
            services: allServices,
          );
      if (shouldRepairCatalog) {
        if (kDebugMode) {
          debugPrint(
            '[SyncService] Local catalog is incomplete compared to cloud metadata - forcing full resync',
          );
        }
        _safeAddStatus('Refreshing full catalog snapshot...');
        await db.delete(db.syncCursors).go();
        await _pullPosDeltaInternal(allowCatalogRepair: false);
        return;
      }

      try {
        _safeAddStatus('Caching media for offline use...');
        final allVariantStocks = await (db.select(db.itemStocks)).get();
        await _primeOfflineMediaCache(
          allItems,
          allServices,
          variantStocks: allVariantStocks,
          businessLogoUrl: businessProfile?.logoUrl,
        );
      } catch (e, st) {
        final telemetry = Telemetry.instance;
        if (telemetry != null) {
          unawaited(
            telemetry.recordError(e, st, hint: 'primeOfflineMediaCache'),
          );
        }
        if (kDebugMode) {
          debugPrint('[SyncService] Failed to cache media offline: $e');
        }
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (DioAuthUtils.isAuthStatus(status)) {
        if (kDebugMode) {
          debugPrint(
            '[SyncService] Auth expired during sync pull; '
            'stopping sync until re-authenticated.',
          );
        }
        DioAuthUtils.notifySyncDeferred();
        return;
      }
      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(telemetry.recordError(e, e.stackTrace, hint: 'pullPosDelta'));
      }
      if (kDebugMode) {
        debugPrint('[SyncService] ERROR in _pullPosDeltaInternal: $e');
        debugPrint(e.stackTrace.toString());
      }
      rethrow;
    } catch (e, st) {
      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(telemetry.recordError(e, st, hint: 'pullPosDelta'));
      }
      if (kDebugMode) {
        debugPrint('[SyncService] ERROR in _pullPosDeltaInternal: $e');
        debugPrint(st.toString());
      }
      rethrow;
    }
  }

  Future<void> _primeOfflineMediaCache(
    List<Item> items,
    List<Service> services, {
    List<ItemStock> variantStocks = const [],
    String? businessLogoUrl,
  }) async {
    final urls = <String>{};
    for (final item in items) {
      if (_isNetworkUrl(item.imageUrl)) {
        urls.add(item.imageUrl!.trim());
      }
      if (_isNetworkUrl(item.thumbnailUrl)) {
        urls.add(item.thumbnailUrl!.trim());
      }
      for (final galleryUrl in _decodeStringList(item.galleryUrls)) {
        if (_isNetworkUrl(galleryUrl)) {
          urls.add(galleryUrl.trim());
        }
      }
    }
    for (final stock in variantStocks) {
      if (_isNetworkUrl(stock.imageUrl)) {
        urls.add(stock.imageUrl!.trim());
      }
    }
    for (final service in services) {
      if (_isNetworkUrl(service.imageUrl)) {
        urls.add(service.imageUrl!.trim());
      }
    }
    if (_isNetworkUrl(businessLogoUrl)) {
      urls.add(businessLogoUrl!.trim());
    }
    if (urls.isEmpty) return;
    if (kDebugMode) {
      debugPrint(
        '[SyncService] Priming offline media cache for ${urls.length} assets',
      );
    }
    await OfflineMediaCache.instance.prefetchAll(urls);
  }

  Future<void> _applyFullSnapshotPruning(PosSyncPullResponse pull) async {
    await db.pruneSyncedRemoteItemsNotIn(pull.snapshotProductIds);
    await db.pruneSyncedRemoteServicesNotIn(pull.snapshotServiceIds);
    await db.pruneSyncedServiceVariantsNotIn(pull.snapshotServiceVariantIds);
    await db.pruneSyncedServicePackagesNotIn(pull.snapshotServicePackageIds);
    await db.pruneSyncedCustomerPackagesNotIn(pull.snapshotCustomerPackageIds);
    await db.pruneSyncedPackageRedemptionsNotIn(
      pull.snapshotPackageRedemptionIds,
    );
  }

  bool _isNetworkUrl(String? value) {
    if (value == null) return false;
    final raw = value.trim();
    if (raw.isEmpty) return false;
    final scheme = Uri.tryParse(raw)?.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  Future<void> pullSellerProducts() async {
    await pullPosDelta();
  }

  Future<void> pullSellerServices() async {
    await pullPosDelta();
  }

  bool _needsCatalogRepair({
    required PosSyncPullResponse pull,
    required List<Item> items,
    required List<Service> services,
  }) {
    final localProductImageCount = items
        .where(
          (item) =>
              item.imageUrl?.trim().isNotEmpty == true ||
              item.thumbnailUrl?.trim().isNotEmpty == true ||
              _decodeStringList(item.galleryUrls).isNotEmpty,
        )
        .length;
    final localServiceImageCount = services
        .where((service) => service.imageUrl?.trim().isNotEmpty == true)
        .length;

    return items.length < pull.catalogProductCount ||
        services.length < pull.catalogServiceCount ||
        localProductImageCount < pull.catalogProductImageCount ||
        localServiceImageCount < pull.catalogServiceImageCount;
  }

  Future<void> pullCustomers() async {
    await pullPosDelta();
  }

  Future<void> pullConfig() async {
    await pullPosDelta();
  }

  Future<void> pullMarketplaceOrders() async {
    final res = await sellerApi.fetchOrders();
    final data = res.data;
    final listRaw = data is Map<String, dynamic>
        ? (data['data'] ?? const [])
        : data;
    final list = MarketplaceOrder.listFromJson(listRaw as Iterable);
    for (final order in list) {
      await _upsertMergedCachedOrder(order);
    }
  }

  Future<MarketplaceOrder?> pullMarketplaceOrderDetail(int orderId) async {
    if (orderId <= 0) return null;

    MarketplaceOrder? cached;
    final row = await db.getCachedOrder(orderId);
    if (row != null) {
      try {
        cached = MarketplaceOrder.fromJson(
          Map<String, dynamic>.from(jsonDecode(row.payloadJson) as Map),
        );
      } catch (_) {
        cached = null;
      }
    }

    try {
      final res = await sellerApi.fetchOrderDetails(orderId);
      final raw = res.data;
      final listRaw = raw is Map<String, dynamic> ? raw['data'] : raw;
      final first = (listRaw is List && listRaw.isNotEmpty)
          ? listRaw.first
          : null;
      if (first is! Map) {
        return cached;
      }

      final details = MarketplaceOrder.fromJson(Map<String, dynamic>.from(first));
      final merged = cached == null ? details : cached.merge(details);
      await db.upsertCachedOrder(orderId, jsonEncode(merged.toJson()));
      return merged;
    } catch (_) {
      return cached;
    }
  }

  Future<void> _upsertMergedCachedOrder(MarketplaceOrder order) async {
    if (order.id <= 0) return;
    final row = await db.getCachedOrder(order.id);
    if (row == null) {
      await db.upsertCachedOrder(order.id, jsonEncode(order.toJson()));
      return;
    }

    try {
      final cached = MarketplaceOrder.fromJson(
        Map<String, dynamic>.from(jsonDecode(row.payloadJson) as Map),
      );
      final merged = cached.merge(order);
      await db.upsertCachedOrder(order.id, jsonEncode(merged.toJson()));
    } catch (_) {
      await db.upsertCachedOrder(order.id, jsonEncode(order.toJson()));
    }
  }

  Future<void> pullServiceBookings() async {
    final res = await sellerApi.fetchServiceBookings();
    final data = res.data;

    // Detect missing backend route and suppress future calls.
    if (data is Map<String, dynamic> &&
        data['success'] == false &&
        (data['status'] == 404 || data['message'] == 'Invalid Route')) {
      _bookingsRouteAvailable = false;
      return;
    }

    final listRaw = data is Map<String, dynamic>
        ? (data['data'] ?? const [])
        : data;
    final list = List<Map<String, dynamic>>.from(
      (listRaw as Iterable).whereType<Map>().map(
        (e) => Map<String, dynamic>.from(e),
      ),
    );
    for (final booking in list) {
      final id = int.tryParse(booking['id']?.toString() ?? '');
      if (id == null) continue;
      await db.upsertCachedServiceBooking(id, jsonEncode(booking));
    }
  }

  Future<void> pullAvailability() async {
    final res = await sellerApi.fetchAvailability();
    final data = res.data is Map ? res.data as Map<String, dynamic> : <String, dynamic>{};
    final listRaw = data['data'] ?? const [];
    final list = List<Map<String, dynamic>>.from(
      (listRaw as Iterable).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
    );

    await db.deleteAllAvailabilitySchedules();
    for (final s in list) {
      await db.upsertAvailabilitySchedule(
        AvailabilitySchedulesCompanion.insert(
          dayOfWeek: s['day_of_week'] as int,
          startTime: s['start_time'] as String,
          endTime: s['end_time'] as String,
          isAvailable: drift.Value(s['is_available'] as bool? ?? true),
        ),
      );
    }
  }

  Future<void> pullAvailabilityExceptions() async {
    final res = await sellerApi.fetchAvailabilityExceptions();
    final data = res.data is Map ? res.data as Map<String, dynamic> : <String, dynamic>{};
    final listRaw = data['data'] ?? const [];
    final list = List<Map<String, dynamic>>.from(
      (listRaw as Iterable).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
    );

    await db.deleteAllAvailabilityExceptions();
    for (final e in list) {
      await db.upsertAvailabilityException(
        AvailabilityExceptionsCompanion.insert(
          remoteId: e['id'] != null ? drift.Value(e['id'] as int) : const drift.Value.absent(),
          date: e['date'] as String,
          isAvailable: drift.Value(e['is_available'] as bool? ?? false),
          startTime: e['start_time'] != null ? drift.Value(e['start_time'] as String) : const drift.Value.absent(),
          endTime: e['end_time'] != null ? drift.Value(e['end_time'] as String) : const drift.Value.absent(),
          reason: e['reason'] != null ? drift.Value(e['reason'] as String) : const drift.Value.absent(),
        ),
      );
    }
  }

  Future<void> syncDeviceContacts({
    bool force = false,
    List<Contact>? contacts,
  }) async {
    final optedIn = await isDeviceContactsOptedIn();
    if (!optedIn) return;

    final status = await Permission.contacts.status;
    if (!status.isGranted) return;

    if (!force) {
      final lastSyncRaw = await secureStorage.read(key: _contactsSyncKey);
      if (lastSyncRaw != null) {
        final lastSync = DateTime.tryParse(lastSyncRaw)?.toUtc();
        if (lastSync != null &&
            DateTime.now().toUtc().difference(lastSync) < _contactsSyncInterval) {
          // Skip interval check only when contact count changed — new contacts
          // should sync immediately even if the interval hasn't elapsed.
          final lastCountRaw = await secureStorage.read(key: _contactsCountKey);
          final lastCount = int.tryParse(lastCountRaw ?? '') ?? -1;
          if (lastCount >= 0) {
            final quickCount = await FlutterContacts.getContacts();
            if (quickCount.length == lastCount) return; // nothing new
            // Contact count changed — fall through to full sync below.
          } else {
            return;
          }
        }
      }
    }

    final sw = Stopwatch()..start();
    try {
      final deviceContacts =
          contacts ?? await FlutterContacts.getContacts(withProperties: true);
      if (deviceContacts.isEmpty) {
        await secureStorage.write(
          key: _contactsSyncKey,
          value: DateTime.now().toUtc().toIso8601String(),
        );
        return;
      }

      _safeAddStatus('Syncing contacts...');
      await importDeviceContacts(deviceContacts);
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

          final deviceId = payload['external_id']?.toString() ?? '';
          final phone = _firstString(phones);
          final email = _firstString(emails);

          String? linkedCustomerId;
          if (deviceId.isNotEmpty) {
            final dc = await (db.select(
              db.deviceContacts,
            )..where((t) => t.deviceId.equals(deviceId))).getSingleOrNull();
            linkedCustomerId = dc?.linkedCustomerId;
          }

          Customer? existing;
          if (linkedCustomerId != null && linkedCustomerId.trim().isNotEmpty) {
            existing = await db.getCustomerById(linkedCustomerId.trim());
          }
          existing ??= (contactId.isNotEmpty
              ? await db.getCustomerByRemoteId(contactId)
              : null);
          existing ??= (phone != null && phone.isNotEmpty
              ? await db.getCustomerByPhoneE164(phone)
              : null);
          existing ??= (email != null && email.isNotEmpty
              ? await db.getCustomerByEmail(email)
              : null);

          final localCustomerId = existing?.id ?? _uuid.v4();
          await db.upsertCustomer(
            CustomersCompanion.insert(
              id: drift.Value(localCustomerId),
              remoteId: drift.Value(contactId),
              name: payload['display_name']?.toString() ?? 'Contact',
              phone: drift.Value(phone),
              email: drift.Value(email),
              synced: const drift.Value(true),
              updatedAt: drift.Value(updatedAt ?? DateTime.now().toUtc()),
            ),
          );

          if (deviceId.isNotEmpty) {
            await db.linkDeviceContactToCustomer(
              deviceId: deviceId,
              customerId: localCustomerId,
            );
          }
        }
      }

      await secureStorage.write(
        key: _contactsSyncKey,
        value: DateTime.now().toUtc().toIso8601String(),
      );
      await secureStorage.write(
        key: _contactsCountKey,
        value: deviceContacts.length.toString(),
      );

      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(
          telemetry.event(
            'contacts_sync_success',
            props: {
              'device_contacts': deviceContacts.length,
              'payload_count': payloads.length,
              'duration_ms': sw.elapsedMilliseconds,
            },
          ),
        );
      }
    } catch (e, st) {
      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(
          telemetry.event(
            'contacts_sync_fail',
            props: {
              'duration_ms': sw.elapsedMilliseconds,
              'error': e.toString(),
            },
          ),
        );
        unawaited(telemetry.recordError(e, st, hint: 'contacts_sync'));
      }
      rethrow;
    }
  }

  Future<void> pullCrmContacts() async {
    final lastPull = await lastCrmContactsPullAt();
    final updatedSince = lastPull?.toIso8601String();

    _safeAddStatus('Pulling CRM contacts...');
    final sw = Stopwatch()..start();

    try {
      int page = 1;
      while (true) {
        final res = await sellerApi.fetchCrmContacts(
          updatedSince: updatedSince,
          perPage: 100,
          page: page,
        );
        final body = res.data;
        if (body is! Map<String, dynamic>) break;

        final data = body['data'];
        if (data is! Map<String, dynamic>) break;

        final listRaw = data['data'];
        if (listRaw is! List) break;

        if (listRaw.isEmpty) break;

        for (final item in listRaw) {
          if (item is! Map<String, dynamic>) continue;
          final contactId = item['id']?.toString();
          if (contactId == null || contactId.isEmpty) continue;

          final displayName = item['display_name']?.toString() ?? 'Contact';
          final updatedAtRaw = item['updated_at']?.toString();
          final updatedAt = updatedAtRaw != null
              ? DateTime.tryParse(updatedAtRaw)?.toUtc()
              : null;

          String? primaryPhone;
          String? primaryEmail;
          final channelsRaw = item['channels'];
          if (channelsRaw is List) {
            for (final ch in channelsRaw) {
              if (ch is! Map<String, dynamic>) continue;
              final type = ch['type']?.toString();
              final value = ch['value_raw']?.toString();
              final isPrimary = ch['is_primary'] == true || ch['is_primary'] == 1;
              if (value == null || value.isEmpty) continue;
              if (type == 'phone' && (primaryPhone == null || isPrimary)) {
                primaryPhone = value;
              }
              if (type == 'email' && (primaryEmail == null || isPrimary)) {
                primaryEmail = value;
              }
            }
          }

          Customer? existing;
          existing = await db.getCustomerByRemoteId(contactId);
          existing ??= primaryPhone != null && primaryPhone.isNotEmpty
              ? await db.getCustomerByPhoneE164(primaryPhone)
              : null;
          existing ??= primaryEmail != null && primaryEmail.isNotEmpty
              ? await db.getCustomerByEmail(primaryEmail)
              : null;

          final localId = existing?.id ?? _uuid.v4();
          await db.upsertCustomer(
            CustomersCompanion.insert(
              id: drift.Value(localId),
              remoteId: drift.Value(contactId),
              name: displayName,
              phone: drift.Value(primaryPhone),
              email: drift.Value(primaryEmail),
              synced: const drift.Value(true),
              updatedAt: drift.Value(updatedAt ?? DateTime.now().toUtc()),
            ),
          );
        }

        final currentPage = data['current_page'];
        final lastPage = data['last_page'];
        if (currentPage is int && lastPage is int) {
          if (currentPage >= lastPage) break;
        }
        page++;
      }

      await setLastCrmContactsPullAt(DateTime.now().toUtc());

      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(
          telemetry.event(
            'crm_contacts_pull_success',
            props: {'duration_ms': sw.elapsedMilliseconds},
          ),
        );
      }
    } catch (e, st) {
      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(
          telemetry.event(
            'crm_contacts_pull_fail',
            props: {
              'duration_ms': sw.elapsedMilliseconds,
              'error': e.toString(),
            },
          ),
        );
        unawaited(telemetry.recordError(e, st, hint: 'crm_contacts_pull'));
      }
      rethrow;
    }
  }

  Future<void> importDeviceContacts(List<Contact> contacts) async {
    final now = DateTime.now().toUtc();
    for (final contact in contacts) {
      final name = contact.displayName.trim();
      final phones = _uniquePhones(contact.phones);
      final emails = _uniqueEmails(contact.emails);

      if (name.isEmpty && phones.isEmpty && emails.isEmpty) continue;

      final displayName = name.isNotEmpty
          ? name
          : (phones.isNotEmpty ? phones.first : emails.first);

      final primaryPhone = phones.isNotEmpty ? phones.first : null;
      final primaryEmail = emails.isNotEmpty ? emails.first : null;

      Customer? matched;
      if (primaryPhone != null) {
        matched = await db.getCustomerByPhoneE164(primaryPhone);
      }
      matched ??= primaryEmail != null
          ? await db.getCustomerByEmail(primaryEmail)
          : null;

      await db.upsertDeviceContact(
        DeviceContactsCompanion.insert(
          deviceId: contact.id,
          displayName: displayName,
          primaryPhoneE164: drift.Value(primaryPhone),
          primaryEmail: drift.Value(primaryEmail),
          phonesJson: drift.Value(jsonEncode(phones)),
          emailsJson: drift.Value(jsonEncode(emails)),
          linkedCustomerId: drift.Value(matched?.id),
          updatedAt: drift.Value(now),
        ),
      );
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    await _syncStatusController.close();
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
        out.add(_truncate(normalized, 64));
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

int _asInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is bool) return value ? 1 : 0;
  return int.tryParse(value.toString()) ?? 0;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is bool) return value ? 1 : 0;
  return int.tryParse(value.toString());
}

double _asDouble(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is bool) return value ? 1 : 0;
  return double.tryParse(value.toString()) ?? 0;
}

bool _asBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = value.toString().trim().toLowerCase();
  if (s == 'true' || s == '1' || s == 'yes') return true;
  if (s == 'false' || s == '0' || s == 'no') return false;
  return false;
}
