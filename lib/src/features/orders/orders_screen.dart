import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../widgets/error_page.dart';
import 'marketplace_order.dart';
import 'order_details_screen.dart';
import 'orders_controller.dart';

enum OrdersListFilter { all, needsAction }

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  OrdersListFilter _filter = OrdersListFilter.all;

  @override
  Widget build(BuildContext context) {
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
          final needsActionCount = countOrdersNeedingAction(orders);
          final visibleOrders = _filter == OrdersListFilter.needsAction
              ? orders.where((order) => order.needsAction).toList()
              : orders;

          final totalRevenue = orders.fold<double>(
            0,
            (sum, order) => sum + order.displayTotal,
          );

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
                    _SummaryItem(
                      label: 'Needs action',
                      value: '$needsActionCount',
                    ),
                    _SummaryItem(label: 'Revenue', value: totalRevenue.toUgx()),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DesignTokens.spaceMd,
                  DesignTokens.spaceSm,
                  DesignTokens.spaceMd,
                  0,
                ),
                child: Row(
                  children: [
                    _OrdersFilterChip(
                      label: 'All',
                      selected: _filter == OrdersListFilter.all,
                      onTap: () => setState(
                        () => _filter = OrdersListFilter.all,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceSm),
                    _OrdersFilterChip(
                      label: 'Needs action',
                      count: needsActionCount,
                      selected: _filter == OrdersListFilter.needsAction,
                      onTap: () => setState(
                        () => _filter = OrdersListFilter.needsAction,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: DesignTokens.brandAccent,
                  onRefresh: () =>
                      ref.read(ordersControllerProvider.notifier).load(),
                  child: visibleOrders.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: DesignTokens.paddingScreen,
                          children: [
                            _EmptyState(
                              filter: _filter,
                              needsActionCount: needsActionCount,
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: DesignTokens.paddingScreen,
                          itemCount: visibleOrders.length,
                          itemBuilder: (context, index) {
                            final order = visibleOrders[index];
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

  void _showDetails(BuildContext context, MarketplaceOrder order) {
    if (order.id == 0) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(
          orderId: order.id,
          initialData: order,
        ),
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
  final MarketplaceOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final id = order.displayCode;
    final customer = order.displayCustomer;
    final status = order.normalizedDeliveryStatus;
    final paymentStatus = order.normalizedPaymentStatus;
    final total = order.displayTotal;

    final statusColor = _statusColor(status);
    final paymentColor = paymentStatus == 'paid'
        ? DesignTokens.success
        : DesignTokens.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
        border: Border(
          left: BorderSide(color: statusColor, width: 4),
        ),
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
              child: Text(
                id,
                style: DesignTokens.textBodyBold.copyWith(
                  decoration: _isCancelled(status)
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
              ),
              child: Text(
                status.toUpperCase().replaceAll('_', ' '),
                style: DesignTokens.textCaption.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
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
        return DesignTokens.info;
      case 'packed':
      case 'out_for_delivery':
        return DesignTokens.info;
      case 'delivered':
      case 'complete':
      case 'completed':
        return DesignTokens.success;
      case 'cancelled':
      case 'canceled':
        return DesignTokens.error;
      default:
        return DesignTokens.grayMedium;
    }
  }

  bool _isCancelled(String status) {
    final s = status.toLowerCase();
    return s == 'cancelled' || s == 'canceled';
  }
}

class _OrdersFilterChip extends StatelessWidget {
  const _OrdersFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final showCount = count != null && count! > 0;
    return FilterChip(
      label: Text(
        showCount ? '$label ($count)' : label,
        style: DesignTokens.textSmall.copyWith(
          color: selected ? DesignTokens.canvas : DesignTokens.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      backgroundColor: DesignTokens.canvasCloud,
      selectedColor: DesignTokens.brandPrimary,
      side: BorderSide(
        color: selected ? DesignTokens.brandPrimary : DesignTokens.hairline,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceSm,
        vertical: DesignTokens.spaceXs,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.filter,
    required this.needsActionCount,
  });

  final OrdersListFilter filter;
  final int needsActionCount;

  @override
  Widget build(BuildContext context) {
    final filteredEmpty = filter == OrdersListFilter.needsAction;
    return Center(
      child: Padding(
        padding: DesignTokens.paddingScreen,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              filteredEmpty
                  ? Icons.task_alt_outlined
                  : Icons.receipt_long_outlined,
              size: DesignTokens.iconXl + DesignTokens.spaceXl,
              color: DesignTokens.grayLight,
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            Text(
              filteredEmpty ? 'No orders need action' : 'No orders yet',
              style: DesignTokens.textTitle,
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              filteredEmpty
                  ? needsActionCount == 0
                      ? 'New marketplace orders that need your attention will appear here first.'
                      : 'Switch to All to see completed and in-progress orders.'
                  : 'Your marketplace orders will appear here',
              style: DesignTokens.textBody.copyWith(
                color: DesignTokens.grayMedium,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
