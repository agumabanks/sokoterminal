import 'dart:convert';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/network/seller_api.dart';
import '../../core/sync/sync_service.dart';
import '../../core/telemetry/telemetry.dart';

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
  final List<Map<String, dynamic>> orders;
  final String? error;
}

class OrdersController extends StateNotifier<OrdersState> {
  OrdersController(this.api, this.db, this.sync) : super(const OrdersState());
  final SellerApi api;
  final AppDatabase db;
  final SyncService sync;
  static const _uuid = Uuid();

  Future<void> load() async {
    state = OrdersState(loading: true, orders: state.orders);
    try {
      final res = await api.fetchOrders();
      final data = res.data;
      final listRaw = data is Map<String, dynamic> ? (data['data'] ?? const []) : data;
      final list = List<Map<String, dynamic>>.from((listRaw as Iterable).map((e) => Map<String, dynamic>.from(e as Map)));

      for (final order in list) {
        final id = int.tryParse(order['id']?.toString() ?? '');
        if (id == null) continue;
        await db.upsertCachedOrder(id, jsonEncode(order));
      }

      state = OrdersState(orders: list);
    } catch (e) {
      final cachedRows = await db.getCachedOrders();
      if (cachedRows.isNotEmpty) {
        final list = cachedRows
            .map((r) => Map<String, dynamic>.from(jsonDecode(r.payloadJson) as Map))
            .toList();
        state = OrdersState(error: e.toString(), orders: list);
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
      await sync.enqueue(opType, {
        'order_id': orderId,
        'delivery_status': delivery,
        'payment_status': payment,
        'idempotency_key': _uuid.v4(),
      });

      final updatedOrders = [
        for (final o in state.orders)
          if (o['id']?.toString() == orderId.toString())
            {
              ...o,
              'delivery_status': delivery,
              'delivery_status_raw': delivery,
              if (payment.trim().isNotEmpty) 'payment_status': payment,
              'pending_sync': true,
            }
          else
            o
      ];

      final existing = updatedOrders.cast<Map<String, dynamic>?>().firstWhere(
            (o) => o?['id']?.toString() == orderId.toString(),
            orElse: () => null,
          );
      if (existing != null) {
        await db.upsertCachedOrder(orderId, jsonEncode(existing));
      }

      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(
          telemetry.event(
            'order_status_update_queued',
            props: {'order_id': orderId, 'delivery': delivery, 'payment': payment},
          ),
        );
      }

      state = OrdersState(
        error: 'Queued for sync: ${e.toString()}',
        orders: updatedOrders,
        loading: false,
      );
    }
  }

  Future<List<Map<String, dynamic>>> loadItems(int orderId) async {
    try {
      final res = await api.fetchOrderItems(orderId);
      final data = res.data;
      final list = data is Map<String, dynamic> ? data['data'] ?? data['items'] ?? [] : data;
      return List<Map<String, dynamic>>.from(list as Iterable);
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> loadOrderDetails(int orderId) async {
    try {
      final existing = state.orders.cast<Map<String, dynamic>?>().firstWhere(
        (o) => o?['id']?.toString() == orderId.toString(),
        orElse: () => null,
      );

      final res = await api.fetchOrderDetails(orderId);
      final raw = res.data;
      final listRaw = raw is Map<String, dynamic> ? raw['data'] : raw;
      final first = (listRaw is List && listRaw.isNotEmpty) ? listRaw.first : null;
      if (first is! Map) {
        throw const FormatException('Invalid order details response shape');
      }

      final details = Map<String, dynamic>.from(first);

      // Normalize items key for UI/invoice consumers.
      if (details['items'] == null && details['order_items'] is List) {
        details['items'] = details['order_items'];
      }
      if (details['order_items'] == null && details['items'] is List) {
        details['order_items'] = details['items'];
      }

      // Merge list payload fields (customer name/phone) when detail is sparse.
      final merged = existing == null ? details : {...existing, ...details};

      await db.upsertCachedOrder(orderId, jsonEncode(merged));
      return merged;
    } catch (e) {
      // Fallback to local state if API fails
      return state.orders.cast<Map<String, dynamic>?>().firstWhere(
        (o) => o?['id']?.toString() == orderId.toString(),
        orElse: () => null,
      );
    }
  }

  Future<void> pullCached() async {
    final cachedRows = await db.getCachedOrders();
    if (cachedRows.isEmpty) return;
    final list = cachedRows
        .map((r) => Map<String, dynamic>.from(jsonDecode(r.payloadJson) as Map))
        .toList();
    state = OrdersState(orders: list, loading: false);
  }
}
