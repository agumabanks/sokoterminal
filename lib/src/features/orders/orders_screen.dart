import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                  onTap: () => _showUpdate(context, ref, order),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showUpdate(BuildContext context, WidgetRef ref, Map<String, dynamic> order) {
    final statuses = ['pending', 'processing', 'shipped', 'completed', 'cancelled'];
    String delivery = order['delivery_status']?.toString() ?? 'pending';
    String payment = order['payment_status']?.toString() ?? 'unpaid';
    final orderId = int.tryParse(order['id']?.toString() ?? '') ?? 0;
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Order #$orderId', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _OrderItemsList(order: order, orderId: orderId),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: delivery,
              items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => delivery = v ?? delivery,
              decoration: const InputDecoration(labelText: 'Delivery'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: payment,
              items: const [
                DropdownMenuItem(value: 'paid', child: Text('Paid')),
                DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
              ],
              onChanged: (v) => payment = v ?? payment,
              decoration: const InputDecoration(labelText: 'Payment'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                if (orderId == 0) return;
                await ref.read(ordersControllerProvider.notifier).updateStatus(
                      orderId: orderId,
                      delivery: delivery,
                      payment: payment,
                    );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
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
