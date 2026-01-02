import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';

/// Provider for all ledger entries (for reports)
final ledgerEntriesStreamProvider = StreamProvider<List<LedgerEntry>>((ref) {
  return ref.watch(appDatabaseProvider).watchLedgerEntries();
});

final cashMovementsStreamProvider = StreamProvider<List<CashMovement>>((ref) {
  return ref.watch(appDatabaseProvider).watchCashMovements(limit: 500);
});

final expensesStreamProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(appDatabaseProvider).watchExpenses(limit: 2000);
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateRange = ref.watch(_dateRangeProvider);
    final entries = ref.watch(ledgerEntriesStreamProvider);
    final movements = ref.watch(cashMovementsStreamProvider);
    final expenses = ref.watch(expensesStreamProvider);

    final hasAnything =
        (entries.asData?.value.isNotEmpty ?? false) ||
        (movements.asData?.value.isNotEmpty ?? false) ||
        (expenses.asData?.value.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Financial Reports', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: hasAnything ? () => _exportPdf(ref, context) : null,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: DesignTokens.paddingScreen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DateFilterBar(),
                  const SizedBox(height: DesignTokens.spaceLg),
                  entries.when(
                    data: (entryList) => movements.when(
                      data: (moveList) {
                        return expenses.when(
                          data: (expenseList) {
                            final report = _computeReport(
                              entryList,
                              moveList,
                              expenseList,
                              dateRange,
                            );

                            final opExpenseChildren = <Widget>[
                              _ReportRow(
                                label: 'Recorded Expenses',
                                value: report.recordedExpenses,
                                isNegative: true,
                              ),
                              if (report.legacyCashouts > 0)
                                _ReportRow(
                                  label: 'Legacy Cashouts (unlinked)',
                                  value: report.legacyCashouts,
                                  isNegative: true,
                                ),
                              if (report.legacyCashouts > 0) const Divider(height: DesignTokens.spaceLg),
                              if (report.legacyCashouts > 0)
                                _ReportRow(
                                  label: 'Total Expenses',
                                  value: report.expenses,
                                  isNegative: true,
                                  isBold: true,
                                ),
                            ];

                            return Column(
                              children: [
                                _NetProfitCard(report: report),
                                const SizedBox(height: DesignTokens.spaceLg),
                                _StatGrid(report: report),
                                const SizedBox(height: DesignTokens.spaceLg),
                                _ReportSection(
                                  title: 'Sales breakdown',
                                  children: [
                                    _ReportRow(
                                      label: 'Gross Sales',
                                      value: report.grossSales,
                                      isPositive: true,
                                    ),
                                    _ReportRow(
                                      label: 'Refunds',
                                      value: report.refunds,
                                      isNegative: true,
                                    ),
                                    _ReportRow(
                                      label: 'Voids',
                                      value: report.voids,
                                      isNegative: true,
                                    ),
                                    const Divider(height: DesignTokens.spaceLg),
                                    _ReportRow(
                                      label: 'Net Sales',
                                      value: report.netSales,
                                      isBold: true,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: DesignTokens.spaceMd),
                                _ReportSection(
                                  title: 'Operating expenses',
                                  children: opExpenseChildren,
                                ),
                              ],
                            );
                          },
                          loading: () => const _ReportLoading(),
                          error: (e, _) => _ReportError(error: e),
                        );
                      },
                      loading: () => const _ReportLoading(),
                      error: (e, _) => _ReportError(error: e),
                    ),
                    loading: () => const _ReportLoading(),
                    error: (e, _) => _ReportError(error: e),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _FinancialReport _computeReport(
    List<LedgerEntry> entries,
    List<CashMovement> movements,
    List<Expense> expenses,
    DateTimeRange? range,
  ) {
    final filteredEntries = range == null
        ? entries
        : entries
            .where(
              (e) =>
                  !e.createdAt.isBefore(range.start) &&
                  e.createdAt.isBefore(range.end),
            )
            .toList();

    final filteredMovements = range == null
        ? movements
        : movements
            .where(
              (m) =>
                  !m.createdAt.isBefore(range.start) &&
                  m.createdAt.isBefore(range.end),
            )
            .toList();

    final filteredExpenses = range == null
        ? expenses
        : expenses
            .where(
              (e) =>
                  !e.occurredAt.isBefore(range.start) &&
                  e.occurredAt.isBefore(range.end),
            )
            .toList();

    double grossSales = 0;
    double refunds = 0;
    double voids = 0;
    int salesCount = 0;
    int refundCount = 0;
    int voidCount = 0;

    for (final e in filteredEntries) {
      if (e.type == 'sale') {
        grossSales += e.total;
        salesCount++;
      } else if (e.type == 'refund') {
        refunds += e.total;
        refundCount++;
      } else if (e.type == 'void') {
        voids += e.total;
        voidCount++;
      }
    }

    double recordedExpenses = 0;
    for (final e in filteredExpenses) {
      recordedExpenses += e.amount;
    }

    double legacyCashouts = 0;
    for (final m in filteredMovements) {
      if (m.type != 'withdrawal') continue;
      final linked = (m.linkedExpenseId ?? '').trim();
      if (linked.isNotEmpty) continue;

      final tag = _extractTag(m.note);
      if (tag == 'owner') continue;
      legacyCashouts += m.amount;
    }

    return _FinancialReport(
      grossSales: grossSales,
      refunds: refunds,
      voids: voids,
      recordedExpenses: recordedExpenses,
      legacyCashouts: legacyCashouts,
      salesCount: salesCount,
      refundCount: refundCount,
      voidCount: voidCount,
    );
  }

  Future<void> _exportPdf(WidgetRef ref, BuildContext context) async {
    final dateRange = ref.read(_dateRangeProvider);
    final entries = ref.read(ledgerEntriesStreamProvider).asData?.value ?? [];
    final movements = ref.read(cashMovementsStreamProvider).asData?.value ?? [];
    final expenses = ref.read(expensesStreamProvider).asData?.value ?? [];
    final report = _computeReport(entries, movements, expenses, dateRange);

    // Get outlet/business info for header
    final db = ref.read(appDatabaseProvider);
    final outlet = await db.getPrimaryOutlet();
    final shopName = outlet?.name ?? 'My Business';
    final shopAddress = outlet?.address ?? '';
    final shopPhone = outlet?.phone ?? '';

    // Get product sales breakdown
    final filteredEntries = dateRange == null
        ? entries.where((e) => e.type == 'sale').toList()
        : entries.where((e) =>
            e.type == 'sale' &&
            !e.createdAt.isBefore(dateRange.start) &&
            e.createdAt.isBefore(dateRange.end)).toList();
    
    // Fetch ledger lines for product and service breakdown
    final productSales = <String, _ProductSale>{};
    final serviceSales = <String, _ProductSale>{};
    for (final entry in filteredEntries) {
      final bundle = await db.fetchLedgerEntryBundle(entry.id);
      if (bundle == null) continue;
      for (final line in bundle.lines) {
        final key = '${line.title}${line.variant != null ? " (${line.variant})" : ""}';
        final isService = (line.serviceId ?? '').trim().isNotEmpty;
        final target = isService ? serviceSales : productSales;
        if (!target.containsKey(key)) {
          target[key] = _ProductSale(name: key, quantity: 0, revenue: 0);
        }
        target[key] = _ProductSale(
          name: key,
          quantity: target[key]!.quantity + line.quantity,
          revenue: target[key]!.revenue + line.lineTotal,
        );
      }
    }
    final topProducts = productSales.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final topServices = serviceSales.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (ctx) => [
          // Company Header
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#1E3A5F'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(shopName, style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                )),
                if (shopAddress.isNotEmpty) pw.SizedBox(height: 4),
                if (shopAddress.isNotEmpty) pw.Text(shopAddress, style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.white,
                )),
                if (shopPhone.isNotEmpty) pw.Text('Tel: $shopPhone', style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.white,
                )),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Report Title & Date Range
          pw.Text('Profit & Loss Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            dateRange == null
                ? 'All time'
                : '${dateRange.start.toLocal().toString().split(' ')[0]} to ${dateRange.end.toLocal().toString().split(' ')[0]}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 24),

          // Sales Breakdown
          _pdfRow('Gross Sales', report.grossSales),
          _pdfRow('Refunds', -report.refunds),
          _pdfRow('Voids', -report.voids),
          pw.Divider(),
          _pdfRow('Net Sales', report.netSales, isBold: true),
          pw.SizedBox(height: 12),
          _pdfRow('Recorded Expenses', -report.recordedExpenses),
          if (report.legacyCashouts > 0) _pdfRow('Legacy Cashouts (unlinked)', -report.legacyCashouts),
          pw.Divider(),
          _pdfRow('Operating Expenses', -report.expenses, isBold: true),
          pw.SizedBox(height: 12),
          pw.Divider(),
          _pdfRow('NET PROFIT', report.netProfit, isBold: true, fontSize: 18),
          pw.SizedBox(height: 40),

          // Operational Stats
          pw.Text('Operational Stats', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          _pdfRow('Sales Transactions', report.salesCount.toDouble()),
          _pdfRow('Refund Transactions', report.refundCount.toDouble()),
          _pdfRow('Void Transactions', report.voidCount.toDouble()),
          pw.SizedBox(height: 40),

          // Top Products Sold
          if (topProducts.isNotEmpty) ...[
            pw.Text('Top Products Sold', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
              },
              headers: ['Product', 'Qty', 'Revenue (UGX)'],
              data: topProducts.take(15).map((p) => [
                p.name,
                p.quantity.toString(),
                p.revenue.toStringAsFixed(0),
              ]).toList(),
            ),
          ],
          pw.SizedBox(height: 24),

          // Top Services Sold
          if (topServices.isNotEmpty) ...[
            pw.Text('Top Services Sold', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
              },
              headers: ['Service (Variant)', 'Qty', 'Revenue (UGX)'],
              data: topServices.take(15).map((s) => [
                s.name,
                s.quantity.toString(),
                s.revenue.toStringAsFixed(0),
              ]).toList(),
            ),
          ],
          pw.SizedBox(height: 40),

          // Footer
          pw.Container(
            width: double.infinity,
            child: pw.Text(
              'Generated on ${DateTime.now().toLocal().toString().split('.')[0]} • Soko POS',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'soko-pl-report.pdf');
  }

  pw.Widget _pdfRow(String label, double value, {bool isBold = false, double fontSize = 12}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text('UGX ${value.toStringAsFixed(0)}',
              style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  String? _extractTag(String? note) {
    if (note == null) return null;
    final trimmed = note.trimLeft();
    if (!trimmed.startsWith('[')) return null;
    final end = trimmed.indexOf(']');
    if (end <= 1) return null;
    return trimmed.substring(1, end).trim().toLowerCase();
  }
}

class _FinancialReport {
  _FinancialReport({
    required this.grossSales,
    required this.refunds,
    required this.voids,
    required this.recordedExpenses,
    required this.legacyCashouts,
    required this.salesCount,
    required this.refundCount,
    required this.voidCount,
  });

  final double grossSales;
  final double refunds;
  final double voids;
  final double recordedExpenses;
  final double legacyCashouts;
  final int salesCount;
  final int refundCount;
  final int voidCount;

  double get netSales => grossSales - refunds - voids;
  double get expenses => recordedExpenses + legacyCashouts;
  double get netProfit => netSales - expenses;
}

class _ProductSale {
  _ProductSale({required this.name, required this.quantity, required this.revenue});
  final String name;
  final int quantity;
  final double revenue;
}

class _DateFilterBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(_dateRangeProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMd, vertical: DesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 18, color: DesignTokens.grayMedium),
          const SizedBox(width: DesignTokens.spaceSm),
          Expanded(
            child: Text(
              range == null
                  ? 'All time'
                  : '${range.start.day}/${range.start.month} - ${range.end.day}/${range.end.month}',
              style: DesignTokens.textBodyBold,
            ),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2023),
                lastDate: DateTime.now().add(const Duration(days: 1)),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: DesignTokens.brandPrimary,
                      onPrimary: Colors.white,
                      onSurface: DesignTokens.grayDark,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                ref.read(_dateRangeProvider.notifier).state = picked;
              }
            },
            child: const Text('Change'),
          ),
          if (range != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => ref.read(_dateRangeProvider.notifier).state = null,
            ),
        ],
      ),
    );
  }
}

