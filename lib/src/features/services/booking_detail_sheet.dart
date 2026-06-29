import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_providers.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../checkout/cart_controller.dart';
import 'job_timer_screen.dart';
import 'service_bookings_controller.dart';

/// Bottom sheet that shows full booking details and actions.
class BookingDetailSheet extends ConsumerWidget {
  const BookingDetailSheet({super.key, required this.booking});

  final Map<String, dynamic> booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(booking['id']?.toString() ?? '') ?? 0;
    final status = booking['status']?.toString() ?? 'pending';
    final offering = booking['offering'] is Map ? booking['offering'] as Map<String, dynamic> : null;
    final user = booking['user'] is Map ? booking['user'] as Map<String, dynamic> : null;
    final metadata = booking['metadata'] is Map ? booking['metadata'] as Map<String, dynamic> : null;

    final offeringTitle = offering?['title']?.toString() ?? 'Service';
    final customerName = user?['name']?.toString() ?? 'Customer';
    final customerPhone = user?['phone']?.toString() ?? '';
    final scheduledStart = DateTime.tryParse(booking['scheduled_start']?.toString() ?? '');
    final scheduledEnd = DateTime.tryParse(booking['scheduled_end']?.toString() ?? '');
    final price = double.tryParse(booking['price']?.toString() ?? '') ?? 0;
    final notes = booking['notes']?.toString() ?? '';
    final meetingType = booking['meeting_type']?.toString() ?? 'in_person';
    final location = booking['location'] is Map
        ? (booking['location'] as Map<String, dynamic>)['address']?.toString()
        : null;
    final meetingLink = booking['meeting_link']?.toString();
    final clientName = metadata?['client_name']?.toString() ?? '';
    final clientPhone = metadata?['client_phone']?.toString() ?? '';

    final displayName = clientName.isNotEmpty ? clientName : customerName;
    final displayPhone = clientPhone.isNotEmpty ? clientPhone : customerPhone;

