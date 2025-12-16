import 'dart:typed_data';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
              pw.Text(
                'Soko 24 Receipt',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
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
                  pw.Text(
                    'Total',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'UGX $sign${entry.total.toStringAsFixed(0)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              if (bundle.payments.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text(
                  'Payment',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
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

  Future<void> shareWhatsapp(String entryId, {String? phone}) async {
    final bundle = await _fetchEntry(entryId);
    if (bundle == null) return;
    final customer = bundle.entry.customerId == null
        ? null
        : await db.getCustomerById(bundle.entry.customerId!);
    final text = _buildReceiptText(bundle, customer: customer);

    final sanitizedPhone = _sanitizePhone(phone ?? customer?.phone);
    final uri = Uri.parse(
      'https://wa.me/${sanitizedPhone ?? ''}?text=${Uri.encodeComponent(text)}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Share.share(text, subject: 'Receipt ${bundle.entry.id}');
      }
    } catch (_) {
      await Share.share(text, subject: 'Receipt ${bundle.entry.id}');
    }
  }

  Future<void> printBluetooth(String entryId, {BluetoothDevice? device}) async {
    final bundle = await _fetchEntry(entryId);
    if (bundle == null) {
      throw StateError('Receipt not found: $entryId');
    }
    await printBluetoothBundle(bundle, device: device);
  }

  Future<void> printBluetoothBundle(
    LedgerEntryBundle bundle, {
    BluetoothDevice? device,
  }) async {
    final printer = BlueThermalPrinter.instance;
    final isConnected = await printer.isConnected ?? false;

    if (!isConnected) {
      if (device == null) {
        final devices = await printer.getBondedDevices();
        if (devices.isEmpty) {
          throw StateError('No paired Bluetooth printers found.');
        }
        device = devices.first;
      }
      await printer.connect(device);
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
      printer.printLeftRight(
        '${line.title} x${line.quantity}',
        'UGX $sign${line.lineTotal.toStringAsFixed(0)}',
        1,
      );
    }
    printer.printLeftRight(
      'TOTAL',
      'UGX $sign${entry.total.toStringAsFixed(0)}',
      2,
    );
    if (bundle.payments.isNotEmpty) {
      printer.printNewLine();
      printer.printCustom('Payment', 1, 0);
      for (final p in bundle.payments) {
        printer.printLeftRight(
          p.method,
          'UGX ${p.amount.toStringAsFixed(0)}',
          1,
        );
      }
    }
    printer.printNewLine();
    printer.printQRcode(entry.id, 200, 200, 1);
    printer.paperCut();
  }

  Future<LedgerEntryBundle?> _fetchEntry(String id) async {
    return db.fetchLedgerEntryBundle(id);
  }

  String _buildReceiptText(LedgerEntryBundle bundle, {Customer? customer}) {
    final entry = bundle.entry;
    final isRefund = entry.type == 'refund';
    final sign = isRefund ? '-' : '';
    final sb = StringBuffer();
    sb.writeln('Soko24 Receipt');
    sb.writeln('Type: ${entry.type.toUpperCase()}');
    sb.writeln('Receipt: ${entry.id}');
    if (customer != null) {
      sb.writeln(
        'Customer: ${customer.name}${customer.phone != null ? ' (${customer.phone})' : ''}',
      );
    }
    sb.writeln('Date: ${entry.createdAt.toLocal()}');
    sb.writeln('-----');
    for (final line in bundle.lines) {
      sb.writeln(
        '${line.title} x${line.quantity} — UGX $sign${line.lineTotal.toStringAsFixed(0)}',
      );
    }
    sb.writeln('-----');
    sb.writeln('Total: UGX $sign${entry.total.toStringAsFixed(0)}');
    if (bundle.payments.isNotEmpty) {
      sb.writeln('Payments:');
      for (final p in bundle.payments) {
        sb.writeln(' - ${p.method}: UGX ${p.amount.toStringAsFixed(0)}');
      }
    }
    sb.writeln('Thank you!');
    return sb.toString();
  }

  String? _sanitizePhone(String? phone) {
    if (phone == null) return null;
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('0')) {
      // Assume country code 256 (Uganda) if missing.
      return '256${digits.substring(1)}';
    }
    return digits;
  }
}
