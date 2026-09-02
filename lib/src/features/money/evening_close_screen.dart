import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';

/// Evening Close Screen — Daily profit/loss ritual
class EveningCloseScreen extends ConsumerStatefulWidget {
  const EveningCloseScreen({super.key});

  @override
  ConsumerState<EveningCloseScreen> createState() => _EveningCloseScreenState();
}

class _EveningCloseScreenState extends ConsumerState<EveningCloseScreen> {
  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(
        title: Text('Evening Close', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: ListView(
        padding: DesignTokens.paddingScreen,
        children: [
          Text(_getGreeting(), style: DesignTokens.textHeadline),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(
            _formatDate(now),
            style: DesignTokens.textSmall.copyWith(color: DesignTokens.inkMuted),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          Row(
            children: [
              Expanded(
                child: _MoneyCard(
                  label: 'Money In',
                  amount: '0',
                  color: DesignTokens.brandAccent,
                  icon: Icons.arrow_downward,
                ),
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Expanded(
                child: _MoneyCard(
                  label: 'Money Out',
                  amount: '0',
                  color: DesignTokens.error,
                  icon: Icons.arrow_upward,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          StreamBuilder<List<LedgerEntry>>(
            stream: db.watchLedgerEntriesSince(todayStart),
            builder: (context, snapshot) {
              final entries = snapshot.data ?? [];
              final sales = entries.where((e) => e.type == 'sale').toList();
              final totalSales = sales.fold<double>(0, (sum, e) => sum + e.total);
              final refunds = entries.where((e) => e.type == 'refund').toList();
              final totalRefunds = refunds.fold<double>(0, (sum, e) => sum + e.total);
              final netSales = totalSales - totalRefunds;
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
                        color: netSales >= 0
                            ? DesignTokens.brandAccentSubtle
                            : DesignTokens.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        netSales >= 0 ? Icons.trending_up : Icons.trending_down,
                        color: netSales >= 0 ? DesignTokens.brandAccent : DesignTokens.error,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Net Sales', style: DesignTokens.textSmall),
                          Text(
                            netSales.toUgx(),
                            style: DesignTokens.textTitle.copyWith(
                              color: netSales >= 0 ? DesignTokens.brandAccent : DesignTokens.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          Text('Top Items Today', style: DesignTokens.textTitle),
          const SizedBox(height: DesignTokens.spaceSm),
          StreamBuilder<List<LedgerEntry>>(
            stream: db.watchLedgerEntriesSince(todayStart),
            builder: (context, snapshot) {
              final entries = snapshot.data ?? [];
              final sales = entries.where((e) => e.type == 'sale').toList();
              final itemCounts = <String, int>{};
              final itemTotals = <String, double>{};
              for (final sale in sales) {
                final itemName = sale.note ?? 'Sale';
                itemCounts[itemName] = (itemCounts[itemName] ?? 0) + 1;
                itemTotals[itemName] = (itemTotals[itemName] ?? 0) + sale.total;
              }
              final sortedItems = itemCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              if (sortedItems.isEmpty) {
                return const Text('No sales today');
              }
              return Column(
                children: sortedItems.take(5).map((entry) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: DesignTokens.spaceXs),
                    padding: DesignTokens.paddingSm,
                    decoration: BoxDecoration(
                      color: DesignTokens.canvas,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(entry.key)),
                        Text('${entry.value}x'),
                        const SizedBox(width: DesignTokens.spaceSm),
                        Text(
                          (itemTotals[entry.key] ?? 0).toUgx(),
                          style: DesignTokens.textSmallBold,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          Text('Debt Reminders', style: DesignTokens.textTitle),
          const SizedBox(height: DesignTokens.spaceSm),
          StreamBuilder<List<MadeniEntry>>(
            stream: db.watchMadeniEntries(),
            builder: (context, snapshot) {
              final entries = snapshot.data ?? [];
              final pending = entries.where((e) => e.status != 'paid').toList();
              if (pending.isEmpty) {
                return const Text('No pending debts');
              }
              return Column(
                children: pending.take(3).map((entry) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: DesignTokens.spaceXs),
                    padding: DesignTokens.paddingSm,
                    decoration: BoxDecoration(
                      color: DesignTokens.canvas,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: DesignTokens.hairline),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.customerName, style: DesignTokens.textBodyBold),
                              Text(entry.description, style: DesignTokens.textCaption),
                            ],
                          ),
                        ),
                        Text(
                          (entry.amount - entry.amountPaid).toUgx(),
                          style: DesignTokens.textSmallBold.copyWith(color: DesignTokens.error),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
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
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final String amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.canvas,
        borderRadius: DesignTokens.borderRadiusMd,
        border: Border.all(color: DesignTokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(label, style: DesignTokens.textCaption),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(amount, style: DesignTokens.textTitle.copyWith(color: color)),
        ],
      ),
    );
  }
}
