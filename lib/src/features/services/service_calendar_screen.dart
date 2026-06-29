import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/design_tokens.dart';
import 'booking_create_screen.dart';
import 'booking_detail_sheet.dart';
import 'service_bookings_controller.dart';

/// Interactive week-view calendar for service bookings.
///
/// - Swipe left/right to change week.
/// - Tap a booking card to open detail sheet.
/// - Tap an empty day column to create a booking for that day.
/// - Today is highlighted.
class ServiceCalendarScreen extends ConsumerStatefulWidget {
  const ServiceCalendarScreen({super.key});

  @override
  ConsumerState<ServiceCalendarScreen> createState() => _ServiceCalendarScreenState();
}

class _ServiceCalendarScreenState extends ConsumerState<ServiceCalendarScreen> {
  late DateTime _weekStart;
  final _dateFormat = DateFormat('E dd');
  final _timeFormat = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(DateTime.now());
  }

  DateTime _startOfWeek(DateTime d) {
    final weekday = d.weekday; // 1=Mon
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: weekday - 1));
  }

  void _prevWeek() => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  void _nextWeek() => setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
  void _goToday() => setState(() => _weekStart = _startOfWeek(DateTime.now()));

  void _showBookingDetail(Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingDetailSheet(booking: booking),
    );
  }

  void _createBookingForDay(DateTime day) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingCreateScreen(preselectedDate: day),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serviceBookingsControllerProvider);

    // Group bookings by day
    final byDay = <DateTime, List<Map<String, dynamic>>>{};
    for (final b in state.bookings) {
      final dt = DateTime.tryParse(b['scheduled_start']?.toString() ?? '');
      if (dt == null) continue;
      final day = DateTime(dt.year, dt.month, dt.day);
      byDay.putIfAbsent(day, () => []).add(b);
    }

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          TextButton(
            onPressed: _goToday,
            child: const Text('Today'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Week navigator
          Padding(
            padding: DesignTokens.paddingScreen,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _prevWeek,
                ),
                Expanded(
                  child: Text(
                    '${DateFormat('dd MMM').format(_weekStart)} — ${DateFormat('dd MMM yyyy').format(_weekStart.add(const Duration(days: 6)))}',
                    style: DesignTokens.textTitle,
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextWeek,
                ),
              ],
            ),
          ),

          // Day headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMd),
            child: Row(
              children: List.generate(7, (i) {
                final day = _weekStart.add(Duration(days: i));
                final isToday = day.year == DateTime.now().year &&
                    day.month == DateTime.now().month &&
                    day.day == DateTime.now().day;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _createBookingForDay(day),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isToday ? DesignTokens.brandAccent.withValues(alpha: 0.1) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isToday ? DesignTokens.brandAccent : DesignTokens.grayMedium,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isToday ? DesignTokens.brandAccent : DesignTokens.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 24),

          // Booking cards by day
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMd),
              children: List.generate(7, (i) {
                final day = _weekStart.add(Duration(days: i));
                final bookings = byDay[day] ?? [];
                bookings.sort((a, b) {
                  final aStart = DateTime.tryParse(a['scheduled_start']?.toString() ?? '');
                  final bStart = DateTime.tryParse(b['scheduled_start']?.toString() ?? '');
                  if (aStart == null || bStart == null) return 0;
                  return aStart.compareTo(bStart);
                });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (i > 0) const SizedBox(height: 12),
                    Text(
                      _dateFormat.format(day),
                      style: DesignTokens.textSmallBold.copyWith(color: DesignTokens.grayMedium),
                    ),
                    const SizedBox(height: 6),
                    if (bookings.isEmpty)
                      GestureDetector(
                        onTap: () => _createBookingForDay(day),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: DesignTokens.surfaceGrouped,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: DesignTokens.grayLight),
                          ),
                          child: const Center(
                            child: Text(
                              'Tap to add booking',
                              style: TextStyle(color: DesignTokens.grayMedium),
                            ),
                          ),
                        ),
                      )
                    else
                      ...bookings.map((b) {
                        return _BookingCard(
                          booking: b,
                          timeFormat: _timeFormat,
                          onTap: () => _showBookingDetail(b),
                        );
                      }),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.timeFormat,
    required this.onTap,
  });

  final Map<String, dynamic> booking;
  final DateFormat timeFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = (booking['offering'] is Map
            ? booking['offering']['title']?.toString()
            : null) ??
        'Booking';
    final customer = (booking['user'] is Map
            ? booking['user']['name']?.toString()
            : null) ??
        'Customer';
    final start = DateTime.tryParse(booking['scheduled_start']?.toString() ?? '');
    final end = DateTime.tryParse(booking['scheduled_end']?.toString() ?? '');
    final price = double.tryParse(booking['price']?.toString() ?? '') ?? 0;
    final status = booking['status']?.toString() ?? 'pending';

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'confirmed':
        statusColor = DesignTokens.info;
        break;
      case 'completed':
        statusColor = DesignTokens.brandAccent;
        break;
      case 'cancelled':
      case 'rescheduled':
        statusColor = DesignTokens.grayMedium;
        break;
      default:
        statusColor = DesignTokens.warning;
    }

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: statusColor, width: 4)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(customer, style: const TextStyle(fontSize: 13, color: DesignTokens.grayMedium)),
                      if (start != null && end != null)
                        Text(
                          '${timeFormat.format(start)} — ${timeFormat.format(end)}',
                          style: const TextStyle(fontSize: 12, color: DesignTokens.grayMedium),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'UGX ${price.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
