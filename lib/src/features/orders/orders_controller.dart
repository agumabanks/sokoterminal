import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/network/seller_api.dart';

final ordersControllerProvider = StateNotifierProvider<OrdersController, OrdersState>((ref) {
  final api = ref.watch(sellerApiProvider);
  final db = ref.watch(appDatabaseProvider);
  return OrdersController(api, db)..load();
});

class OrdersState {
  const OrdersState({this.loading = false, this.orders = const [], this.error});
  final bool loading;
  final List<Map<String, dynamic>> orders;
  final String? error;
}

class OrdersController extends StateNotifier<OrdersState> {
  OrdersController(this.api, this.db) : super(const OrdersState());
  final SellerApi api;
  final AppDatabase db;

  Future<void> load() async {
    state = OrdersState(loading: true, orders: state.orders);
    try {
      final res = await api.fetchOrders();
      final data = (res.data['data'] ?? res.data ?? []) as dynamic;
      final list = List<Map<String, dynamic>>.from(data as Iterable);
      final enriched = <Map<String, dynamic>>[];
      for (final order in list) {
        final id = int.tryParse(order['id']?.toString() ?? '');
        if (id == null) continue;
        final items = await loadItems(id);
        final merged = {...order, 'items': items};
        enriched.add(merged);
        await db.upsertCachedOrder(id, jsonEncode(merged));
      }
      state = OrdersState(orders: enriched);
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
      await api.updateOrderStatus(
        orderId: orderId,
        deliveryStatus: delivery,
        paymentStatus: payment,
      );
      await load();
    } catch (e) {
      state = OrdersState(error: e.toString(), orders: state.orders);
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
      // First try to find in current state
      final existing = state.orders.cast<Map<String, dynamic>?>().firstWhere(
        (o) => o?['id']?.toString() == orderId.toString(),
        orElse: () => null,
      );
      
      // Fetch fresh details from API
      final res = await api.fetchOrderDetails(orderId);
      final data = (res.data is List ? res.data.first : res.data) as Map<String, dynamic>;
      
      // If we have existing items, merge them if new data doesn't have items
      if (existing != null && existing['items'] != null && data['items'] == null) {
        data['items'] = existing['items'];
      } else if (data['items'] == null) {
        // Fetch items if missing
        data['items'] = await loadItems(orderId);
      }
      
      return data;
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
