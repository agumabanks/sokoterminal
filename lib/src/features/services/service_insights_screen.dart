import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/design_tokens.dart';
import 'booking_create_screen.dart';
import 'service_bookings_controller.dart';
import 'service_insights_controller.dart';

class ServiceInsightsScreen extends ConsumerStatefulWidget {
  const ServiceInsightsScreen({super.key});

  @override
  ConsumerState<ServiceInsightsScreen> createState() => _ServiceInsightsScreenState();
}

class _ServiceInsightsScreenState extends ConsumerState<ServiceInsightsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(serviceBookingsControllerProvider.notifier).load();
      ref.read(serviceInsightsControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serviceInsightsControllerProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Service Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(serviceBookingsControllerProvider.notifier).load();
              ref.read(serviceInsightsControllerProvider.notifier).load();
            },
          ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(serviceBookingsControllerProvider.notifier).load();
                await ref.read(serviceInsightsControllerProvider.notifier).load();
              },
              child: ListView(
                padding: DesignTokens.paddingScreen,
                children: [
                  if (state.error != null)
                    _ErrorCard(message: state.error!),
                  if (state.bookings.isEmpty)
                    _EmptyInsightsState(
                      onCreateBooking: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BookingCreateScreen()),
                      ),
                    )
                  else
                    _RevenueHeadline(state: state),
                  if (state.bookings.isNotEmpty && state.thisWeekBookings > 0) ...[
                    const SizedBox(height: 20),
                    _SectionTitle('This Week Revenue'),
                    const SizedBox(height: 8),
                    _DailyRevenueChart(data: state.dailyRevenue),
                  ],
                  if (state.bookings.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionTitle('Booking Status'),
                    const SizedBox(height: 8),
                    _StatusBreakdown(state: state),
                    const SizedBox(height: 24),
                    if (state.upcomingCount > 0)
                      _UpcomingCard(count: state.upcomingCount),
                    if (state.topServices.isNotEmpty) ...[
                      _SectionTitle('Top Services'),
                      const SizedBox(height: 8),
                      ...state.topServices.map((s) => _ServiceRow(
                        title: s['title'] as String,
                        count: s['count'] as int,
                        revenue: s['revenue'] as double,
                      )),
                    ],
                    const SizedBox(height: 24),
                    _CompletionRateCard(
                      rate: state.completionRate,
                      cancellationRate: state.cancellationRate,
                    ),
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
    );
  }
}

class _RevenueHeadline extends StatelessWidget {
  const _RevenueHeadline({required this.state});
  final ServiceInsightsState state;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
    final change = state.weekOverWeekRevenueChange;
    final isPositive = change >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This Week',
          style: TextStyle(fontSize: 14, color: DesignTokens.grayMedium, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          fmt.format(state.thisWeekRevenue),
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: DesignTokens.brandPrimary),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isPositive ? DesignTokens.brandAccent.withValues(alpha: 0.15) : DesignTokens.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${isPositive ? '+' : ''}${change.toStringAsFixed(0)}% vs last week',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isPositive ? DesignTokens.brandAccent : DesignTokens.error,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${state.thisWeekBookings} bookings',
              style: const TextStyle(fontSize: 13, color: DesignTokens.grayMedium),
            ),
          ],
        ),
      ],
    );
  }
}

class _DailyRevenueChart extends StatelessWidget {
  const _DailyRevenueChart({required this.data});
  final List<double> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        height: 160,
        padding: const EdgeInsets.only(top: 16, right: 16),
        decoration: BoxDecoration(
          color: DesignTokens.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesignTokens.grayLight),
        ),
        child: const Center(
          child: Text('No data yet'),
        ),
      );
    }
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final scale = maxVal > 0 ? maxVal : 1;

    return Container(
      height: 160,
      padding: const EdgeInsets.only(top: 16, right: 16),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.grayLight),
      ),
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) {
                  final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  final idx = v.toInt();
                  if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(days[idx], style: const TextStyle(fontSize: 11, color: DesignTokens.grayMedium)),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(7, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i],
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  color: i == DateTime.now().weekday - 1
                      ? DesignTokens.brandAccent
                      : DesignTokens.brandPrimary.withValues(alpha: 0.3),
                ),
              ],
            );
          }),
          maxY: scale * 1.2,
        ),
      ),
    );
  }
}

class _StatusBreakdown extends StatelessWidget {
  const _StatusBreakdown({required this.state});
  final ServiceInsightsState state;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatusItem('Pending', state.pendingCount, DesignTokens.warning),
      _StatusItem('Confirmed', state.confirmedCount, DesignTokens.info),
      _StatusItem('Completed', state.completedCount, DesignTokens.brandAccent),
      _StatusItem('Cancelled', state.cancelledCount, DesignTokens.grayMedium),
    ];

    return Row(
      children: items.map((item) => Expanded(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  '${item.count}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: const TextStyle(fontSize: 11, color: DesignTokens.grayMedium),
                ),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }
}

class _StatusItem {
  _StatusItem(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.brandAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesignTokens.brandAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available, color: DesignTokens.brandAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count upcoming ${count == 1 ? 'booking' : 'bookings'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Text(
                  'Keep your calendar filled',
                  style: TextStyle(fontSize: 12, color: DesignTokens.grayMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.title, required this.count, required this.revenue});
  final String title;
  final int count;
  final double revenue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('$count ${count == 1 ? 'booking' : 'bookings'}', style: const TextStyle(fontSize: 12, color: DesignTokens.grayMedium)),
              ],
            ),
          ),
          Text(
            'UGX ${revenue.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.w600, color: DesignTokens.brandPrimary),
          ),
        ],
      ),
    );
  }
}

class _CompletionRateCard extends StatelessWidget {
  const _CompletionRateCard({required this.rate, required this.cancellationRate});
  final double rate;
  final double cancellationRate;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Performance', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 80,
                        width: 80,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: rate / 100,
                              strokeWidth: 8,
                              backgroundColor: DesignTokens.grayLight,
                              valueColor: const AlwaysStoppedAnimation(DesignTokens.brandAccent),
                            ),
                            Center(
                              child: Text(
                                '${rate.toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Completion', style: TextStyle(fontSize: 12, color: DesignTokens.grayMedium)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 80,
                        width: 80,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: cancellationRate / 100,
                              strokeWidth: 8,
                              backgroundColor: DesignTokens.grayLight,
                              valueColor: const AlwaysStoppedAnimation(DesignTokens.error),
                            ),
                            Center(
                              child: Text(
                                '${cancellationRate.toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Cancellation', style: TextStyle(fontSize: 12, color: DesignTokens.grayMedium)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: DesignTokens.textSmallBold.copyWith(fontSize: 14));
  }
}

class _EmptyInsightsState extends StatelessWidget {
  const _EmptyInsightsState({required this.onCreateBooking});
  final VoidCallback onCreateBooking;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: DesignTokens.brandAccent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.trending_up, size: 40, color: DesignTokens.brandAccent),
        ),
        const SizedBox(height: 20),
        const Text(
          'Your insights will appear here',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Create your first booking to see revenue, popular services, and completion rates — all in one place.',
            textAlign: TextAlign.center,
            style: TextStyle(color: DesignTokens.grayMedium, height: 1.5),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onCreateBooking,
          icon: const Icon(Icons.add),
          label: const Text('Create First Booking'),
          style: ElevatedButton.styleFrom(
            backgroundColor: DesignTokens.brandAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: DesignTokens.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: DesignTokens.error)),
    );
  }
}