class _NetProfitCard extends StatelessWidget {
  const _NetProfitCard({required this.report});
  final _FinancialReport report;

  @override
  Widget build(BuildContext context) {
    final isNegative = report.netProfit < 0;
    return Container(
      width: double.infinity,
      padding: DesignTokens.paddingLg,
      decoration: BoxDecoration(
        gradient: DesignTokens.brandGradient,
        borderRadius: DesignTokens.borderRadiusLg,
        boxShadow: DesignTokens.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NET PROFIT', style: DesignTokens.textSmallLight.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(
            'UGX ${report.netProfit.toStringAsFixed(0)}',
            style: DesignTokens.textTitleLight.copyWith(fontSize: 28),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isNegative ? 'Loss position' : 'Profitable',
              style: DesignTokens.textSmallLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.report});
  final _FinancialReport report;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatItem(label: 'Transactions', value: report.salesCount.toString(), icon: Icons.receipt_long_outlined),
        const SizedBox(width: DesignTokens.spaceMd),
        _StatItem(label: 'Refunds', value: report.refundCount.toString(), icon: Icons.assignment_return_outlined),
        const SizedBox(width: DesignTokens.spaceMd),
        _StatItem(label: 'Voids', value: report.voidCount.toString(), icon: Icons.block_outlined),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: DesignTokens.paddingMd,
        decoration: BoxDecoration(
          color: DesignTokens.surfaceWhite,
          borderRadius: DesignTokens.borderRadiusMd,
          boxShadow: DesignTokens.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: DesignTokens.brandAccent),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(value, style: DesignTokens.textBodyBold),
            Text(label, style: DesignTokens.textSmall),
          ],
        ),
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title.toUpperCase(), style: DesignTokens.textSmallBold.copyWith(letterSpacing: 1.1)),
        ),
        Container(
          padding: DesignTokens.paddingMd,
          decoration: BoxDecoration(
            color: DesignTokens.surfaceWhite,
            borderRadius: DesignTokens.borderRadiusMd,
            boxShadow: DesignTokens.shadowSm,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.label,
    required this.value,
    this.isPositive = false,
    this.isNegative = false,
    this.isBold = false,
  });

  final String label;
  final double value;
  final bool isPositive;
  final bool isNegative;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    Color valColor = DesignTokens.grayDark;
    if (isPositive) valColor = DesignTokens.brandAccent;
    if (isNegative) valColor = DesignTokens.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: isBold ? DesignTokens.textBodyBold : DesignTokens.textBody),
          Text(
            'UGX ${value.toStringAsFixed(0)}',
            style: (isBold ? DesignTokens.textBodyBold : DesignTokens.textBody).copyWith(color: valColor),
          ),
        ],
      ),
    );
  }
}

class _ReportLoading extends StatelessWidget {
  const _ReportLoading();
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class _ReportError extends StatelessWidget {
  const _ReportError({required this.error});
  final Object error;
  @override
  Widget build(BuildContext context) => Center(child: Text('Error: $error'));
}

final _dateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);
