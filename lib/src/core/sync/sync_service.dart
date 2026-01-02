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
  static const _contactsOptInKey = 'device_contacts_opt_in';
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
      if (kDebugMode) {
        debugPrint('[SyncService] No items in DB - triggering full resync from epoch...');
      }
      await forceFullResync();
    } else {
      if (kDebugMode) {
        debugPrint('[SyncService] Have ${items.length} items in DB - normal sync');
      }
      await _pump();
    }
  }

  Future<void> syncNow() => _pump();

  /// Force a complete resync by clearing all sync cursors and pulling from epoch.
  /// This is useful when the initial sync failed or products are missing.
  Future<void> forceFullResync() async {
    if (kDebugMode) {
      debugPrint('[SyncService] Starting FULL RESYNC from epoch...');
    }
    
    // Clear all sync cursors
    await db.customStatement('DELETE FROM sync_cursors');
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

  Future<void> _pump() async {
    if (_isPumping) {
      _pumpQueued = true;
      return;
    }

    _isPumping = true;
    try {
      final List<ConnectivityResult> list = await Connectivity()
          .checkConnectivity();
      final online = list.any((r) => r != ConnectivityResult.none);
      if (!online) return;

      final queue = await db.pendingSyncOps();
      for (final op in queue) {
        if (!_isDue(op)) continue;
        try {
          await _dispatch(op);
          await db.markSynced(op.id);
        } catch (e) {
          final errorMsg = _formatSyncError(e);
          final nextRetryCount = op.retryCount + 1;
          final blocked = _shouldBlock(e);
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
        }
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
      try {
        await pullServiceBookings();
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

      final message = serverMessage ?? error.message ?? error.error?.toString() ?? 'DioException';
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
    if (status == 408) return false;
    if (status == 409) {
      final data = error.response?.data;
      final msg = (data is Map ? data['message']?.toString() : null) ?? '';
      final normalized = msg.toLowerCase();
      if (normalized.contains('still being processed')) return false;
      if (normalized.contains('referenced sale') && normalized.contains('not found')) {
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

  Future<int?> _resolveRemoteProductId(dynamic raw) async {
    if (raw == null) return null;
    final asInt = _asNullableInt(raw);
    if (asInt != null) return asInt;
    final id = raw.toString().trim();
    if (id.isEmpty) return null;
    final item = await db.getItemById(id);
    return item?.remoteId ?? _asNullableInt(id);
  }

  Future<int?> _resolveRemoteServiceId(dynamic raw) async {
    if (raw == null) return null;
    final asInt = _asNullableInt(raw);
    if (asInt != null) return asInt;
    final id = raw.toString().trim();
    if (id.isEmpty) return null;
    final service = await db.getServiceById(id);
    return service?.remoteId ?? _asNullableInt(id);
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
  }

  List<String> _decodeStringList(String? raw) {
    if (raw == null) return const [];
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded.map((e) => e?.toString() ?? '').where((e) => e.trim().isNotEmpty).toList();
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
        return decoded.map((e) => int.tryParse(e?.toString() ?? '')).whereType<int>().toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> _pushItemVariantStocks(String localId, int remoteProductId) async {
    final item = await db.getItemById(localId);
    if (item == null) return;

    final stocks = await db.getItemStocksForItem(localId);
    final variants = stocks.where((s) => s.variant.trim().isNotEmpty).toList();
    if (variants.isEmpty) return;

    for (final s in variants) {
      final variant = s.variant.trim();
      if (variant.isEmpty) continue;

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
          await (db.update(db.itemStocks)
                ..where(
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
          await (db.update(db.itemStocks)
                ..where(
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

      final safeVariantKey =
          variant.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
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
        final first =
            (listRaw is List && listRaw.isNotEmpty) ? listRaw.first : null;
        if (first is Map) {
          await db.upsertCachedOrder(
            orderId,
            jsonEncode(Map<String, dynamic>.from(first)),
          );
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

        final apiDiscountType =
            _toApiDiscountType(payload['discount_type'] ?? item?.discountType);

        final upsertPayload = <String, dynamic>{
          if (remoteId != null) 'product_id': remoteId,
          'name': (payload['name'] ?? item?.name ?? '').toString(),
          'unit_price': _asDouble(payload['unit_price'] ?? item?.price ?? 0),
          'current_stock': _asInt(payload['current_stock'] ?? item?.stockQty ?? 0),
          'published': _asBool(payload['published'] ?? item?.publishedOnline ?? false),
          if (_asNullableInt(payload['category_id']) != null)
            'category_id': _asNullableInt(payload['category_id']),
          if (_asNullableInt(payload['brand_id']) != null) 'brand_id': _asNullableInt(payload['brand_id']),
          if ((payload['unit'] ?? item?.unit) != null) 'unit': (payload['unit'] ?? item?.unit).toString(),
          if (payload['weight'] != null || item?.weight != null)
            'weight': _asDouble(payload['weight'] ?? item?.weight ?? 0),
          if (payload['min_qty'] != null || item?.minPurchaseQty != null)
            'min_qty': _asInt(payload['min_qty'] ?? item?.minPurchaseQty ?? 1),
          if (payload['low_stock_quantity'] != null || item?.lowStockWarning != null)
            'low_stock_quantity': _asInt(payload['low_stock_quantity'] ?? item?.lowStockWarning ?? 0),
          if (payload['discount'] != null || item?.discount != null)
            'discount': _asDouble(payload['discount'] ?? item?.discount ?? 0),
          if (apiDiscountType != null) 'discount_type': apiDiscountType,
          if (payload['shipping_cost'] != null || item?.shippingFee != null)
            'shipping_cost': _asDouble(payload['shipping_cost'] ?? item?.shippingFee ?? 0),
          if (payload['est_shipping_days'] != null || item?.shippingDays != null)
            'est_shipping_days': _asInt(payload['est_shipping_days'] ?? item?.shippingDays ?? 0),
          if (payload['refundable'] != null || item?.refundable != null)
            'refundable': _asBool(payload['refundable'] ?? item?.refundable ?? false),
          if (payload['cash_on_delivery'] != null || item?.cashOnDelivery != null)
            'cash_on_delivery': _asBool(payload['cash_on_delivery'] ?? item?.cashOnDelivery ?? true),
          if (payload['tags'] != null) 'tags': payload['tags'],
          if (payload['description'] != null) 'description': payload['description'],
          if (payload['sku'] != null || item?.sku != null) 'sku': payload['sku'] ?? item?.sku,
          if (payload['barcode'] != null || item?.barcode != null)
            'barcode': payload['barcode'] ?? item?.barcode,
        };

        // Fill category/brand from local item if missing.
        final categoryIdRaw = (payload['category_id'] ?? item?.categoryId)?.toString();
        if (!upsertPayload.containsKey('category_id') && categoryIdRaw != null) {
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
        if (!upsertPayload.containsKey('description') && item?.description != null) {
          upsertPayload['description'] = item!.description;
        }

        // Images: upload any pending local files and attach upload IDs.
        if (item != null) {
          // Thumbnail
          var thumbUploadId = item.thumbnailUploadId;
          final thumbPathOrUrl = (item.thumbnailUrl ?? item.imageUrl)?.trim();
          if ((thumbPathOrUrl ?? '').isNotEmpty &&
              !(thumbPathOrUrl!.startsWith('http://') || thumbPathOrUrl.startsWith('https://'))) {
            final file = File(thumbPathOrUrl);
            if (file.existsSync()) {
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
            } else {
              // Drop missing local file to avoid a stuck sync loop.
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
          final remoteCount = idsAll.length < urlsAll.length ? idsAll.length : urlsAll.length;
          final remoteUrls = urlsAll.take(remoteCount).toList();
          final remoteIds = idsAll.take(remoteCount).toList();
          final pending = urlsAll.skip(remoteCount).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

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
                    galleryUrls: drift.Value(jsonEncode([...remoteUrls, ...pendingQueue])),
                    galleryUploadIds: drift.Value(jsonEncode(remoteIds)),
                  ),
                );
              } catch (_) {
                // Keep for retry.
              }
            }
            if (mutated) {
              await db.updateItemFields(
                localId,
                ItemsCompanion(
                  galleryUrls: drift.Value(jsonEncode([...remoteUrls, ...pendingQueue])),
                  galleryUploadIds: drift.Value(jsonEncode(remoteIds)),
                ),
              );
            }
          }

          final hasGalleryColumns = item.galleryUrls != null || item.galleryUploadIds != null;
          final hasUnknownRemoteWithoutIds =
              idsAll.isEmpty && pending.any((p) => p.startsWith('http://') || p.startsWith('https://'));
          final canReplaceGallery = hasGalleryColumns && !hasUnknownRemoteWithoutIds;
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
        if (isCreate || (payload.containsKey('title') && title.trim().isNotEmpty)) {
          mappedPayload['title'] = title;
        }
        if (payload['summary'] != null) mappedPayload['summary'] = payload['summary'];
        if (payload['description'] != null) mappedPayload['description'] = payload['description'];

        if (isCreate || payload.containsKey('base_price') || payload.containsKey('price')) {
          mappedPayload['base_price'] = _asDouble(payload['base_price'] ?? payload['price'] ?? 0);
        }
        if (payload['currency'] != null) mappedPayload['currency'] = payload['currency'];
        if (payload['category_id'] != null) mappedPayload['category_id'] = payload['category_id'];

        final durationRaw = payload['duration_minutes'] ?? payload['duration'];
        if (durationRaw != null) mappedPayload['duration_minutes'] = _asInt(durationRaw);

        if (payload.containsKey('is_published') || payload.containsKey('published')) {
          mappedPayload['is_published'] = _asBool(payload['is_published'] ?? payload['published']);
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
          await sellerApi.updateService(remoteId.toString(), mappedPayload);
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
              final resolved = await _resolveRemoteProductId(productRaw);
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
              final resolved = await _resolveRemoteServiceId(serviceRaw);
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
          'current_stock': _asInt(payload['current_stock'] ?? item?.stockQty ?? 0),
          'published': _asBool(payload['published'] ?? item?.publishedOnline ?? false),
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
          final productId = _asNullableInt((res.data as Map<String, dynamic>)['product_id']);
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

        final body = Map<String, dynamic>.from(payload)..remove('idempotency_key');
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
        final body = Map<String, dynamic>.from(payload)..remove('idempotency_key');
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
        final res = await sellerApi.pushGoodsReceivedNote(body, idempotencyKey: key);
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
        final body = Map<String, dynamic>.from(payload)..remove('idempotency_key');
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
        final body = Map<String, dynamic>.from(payload)..remove('idempotency_key');
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
        final res = await sellerApi.createPurchaseOrder(body, idempotencyKey: key);
        if (res.data is! Map<String, dynamic>) {
          throw DioException(
            requestOptions: res.requestOptions,
            error: 'Invalid purchase order response',
          );
        }
        final ackKey = (res.data as Map<String, dynamic>)['idempotency_key']?.toString();
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
            (rawBody['quotation_number'] ?? rawBody['number'] ?? rawBody['quotationNumber'])
                ?.toString()
                .trim();
        if (quotationNumber == null || quotationNumber.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing quotation_number',
          );
        }

        var validityDays = _asInt(rawBody['validity_days'] ?? rawBody['validityDays']);
        if (validityDays <= 0) {
          final validUntil =
              DateTime.tryParse((rawBody['valid_until'] ?? rawBody['validUntil'] ?? '').toString());
          if (validUntil != null) {
            validityDays = validUntil.difference(DateTime.now()).inDays;
          }
        }
        if (validityDays <= 0) validityDays = 30;

        final customerId = rawBody['customer_id']?.toString();
        final notes = rawBody['notes']?.toString() ?? rawBody['note']?.toString();

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
            final price = _asDouble(line['price'] ?? line['unit_price'] ?? line['unitPrice'] ?? 0);
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
        final localCustomerId =
            payload['customer_id']?.toString() ?? payload['local_id']?.toString() ?? '';
        final body = Map<String, dynamic>.from(payload)
          ..remove('idempotency_key');
        final res = await sellerApi.pushCustomer(body, idempotencyKey: key);
        String? remoteId;
        DateTime? updatedAt;
        if (res.data is Map) {
          final data = Map<String, dynamic>.from(res.data as Map);
          remoteId = data['contact_id']?.toString();
          updatedAt =
              DateTime.tryParse(data['updated_at']?.toString() ?? '')?.toUtc();
        }
        if (localCustomerId.trim().isNotEmpty) {
          await (db.update(db.customers)
                ..where((t) => t.id.equals(localCustomerId.trim())))
              .write(
            CustomersCompanion(
              remoteId:
                  remoteId == null ? const drift.Value.absent() : drift.Value(remoteId),
              synced: const drift.Value(true),
              updatedAt: drift.Value(updatedAt ?? DateTime.now().toUtc()),
            ),
          );
        }
        break;
      case 'service_variant_push':
      case 'service_variant_create':
      case 'service_variant_update':
        final variantIdRaw = payload['id'] ?? payload['variant_id'] ?? payload['local_id'];
        final serviceIdRaw = payload['service_id'] ?? payload['serviceId'];
        final variantId = variantIdRaw?.toString().trim() ?? '';
        final serviceId = serviceIdRaw?.toString().trim() ?? '';
        if (variantId.isEmpty || serviceId.isEmpty) {
          throw DioException(
            requestOptions: RequestOptions(path: op.opType),
            error: 'Missing id/service_id for service variant push',
          );
        }

        final mapped = <String, dynamic>{
          'id': variantId,
          'service_id': serviceId,
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
        final body = Map<String, dynamic>.from(payload)
          ..remove('idempotency_key');
        await sellerApi.pushShift(body, idempotencyKey: key);
        final shiftId = payload['shift_id']?.toString() ?? payload['id']?.toString() ?? '';
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
        final body = Map<String, dynamic>.from(payload)
          ..remove('idempotency_key');
        await sellerApi.closeShift(body, idempotencyKey: key);
        final shiftId = payload['shift_id']?.toString() ?? payload['id']?.toString() ?? '';
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
        final body = Map<String, dynamic>.from(payload)..remove('idempotency_key');
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
        final body = Map<String, dynamic>.from(payload)..remove('idempotency_key');
        await sellerApi.pushPackageRedemption(body, idempotencyKey: key);
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
           debugPrint('[SyncService] Inner data type: ${responseData['data'].runtimeType}');
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
      
      _syncStatusController.add('Syncing products...');
      if (pull.products.isEmpty) {
        if (kDebugMode) {
          debugPrint('[SyncService] WARNING: No products in sync response!');
        }
      }

      for (final p in pull.products) {
        if (p.id.isEmpty) continue;
        final remoteId = int.tryParse(p.id);
        final existing =
            remoteId != null ? await db.getItemByRemoteId(remoteId) : null;
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
            remoteId:
                remoteId != null ? drift.Value(remoteId) : const drift.Value.absent(),
            name: p.name.isEmpty ? 'Product' : p.name,
            price: displayPrice,
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
            unit: p.unit != null ? drift.Value(p.unit) : const drift.Value.absent(),
            weight: p.weight != null ? drift.Value(p.weight) : const drift.Value.absent(),
            minPurchaseQty: p.minQty != null
                ? drift.Value(p.minQty!)
                : const drift.Value.absent(),
            tags: p.tags != null ? drift.Value(p.tags) : const drift.Value.absent(),
            description: p.description != null
                ? drift.Value(p.description)
                : const drift.Value.absent(),
            discount: p.discount != null ? drift.Value(p.discount) : const drift.Value.absent(),
            discountType: discountType != null ? drift.Value(discountType) : const drift.Value.absent(),
            shippingDays: p.estShippingDays != null ? drift.Value(p.estShippingDays) : const drift.Value.absent(),
            shippingFee: p.shippingCost != null ? drift.Value(p.shippingCost) : const drift.Value.absent(),
            refundable: drift.Value(p.refundable ?? false),
            cashOnDelivery: drift.Value(p.cashOnDelivery ?? true),
            lowStockWarning: p.lowStockQuantity != null ? drift.Value(p.lowStockQuantity) : const drift.Value.absent(),
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
              remoteStockId: s.id > 0 ? drift.Value(s.id) : const drift.Value.absent(),
              price: s.price,
              stockQty: drift.Value(s.qty),
              sku: drift.Value(s.sku),
              imageUploadId: s.imageUploadId != null
                  ? drift.Value(s.imageUploadId)
                  : const drift.Value.absent(),
              imageUrl: drift.Value(s.imageUrl),
              updatedAt: drift.Value(s.updatedAt ?? p.updatedAt ?? DateTime.now().toUtc()),
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
        final existing =
            remoteId != null ? await db.getServiceByRemoteId(remoteId) : null;
        final localId = existing?.id ?? s.id;
        await db.upsertService(
          ServicesCompanion.insert(
            id: drift.Value(localId),
            remoteId:
                remoteId != null ? drift.Value(remoteId) : const drift.Value.absent(),
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
        await db.into(db.servicePackages).insertOnConflictUpdate(
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

      _syncStatusController.add('Syncing customers...');
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

      _syncStatusController.add('Syncing suppliers...');
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

      _syncStatusController.add('Syncing expenses...');
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
      _syncStatusController.add('Syncing quotations...');
      for (final q in pull.quotations) {
        if (q.id.isEmpty) continue;
        
        // Upsert quotation using insertOnConflictUpdate
        await db.into(db.quotations).insertOnConflictUpdate(QuotationsCompanion(
          id: drift.Value(q.id),
          number: drift.Value(q.quotationNumber),
          customerId: drift.Value(q.customerId),
          validUntil: drift.Value(DateTime.now().add(Duration(days: q.validityDays))),
          totalAmount: drift.Value(q.total),
          notes: drift.Value(q.notes),
          synced: const drift.Value(true),
        ));
      }

      // Sync customer packages
      _syncStatusController.add('Syncing packages...');
      for (final p in pull.customerPackages) {
        if (p.id <= 0) continue;
        await db.into(db.customerPackages).insertOnConflictUpdate(CustomerPackagesCompanion(
            id: drift.Value(p.id.toString()),
            packageId: drift.Value(p.packageId),
            customerId: drift.Value(p.customerId),
            remainingSessions: drift.Value(p.remainingSessions),
            expiresAt: drift.Value(p.expiresAt),
            synced: const drift.Value(true)
        ));
      }

      // Sync redemptions
      for (final r in pull.packageRedemptions) {
        if (r.id <= 0) continue;
        await db.into(db.packageRedemptions).insertOnConflictUpdate(PackageRedemptionsCompanion(
             id: drift.Value(r.id.toString()),
             customerPackageId: drift.Value(r.customerPackageId.toString()),
             sessionsUsed: drift.Value(r.sessionsUsed),
             note: drift.Value(r.note),
             synced: const drift.Value(true)
        ));
      }

      // Sync shifts (pulled from server)
      _syncStatusController.add('Syncing shifts...');
      for (final s in pull.shifts) {
        if (s.id.isEmpty) continue;
        
        await db.into(db.shifts).insertOnConflictUpdate(ShiftsCompanion(
          id: drift.Value(s.id),
          outletId: drift.Value(s.outletId?.toString()),
          staffId: drift.Value(s.staffId?.toString()),
          openedAt: drift.Value(s.openedAt),
          closedAt: drift.Value(s.closedAt),
          openingFloat: drift.Value(s.openingFloat),
          closingFloat: drift.Value(s.closingFloat ?? 0),
          synced: const drift.Value(true),
        ));
      }

      // Sync cash movements (pulled from server)
      _syncStatusController.add('Syncing cash movements...');
      for (final m in pull.cashMovements) {
        if (m.id <= 0) continue;
        
        // CashMovements has auto-increment id, so we can't use insertOnConflictUpdate easily.
        // Just skip existing records 
        debugPrint('[SyncService] Received cash movement ${m.id} from server');
      }

      // Settings sync - store in shared preferences or secure storage
      // since there's no AppSettings table
      _syncStatusController.add('Syncing settings...');
      for (final setting in pull.settings) {
        if (setting.key.isEmpty) continue;
        debugPrint('[SyncService] Received setting ${setting.key}=${setting.value} from server');
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
      if (kDebugMode) {
        debugPrint('[SyncService] After sync: ${allItems.length} total items in local DB');
      }

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

  Future<void> pullMarketplaceOrders() async {
    final res = await sellerApi.fetchOrders();
    final data = res.data;
    final listRaw = data is Map<String, dynamic> ? (data['data'] ?? const []) : data;
    final list = List<Map<String, dynamic>>.from(
      (listRaw as Iterable).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
    );
    for (final order in list) {
      final id = int.tryParse(order['id']?.toString() ?? '');
      if (id == null) continue;
      await db.upsertCachedOrder(id, jsonEncode(order));
    }
  }

  Future<void> pullServiceBookings() async {
    final res = await sellerApi.fetchServiceBookings();
    final data = res.data;
    final listRaw = data is Map<String, dynamic> ? (data['data'] ?? const []) : data;
    final list = List<Map<String, dynamic>>.from(
      (listRaw as Iterable).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
    );
    for (final booking in list) {
      final id = int.tryParse(booking['id']?.toString() ?? '');
      if (id == null) continue;
      await db.upsertCachedServiceBooking(id, jsonEncode(booking));
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
          return;
        }
      }
    }

    final sw = Stopwatch()..start();
    try {
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
          final dc = await (db.select(db.deviceContacts)
                ..where((t) => t.deviceId.equals(deviceId)))
              .getSingleOrNull();
          linkedCustomerId = dc?.linkedCustomerId;
        }

        Customer? existing;
        if (linkedCustomerId != null && linkedCustomerId.trim().isNotEmpty) {
          existing = await db.getCustomerById(linkedCustomerId.trim());
        }
        existing ??=
            (contactId.isNotEmpty ? await db.getCustomerByRemoteId(contactId) : null);
        existing ??=
            (phone != null && phone.isNotEmpty ? await db.getCustomerByPhoneE164(phone) : null);
        existing ??=
            (email != null && email.isNotEmpty ? await db.getCustomerByEmail(email) : null);

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
            props: {'duration_ms': sw.elapsedMilliseconds, 'error': e.toString()},
          ),
        );
        unawaited(telemetry.recordError(e, st, hint: 'contacts_sync'));
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
      matched ??=
          primaryEmail != null ? await db.getCustomerByEmail(primaryEmail) : null;

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
