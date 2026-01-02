import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../checkout/cart_controller.dart';
import 'service_bookings_controller.dart';

enum _BookingAction { confirm, complete, cancel, createSale }

class ServiceBookingsScreen extends ConsumerWidget {
  const ServiceBookingsScreen({super.key, this.serviceId});

  /// Optional: filter bookings for a specific service
  final String? serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serviceBookingsControllerProvider);
    final controller = ref.read(serviceBookingsControllerProvider.notifier);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Service Bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.load,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.loading && state.bookings.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null && state.bookings.isEmpty) {
            return Center(child: Text('Error: ${state.error}'));
          }
          return ListView.builder(
            padding: DesignTokens.paddingScreen,
            itemCount: state.bookings.length,
            itemBuilder: (context, index) {
              final booking = state.bookings[index];
              final id = int.tryParse(booking['id']?.toString() ?? '') ?? 0;
              final status = booking['status']?.toString() ?? 'pending';
              final offeringTitle =
                  (booking['offering'] is Map ? (booking['offering']['title']?.toString()) : null) ??
                  'Booking';
              final customerName =
                  (booking['user'] is Map ? (booking['user']['name']?.toString()) : null) ??
                  'Customer';
              final scheduledStart = DateTime.tryParse(booking['scheduled_start']?.toString() ?? '');
              final whenLabel = scheduledStart == null ? '' : _formatWhen(scheduledStart);
              final price = double.tryParse(booking['price']?.toString() ?? '') ?? 0;

              final actions = _actionsForStatus(status);

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.event_note_outlined),
                  title: Text(offeringTitle),
                  subtitle: Text(
                    [customerName, if (whenLabel.isNotEmpty) whenLabel]
                        .where((e) => e.trim().isNotEmpty)
                        .join(' • '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _StatusChip(status: status),
                          const SizedBox(height: 6),
                          Text(
                            'UGX ${price.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      if (actions.isNotEmpty && id != 0) ...[
                        const SizedBox(width: 8),
                        PopupMenuButton<_BookingAction>(
                          itemBuilder: (context) => actions
                              .map(
                                (a) => PopupMenuItem<_BookingAction>(
                                  value: a,
                                  child: Text(_actionLabel(a)),
                                ),
                              )
                              .toList(),
                          onSelected: (action) async {
                            switch (action) {
                              case _BookingAction.confirm:
                                await controller.confirm(id);
                                break;
                              case _BookingAction.complete:
                                await controller.complete(id);
                                break;
                              case _BookingAction.cancel:
                                final reason = await _promptCancelReason(context);
                                if (!context.mounted) return;
                                await controller.cancel(id, reason: reason);
                                break;
                              case _BookingAction.createSale:
                                // Pre-fill checkout with booking data
                                final offeringId = booking['offering_id']?.toString() ?? booking['offering']?['id']?.toString();
                                if (offeringId == null || offeringId.isEmpty) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Cannot find service for this booking')),
                                    );
                                  }
                                  return;
                                }
                                final db = ref.read(appDatabaseProvider);
                                // Try to find local service by remote ID
                                final serviceRemoteId = int.tryParse(offeringId);
                                final service = serviceRemoteId != null 
                                    ? await db.getServiceByRemoteId(serviceRemoteId)
                                    : await db.getServiceById(offeringId);
                                if (service == null) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Service not found locally. Sync first.')),
                                    );
                                  }
                                  return;
                                }
                                // Add to cart
                                ref.read(cartControllerProvider.notifier).addService(
                                  service: service,
                                  variantPrice: price > 0 ? price : null,
                                );
                                // Navigate to checkout
                                if (context.mounted) {
                                  context.go('/checkout');
                                }
                                break;
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static List<_BookingAction> _actionsForStatus(String statusRaw) {
    final status = statusRaw.toLowerCase().trim();
    if (status == 'pending') return [_BookingAction.confirm, _BookingAction.createSale, _BookingAction.cancel];
    if (status == 'confirmed') return [_BookingAction.complete, _BookingAction.createSale, _BookingAction.cancel];
    return const [];
  }

  static String _actionLabel(_BookingAction action) {
    switch (action) {
      case _BookingAction.confirm:
        return 'Confirm';
      case _BookingAction.complete:
        return 'Complete';
      case _BookingAction.cancel:
        return 'Cancel';
      case _BookingAction.createSale:
        return 'Create Sale';
    }
  }

  static String _formatWhen(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  static Future<String?> _promptCancelReason(BuildContext context) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel booking'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'Customer requested, no-show, etc.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isEmpty ? null : ctrl.text.trim()),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return reason;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase().trim();
    final label = normalized.isEmpty ? 'pending' : normalized;

    Color bg;
    Color fg;
    switch (label) {
      case 'confirmed':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        break;
      case 'completed':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'cancelled':
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        break;
      default:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
