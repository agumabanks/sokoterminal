import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/design_tokens.dart';
import 'analytics_controller.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Business Insights', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(analyticsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(analyticsProvider.notifier).refresh(),
              child: ListView(
                padding: DesignTokens.paddingScreen,
                children: [
                  _buildSummaryCards(state),
                  const SizedBox(height: DesignTokens.spaceLg),
                  _buildSalesChart(state),
                  const SizedBox(height: DesignTokens.spaceLg),
                  _buildTopProducts(state),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards(AnalyticsState state) {
    final total7d = state.dailySales.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Revenue (7d)',
            value: 'UGX ${NumberFormat.compact().format(total7d)}',
            icon: Icons.payments_outlined,
            color: DesignTokens.success,
          ),
        ),
        const SizedBox(width: DesignTokens.spaceMd),
        Expanded(
          child: _StatCard(
            label: 'Stock Value',
            value:
                'UGX ${NumberFormat.compact().format(state.totalInventoryValue)}',
            icon: Icons.inventory_2_outlined,
            color: DesignTokens.brandAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildSalesChart(AnalyticsState state) {
    if (state.dailySales.isEmpty) return const SizedBox.shrink();

    final maxVal = state.dailySales.fold<double>(
      0,
      (max, e) => e.amount > max ? e.amount : max,
    );
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Sales Trend', style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceLg),
          AspectRatio(
            aspectRatio: 1.7,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= state.dailySales.length) {
                          return const Text('');
                        }
                        final date = state.dailySales[index].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            DateFormat('E').format(date),
                            style: DesignTokens.textSmall.copyWith(
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('');
                        return Text(
                          NumberFormat.compact().format(value),
                          style: DesignTokens.textSmall.copyWith(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: state.dailySales.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.amount,
                        color: DesignTokens.brandPrimary,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProducts(AnalyticsState state) {
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Selling Products', style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceMd),
          if (state.topProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: DesignTokens.spaceLg,
              ),
              child: Center(
                child: Text('No sales data yet', style: DesignTokens.textSmall),
              ),
            )
          else
            ...state.topProducts.map(
              (p) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: DesignTokens.brandPrimary.withValues(
                    alpha: 0.1,
                  ),
                  child: Text(
                    p.name[0].toUpperCase(),
                    style: const TextStyle(color: DesignTokens.brandPrimary),
                  ),
                ),
                title: Text(p.name, style: DesignTokens.textBody),
                subtitle: Text(
                  '${p.quantity} sold',
                  style: DesignTokens.textSmall,
                ),
                trailing: Text(
                  'UGX ${NumberFormat.compact().format(p.revenue)}',
                  style: DesignTokens.textBodyBold.copyWith(
                    color: DesignTokens.brandAccent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(
            label,
            style: DesignTokens.textSmall.copyWith(
              color: DesignTokens.grayMedium,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: DesignTokens.textBodyBold),
          ),
        ],
      ),
    );
  }
}
