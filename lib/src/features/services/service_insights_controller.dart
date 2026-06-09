import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';

final serviceInsightsControllerProvider =
    StateNotifierProvider<ServiceInsightsController, ServiceInsightsState>((
      ref,
    ) {
      final db = ref.watch(appDatabaseProvider);
      return ServiceInsightsController(db)..load();
    });

class ServiceInsightsState {
  const ServiceInsightsState({
    this.loading = false,
    this.bookings = const [],
    this.thisWeekRevenue = 0,
    this.lastWeekRevenue = 0,
    this.thisWeekBookings = 0,
    this.lastWeekBookings = 0,
    this.upcomingCount = 0,
    this.pendingCount = 0,
    this.confirmedCount = 0,
    this.completedCount = 0,
    this.cancelledCount = 0,
    this.topServices = const [],
    this.dailyRevenue = const [],
    this.error,
  });

  final bool loading;
  final List<Map<String, dynamic>> bookings;
  final double thisWeekRevenue;
  final double lastWeekRevenue;
  final int thisWeekBookings;
  final int lastWeekBookings;
  final int upcomingCount;
  final int pendingCount;
  final int confirmedCount;
  final int completedCount;
  final int cancelledCount;
  final List<Map<String, dynamic>> topServices;
  final List<double> dailyRevenue;
  final String? error;

  double get weekOverWeekRevenueChange {
    if (lastWeekRevenue == 0) return thisWeekRevenue > 0 ? 100 : 0;
    return ((thisWeekRevenue - lastWeekRevenue) / lastWeekRevenue) * 100;
  }

  double get weekOverWeekBookingsChange {
    if (lastWeekBookings == 0) return thisWeekBookings > 0 ? 100 : 0;
    return ((thisWeekBookings - lastWeekBookings) / lastWeekBookings) * 100;
  }

  double get completionRate {
    final total = pendingCount + confirmedCount + completedCount + cancelledCount;
    if (total == 0) return 0;
    return (completedCount / total) * 100;
  }

  double get cancellationRate {
    final total = pendingCount + confirmedCount + completedCount + cancelledCount;
    if (total == 0) return 0;
    return (cancelledCount / total) * 100;
  }
}

class ServiceInsightsController extends StateNotifier<ServiceInsightsState> {
  ServiceInsightsController(this.db) : super(const ServiceInsightsState());

  final AppDatabase db;

  Future<void> load() async {
    state = const ServiceInsightsState(loading: true);
    try {
      final cached = await db.getCachedServiceBookings();
      final bookings = cached
          .map((r) => Map<String, dynamic>.from(jsonDecode(r.payloadJson) as Map))
          .toList();

      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
      final lastWeekStart = weekStartDate.subtract(const Duration(days: 7));
      final lastWeekEnd = weekStartDate.subtract(const Duration(days: 1));

      double thisWeekRevenue = 0;
      double lastWeekRevenue = 0;
      int thisWeekBookings = 0;
      int lastWeekBookings = 0;
      int upcoming = 0;
      int pending = 0;
      int confirmed = 0;
      int completed = 0;
      int cancelled = 0;
      final serviceCounts = <String, Map<String, dynamic>>{};
      final dailyRev = List<double>.filled(7, 0);

      for (final b in bookings) {
        final startStr = b['scheduled_start']?.toString();
        final start = startStr != null ? DateTime.tryParse(startStr) : null;
        final status = b['status']?.toString().toLowerCase() ?? 'pending';
        final price = double.tryParse(b['price']?.toString() ?? '') ?? 0;
        final offering = b['offering'] is Map ? b['offering'] as Map<String, dynamic> : null;
        final serviceTitle = offering?['title']?.toString() ?? 'Unknown';

        // Status counts
        switch (status) {
          case 'pending':
            pending++;
            break;
          case 'confirmed':
            confirmed++;
            break;
          case 'completed':
            completed++;
            break;
          case 'cancelled':
          case 'rescheduled':
            cancelled++;
            break;
        }

        if (start != null) {
          final local = start.toLocal();
          final dayStart = DateTime(local.year, local.month, local.day);

          // This week
          if (!dayStart.isBefore(weekStartDate)) {
            thisWeekRevenue += price;
            thisWeekBookings++;
            final dow = local.weekday - 1; // 0=Mon
            if (dow >= 0 && dow < 7) {
              dailyRev[dow] += price;
            }
          }
          // Last week
          else if (!dayStart.isBefore(lastWeekStart) && !dayStart.isAfter(lastWeekEnd)) {
            lastWeekRevenue += price;
            lastWeekBookings++;
          }

          // Upcoming (future confirmed/pending)
          if (dayStart.isAfter(now) && (status == 'pending' || status == 'confirmed')) {
            upcoming++;
          }
        }

        // Top services
        serviceCounts.update(
          serviceTitle,
          (existing) => {
            'title': serviceTitle,
            'count': (existing['count'] as int) + 1,
            'revenue': (existing['revenue'] as double) + price,
          },
          ifAbsent: () => {'title': serviceTitle, 'count': 1, 'revenue': price},
        );
      }

      final topServices = serviceCounts.values.toList()
        ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

      state = ServiceInsightsState(
        loading: false,
        bookings: bookings,
        thisWeekRevenue: thisWeekRevenue,
        lastWeekRevenue: lastWeekRevenue,
        thisWeekBookings: thisWeekBookings,
        lastWeekBookings: lastWeekBookings,
        upcomingCount: upcoming,
        pendingCount: pending,
        confirmedCount: confirmed,
        completedCount: completed,
        cancelledCount: cancelled,
        topServices: topServices.take(5).toList(),
        dailyRevenue: dailyRev,
      );
    } catch (e) {
      state = ServiceInsightsState(loading: false, error: e.toString());
    }
  }
}
