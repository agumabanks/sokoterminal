import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_status_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/stat_card.dart';

final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  final db = ref.read(appDatabaseProvider);
  final entries = await db.watchLedgerEntries().first;
  final sales = entries.where((e) => e.type == 'sale').toList();
  final refunds = entries.where((e) => e.type == 'refund').toList();
  final gross = sales.fold<double>(0, (p, e) => p + e.total);
  final net = gross - refunds.fold<double>(0, (p, e) => p + e.total);

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todaySales = sales.where((t) => !t.createdAt.isBefore(todayStart)).toList();
  final todayRevenue = todaySales.fold<double>(0, (p, e) => p + e.total);
  final todayCount = todaySales.length;

  // Estimate gross profit assuming ~40% margin when cost data unavailable
  // Use net sales as proxy (net = gross - refunds)
  final grossProfit = net * 0.4;

  return DashboardMetrics(
    grossSales: gross,
    netSales: net,
    transactions: sales.length,
    averageSale: sales.isEmpty ? 0 : gross / sales.length,
    todayTransactions: todayCount,
    todayRevenue: todayRevenue,
    grossProfit: grossProfit,
  );
});

final _businessProfileProvider = FutureProvider<BusinessProfile?>((ref) async {
  final db = ref.read(appDatabaseProvider);
  return db.getBusinessProfile();
});

final _recentLedgerProvider = FutureProvider<List<_RecentSale>>((ref) async {
  final db = ref.read(appDatabaseProvider);
  final entries = await db.watchLedgerEntries().first;
  final sales = entries.where((e) => e.type == 'sale').take(5).toList();
  final result = <_RecentSale>[];
  for (final entry in sales) {
    final payments =
        await (db.select(db.payments)..where((p) => p.entryId.equals(entry.id))).get();
    final method = payments.isNotEmpty ? payments.first.method : 'cash';
    result.add(_RecentSale(entry: entry, paymentMethod: method));
  }
  return result;
});

final _sparklineDataProvider = FutureProvider<List<double>>((ref) async {
  final db = ref.read(appDatabaseProvider);
  final entries = await db.watchLedgerEntries().first;
  final now = DateTime.now();
  final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
  final dailySales = <double>[];
  for (final day in days) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final total = entries
        .where((e) =>
            e.type == 'sale' &&
            !e.createdAt.isBefore(dayStart) &&
            e.createdAt.isBefore(dayEnd))
        .fold<double>(0, (sum, e) => sum + e.total);
    dailySales.add(total);
  }
  return dailySales;
});

