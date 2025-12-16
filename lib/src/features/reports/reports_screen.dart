import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../transactions/transactions_screen.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateRange = ref.watch(_dateRangeProvider);
    final entries = ref.watch(ledgerEntriesStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: entries.when(
        data: (list) {
          final filtered = dateRange == null
              ? list
              : list.where((e) {
                  final d = e.createdAt;
                  return d.isAfter(dateRange.start) && d.isBefore(dateRange.end);
                }).toList();
          final net = filtered.fold<double>(0, (p, e) => p + _signedTotal(e));
          final salesCount = filtered.where((e) => e.type == 'sale').length;
          final refundCount = filtered.where((e) => e.type == 'refund').length;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (picked != null && context.mounted) {
                          ref.read(_dateRangeProvider.notifier).state = picked;
                        }
                      },
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        dateRange == null
                            ? 'All dates'
                            : '${dateRange.start.toLocal()} - ${dateRange.end.toLocal()}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Export PDF',
                      icon: const Icon(Icons.picture_as_pdf),
                      onPressed: filtered.isEmpty
                          ? null
                          : () => _exportPdf(filtered, context),
                    ),
                  ],
                ),
                _Metric(label: 'Net sales', value: net),
                _Metric(label: 'Sales', value: salesCount.toDouble()),
                _Metric(label: 'Refunds', value: refundCount.toDouble()),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _exportPdf(List<LedgerEntry> entries, BuildContext context) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Sales Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            ...entries.map(
              (t) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(t.createdAt.toLocal().toString()),
                  pw.Text('UGX ${_signedTotal(t).toStringAsFixed(0)}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'soko24-report.pdf');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report exported')));
    }
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value >= 1000 ? value.toStringAsFixed(0) : value.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

final _dateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

double _signedTotal(LedgerEntry entry) {
  if (entry.type == 'refund') return -entry.total;
  return entry.total;
}