    final controller = ref.read(serviceBookingsControllerProvider.notifier);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DesignTokens.grayLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  offeringTitle,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 4),
          if (scheduledStart != null)
            Text(
              DateFormat('EEEE, dd MMM yyyy • HH:mm').format(scheduledStart.toLocal()),
              style: const TextStyle(color: DesignTokens.grayMedium, fontSize: 14),
            ),
          if (scheduledEnd != null && scheduledStart != null)
            Text(
              'Duration: ${_fmtDuration(scheduledEnd.difference(scheduledStart))}',
              style: const TextStyle(color: DesignTokens.grayMedium, fontSize: 13),
            ),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.person_outline, label: displayName),
          if (displayPhone.isNotEmpty)
            _InfoRow(icon: Icons.phone_outlined, label: displayPhone),
          _InfoRow(
            icon: _meetingIcon(meetingType),
            label: _meetingLabel(meetingType),
          ),
          if (location != null && location.isNotEmpty)
            _InfoRow(icon: Icons.place_outlined, label: location),
          if (meetingLink != null && meetingLink.isNotEmpty)
            _InfoRow(icon: Icons.link, label: meetingLink),
          if (notes.isNotEmpty)
            _InfoRow(icon: Icons.notes_outlined, label: notes),
          if (price > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'UGX ${price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.brandPrimary,
                ),
              ),
            ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (status == 'pending')
                _ActionChip(
                  icon: Icons.check_circle_outline,
                  label: 'Confirm',
                  color: DesignTokens.brandAccent,
                  onTap: () async {
                    Navigator.pop(context);
                    await controller.confirm(id);
                  },
                ),
              if (status == 'confirmed')
                _ActionChip(
                  icon: Icons.done_all,
                  label: 'Complete',
                  color: DesignTokens.brandAccent,
                  onTap: () async {
                    Navigator.pop(context);
                    await controller.complete(id);
                  },
                ),
              if (status == 'pending' || status == 'confirmed')
                _ActionChip(
                  icon: Icons.schedule,
                  label: 'Reschedule',
                  color: DesignTokens.info,
                  onTap: () async {
                    Navigator.pop(context);
                    await _showRescheduleDialog(context, ref, id, scheduledStart, scheduledEnd);
                  },
                ),
              _ActionChip(
                icon: Icons.timer_outlined,
                label: 'Timer',
                color: DesignTokens.brandPrimary,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const JobTimerScreen()),
                  );
                },
              ),
              _ActionChip(
                icon: Icons.point_of_sale_outlined,
                label: 'Create Sale',
                color: DesignTokens.warning,
                onTap: () async {
                  Navigator.pop(context);
                  await _createSale(context, ref);
                },
              ),
              if (status == 'pending' || status == 'confirmed')
                _ActionChip(
                  icon: Icons.cancel_outlined,
                  label: 'Cancel',
                  color: DesignTokens.error,
                  onTap: () async {
                    Navigator.pop(context);
                    final reason = await _promptCancelReason(context);
                    if (reason != null || context.mounted) {
                      await controller.cancel(id, reason: reason);
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showRescheduleDialog(
    BuildContext context,
    WidgetRef ref,
    int bookingId,
    DateTime? currentStart,
    DateTime? currentEnd,
  ) async {
    DateTime? newDate = currentStart;
    String? newSlot;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reschedule Booking'),
        content: StatefulBuilder(
          builder: (ctx, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('New Date'),
                  subtitle: Text(
                    newDate != null
                        ? DateFormat('EEE, dd MMM yyyy').format(newDate!)
                        : 'Select date',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: newDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => newDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                const Text('New Time', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '09:00', '10:00', '11:00', '12:00',
                    '13:00', '14:00', '15:00', '16:00',
                  ].map((slot) {
                    final selected = newSlot == slot;
                    return ChoiceChip(
                      label: Text(slot),
                      selected: selected,
                      onSelected: (_) => setState(() => newSlot = slot),
                      selectedColor: DesignTokens.brandAccent,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : DesignTokens.textPrimary,
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (newDate == null || newSlot == null) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Reschedule'),
          ),
        ],
      ),
    );

    if (result == true && newDate != null && newSlot != null && context.mounted) {
      final parts = newSlot!.split(':');
      final start = DateTime(
        newDate!.year,
        newDate!.month,
        newDate!.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      final duration = currentEnd != null && currentStart != null
          ? currentEnd.difference(currentStart)
          : const Duration(hours: 1);
      final end = start.add(duration);

      final sync = ref.read(syncServiceProvider);
      await sync.enqueue('booking_reschedule', {
        'booking_id': bookingId,
        'scheduled_start': start.toUtc().toIso8601String(),
        'scheduled_end': end.toUtc().toIso8601String(),
      });
      unawaited(sync.syncNow());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reschedule queued')),
        );
      }
    }
  }

  Future<void> _createSale(BuildContext context, WidgetRef ref) async {
    final offeringId = booking['offering_id']?.toString() ??
        booking['offering']?['id']?.toString();
    if (offeringId == null || offeringId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot find service for this booking')),
      );
      return;
    }
    final db = ref.read(appDatabaseProvider);
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
    final price = double.tryParse(booking['price']?.toString() ?? '') ?? 0;
    ref.read(cartControllerProvider.notifier).addService(
      service: service,
      variantPrice: price > 0 ? price : null,
    );
    if (context.mounted) {
      context.go('/checkout');
    }
  }

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  static IconData _meetingIcon(String type) {
    switch (type) {
      case 'virtual':
        return Icons.videocam_outlined;
      case 'hybrid':
        return Icons.sync_alt;
      default:
        return Icons.meeting_room_outlined;
    }
  }

  static String _meetingLabel(String type) {
    switch (type) {
      case 'virtual':
        return 'Virtual meeting';
      case 'hybrid':
        return 'Hybrid meeting';
      default:
        return 'In-person meeting';
    }
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: DesignTokens.grayMedium),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: DesignTokens.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase().trim();
    Color bg;
    Color fg;
    switch (normalized) {
      case 'confirmed':
        bg = DesignTokens.canvasCloud;
        fg = DesignTokens.info;
        break;
      case 'completed':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'cancelled':
      case 'rescheduled':
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        break;
      default:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        normalized.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
