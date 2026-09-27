import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/util/haptics.dart';
import '../../widgets/empty_state.dart';
import 'today_providers.dart';
import '../services/service_bookings_controller.dart';
import '../services/service_bookings_screen.dart';

/// Today Screen — A simple, beautiful daily summary.
///
/// Design principles (WhatsApp/Apple standard):
/// - Most important info visible immediately (today's sales)
/// - One screen = one purpose (today's business)
/// - Cards, not lists
/// - Zero learning curve
/// - Actionable items first
/// - Works offline-first from Drift
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(todayMetricsProvider);
    final salesAsync = ref.watch(recentSalesProvider);
    final madeniAsync = ref.watch(outstandingMadeniProvider);
    final pendingSync = ref
        .watch(pendingSyncCountProvider)
        .maybeWhen(data: (count) => count, orElse: () => 0);
    final bookings = ref.watch(serviceBookingsControllerProvider).bookings;
    final todayBookings = bookings.where((booking) {
      final raw = booking['scheduled_start']?.toString();
      final date = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
      final now = DateTime.now();
      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day &&
          booking['status']?.toString() != 'cancelled';
    }).length;

    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            Haptics.selection();
            // Re-trigger providers
            ref.invalidate(todayMetricsProvider);
            ref.invalidate(recentSalesProvider);
            ref.invalidate(outstandingMadeniProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: DesignTokens.paddingScreen,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        label: _getSemanticGreeting(),
                        child: Text(
                          _getGreeting(),
                          style: DesignTokens.textHeadline,
                        ),
                      ),
                      const SizedBox(height: DesignTokens.spaceXs),
                      Text(
                        _formatDate(DateTime.now()),
                        style: DesignTokens.textSmall.copyWith(
                          color: DesignTokens.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Today's numbers
              SliverPadding(
                padding: DesignTokens.paddingHorizontalMd,
                sliver: SliverToBoxAdapter(
                  child: metricsAsync.when(
                    loading: () => const _MetricsSkeleton(),
                    error: (_, __) => const _MetricsSkeleton(),
                    data: (metrics) => _MetricsRow(metrics: metrics),
                  ),
                ),
              ),

              SliverPadding(
                padding: DesignTokens.paddingHorizontalMd,
                sliver: SliverToBoxAdapter(
                  child: _BusinessBriefCard(
                    todayBookings: todayBookings,
                    pendingSync: pendingSync,
                    outstandingCredit: madeniAsync.valueOrNull?.count ?? 0,
                    onBookings: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ServiceBookingsScreen(),
                      ),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: DesignTokens.spaceMd),
              ),

              // Madeni card (outstanding credit)
              if (madeniAsync.valueOrNull?.count != null &&
                  (madeniAsync.valueOrNull?.count ?? 0) > 0)
                SliverPadding(
                  padding: DesignTokens.paddingHorizontalMd,
                  sliver: SliverToBoxAdapter(
                    child: madeniAsync.maybeWhen(
                      data: (m) => _MadeniCard(summary: m),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: DesignTokens.spaceMd),
              ),

              // Recent sales
              SliverPadding(
                padding: DesignTokens.paddingHorizontalMd,
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Text('Recent Sales', style: DesignTokens.textTitle),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.go('/home/transactions'),
                        child: const Text('See all'),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: DesignTokens.spaceSm),
              ),
              salesAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, __) => const SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.error_outline,
                    title: 'Could not load sales',
                  ),
                ),
                data: (sales) {
                  if (sales.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: DesignTokens.spaceXxl),
                        child: EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No sales today',
                          subtitle: 'Your sales will appear here',
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: DesignTokens.paddingHorizontalMd,
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final sale = sales[index];
                        return _SaleCard(sale: sale);
                      }, childCount: sales.length > 5 ? 5 : sales.length),
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: DesignTokens.spaceXxl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getSemanticGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatDate(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}

class _BusinessBriefCard extends StatelessWidget {
  const _BusinessBriefCard({
    required this.todayBookings,
    required this.pendingSync,
    required this.outstandingCredit,
    required this.onBookings,
  });

  final int todayBookings;
  final int pendingSync;
  final int outstandingCredit;
  final VoidCallback onBookings;

