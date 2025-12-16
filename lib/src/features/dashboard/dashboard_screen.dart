import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/stat_card.dart';

final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  final db = ref.read(appDatabaseProvider);
  final entries = await db.watchLedgerEntries().first;
  final sales = entries.where((e) => e.type == 'sale').toList();
  final refunds = entries.where((e) => e.type == 'refund').toList();
  final gross = sales.fold<double>(0, (p, e) => p + e.total);
  final net = gross - refunds.fold<double>(0, (p, e) => p + e.total);
  
  // Calculate trend (mock for now - compare to previous period)
  final todayCount = sales
      .where((t) => t.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 1))))
      .length;
  
  return DashboardMetrics(
    grossSales: gross,
    netSales: net,
    transactions: sales.length,
    averageSale: sales.isEmpty ? 0 : gross / sales.length,
    todayTransactions: todayCount,
  );
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dashboardMetricsProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      body: metrics.when(
        data: (m) => CustomScrollView(
          slivers: [
            // ─────────────────────────────────────────────────────────────────
            // GRADIENT HEADER
            // ─────────────────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 180,
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
                            'My Business',
                            style: DesignTokens.textTitleLight.copyWith(fontSize: 24),
                          ),
                          const SizedBox(height: DesignTokens.spaceXs),
                          Text(
                            _getGreeting(),
                            style: DesignTokens.textSmallLight,
                          ),
                          const SizedBox(height: DesignTokens.spaceMd),
                          Row(
                            children: [
                              const Icon(
                                Icons.circle,
                                size: 8,
                                color: DesignTokens.brandAccent,
                              ),
                              const SizedBox(width: DesignTokens.spaceXs),
                              Text(
                                'All systems operational',
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

            // ─────────────────────────────────────────────────────────────────
            // STATS CARDS
            // ─────────────────────────────────────────────────────────────────
            SliverPadding(
              padding: DesignTokens.paddingScreen,
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: DesignTokens.spaceSm),
                    
                    // Primary stat - Gross Sales
                    StatCard(
                      label: 'Total Sales',
                      value: 'UGX ${_formatNumber(m.grossSales)}',
                      icon: Icons.account_balance_wallet_outlined,
                      trend: m.grossSales > 0 ? StatTrend.up : StatTrend.flat,
                      trendLabel: m.grossSales > 0 ? '+${m.todayTransactions} today' : null,
                      variant: StatCardVariant.gradient,
                    ),
                    
                    const SizedBox(height: DesignTokens.spaceSm),
                    
                    // Secondary stats row
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Transactions',
                            value: m.transactions.toString(),
                            icon: Icons.receipt_long_outlined,
                            variant: StatCardVariant.standard,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceSm),
                        Expanded(
                          child: StatCard(
                            label: 'Avg Sale',
                            value: 'UGX ${_formatNumber(m.averageSale)}',
                            icon: Icons.trending_up,
                            variant: StatCardVariant.standard,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: DesignTokens.spaceLg),
                    
                    // ─────────────────────────────────────────────────────────
                    // QUICK ACTIONS
                    // ─────────────────────────────────────────────────────────
                    Text('Quick Actions', style: DesignTokens.textTitle),
                    const SizedBox(height: DesignTokens.spaceMd),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.point_of_sale,
                            label: 'New Sale',
                            color: DesignTokens.brandAccent,
                            onTap: () => context.go('/home/checkout'),
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceSm),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.shopping_bag_outlined,
                            label: 'Orders',
                            color: DesignTokens.brandPrimary,
                            onTap: () => context.go('/home/more/orders'),
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceSm),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.bar_chart,
                            label: 'Reports',
                            color: DesignTokens.info,
                            onTap: () => context.go('/home/more/reports'),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: DesignTokens.spaceLg),
                    
                    // ─────────────────────────────────────────────────────────
                    // INSIGHTS
                    // ─────────────────────────────────────────────────────────
                    Text('Insights', style: DesignTokens.textTitle),
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
                      iconColor: DesignTokens.info,
                      title: 'Sync Status',
                      subtitle: 'All data synced successfully',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.spaceSm,
                          vertical: DesignTokens.spaceXs,
                        ),
                        decoration: BoxDecoration(
                          color: DesignTokens.brandAccent.withOpacity(0.1),
                          borderRadius: DesignTokens.borderRadiusSm,
                        ),
                        child: Text(
                          'Online',
                          style: DesignTokens.textSmall.copyWith(
                            color: DesignTokens.brandAccent,
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
        loading: () => const Center(child: CircularProgressIndicator()),
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning! Here\'s your business overview.';
    if (hour < 17) return 'Good afternoon! Here\'s how you\'re doing.';
    return 'Good evening! Here\'s your daily summary.';
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

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: DesignTokens.paddingMd,
        decoration: BoxDecoration(
          color: DesignTokens.surfaceWhite,
          borderRadius: DesignTokens.borderRadiusMd,
          boxShadow: DesignTokens.shadowSm,
        ),
        child: Column(
          children: [
            Container(
              padding: DesignTokens.paddingSm,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: DesignTokens.borderRadiusSm,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              label,
              style: DesignTokens.textSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: DesignTokens.grayDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
          color: DesignTokens.surfaceWhite,
          borderRadius: DesignTokens.borderRadiusMd,
          boxShadow: DesignTokens.shadowSm,
        ),
        child: Row(
          children: [
            Container(
              padding: DesignTokens.paddingSm,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: DesignTokens.borderRadiusSm,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: DesignTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DesignTokens.textBodyBold),
                  Text(subtitle, style: DesignTokens.textSmall),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(
                Icons.chevron_right,
                color: DesignTokens.grayMedium,
              ),
          ],
        ),
      ),
    );
  }
}

class DashboardMetrics {
  DashboardMetrics({
    required this.grossSales,
    required this.netSales,
    required this.transactions,
    required this.averageSale,
    this.todayTransactions = 0,
  });
  final double grossSales;
  final double netSales;
  final int transactions;
  final double averageSale;
  final int todayTransactions;
}
