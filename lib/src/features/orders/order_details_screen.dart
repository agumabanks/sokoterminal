import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../invoices/invoice_providers.dart';
import 'orders_controller.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  const OrderDetailsScreen({super.key, required this.orderId, this.initialData});

  final int orderId;
  final Map<String, dynamic>? initialData;

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _order = widget.initialData;
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _loading = true);
    final data = await ref.read(ordersControllerProvider.notifier).loadOrderDetails(widget.orderId);
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Order #${widget.orderId}')),
        body: const Center(child: Text('Failed to load order details')),
      );
    }

    final code = _order!['order_code']?.toString() ?? _order!['code']?.toString() ?? _order!['id']?.toString() ?? 'N/A';
    final dateStr = _order!['created_at']?.toString();
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    final formattedDate = date != null ? DateFormat('MMM d, y HH:mm').format(date) : '-';

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #$code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Share invoice PDF',
            onPressed: _order == null
                ? null
                : () async {
                    final current = _order;
                    if (current == null) return;
                    try {
                      await ref
                          .read(invoiceServiceProvider)
                          .shareOrderInvoicePdf(current);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Invoice export failed: $e')),
                      );
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDetails,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(code, formattedDate),
            const SizedBox(height: 24),
            _buildActions(context),
            const SizedBox(height: 24),
            _buildSectionTitle('Items'),
            _buildItemsList(),
            const SizedBox(height: 24),
            _buildSectionTitle('Payment & Shipping'),
            const SizedBox(height: 8),
            _buildInfoCard([
              _InfoRow('Payment Status', _order!['payment_status']?.toString().toUpperCase() ?? 'PENDING',
                  isBadge: true,
                  color: _getStatusColor(_order!['payment_status']?.toString() ?? '')),
              _InfoRow(
                'Delivery Status',
                (_order!['delivery_status']?.toString() ?? 'pending').toUpperCase().replaceAll('_', ' '),
                  isBadge: true,
                  color: _getStatusColor(_order!['delivery_status']?.toString() ?? '')),
              _InfoRow('Payment Method', _order!['payment_type']?.toString() ?? '-'),
            ]),
            const SizedBox(height: 24),
            _buildSectionTitle('Customer'),
            const SizedBox(height: 8),
            _buildInfoCard([
              _InfoRow('Name', _order!['customer_name']?.toString() ?? _order!['shipping_address']?['name'] ?? '-'),
              _InfoRow('Phone', _order!['customer_phone']?.toString() ?? _order!['shipping_address']?['phone'] ?? '-'),
              _InfoRow('Address', _order!['shipping_address']?['address'] ?? '-'),
              _InfoRow('City', _order!['shipping_address']?['city'] ?? '-'),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String code, String date) {
    final total = double.tryParse(_order!['grand_total']?.toString() ?? '0') ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Placed on $date', style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 8),
        Text(
          'UGX ${NumberFormat('#,###').format(total)}',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manage Order', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Update Status'),
                    onPressed: () => _showStatusModal(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    final itemsRaw = _order!['order_items'] ?? _order!['items'];
    final items = (itemsRaw is List ? itemsRaw : const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (items.isEmpty) return const Text('No items found');

    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          final name = item['product_name']?.toString() ?? item['name']?.toString() ?? 'Item';
          final qty = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
          final unitPrice = item['unit_price'] is num
              ? (item['unit_price'] as num).toDouble()
              : double.tryParse(item['unit_price']?.toString() ?? '') ?? 0;
          final lineTotal = item['total'] is num
              ? (item['total'] as num).toDouble()
              : (unitPrice * qty);
          final variant = item['variation']?.toString() ?? '';

          return ListTile(
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: variant.isNotEmpty ? Text(variant) : null,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('x$qty', style: TextStyle(color: Colors.grey[600])),
                Text('UGX ${NumberFormat('#,###').format(lineTotal)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(List<_InfoRow> rows) {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: rows.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(row.label, style: TextStyle(color: Colors.grey[600])),
                  ),
                  Expanded(
                    child: row.isBadge
                        ? Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: row.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: row.color.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  row.value,
                                  style: TextStyle(color: row.color, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          )
                        : Text(row.value, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showStatusModal(BuildContext context) {
    final statuses = ['pending', 'confirmed', 'picked_up', 'on_the_way', 'delivered', 'cancelled'];
    final paymentStatuses = ['paid', 'unpaid'];
    
    String delivery = (_order!['delivery_status_raw'] ?? _order!['delivery_status'] ?? 'pending')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_');
    String payment = _order!['payment_status']?.toString() ?? 'unpaid';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Update Order Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: statuses.contains(delivery) ? delivery : statuses.first,
              decoration: const InputDecoration(labelText: 'Delivery Status', border: OutlineInputBorder()),
              items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase().replaceAll('_', ' ')))).toList(),
              onChanged: (v) => delivery = v!,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: paymentStatuses.contains(payment) ? payment : paymentStatuses.last,
              decoration: const InputDecoration(labelText: 'Payment Status', border: OutlineInputBorder()),
              items: paymentStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
              onChanged: (v) => payment = v!,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(ordersControllerProvider.notifier).updateStatus(
                      orderId: widget.orderId,
                      delivery: delivery,
                      payment: payment,
                    );
                _fetchDetails(); // Refresh details
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
        return Colors.green;
      case 'pending':
      case 'unpaid':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}

class _InfoRow {
  final String label;
  final String value;
  final bool isBadge;
  final Color color;

  _InfoRow(this.label, this.value, {this.isBadge = false, this.color = Colors.black});
}