  @override
  Widget build(BuildContext context) {
    final attention = <String>[
      if (todayBookings > 0)
        '$todayBookings booking${todayBookings == 1 ? '' : 's'} today',
      if (pendingSync > 0)
        '$pendingSync change${pendingSync == 1 ? '' : 's'} waiting to sync',
      if (outstandingCredit > 0)
        '$outstandingCredit unpaid credit entr${outstandingCredit == 1 ? 'y' : 'ies'}',
    ];
    final headline = attention.isEmpty
        ? 'Your business is ready'
        : 'Here is what needs attention';
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: DesignTokens.brandPrimary,
      shape: RoundedRectangleBorder(borderRadius: DesignTokens.borderRadiusLg),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: DesignTokens.brandAccent,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    attention.isEmpty
                        ? 'Sales, stock and bookings are up to date.'
                        : attention.join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (todayBookings > 0)
              IconButton(
                tooltip: 'Open bookings',
                onPressed: onBookings,
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricsSkeleton extends StatelessWidget {
  const _MetricsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          Expanded(
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: DesignTokens.canvas,
                borderRadius: DesignTokens.borderRadiusMd,
                border: Border.all(color: DesignTokens.hairline),
              ),
            ),
          ),
          if (i < 2) const SizedBox(width: DesignTokens.spaceSm),
        ],
      ],
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.metrics});

  final TodayMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final change = metrics.percentChange;
    final isUp = change >= 0;
    final changeText = change.abs() >= 0.1
        ? '${isUp ? '▲' : '▼'} ${change.abs().toStringAsFixed(0)}% vs yesterday'
        : 'same as yesterday';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Sales',
                value:
                    'UGX ${NumberFormat.compact().format(metrics.netRevenue)}',
                icon: Icons.payments_rounded,
                color: DesignTokens.brandAccent,
                semanticLabel:
                    'Today\'s net sales, ${metrics.netRevenue.toUgx()}, $changeText',
              ),
            ),
            const SizedBox(width: DesignTokens.spaceSm),
            Expanded(
              child: _MetricCard(
                label: 'Orders',
                value: '${metrics.orderCount}',
                icon: Icons.shopping_bag_outlined,
                color: DesignTokens.brandPrimary,
                semanticLabel: 'Today\'s orders, ${metrics.orderCount}',
              ),
            ),
            const SizedBox(width: DesignTokens.spaceSm),
            Expanded(
              child: _MetricCard(
                label: 'Refunds',
                value: '${metrics.refundCount}',
                icon: Icons.assignment_return_outlined,
                color: metrics.refundCount == 0
                    ? DesignTokens.inkMuted
                    : DesignTokens.error,
                semanticLabel: 'Today\'s refunds, ${metrics.refundCount}',
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.spaceXs),
        Semantics(
          label: changeText,
          child: Row(
            children: [
              Icon(
                isUp ? Icons.trending_up : Icons.trending_down,
                size: 14,
                color: isUp ? DesignTokens.success : DesignTokens.error,
              ),
              const SizedBox(width: 4),
              Text(
                changeText,
                style: DesignTokens.textCaption.copyWith(
                  color: isUp ? DesignTokens.success : DesignTokens.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.semanticLabel,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        decoration: BoxDecoration(
          color: DesignTokens.canvas,
          borderRadius: DesignTokens.borderRadiusMd,
          border: Border.all(color: DesignTokens.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              value,
              style: DesignTokens.textTitle.copyWith(
                fontSize: 18,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: DesignTokens.textCaption),
          ],
        ),
      ),
    );
  }
}

class _MadeniCard extends StatelessWidget {
  const _MadeniCard({required this.summary});

  final MadeniSummary summary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${summary.count} customers owe ${summary.total.toUgx()}',
      child: GestureDetector(
        onTap: () => context.go('/home/more/madeni'),
        onTapDown: (_) => Haptics.selection(),
        child: Container(
          padding: DesignTokens.paddingMd,
          decoration: BoxDecoration(
            color: DesignTokens.canvas,
            borderRadius: DesignTokens.borderRadiusMd,
            border: Border.all(
              color: DesignTokens.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DesignTokens.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: DesignTokens.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${summary.count} customer${summary.count == 1 ? '' : 's'} owe',
                      style: DesignTokens.textBodyBold,
                    ),
                    Text('Tap to collect', style: DesignTokens.textCaption),
                  ],
                ),
              ),
              Text(
                'UGX ${NumberFormat.compact().format(summary.total)}',
                style: DesignTokens.textMono.copyWith(
                  color: DesignTokens.warning,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.sale});

  final LedgerEntry sale;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(sale.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: DesignTokens.spaceXs),
        decoration: BoxDecoration(
          color: DesignTokens.success.withValues(alpha: 0.15),
          borderRadius: DesignTokens.borderRadiusMd,
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.share, color: DesignTokens.success),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: DesignTokens.spaceXs),
        decoration: BoxDecoration(
          color: DesignTokens.error.withValues(alpha: 0.15),
          borderRadius: DesignTokens.borderRadiusMd,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.assignment_return, color: DesignTokens.error),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Share receipt via WhatsApp
          _shareReceipt(context);
          return false;
        } else {
          // Mark as credit / refund
          _markAsCredit(context);
          return false;
        }
      },
      child: Semantics(
        label:
            'Sale to Walk-in Customer, ${sale.total.toUgx()}, ${_formatTime(sale.createdAt)}. Swipe right to share receipt, left to mark as credit.',
        child: Container(
          margin: const EdgeInsets.only(bottom: DesignTokens.spaceXs),
          padding: DesignTokens.paddingMd,
          decoration: BoxDecoration(
            color: DesignTokens.canvas,
            borderRadius: DesignTokens.borderRadiusMd,
            border: Border.all(color: DesignTokens.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DesignTokens.brandAccentSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check_circle_outline,
                  color: DesignTokens.brandAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Walk-in Customer', style: DesignTokens.textBodyBold),
                    Text(
                      _formatTime(sale.createdAt),
                      style: DesignTokens.textCaption,
                    ),
                  ],
                ),
              ),
              Text(sale.total.toUgx(), style: DesignTokens.textMono),
            ],
          ),
        ),
      ),
    );
  }

  void _shareReceipt(BuildContext context) {
    Haptics.success();
    // In production, generate PDF receipt and share via WhatsApp
    // For now, show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt sharing coming soon')),
    );
  }

  void _markAsCredit(BuildContext context) {
    Haptics.success();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mark as credit coming soon')));
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
