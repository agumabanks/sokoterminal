import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../widgets/error_page.dart';
import 'order_details_screen.dart';
import 'orders_controller.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ordersControllerProvider);
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Marketplace Orders', style: DesignTokens.textTitle),
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
            return ErrorPage(
              title: 'Failed to load orders',
              message: state.error,
              onRetry: () => ref.read(ordersControllerProvider.notifier).load(),
            );
          }
          final orders = state.orders;

          final totalRevenue = orders.fold<double>(0, (sum, order) {
            return sum + (double.tryParse(order['grand_total']?.toString() ?? '0') ?? 0);
          });

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: DesignTokens.paddingMd,
                color: DesignTokens.brandPrimary.withValues(alpha: 0.06),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryItem(label: 'Orders', value: '${orders.length}'),
                    _SummaryItem(label: 'Revenue', value: totalRevenue.toUgx()),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.read(ordersControllerProvider.notifier).load(),
                  child: ListView.builder(
                    padding: DesignTokens.paddingScreen,
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _OrderTile(
                        order: order,
                        onTap: () => _showDetails(context, order),
                      );
                    },
                  ),
                ),
              ),
            ],
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

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: DesignTokens.textBodyBold),
        const SizedBox(height: 2),
        Text(label, style: DesignTokens.textSmall),
      ],
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.onTap});
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final id =
        order['order_code']?.toString() ??
        order['code']?.toString() ??
        order['id']?.toString() ??
        'N/A';
    final customer = order['customer_name']?.toString() ?? 'Customer';
    final status =
        order['delivery_status']?.toString() ??
        order['delivery_status_raw']?.toString() ??
        'pending';
    final paymentStatus = order['payment_status']?.toString() ?? 'unpaid';
    final total = double.tryParse(order['grand_total']?.toString() ?? '') ?? 0;

    final statusColor = _statusColor(status);
    final paymentColor = paymentStatus == 'paid' ? DesignTokens.success : DesignTokens.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: ListTile(
        leading: Container(
          padding: DesignTokens.paddingSm,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: DesignTokens.borderRadiusSm,
          ),
          child: Icon(Icons.shopping_bag_outlined, color: statusColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(id, style: DesignTokens.textBodyBold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.toUpperCase().replaceAll('_', ' '),
                style: DesignTokens.textSmall.copyWith(
                  color: statusColor,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          customer,
          style: DesignTokens.textSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(total.toUgx(), style: DesignTokens.textBodyBold),
            Text(
              paymentStatus.toUpperCase(),
              style: DesignTokens.textSmall.copyWith(color: paymentColor),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return DesignTokens.warning;
      case 'confirmed':
      case 'processing':
        return DesignTokens.brandAccent;
      case 'packed':
      case 'out_for_delivery':
        return DesignTokens.info;
      case 'delivered':
      case 'complete':
        return DesignTokens.success;
      case 'cancelled':
      case 'canceled':
        return DesignTokens.error;
      default:
        return DesignTokens.grayMedium;
    }
  }
}
