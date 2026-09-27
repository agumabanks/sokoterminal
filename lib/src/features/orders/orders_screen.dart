import 'package:intl/intl.dart';
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
        title: Text('Orders', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: state.loading
                ? null
                : () => ref.read(ordersControllerProvider.notifier).load(),
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

          final totalRevenue = orders
              .where(
                (order) => !const [
                  'cancelled',
                  'canceled',
                ].contains(order.normalizedDeliveryStatus),
              )
              .fold<double>(0, (sum, order) => sum + order.displayTotal);

          return Column(
            children: [
              if (state.error != null)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Showing saved orders. Pull down to retry the latest updates.',
                  ),
                ),
              Container(
                width: double.infinity,
                margin: DesignTokens.paddingScreen,
                padding: DesignTokens.paddingCard,
                decoration: BoxDecoration(
                  color: DesignTokens.brandPrimary,
                  borderRadius: DesignTokens.borderRadiusLg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      needsActionCount == 0
                          ? 'You’re all caught up'
                          : '$needsActionCount order${needsActionCount == 1 ? '' : 's'} need you',
                      style: DesignTokens.textTitle.copyWith(
                        color: DesignTokens.surfaceWhite,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceXs),
                    Text(
                      'Marketplace activity updates quietly in the background.',
                      style: DesignTokens.textCaption.copyWith(
                        color: DesignTokens.surfaceWhite.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryItem(
                            label: 'Orders',
                            value: '${orders.length}',
                          ),
                        ),
                        Expanded(
                          child: _SummaryItem(
                            label: 'Needs action',
                            value: '$needsActionCount',
                          ),
                        ),
                        Expanded(
                          child: _SummaryItem(
                            label: 'Order value',
                            value:
                                'UGX ${NumberFormat.compact().format(totalRevenue)}',
                          ),
                        ),
                      ],
                    ),
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
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _OrdersFilterChip(
                      label: 'All',
                      selected: _filter == OrdersListFilter.all,
                      onTap: () =>
                          setState(() => _filter = OrdersListFilter.all),
                    ),
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
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            100 + MediaQuery.paddingOf(context).bottom,
                          ),
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
        builder: (_) =>
            OrderDetailsScreen(orderId: order.id, initialData: order),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: DesignTokens.textBodyBold.copyWith(
            color: DesignTokens.surfaceWhite,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: DesignTokens.textSmall.copyWith(
            color: DesignTokens.surfaceWhite.withValues(alpha: 0.62),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: InkWell(
        borderRadius: DesignTokens.borderRadiusMd,
        onTap: onTap,
        child: Padding(
          padding: DesignTokens.paddingCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: DesignTokens.borderRadiusSm,
                    ),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSm),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusFull,
                      ),
                    ),
                    child: Text(
                      status.toUpperCase().replaceAll('_', ' '),
                      style: DesignTokens.textCaption.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      customer,
                      style: DesignTokens.textSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      total.toUgx(),
                      style: DesignTokens.textBodyBold,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spaceXs),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  paymentStatus.toUpperCase(),
                  style: DesignTokens.textCaption.copyWith(
                    color: paymentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
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
  const _EmptyState({required this.filter, required this.needsActionCount});

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
