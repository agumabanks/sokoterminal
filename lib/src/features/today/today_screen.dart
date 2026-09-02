import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';

/// Today Screen — A simple, beautiful daily summary.
///
/// Design principles (WhatsApp/Apple standard):
/// - Most important info visible immediately (today's sales)
/// - One screen = one purpose (today's business)
/// - Cards, not lists
/// - Zero learning curve
/// - Actionable items first
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      body: SafeArea(
        child: StreamBuilder<List<LedgerEntry>>(
          stream: db.watchLedgerEntriesSince(todayStart),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingState();
            }

            final entries = snapshot.data ?? [];
            final sales = entries.where((e) => e.type == 'sale').toList();
            final refunds = entries.where((e) => e.type == 'refund').toList();

            final totalRevenue = sales.fold<double>(0, (sum, e) => sum + e.total);
            final totalRefunds = refunds.fold<double>(0, (sum, e) => sum + e.total);
            final netRevenue = totalRevenue - totalRefunds;



            return CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: DesignTokens.paddingScreen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: DesignTokens.textHeadline,
                        ),
                        const SizedBox(height: DesignTokens.spaceXs),
                        Text(
                          _formatDate(now),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            label: 'Sales',
                            value: netRevenue.toUgx(),
                            icon: Icons.payments_rounded,
                            color: DesignTokens.brandAccent,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceSm),
                        Expanded(
                          child: _MetricCard(
                            label: 'Orders',
                            value: '${sales.length}',
                            icon: Icons.shopping_bag_outlined,
                            color: DesignTokens.brandPrimary,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceSm),
                        Expanded(
                          child: _MetricCard(
                            label: 'Refunds',
                            value: '${refunds.length}',
                            icon: Icons.assignment_return_outlined,
                            color: refunds.isEmpty
                                ? DesignTokens.inkMuted
                                : DesignTokens.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: DesignTokens.spaceMd),
                ),

                // Recent sales
                if (sales.isNotEmpty) ...[
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
                  SliverPadding(
                    padding: DesignTokens.paddingHorizontalMd,
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final sale = sales[index];
                          return _SaleCard(sale: sale);
                        },
                        childCount: sales.length > 5 ? 5 : sales.length,
                      ),
                    ),
                  ),
                ],

                // Empty state
                if (sales.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: DesignTokens.spaceXxl),
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No sales today',
                        subtitle: 'Your sales will appear here',
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: DesignTokens.spaceXxl),
                ),
              ],
            );
          },
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

  String _formatDate(DateTime date) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            label,
            style: DesignTokens.textCaption,
          ),
        ],
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.sale});

  final LedgerEntry sale;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Text(
                  'Walk-in Customer',
                  style: DesignTokens.textBodyBold,
                ),
                Text(
                  _formatTime(sale.createdAt),
                  style: DesignTokens.textCaption,
                ),
              ],
            ),
          ),
          Text(
            sale.total.toUgx(),
            style: DesignTokens.textMono,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
