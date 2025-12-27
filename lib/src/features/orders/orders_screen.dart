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
              final id = order['order_code']?.toString() ?? order['code']?.toString() ?? order['id']?.toString() ?? 'N/A';
              final customer = order['customer_name']?.toString() ?? 'Customer';
              final status = order['delivery_status']?.toString() ?? order['delivery_status_raw']?.toString() ?? 'pending';
              final totalLabel = order['total']?.toString();
              final total = double.tryParse(order['grand_total']?.toString() ?? '') ?? 0;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.shopping_bag_outlined),
                  title: Text(id),
                  subtitle: Text('$customer • ${status.toUpperCase().replaceAll('_', ' ')}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(totalLabel ?? 'UGX ${total.toStringAsFixed(0)}'),
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
