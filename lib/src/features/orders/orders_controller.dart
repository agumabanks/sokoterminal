import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/network/seller_api.dart';
import '../../core/sync/sync_service.dart';
import '../../core/telemetry/telemetry.dart';
import 'marketplace_order.dart';

final ordersControllerProvider =
    StateNotifierProvider<OrdersController, OrdersState>((ref) {
      final api = ref.watch(sellerApiProvider);
      final db = ref.watch(appDatabaseProvider);
      final sync = ref.watch(syncServiceProvider);
      return OrdersController(api, db, sync)..load();
    });

class OrdersState {
  const OrdersState({this.loading = false, this.orders = const [], this.error});
  final bool loading;
  final List<MarketplaceOrder> orders;
  final String? error;
}

class OrdersController extends StateNotifier<OrdersState> {
  OrdersController(this.api, this.db, this.sync) : super(const OrdersState());
  final SellerApi api;
  final AppDatabase db;
  final SyncService sync;
  static const _uuid = Uuid();

  Future<MarketplaceOrder?> _readCachedOrder(int orderId) async {
    final row = await db.getCachedOrder(orderId);
    if (row == null) return null;
    try {
      return MarketplaceOrder.fromJson(
        Map<String, dynamic>.from(jsonDecode(row.payloadJson) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    state = OrdersState(loading: true, orders: state.orders);
    try {
      await sync.pullMarketplaceOrders();
      final cachedRows = await db.getCachedOrders();
      final list = cachedRows
          .map(
            (r) => MarketplaceOrder.fromJson(
              Map<String, dynamic>.from(jsonDecode(r.payloadJson) as Map),
            ),
          )
          .toList();
      state = OrdersState(orders: sortOrdersForDisplay(list));
    } catch (e) {
      final cachedRows = await db.getCachedOrders();
      if (cachedRows.isNotEmpty) {
        final list = cachedRows
            .map(
              (r) => MarketplaceOrder.fromJson(
                Map<String, dynamic>.from(jsonDecode(r.payloadJson) as Map),
              ),
            )
            .toList();
        state = OrdersState(
          error: e.toString(),
          orders: sortOrdersForDisplay(list),
        );
      } else {
        state = OrdersState(error: e.toString(), orders: state.orders);
      }
    }
  }

  Future<void> updateStatus({
    required int orderId,
    required String delivery,
    required String payment,
  }) async {
    state = OrdersState(orders: state.orders, loading: true);
    try {
      if (delivery.trim().isNotEmpty) {
        await api.updateOrderDeliveryStatus(orderId: orderId, status: delivery);
      }
      if (payment.trim().isNotEmpty) {
        await api.updateOrderPaymentStatus(orderId: orderId, status: payment);
      }
      await load();
    } catch (e) {
      // Offline-first: enqueue and optimistically update cache/UI.
      final opType = 'order_status_update:$orderId';
      try {
        await sync.enqueue(opType, {
          'order_id': orderId,
          'delivery_status': delivery,
          'payment_status': payment,
          'idempotency_key': _uuid.v4(),
        });
      } catch (e) {
        debugPrint('[Orders] Sync enqueue failed: $e');
      }

      final updatedOrders = [
        for (final order in state.orders)
          if (order.id == orderId)
            order.copyWith(
              deliveryStatus: delivery,
              deliveryStatusRaw: delivery,
              paymentStatus: payment.trim().isNotEmpty
                  ? payment
                  : order.paymentStatus,
              pendingSync: true,
            )
          else
            order,
      ];

      final existing = updatedOrders.cast<MarketplaceOrder?>().firstWhere(
        (order) => order?.id == orderId,
        orElse: () => null,
      );
      if (existing != null) {
        await db.upsertCachedOrder(orderId, jsonEncode(existing.toJson()));
      }

      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(
          telemetry.event(
            'order_status_update_queued',
            props: {
              'order_id': orderId,
              'delivery': delivery,
              'payment': payment,
            },
          ),
        );
      }

      state = OrdersState(
        error: 'Queued for sync: ${e.toString()}',
        orders: sortOrdersForDisplay(updatedOrders),
        loading: false,
      );
    }
  }

  Future<List<OrderLine>> loadItems(int orderId) async {
    final cached = await _readCachedOrder(orderId);
    if (cached != null && cached.orderItems.isNotEmpty) {
      return cached.orderItems;
    }

    try {
      final res = await api.fetchOrderItems(orderId);
      final data = res.data;
      final list = data is Map<String, dynamic>
          ? data['data'] ?? data['items'] ?? []
          : data;
      return (list as Iterable)
          .whereType<Map>()
          .map((entry) => OrderLine.fromJson(Map<String, dynamic>.from(entry)))
          .toList();
    } catch (_) {
      return cached?.orderItems ?? const [];
    }
  }

  Future<MarketplaceOrder?> loadOrderDetails(int orderId) async {
    final cached = await _readCachedOrder(orderId);
    final inState = state.orders.cast<MarketplaceOrder?>().firstWhere(
      (order) => order?.id == orderId,
      orElse: () => null,
    );
    final seed = cached ?? inState;

    try {
      final merged = await sync.pullMarketplaceOrderDetail(orderId);
      if (merged != null) {
        _upsertOrderInState(merged);
        return merged;
      }
    } catch (e) {
      debugPrint('[Orders] Order detail pull failed: $e');
    }

    return seed;
  }

  void _upsertOrderInState(MarketplaceOrder order) {
    final updated = [
      for (final existing in state.orders)
        if (existing.id == order.id) order else existing,
    ];
    if (!updated.any((o) => o.id == order.id)) {
      updated.insert(0, order);
    }
    state = OrdersState(
      orders: sortOrdersForDisplay(updated),
      loading: state.loading,
      error: state.error,
    );
  }

  Future<String> requestSokoDelivery(int orderId) async {
    final res = await api.requestSokoDelivery(orderId);
    final body = res.data;
    await load();
    return body is Map<String, dynamic>
        ? (body['message'] ?? 'Soko24 delivery requested').toString()
        : 'Soko24 delivery requested';
  }

  Future<void> pullCached() async {
    final cachedRows = await db.getCachedOrders();
    if (cachedRows.isEmpty) return;
    final list = cachedRows
        .map(
          (r) => MarketplaceOrder.fromJson(
            Map<String, dynamic>.from(jsonDecode(r.payloadJson) as Map),
          ),
        )
        .toList();
    state = OrdersState(orders: sortOrdersForDisplay(list), loading: false);
  }
}