import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../invoices/invoice_providers.dart';
import 'marketplace_order.dart';
import 'orders_controller.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    this.initialData,
  });

  final int orderId;
  final MarketplaceOrder? initialData;

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  MarketplaceOrder? _order;
  bool _loading = true;
  bool _requestingSokoDelivery = false;

  @override
  void initState() {
    super.initState();
    _order = widget.initialData;
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _loading = true);
    final data = await ref
        .read(ordersControllerProvider.notifier)
        .loadOrderDetails(widget.orderId);
    if (mounted) {
      setState(() {
        _order = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _order == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Order #${widget.orderId}')),
        body: const Center(child: Text('Failed to load order details')),
      );
    }

    final order = _order!;
    final code = order.displayCode;
    final formattedDate = order.orderedAt != null
        ? DateFormat('MMM d, y HH:mm').format(order.orderedAt!.toLocal())
        : '-';

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Order #$code', style: DesignTokens.textTitleLight),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Share invoice PDF',
            onPressed: () async {
              try {
                await ref
                    .read(invoiceServiceProvider)
                    .shareOrderInvoicePdf(order.toJson());
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invoice export failed: $e')),
                );
              }
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchDetails),
        ],
      ),
      body: SingleChildScrollView(
        padding: DesignTokens.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(formattedDate, order.displayTotal),
            const SizedBox(height: DesignTokens.spaceLg),
            _buildActions(context, order),
            const SizedBox(height: DesignTokens.spaceLg),
            _buildSectionTitle('Items'),
            _buildItemsList(order),
            const SizedBox(height: DesignTokens.spaceLg),
            _buildSectionTitle('Payment & Shipping'),
            const SizedBox(height: DesignTokens.spaceSm),
            _buildInfoCard([
              _InfoRow(
                'Payment Status',
                order.normalizedPaymentStatus.toUpperCase(),
                isBadge: true,
                color: _getStatusColor(order.normalizedPaymentStatus),
              ),
              _InfoRow(
                'Delivery Status',
                order.normalizedDeliveryStatus.toUpperCase().replaceAll('_', ' '),
                isBadge: true,
                color: _getStatusColor(order.normalizedDeliveryStatus),
              ),
              _InfoRow(
                'Payment Method',
                order.displayPaymentMethod.isEmpty ? '-' : order.displayPaymentMethod,
              ),
              _InfoRow(
                'Shipping Cost',
                (order.shippingCost ?? 'UGX 0').toString(),
              ),
              if (order.sokoDeliveryRequest != null)
                _InfoRow(
                  'Soko24 Delivery',
                  (order.sokoDeliveryRequest!['status'] ?? 'pending')
                      .toString()
                      .toUpperCase(),
                  isBadge: true,
                  color: _getStatusColor(
                    (order.sokoDeliveryRequest!['status'] ?? '').toString(),
                  ),
                ),
            ]),
            const SizedBox(height: DesignTokens.spaceLg),
            _buildSectionTitle('Customer'),
            const SizedBox(height: DesignTokens.spaceSm),
            _buildInfoCard([
              _InfoRow('Name', order.displayCustomer),
              _InfoRow('Phone', order.displayPhone),
              _InfoRow(
                'Address',
                order.shippingAddress?['address']?.toString() ?? '-',
              ),
              _InfoRow(
                'City',
                order.shippingAddress?['city']?.toString() ?? '-',
              ),
            ]),
            const SizedBox(height: DesignTokens.spaceXl),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String date, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Placed on $date', style: DesignTokens.textSmall),
        const SizedBox(height: DesignTokens.spaceSm),
        Text(total.toUgx(), style: DesignTokens.textMonoDisplay),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: DesignTokens.textTitle);
  }

  Widget _buildActions(BuildContext context, MarketplaceOrder order) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Padding(
        padding: DesignTokens.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manage Order', style: DesignTokens.textBodyBold),
            const SizedBox(height: DesignTokens.spaceMd),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Update Status'),
                    onPressed: () => _showStatusModal(context, order),
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceSm + DesignTokens.spaceXs),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: order.canRequestSokoDelivery && !_requestingSokoDelivery
                        ? _requestSokoDelivery
                        : null,
                    icon: _requestingSokoDelivery
                        ? const SizedBox(
                            width: DesignTokens.iconSm,
                            height: DesignTokens.iconSm,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delivery_dining_outlined),
                    label: Text(
                      order.hasSokoDeliveryRequest
                          ? 'Soko24 Requested'
                          : 'Request Soko24',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceSm + DesignTokens.spaceXs),
            Text(
              'Use seller delivery for nearby buyers, or request Soko24 delivery for marketplace orders that need platform fulfillment.',
              style: DesignTokens.textSmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestSokoDelivery() async {
    setState(() => _requestingSokoDelivery = true);
    try {
      final message = await ref
          .read(ordersControllerProvider.notifier)
          .requestSokoDelivery(widget.orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _fetchDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Soko24 delivery request failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _requestingSokoDelivery = false);
      }
    }
  }

  Widget _buildItemsList(MarketplaceOrder order) {
    final items = order.orderItems.isNotEmpty ? order.orderItems : order.items;
    if (items.isEmpty) {
      return Text('No items found', style: DesignTokens.textBody);
    }

    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.canvasCloud,
        borderRadius: DesignTokens.borderRadiusMd,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          final variant = item.variant ?? '';

          return ListTile(
            title: Text(item.name, style: DesignTokens.textBodyBold),
            subtitle: variant.isNotEmpty
                ? Text(variant, style: DesignTokens.textSmall)
                : null,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('x${item.quantity}', style: DesignTokens.textSmall),
                Text(
                  item.lineTotal.toUgx(),
                  style: DesignTokens.textMono,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(List<_InfoRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.canvasCloud,
        borderRadius: DesignTokens.borderRadiusMd,
      ),
      child: Padding(
        padding: DesignTokens.paddingMd,
        child: Column(
          children: rows.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.spaceSm + DesignTokens.spaceXs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(row.label, style: DesignTokens.textSmall),
                  ),
                  Expanded(
                    child: row.isBadge
                        ? Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: DesignTokens.spaceSm,
                                  vertical: DesignTokens.spaceXxs,
                                ),
                                decoration: BoxDecoration(
                                  color: row.color.withValues(alpha: 0.1),
                                  borderRadius: DesignTokens.borderRadiusXs,
                                  border: Border.all(
                                    color: row.color.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  row.value,
                                  style: DesignTokens.textCaption.copyWith(
                                    color: row.color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(row.value, style: DesignTokens.textBodyBold),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showStatusModal(BuildContext context, MarketplaceOrder order) {
    final statuses = [
      'pending',
      'confirmed',
      'picked_up',
      'on_the_way',
      'delivered',
      'cancelled',
    ];
    final paymentStatuses = ['paid', 'unpaid'];

    String delivery = order.normalizedDeliveryStatus;
    String payment = order.normalizedPaymentStatus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + DesignTokens.spaceMd,
          left: DesignTokens.spaceMd,
          right: DesignTokens.spaceMd,
          top: DesignTokens.spaceMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Update Order Status', style: DesignTokens.textTitle),
            const SizedBox(height: DesignTokens.spaceLg),
            DropdownButtonFormField<String>(
              initialValue: statuses.contains(delivery)
                  ? delivery
                  : statuses.first,
              decoration: const InputDecoration(
                labelText: 'Delivery Status',
                border: OutlineInputBorder(),
              ),
              items: statuses
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.toUpperCase().replaceAll('_', ' ')),
                    ),
                  )
                  .toList(),
              onChanged: (v) => delivery = v!,
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            DropdownButtonFormField<String>(
              initialValue: paymentStatuses.contains(payment)
                  ? payment
                  : paymentStatuses.last,
              decoration: const InputDecoration(
                labelText: 'Payment Status',
                border: OutlineInputBorder(),
              ),
              items: paymentStatuses
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) => payment = v!,
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: DesignTokens.paddingVerticalSm.copyWith(
                  top: DesignTokens.spaceMd,
                  bottom: DesignTokens.spaceMd,
                ),
                backgroundColor: DesignTokens.ink,
                foregroundColor: DesignTokens.canvas,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await ref
                    .read(ordersControllerProvider.notifier)
                    .updateStatus(
                      orderId: widget.orderId,
                      delivery: delivery,
                      payment: payment,
                    );
                _fetchDetails();
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'delivered':
      case 'completed':
        return DesignTokens.success;
      case 'pending':
      case 'unpaid':
        return DesignTokens.warning;
      case 'cancelled':
        return DesignTokens.error;
      default:
        return DesignTokens.info;
    }
  }
}

class _InfoRow {
  final String label;
  final String value;
  final bool isBadge;
  final Color color;

  _InfoRow(
    this.label,
    this.value, {
    this.isBadge = false,
    this.color = DesignTokens.ink,
  });
}