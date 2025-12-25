import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'order_details_screen.dart';
import 'orders_controller.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ordersControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(ordersControllerProvider.notifier).load(),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.loading && state.orders.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null && state.orders.isEmpty) {
            return Center(child: Text('Error: ${state.error}'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.orders.length,
            itemBuilder: (context, index) {
              final order = state.orders[index];
              final id = order['code']?.toString() ?? order['id']?.toString() ?? 'N/A';
              final customer = order['customer_name']?.toString() ?? 'Customer';
              final status = order['delivery_status']?.toString() ?? 'pending';
              final total = double.tryParse(order['grand_total']?.toString() ?? '0') ?? 0;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.shopping_bag_outlined),
                  title: Text(id),
                  subtitle: Text('$customer • ${status.toUpperCase()}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('UGX ${total.toStringAsFixed(0)}'),
                      Text(order['payment_status']?.toString() ?? '-', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  onTap: () => _showDetails(context, order),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetails(BuildContext context, Map<String, dynamic> order) {
    final orderId = int.tryParse(order['id']?.toString() ?? '') ?? 0;
    if (orderId == 0) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(orderId: orderId, initialData: order),
      ),
    );
  }
}

class _OrderItemsList extends ConsumerWidget {
  const _OrderItemsList({required this.order, required this.orderId});
  final Map<String, dynamic> order;
  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cached = order['items'];
    if (cached is List && cached.isNotEmpty) {
      return SizedBox(
        height: 180,
        child: ListView.builder(
          itemCount: cached.length,
          itemBuilder: (context, index) {
            final item = cached[index] as Map<String, dynamic>;
            final name = item['name']?.toString() ?? item['product_name']?.toString() ?? 'Item';
            final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
            final price = double.tryParse(item['price']?.toString() ?? item['total']?.toString() ?? '0') ?? 0;
            return ListTile(
              dense: true,
              title: Text(name),
              subtitle: Text('Qty $qty'),
              trailing: Text('UGX ${price.toStringAsFixed(0)}'),
            );
          },
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(ordersControllerProvider.notifier).loadItems(orderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Text('No items found'),
          );
        }
        return SizedBox(
          height: 180,
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final name = item['name']?.toString() ?? item['product_name']?.toString() ?? 'Item';
              final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
              final price = double.tryParse(item['price']?.toString() ?? item['total']?.toString() ?? '0') ?? 0;
              return ListTile(
                dense: true,
                title: Text(name),
                subtitle: Text('Qty $qty'),
                trailing: Text('UGX ${price.toStringAsFixed(0)}'),
              );
            },
          ),
        );
      },
    );
  }
}
