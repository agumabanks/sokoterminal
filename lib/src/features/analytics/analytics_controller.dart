import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_providers.dart';

class SaleData {
  final DateTime date;
  final double amount;
  SaleData(this.date, this.amount);
}

class TopProduct {
  final String name;
  final int quantity;
  final double revenue;
  TopProduct(this.name, this.quantity, this.revenue);
}

class AnalyticsState {
  final List<SaleData> dailySales;
  final List<TopProduct> topProducts;
  final double totalInventoryValue;
  final bool loading;

  AnalyticsState({
    this.dailySales = const [],
    this.topProducts = const [],
    this.totalInventoryValue = 0,
    this.loading = true,
  });

  AnalyticsState copyWith({
    List<SaleData>? dailySales,
    List<TopProduct>? topProducts,
    double? totalInventoryValue,
    bool? loading,
  }) {
    return AnalyticsState(
      dailySales: dailySales ?? this.dailySales,
      topProducts: topProducts ?? this.topProducts,
      totalInventoryValue: totalInventoryValue ?? this.totalInventoryValue,
      loading: loading ?? this.loading,
    );
  }
}

class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  AnalyticsNotifier(this.ref) : super(AnalyticsState()) {
    refresh();
  }

  final Ref ref;

  Future<void> refresh() async {
    state = state.copyWith(loading: true);
    final db = ref.read(appDatabaseProvider);

    // 1. Fetch sales for last 7 days
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    // We'll perform the aggregation in Dart for simplicity,
    // though for large datasets we'd use SQL group by.
    final entries = await db.ledgerEntriesBetween(weekAgo, now);

    final salesMap = <DateTime, double>{};
    for (int i = 0; i <= 7; i++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      salesMap[date] = 0;
    }

    for (final entry in entries) {
      if (entry.type != 'sale') continue;
      final date = DateTime(
        entry.createdAt.year,
        entry.createdAt.month,
        entry.createdAt.day,
      );
      salesMap[date] = (salesMap[date] ?? 0) + entry.total;
    }

    final dailyData =
        salesMap.entries.map((e) => SaleData(e.key, e.value)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    // 2. Fetch top products
    // This is more complex since we need to join LedgerLines with LedgerEntries
    // For now, we'll use a simpler approach: get all lines from recent successful sales
    final recentSaleIds = entries
        .where((e) => e.type == 'sale')
        .map((e) => e.id)
        .toList();
    final allLines = await db.getLinesForEntries(recentSaleIds);

    final productAgg = <String, _Agg>{};
    for (final line in allLines) {
      final key = line.title;
      final current = productAgg[key] ?? _Agg(0, 0);
      productAgg[key] = _Agg(
        current.qty + line.quantity,
        current.rev + line.lineTotal,
      );
    }

    final topProducts =
        productAgg.entries
            .map((e) => TopProduct(e.key, e.value.qty, e.value.rev))
            .toList()
          ..sort((a, b) => b.revenue.compareTo(a.revenue));

    // 3. Inventory Value (SQL-level aggregation)
    final invValue = await db.totalInventoryValue();

    state = state.copyWith(
      dailySales: dailyData,
      topProducts: topProducts.take(5).toList(),
      totalInventoryValue: invValue,
      loading: false,
    );
  }
}

class _Agg {
  final int qty;
  final double rev;
  _Agg(this.qty, this.rev);
}

final analyticsProvider =
    StateNotifierProvider<AnalyticsNotifier, AnalyticsState>((ref) {
      return AnalyticsNotifier(ref);
    });
