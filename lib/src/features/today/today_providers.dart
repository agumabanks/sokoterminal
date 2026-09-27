import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';

/// Today metrics — scoped provider so greeting/metrics/list rebuild independently.
final todayMetricsProvider = StreamProvider<TodayMetrics>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));

  // The brief is local-first; refresh periodically without querying Drift
  // every second while the screen is open.
  return Stream.periodic(const Duration(seconds: 15), (_) => DateTime.now())
      .asyncMap((_) async {
        final today = await db.ledgerEntriesBetween(todayStart, now);
        final yesterday = await db.ledgerEntriesBetween(
          yesterdayStart,
          todayStart.subtract(const Duration(milliseconds: 1)),
        );

        final todaySales = today.where((e) => e.type == 'sale').toList();
        final todayRefunds = today.where((e) => e.type == 'refund').toList();
        final yesterdaySales = yesterday
            .where((e) => e.type == 'sale')
            .toList();

        final totalRevenue = todaySales.fold<double>(0, (s, e) => s + e.total);
        final totalRefunds = todayRefunds.fold<double>(
          0,
          (s, e) => s + e.total,
        );
        final yesterdayRevenue = yesterdaySales.fold<double>(
          0,
          (s, e) => s + e.total,
        );

        return TodayMetrics(
          revenue: totalRevenue,
          refunds: totalRefunds,
          netRevenue: totalRevenue - totalRefunds,
          orderCount: todaySales.length,
          refundCount: todayRefunds.length,
          yesterdayRevenue: yesterdayRevenue,
        );
      })
      .distinct(
        (a, b) => a.netRevenue == b.netRevenue && a.orderCount == b.orderCount,
      );
});

/// Recent sales — windowed stream, LIMIT 20.
final recentSalesProvider = StreamProvider<List<LedgerEntry>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  return db.watchLedgerEntriesSince(todayStart).map((entries) {
    return entries.where((e) => e.type == 'sale').take(20).toList();
  });
});

/// Outstanding madeni summary for Today card.
final outstandingMadeniProvider = StreamProvider<MadeniSummary>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchMadeniEntries().map((entries) {
    final outstanding = entries.where((e) => e.status != 'paid').toList();
    final total = outstanding.fold<double>(
      0,
      (s, e) => s + (e.amount - e.amountPaid),
    );
    return MadeniSummary(count: outstanding.length, total: total);
  });
});

class TodayMetrics {
  const TodayMetrics({
    required this.revenue,
    required this.refunds,
    required this.netRevenue,
    required this.orderCount,
    required this.refundCount,
    required this.yesterdayRevenue,
  });

  final double revenue;
  final double refunds;
  final double netRevenue;
  final int orderCount;
  final int refundCount;
  final double yesterdayRevenue;

  double get percentChange {
    if (yesterdayRevenue == 0) return netRevenue > 0 ? 100 : 0;
    return ((netRevenue - yesterdayRevenue) / yesterdayRevenue) * 100;
  }
}

class MadeniSummary {
  const MadeniSummary({required this.count, required this.total});
  final int count;
  final double total;
}
