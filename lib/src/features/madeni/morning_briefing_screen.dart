import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';

/// Morning Briefing Screen — Daily 7am money summary
///
/// Shows:
/// - Yesterday's sales
/// - Debts in/out
/// - Reminders sent
/// - Estimated cash position
/// - Stock alerts
///
/// This is the reason merchants open the app every day.
class MorningBriefingScreen extends ConsumerWidget {
  const MorningBriefingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(
        title: Text('Morning Briefing', style: DesignTokens.textTitle),
      ),
      body: ListView(
        padding: DesignTokens.paddingScreen,
        children: [
          // Greeting
          Text(_getGreeting(), style: DesignTokens.textHeadline),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(
            _formatDate(now),
            style: DesignTokens.textSmall.copyWith(color: DesignTokens.inkMuted),
          ),
          const SizedBox(height: DesignTokens.spaceMd),

          // Yesterday's sales
          StreamBuilder<List<LedgerEntry>>(
            stream: db.watchLedgerEntriesSince(
              todayStart.subtract(const Duration(days: 1)),
            ),
            builder: (context, snapshot) {
              final entries = snapshot.data ?? [];
              final sales = entries.where((e) => e.type == 'sale').toList();
              final totalSales = sales.fold<double>(0, (sum, e) => sum + e.total);
              return _MetricCard(
                icon: Icons.payments_rounded,
                label: 'Yesterday\'s Sales',
                value: totalSales.toUgx(),
                subtitle: '${sales.length} transactions',
                color: DesignTokens.brandAccent,
              );
            },
          ),
          const SizedBox(height: DesignTokens.spaceSm),

          // Debts in/out
          StreamBuilder<List<MadeniEntry>>(
            stream: db.watchMadeniEntries(),
            builder: (context, snapshot) {
              final entries = snapshot.data ?? [];
              final pending = entries.where((e) => e.status != 'paid').toList();
              final totalOwed = pending.fold<double>(
                0,
                (sum, e) => sum + (e.amount - e.amountPaid),
              );
              return _MetricCard(
                icon: Icons.menu_book_outlined,
                label: 'Customer Debts',
                value: totalOwed.toUgx(),
                subtitle: '${pending.length} pending',
                color: DesignTokens.warning,
              );
            },
          ),
          const SizedBox(height: DesignTokens.spaceSm),

          // Estimated cash position
          StreamBuilder<List<LedgerEntry>>(
            stream: db.watchLedgerEntriesSince(
              todayStart.subtract(const Duration(days: 7)),
            ),
            builder: (context, snapshot) {
              final entries = snapshot.data ?? [];
              final sales = entries.where((e) => e.type == 'sale').toList();
              final totalSales = sales.fold<double>(0, (sum, e) => sum + e.total);
              final avgDaily = totalSales / 7;
              return _MetricCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Avg Daily Sales',
                value: avgDaily.toUgx(),
                subtitle: 'Last 7 days',
                color: DesignTokens.info,
              );
            },
          ),
          const SizedBox(height: DesignTokens.spaceMd),

          // Quick actions
          Text('Quick Actions', style: DesignTokens.textTitle),
          const SizedBox(height: DesignTokens.spaceSm),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.add,
                  label: 'Add Sale',
                  color: DesignTokens.brandAccent,
                  onTap: () {
                    // Navigate to checkout
                  },
                ),
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.menu_book_outlined,
                  label: 'Add Debt',
                  color: DesignTokens.warning,
                  onTap: () {
                    // Navigate to madeni
                  },
                ),
              ),
            ],
          ),
        ],
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
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.canvas,
        borderRadius: DesignTokens.borderRadiusMd,
        border: Border.all(color: DesignTokens.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: DesignTokens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: DesignTokens.textSmall),
                Text(value, style: DesignTokens.textTitle),
                Text(subtitle, style: DesignTokens.textCaption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DesignTokens.borderRadiusMd,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceMd),
          decoration: BoxDecoration(
            color: DesignTokens.canvas,
            borderRadius: DesignTokens.borderRadiusMd,
            border: Border.all(color: DesignTokens.hairline),
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: DesignTokens.spaceXs),
              Text(
                label,
                style: DesignTokens.textCaption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
