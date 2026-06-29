import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';

/// Simple accounting overview: sales totals and tax collected.
class AccountingScreen extends ConsumerStatefulWidget {
  const AccountingScreen({super.key});

  @override
  ConsumerState<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends ConsumerState<AccountingScreen> {
  bool _loading = true;
  double _todaySales = 0;
  double _todayTax = 0;
  int _todayCount = 0;
  double _weekSales = 0;
  double _weekTax = 0;
  int _weekCount = 0;
  double _monthSales = 0;
  double _monthTax = 0;
  int _monthCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final todayEntries = await db.ledgerEntriesBetween(todayStart, todayEnd);
    final weekEntries = await db.ledgerEntriesBetween(weekStart, todayEnd);
    final monthEntries = await db.ledgerEntriesBetween(monthStart, monthEnd);

    if (mounted) {
      setState(() {
        _todaySales = _sumSales(todayEntries);
        _todayTax = _sumTax(todayEntries);
        _todayCount = _countSales(todayEntries);
        _weekSales = _sumSales(weekEntries);
        _weekTax = _sumTax(weekEntries);
        _weekCount = _countSales(weekEntries);
        _monthSales = _sumSales(monthEntries);
        _monthTax = _sumTax(monthEntries);
        _monthCount = _countSales(monthEntries);
        _loading = false;
      });
    }
  }

  double _sumSales(List<LedgerEntry> entries) {
    return entries
        .where((e) => e.type == 'sale')
        .fold<double>(0, (sum, e) => sum + e.total);
  }

  double _sumTax(List<LedgerEntry> entries) {
    return entries
        .where((e) => e.type == 'sale')
        .fold<double>(0, (sum, e) => sum + e.tax);
  }

  int _countSales(List<LedgerEntry> entries) {
    return entries.where((e) => e.type == 'sale').length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(
        backgroundColor: DesignTokens.surfaceRaised,
        elevation: 0,
        title: Text('Accounting', style: DesignTokens.textTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: DesignTokens.paddingScreen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummaryCard(
                      title: 'Today',
                      sales: _todaySales,
                      tax: _todayTax,
                      count: _todayCount,
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryCard(
                      title: 'This Week',
                      sales: _weekSales,
                      tax: _weekTax,
                      count: _weekCount,
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryCard(
                      title: 'This Month',
                      sales: _monthSales,
                      tax: _monthTax,
                      count: _monthCount,
                    ),
                    const SizedBox(height: 24),
                    _buildActionTile(
                      icon: Icons.account_balance_outlined,
                      title: 'Tax Settings',
                      subtitle: 'Configure tax rate and inclusion mode',
                      onTap: () => context.go('/home/more/tax-settings'),
                    ),
                    const SizedBox(height: 12),
                    _buildActionTile(
                      icon: Icons.receipt_long_outlined,
                      title: 'Transactions',
                      subtitle: 'View all sales, refunds, and credits',
                      onTap: () => context.go('/home/transactions'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double sales,
    required double tax,
    required int count,
  }) {
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceRaised,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DesignTokens.textBodyBold),
          const SizedBox(height: 12),
          _buildMetricRow('Sales', sales.toUgx()),
          const SizedBox(height: 8),
          _buildMetricRow('Tax collected', tax.toUgx()),
          const SizedBox(height: 8),
          _buildMetricRow('Transactions', '$count'),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: DesignTokens.textBody),
        Text(
          value,
          style: DesignTokens.textBodyBold.copyWith(
            color: DesignTokens.brandPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surfaceRaised,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: DesignTokens.brandPrimary),
        title: Text(title, style: DesignTokens.textBodyBold),
        subtitle: Text(subtitle, style: DesignTokens.textSmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
