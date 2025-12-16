import 'dart:typed_data';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/db/app_database.dart';

class ReceiptService {
  ReceiptService(this.db);
  final AppDatabase db;

  Future<Uint8List> buildPdf(LedgerEntryBundle bundle) async {
    final doc = pw.Document();
    final entry = bundle.entry;
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) {
          final isRefund = entry.type == 'refund';
          final sign = isRefund ? '-' : '';
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Soko 24 Receipt', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Receipt: ${entry.id}'),
              pw.Text('Type: ${entry.type.toUpperCase()}'),
              pw.Text('Date: ${entry.createdAt.toLocal()}'),
              pw.SizedBox(height: 12),
              ...bundle.lines.map(
                (l) => pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${l.title} x${l.quantity}'),
                    pw.Text('UGX $sign${l.lineTotal.toStringAsFixed(0)}'),
                  ],
                ),
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('UGX $sign${entry.total.toStringAsFixed(0)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              if (bundle.payments.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text('Payment', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ...bundle.payments.map(
                  (p) => pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(p.method),
                      pw.Text('UGX ${p.amount.toStringAsFixed(0)}'),
                    ],
                  ),
                ),
              ],
              pw.SizedBox(height: 8),
              pw.Text('Thank you for your business!'),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  Future<void> sharePdf(String entryId) async {
    try {
      final data = await _fetchEntry(entryId);
      if (data == null) return;
      final pdfData = await buildPdf(data);
      await Printing.sharePdf(bytes: pdfData, filename: 'receipt-$entryId.pdf');
    } catch (_) {}
  }

  Future<void> printBluetooth(String entryId) async {
    try {
      final bundle = await _fetchEntry(entryId);
      if (bundle == null) return;
      final printer = BlueThermalPrinter.instance;
      final isConnected = await printer.isConnected ?? false;
      if (!isConnected) {
        final devices = await printer.getBondedDevices();
        if (devices.isEmpty) return;
        await printer.connect(devices.first);
      }
      final entry = bundle.entry;
      final isRefund = entry.type == 'refund';
      final sign = isRefund ? '-' : '';
      printer.printCustom('Soko 24 Receipt', 2, 1);
      printer.printNewLine();
      printer.printCustom('Type: ${entry.type.toUpperCase()}', 1, 1);
      printer.printCustom('Receipt: ${entry.id}', 1, 1);
      printer.printNewLine();
      for (final line in bundle.lines) {
        printer.printLeftRight('${line.title} x${line.quantity}',
            'UGX $sign${line.lineTotal.toStringAsFixed(0)}', 1);
      }
      printer.printLeftRight('TOTAL', 'UGX $sign${entry.total.toStringAsFixed(0)}', 2);
      if (bundle.payments.isNotEmpty) {
        printer.printNewLine();
        printer.printCustom('Payment', 1, 0);
        for (final p in bundle.payments) {
          printer.printLeftRight(p.method, 'UGX ${p.amount.toStringAsFixed(0)}', 1);
        }
      }
      printer.printNewLine();
      printer.printQRcode(entry.id, 200, 200, 1);
      printer.paperCut();
    } catch (_) {}
  }

  Future<LedgerEntryBundle?> _fetchEntry(String id) async {
    return db.fetchLedgerEntryBundle(id);
  }
}