class _RecentSale {
  const _RecentSale({required this.entry, required this.paymentMethod});
  final LedgerEntry entry;
  final String paymentMethod;
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dashboardMetricsProvider);
    final connectivity = ref.watch(connectivityProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final businessProfile = ref.watch(_businessProfileProvider);
    final recentSales = ref.watch(_recentLedgerProvider);

    final isOnline = connectivity.asData?.value.any(
          (r) => r != ConnectivityResult.none,
        ) ??
        true;

    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      body: metrics.when(
        data: (m) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: DesignTokens.brandPrimary,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: DesignTokens.brandGradient,
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: DesignTokens.paddingScreen,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            businessProfile.asData?.value?.shopName ?? 'My Business',
                            style: DesignTokens.textDisplay.copyWith(
                              color: DesignTokens.surfaceWhite,
                              fontSize: 28,
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spaceXs),
                          Text(
                            _getGreeting(businessProfile.asData?.value?.sellerName),
                            style: DesignTokens.textSmallLight,
                          ),
                          const SizedBox(height: DesignTokens.spaceMd),
                          Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: isOnline
                                    ? DesignTokens.brandAccent
                                    : DesignTokens.warning,
                              ),
                              const SizedBox(width: DesignTokens.spaceXs),
                              Text(
                                isOnline ? 'Live' : 'Offline mode',
                                style: DesignTokens.textSmallLight.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                DateFormat('EEE d MMM').format(DateTime.now()),
                                style: DesignTokens.textSmallLight,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: DesignTokens.paddingScreen,
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: DesignTokens.spaceSm),
                    // ── Hero Revenue Card ─────────────────────────────────
                    _HeroRevenueCard(metrics: m, formatter: _formatNumber),
                    const SizedBox(height: DesignTokens.spaceSm),
                    // ── 7-day Sparkline ───────────────────────────────────
                    const SizedBox(height: 72, child: _SparklineChart()),
                    const SizedBox(height: DesignTokens.spaceSm),
                    // ── KPI Row: Transactions | Avg Order | Gross Profit ──
                    Row(
                      children: [
                        Expanded(
                          child: _KpiCard(
                            label: 'Transactions',
                            value: m.transactions.toString(),
                            icon: Icons.receipt_long_outlined,
                            iconColor: DesignTokens.info,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceSm),
                        Expanded(
                          child: _KpiCard(
                            label: 'Avg Order',
                            value: 'UGX ${_formatNumber(m.averageSale)}',
                            icon: Icons.trending_up,
                            iconColor: const Color(0xFF805AD5),
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceSm),
                        Expanded(
                          child: _KpiCard(
                            label: 'Est. Profit',
                            value: 'UGX ${_formatNumber(m.grossProfit)}',
                            icon: Icons.savings_outlined,
                            iconColor: DesignTokens.brandAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                    if (m.transactions >= 5)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: DesignTokens.paddingCard,
                            decoration: BoxDecoration(
                              color: DesignTokens.brandAccent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                              border: Border.all(
                                color: DesignTokens.brandAccent.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.bar_chart,
                                  color: DesignTokens.brandAccent,
                                ),
                                const SizedBox(width: DesignTokens.spaceMd),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'View your sales report',
                                        style: DesignTokens.textTitle.copyWith(
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: DesignTokens.spaceXs,
                                      ),
                                      Text(
                                        '${m.transactions} transactions recorded — see your P&L.',
                                        style: DesignTokens.textCaption,
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      context.go('/home/more/reports'),
                                  child: const Text('View'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spaceLg),
                        ],
                      ),
                    Text('Quick Actions', style: DesignTokens.textTitle),
                    const SizedBox(height: DesignTokens.spaceMd),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 80,
                                child: _QuickActionTile(
                                  icon: Icons.point_of_sale,
                                  label: 'New Sale',
                                  subtitle: 'Start checkout',
                                  color: DesignTokens.brandAccent,
                                  onTap: () => context.go('/home/checkout'),
                                ),
                              ),
                            ),
                            const SizedBox(width: DesignTokens.spaceSm),
                            Expanded(
                              child: SizedBox(
                                height: 80,
                                child: _QuickActionTile(
                                  icon: Icons.shopping_bag_outlined,
                                  label: 'Orders',
                                  subtitle: 'Manage orders',
                                  color: DesignTokens.brandPrimary,
                                  onTap: () => context.go('/home/more/orders'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DesignTokens.spaceSm),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 80,
                                child: _QuickActionTile(
                                  icon: Icons.inventory_2_outlined,
                                  label: 'Products',
                                  subtitle: 'View inventory',
                                  color: DesignTokens.info,
                                  onTap: () => context.go('/home/more/items'),
                                ),
                              ),
                            ),
                            const SizedBox(width: DesignTokens.spaceSm),
                            Expanded(
                              child: SizedBox(
                                height: 80,
                                child: _QuickActionTile(
                                  icon: Icons.bar_chart,
                                  label: 'Reports',
                                  subtitle: 'Sales reports',
                                  color: const Color(0xFF805AD5),
                                  onTap: () => context.go('/home/more/reports'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                    Text('Recent Sales', style: DesignTokens.textTitle),
                    const SizedBox(height: DesignTokens.spaceMd),
                    recentSales.when(
                      data: (sales) {
                        if (sales.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: DesignTokens.spaceLg,
                              ),
                              child: Text(
                                'Your sales trend will appear after your first day',
                                style: DesignTokens.textCaption,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        return Container(
                          decoration: BoxDecoration(
                            color: DesignTokens.surfaceRaised,
                            borderRadius: DesignTokens.borderRadiusMd,
                            boxShadow: DesignTokens.shadowSm,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: sales.asMap().entries.map((e) {
                              final sale = e.value;
                              final isLast = e.key == sales.length - 1;
                              return Column(
                                children: [
                                  _RecentSaleRow(sale: sale),
                                  if (!isLast)
                                    const Divider(
                                      height: 0.5,
                                      thickness: 0.5,
                                      indent: 72,
                                      color: DesignTokens.dividerSolid,
                                    ),
                                ],
                              );
                            }).toList(),
                          ),
                        );
                      },
                      loading: () => const SizedBox(
                        height: 80,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                    Text('Insights', style: DesignTokens.textHeadline),
                    const SizedBox(height: DesignTokens.spaceMd),
                    _InsightCard(
                      icon: Icons.trending_up,
                      iconColor: DesignTokens.brandAccent,
                      title: 'Sales Trajectory',
                      subtitle: 'Track daily vs last week performance',
                      onTap: () => context.go('/home/more/reports'),
                    ),
                    const SizedBox(height: DesignTokens.spaceSm),
                    _InsightCard(
                      icon: Icons.inventory_2_outlined,
                      iconColor: DesignTokens.warning,
                      title: 'Low Stock Alerts',
                      subtitle: 'Items dropping below thresholds',
                      onTap: () => context.go('/home/more/items'),
                    ),
                    const SizedBox(height: DesignTokens.spaceSm),
                    _InsightCard(
                      icon: Icons.sync,
                      iconColor: _syncColor(syncStatus),
                      title: 'Sync Status',
                      subtitle: _syncSubtitle(syncStatus),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.spaceSm,
                          vertical: DesignTokens.spaceXs,
                        ),
                        decoration: BoxDecoration(
                          color: _syncColor(syncStatus).withValues(alpha: 0.1),
                          borderRadius: DesignTokens.borderRadiusSm,
                        ),
                        child: Text(
                          _syncLabel(syncStatus),
                          style: DesignTokens.textSmall.copyWith(
                            color: _syncColor(syncStatus),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceXl),
                  ],
                ),
              ),
            ),
          ],
        ),
        loading: () => const _DashboardSkeleton(),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: DesignTokens.error),
              const SizedBox(height: DesignTokens.spaceMd),
              Text('Error loading dashboard', style: DesignTokens.textBody),
              const SizedBox(height: DesignTokens.spaceSm),
              Text('$e', style: DesignTokens.textSmall),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting(String? firstName) {
    final hour = DateTime.now().hour;
    final namePart = (firstName != null && firstName.trim().isNotEmpty)
        ? ', ${firstName.trim().split(' ').first}'
        : '';
    if (hour < 12) return 'Good morning$namePart';
    if (hour < 17) return 'Good afternoon$namePart';
    return 'Good evening$namePart';
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }
}

class _AnimatedValue extends StatelessWidget {
  const _AnimatedValue({
    required this.value,
    required this.formatter,
    required this.style,
  });

  final double value;
  final String Function(double) formatter;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutQuart,
      builder: (context, animated, child) {
        return Text(
          formatter(animated),
          style: style,
        );
      },
    );
  }
}

class _SparklineChart extends ConsumerWidget {
  const _SparklineChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_sparklineDataProvider);
    return dataAsync.when(
      data: (data) {
        if (data.every((v) => v == 0)) {
          return Center(
            child: Text(
              'Your sales trend will appear after your first day',
              style: DesignTokens.textCaption,
              textAlign: TextAlign.center,
            ),
          );
        }
        final maxY = data.reduce((a, b) => a > b ? a : b) * 1.2;
        final normalizedMaxY = maxY < 1 ? 1.0 : maxY;
        return LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: data.length - 1,
            minY: 0,
            maxY: normalizedMaxY,
            lineBarsData: [
              LineChartBarData(
                spots: data
                    .asMap()
                    .entries
                    .map((e) => FlSpot(e.key.toDouble(), e.value))
                    .toList(),
                isCurved: true,
                color: DesignTokens.brandAccent.withValues(alpha: 0.95),
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: DesignTokens.brandAccent.withValues(alpha: 0.12),
                ),
              ),
            ],
            lineTouchData: const LineTouchData(enabled: false),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _DashboardSkeleton extends StatefulWidget {
  const _DashboardSkeleton();

  @override
  State<_DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<_DashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = 0.3 + (_controller.value * 0.4);
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: DesignTokens.brandPrimary,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: DesignTokens.brandGradient,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: DesignTokens.paddingScreen,
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: DesignTokens.spaceSm),
                    Opacity(
                      opacity: opacity,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: DesignTokens.grayLight,
                          borderRadius: DesignTokens.borderRadiusMd,
                        ),
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceSm),
                    Row(
                      children: [
                        Expanded(
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: DesignTokens.grayLight,
                                borderRadius: DesignTokens.borderRadiusMd,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceSm),
                        Expanded(
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: DesignTokens.grayLight,
                                borderRadius: DesignTokens.borderRadiusMd,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                    Opacity(
                      opacity: opacity,
                      child: Container(
                        height: 16,
                        width: 120,
                        decoration: BoxDecoration(
                          color: DesignTokens.grayLight,
                          borderRadius: DesignTokens.borderRadiusSm,
                        ),
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceMd),
                    Row(
                      children: [
                        Expanded(
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: DesignTokens.grayLight,
                                borderRadius: DesignTokens.borderRadiusMd,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceSm),
                        Expanded(
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: DesignTokens.grayLight,
                                borderRadius: DesignTokens.borderRadiusMd,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.spaceSm),
                    Row(
                      children: [
                        Expanded(
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: DesignTokens.grayLight,
                                borderRadius: DesignTokens.borderRadiusMd,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceSm),
                        Expanded(
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: DesignTokens.grayLight,
                                borderRadius: DesignTokens.borderRadiusMd,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignTokens.surfaceRaised,
      borderRadius: DesignTokens.borderRadiusMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: DesignTokens.borderRadiusMd,
        splashFactory: NoSplash.splashFactory,
        highlightColor: DesignTokens.surfaceGrouped,
        child: Ink(
          decoration: BoxDecoration(
            color: DesignTokens.surfaceRaised,
            borderRadius: DesignTokens.borderRadiusMd,
            boxShadow: DesignTokens.shadowSm,
          ),
          child: Padding(
            padding: DesignTokens.paddingMd,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: DesignTokens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: DesignTokens.textBodyBold,
                      ),
                      Text(
                        subtitle,
                        style: DesignTokens.textCaption,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: DesignTokens.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero Revenue Card ────────────────────────────────────────────────────────
class _HeroRevenueCard extends StatelessWidget {
  const _HeroRevenueCard({required this.metrics, required this.formatter});

  final DashboardMetrics metrics;
  final String Function(double) formatter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EBE7E), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DesignTokens.borderRadiusLg,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EBE7E).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Today's Revenue",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          _AnimatedValue(
            value: metrics.todayRevenue,
            formatter: (v) => 'UGX ${formatter(v)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_outlined, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(
                '${metrics.todayTransactions} transaction${metrics.todayTransactions == 1 ? '' : 's'} today',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(width: 16),
              Container(
                width: 1,
                height: 12,
                color: Colors.white38,
              ),
              const SizedBox(width: 16),
              const Icon(Icons.show_chart, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(
                'Total UGX ${formatter(metrics.grossSales)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── KPI Card ─────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceRaised,
        borderRadius: DesignTokens.borderRadiusMd,
        border: Border.all(color: DesignTokens.grayLight.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: DesignTokens.textBodyBold.copyWith(
              fontSize: 14,
              color: DesignTokens.grayDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: DesignTokens.textCaption.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _RecentSaleRow extends StatelessWidget {
  const _RecentSaleRow({required this.sale});

  final _RecentSale sale;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a').format(sale.entry.createdAt.toLocal());
    // Build initials from note or show generic receipt icon
    final note = sale.entry.note ?? '';
    final initials = note.trim().isNotEmpty
        ? note.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '';
    final hasInitials = initials.isNotEmpty;

    return Padding(
      padding: DesignTokens.paddingMd,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DesignTokens.brandAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: hasInitials
                  ? Text(
                      initials,
                      style: const TextStyle(
                        color: DesignTokens.brandAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    )
                  : const Icon(
                      Icons.receipt_long_outlined,
                      color: DesignTokens.brandAccent,
                      size: 20,
                    ),
            ),
          ),
          const SizedBox(width: DesignTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.trim().isNotEmpty ? note.trim() : 'Walk-in sale',
                  style: DesignTokens.textBodyBold.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(time, style: DesignTokens.textCaption),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'UGX ${_formatCurrency(sale.entry.total)}',
                style: DesignTokens.textMono.copyWith(
                  fontSize: 14,
                  color: DesignTokens.grayDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: DesignTokens.surfaceGrouped,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _capitalize(sale.paymentMethod),
                  style: DesignTokens.textCaption.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: DesignTokens.paddingMd,
        decoration: BoxDecoration(
          color: DesignTokens.surfaceRaised,
          borderRadius: DesignTokens.borderRadiusMd,
          boxShadow: DesignTokens.shadowSm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: DesignTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DesignTokens.textBodyBold),
                  Text(subtitle, style: DesignTokens.textCaption),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              const Icon(Icons.chevron_right, color: DesignTokens.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

String _syncSubtitle(SyncStatus status) {
  switch (status.state) {
    case SyncState.syncing:
      return status.message ?? 'Syncing data…';
    case SyncState.error:
      return status.message ?? 'Sync error';
    case SyncState.offline:
      return 'Working offline • ${status.pendingCount} pending';
    case SyncState.idle:
      if (status.pendingCount > 0) {
        return '${status.pendingCount} items waiting to sync';
      }
      return 'All data synced successfully';
  }
}

Color _syncColor(SyncStatus status) {
  switch (status.state) {
    case SyncState.syncing:
      return DesignTokens.info;
    case SyncState.error:
      return DesignTokens.error;
    case SyncState.offline:
      return DesignTokens.warning;
    case SyncState.idle:
      return status.pendingCount > 0 ? DesignTokens.warning : DesignTokens.brandAccent;
  }
}

String _syncLabel(SyncStatus status) {
  switch (status.state) {
    case SyncState.syncing:
      return 'Syncing';
    case SyncState.error:
      return 'Error';
    case SyncState.offline:
      return 'Offline';
    case SyncState.idle:
      return status.pendingCount > 0 ? 'Pending' : 'Online';
  }
}

class DashboardMetrics {
  DashboardMetrics({
    required this.grossSales,
    required this.netSales,
    required this.transactions,
    required this.averageSale,
    this.todayTransactions = 0,
    this.todayRevenue = 0,
    this.grossProfit = 0,
  });
  final double grossSales;
  final double netSales;
  final int transactions;
  final double averageSale;
  final int todayTransactions;
  final double todayRevenue;
  final double grossProfit;
}
