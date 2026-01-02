import 'dart:typed_data';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/db/app_database.dart';
import '../../core/settings/shop_payment_settings.dart';

class ReceiptService {
  ReceiptService(this.db, {required this.prefs});
  final AppDatabase db;
  final SharedPreferences prefs;

  // Date formatters
  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _timeFormat = DateFormat('HH:mm');
  
  // Colors
  static const _primaryColor = PdfColor.fromInt(0xFF1A1A2E);
  static const _accentColor = PdfColor.fromInt(0xFF00A884);
  static const _grayLight = PdfColor.fromInt(0xFFF5F5F5);
  static const _grayMedium = PdfColor.fromInt(0xFF666666);

  Future<Uint8List> buildPdf(LedgerEntryBundle bundle) async {
    final doc = pw.Document();
    final entry = bundle.entry;
    final outlet = await _resolveOutlet(entry.outletId);
    final template = await _resolveTemplate();
    final headerText = _cleanText(template?.headerText);
    final footerText = _cleanText(template?.footerText);
    
    // Format data
    final isRefund = entry.type == 'refund';
    final isVoid = entry.type == 'void';
    final isReversal = isRefund || isVoid;
    final sign = isReversal ? '-' : '';
    final voidForSale = entry.type == 'sale' ? await db.findVoidForSale(entry.id) : null;
    final isVoided = isVoid || voidForSale != null;
    final receiptNo = _formatReceiptNumber(entry.receiptNumber);
    final dateStr = _dateFormat.format(entry.createdAt.toLocal());
    final timeStr = _timeFormat.format(entry.createdAt.toLocal());

    final paymentSettings = ShopPaymentSettingsCache.read(prefs);
    final paymentInstructions = paymentSettings.paymentInstructionsText();
    final showPaymentInstructions =
        !isReversal &&
        voidForSale == null &&
        paymentInstructions != null &&
        bundle.payments.any((p) {
          final method = p.method.toLowerCase();
          return method == 'mobile_money' ||
              method == 'bank_transfer' ||
              method == 'credit';
        });
    
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(16),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ============ HEADER ============
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 12),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: _accentColor, width: 2)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      outlet?.name.toUpperCase() ?? 'SOKO 24',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: _primaryColor,
                        letterSpacing: 1.5,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    if (outlet?.address?.trim().isNotEmpty ?? false)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Text(
                          outlet!.address!.trim(),
                          style: const pw.TextStyle(fontSize: 10, color: _grayMedium),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    if (outlet?.phone?.trim().isNotEmpty ?? false)
                      pw.Text(
                        'Tel: ${outlet!.phone!.trim()}',
                        style: const pw.TextStyle(fontSize: 10, color: _grayMedium),
                        textAlign: pw.TextAlign.center,
                      ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 12),

              if (isVoided) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.red, width: 2),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Text(
                        'VOIDED',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                          letterSpacing: 2,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      if (isVoid && entry.originalEntryId?.trim().isNotEmpty == true) ...[
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'Original: ${entry.originalEntryId}',
                          style: const pw.TextStyle(fontSize: 9, color: _grayMedium),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                      if (voidForSale != null) ...[
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'Void entry: ${voidForSale.id}',
                          style: const pw.TextStyle(fontSize: 9, color: _grayMedium),
                          textAlign: pw.TextAlign.center,
                        ),
                        if (voidForSale.note?.trim().isNotEmpty == true)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 4),
                            child: pw.Text(
                              voidForSale.note!.trim(),
                              style: const pw.TextStyle(fontSize: 8, color: _grayMedium),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
              ],
              
              // ============ RECEIPT INFO BOX ============
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: _grayLight,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Receipt #', style: const pw.TextStyle(fontSize: 10, color: _grayMedium)),
                        pw.Text(receiptNo, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Date', style: const pw.TextStyle(fontSize: 10, color: _grayMedium)),
                        pw.Text('$dateStr | $timeStr', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    if (isRefund) ...[
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(0xFFFFEBEE),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'REFUND',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFFD32F2F),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // ============ HEADER MESSAGE ============
              if (headerText != null) ...[
                pw.SizedBox(height: 10),
                pw.Text(
                  headerText,
                  style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: _grayMedium),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              
              pw.SizedBox(height: 16),
              
              // ============ ITEMS TABLE ============
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: _grayLight),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Item', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Qty', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Amount', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  // Item rows
                  ...bundle.lines.map((l) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(l.title, style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${l.quantity}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('$sign${_formatAmount(l.lineTotal)}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  )),
                ],
              ),
              
              pw.SizedBox(height: 8),
              
              // ============ TOTAL ============
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: _primaryColor,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text(
                      'UGX $sign${_formatAmount(entry.total)}',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    ),
                  ],
                ),
              ),
              
              // ============ PAYMENTS ============
              if (bundle.payments.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Text('Payment Details', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _grayMedium)),
                pw.SizedBox(height: 4),
                ...bundle.payments.map((p) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(_capitalize(p.method), style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('UGX ${_formatAmount(p.amount)}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                )),
              ],

              if (showPaymentInstructions) ...[
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: _grayLight,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    paymentInstructions,
                    style: const pw.TextStyle(fontSize: 9, color: _grayMedium),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
              
              pw.SizedBox(height: 16),
              
              // ============ FOOTER ============
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              
              if (footerText != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(
                    footerText,
                    style: const pw.TextStyle(fontSize: 9, color: _grayMedium),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              
              pw.Text(
                'Thank you for your business!',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Powered by Soko 24 | soko.sanaa.ug',
                style: const pw.TextStyle(fontSize: 8, color: _grayMedium),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  /// Format receipt number as 000-XXX (e.g., 000-001, 000-010, 000-100)
  String _formatReceiptNumber(int? number) {
    if (number == null || number <= 0) {
      return '000-001'; // Default for legacy entries
    }
    // Format: 000-XXX (3-digit prefix, 3-digit number, expands if needed)
    final numStr = number.toString().padLeft(3, '0');
    return '000-$numStr';
  }

  /// Format amount with thousand separators
  String _formatAmount(double amount) {
    return NumberFormat('#,###').format(amount.round());
  }

  /// Capitalize first letter
  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
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
    final outlet = await _resolveOutlet(bundle.entry.outletId);
    final template = await _resolveTemplate();
    final voidForSale =
        bundle.entry.type == 'sale' ? await db.findVoidForSale(bundle.entry.id) : null;
    final text = _buildReceiptText(
      bundle,
      customer: customer,
      outlet: outlet,
      template: template,
      voidForSale: voidForSale,
    );

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

  Future<void> printBluetooth(
    String entryId, {
    BluetoothDevice? device,
    bool compatibilityMode = false,
  }) async {
    final bundle = await _fetchEntry(entryId);
    if (bundle == null) {
      throw StateError('Receipt not found: $entryId');
    }
    await printBluetoothBundle(
      bundle,
      device: device,
      compatibilityMode: compatibilityMode,
    );
  }

  Future<void> printBluetoothBundle(
    LedgerEntryBundle bundle, {
    BluetoothDevice? device,
    bool compatibilityMode = false,
  }) async {
    final printer = BlueThermalPrinter.instance;
    final isConnected = await printer.isConnected ?? false;
    final outlet = await _resolveOutlet(bundle.entry.outletId);
    final template = await _resolveTemplate();
    final headerText = _cleanText(template?.headerText);
    final footerText = _cleanText(template?.footerText);

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
    final isVoid = entry.type == 'void';
    final isReversal = isRefund || isVoid;
    final sign = isReversal ? '-' : '';
    final voidForSale = entry.type == 'sale' ? await db.findVoidForSale(entry.id) : null;
    final isVoided = isVoid || voidForSale != null;
    final paymentSettings = ShopPaymentSettingsCache.read(prefs);
    final paymentInstructions = paymentSettings.paymentInstructionsText();
    final showPaymentInstructions =
        !isReversal &&
        voidForSale == null &&
        paymentInstructions != null &&
        bundle.payments.any((p) {
          final method = p.method.toLowerCase();
          return method == 'mobile_money' ||
              method == 'bank_transfer' ||
              method == 'credit';
        });
    printer.printCustom(outlet?.name ?? 'Soko 24', 2, 1);
    if (outlet != null && (outlet.address?.trim().isNotEmpty ?? false)) {
      printer.printCustom(outlet.address!.trim(), 1, 1);
    }
    if (outlet != null && (outlet.phone?.trim().isNotEmpty ?? false)) {
      printer.printCustom(outlet.phone!.trim(), 1, 1);
    }
    printer.printNewLine();
    printer.printCustom('Type: ${entry.type.toUpperCase()}', 1, 1);
    printer.printCustom('Receipt: ${entry.id}', 1, 1);
    if (isVoided) {
      printer.printCustom('*** VOIDED ***', 2, 1);
      if (isVoid && entry.originalEntryId?.trim().isNotEmpty == true) {
        printer.printCustom('Original: ${entry.originalEntryId}', 1, 1);
      }
      if (voidForSale != null) {
        printer.printCustom('Void entry: ${voidForSale.id}', 1, 1);
      }
    }
    if (headerText != null) {
      printer.printNewLine();
      printer.printCustom(headerText, 1, 1);
    }
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
    if (showPaymentInstructions) {
      printer.printNewLine();
      printer.printCustom(paymentInstructions, 1, 1);
    }
    printer.printNewLine();
    if (!compatibilityMode && (template?.showQr ?? true)) {
      printer.printQRcode(entry.id, 200, 200, 1);
    }
    if (footerText != null) {
      printer.printNewLine();
      printer.printCustom(footerText, 1, 1);
    }
    printer.printCustom('Powered by Soko 24', 1, 1);
    if (!compatibilityMode) {
      printer.paperCut();
    }
  }

  Future<LedgerEntryBundle?> _fetchEntry(String id) async {
    return db.fetchLedgerEntryBundle(id);
  }

  String _buildReceiptText(
    LedgerEntryBundle bundle, {
    Customer? customer,
    Outlet? outlet,
    ReceiptTemplate? template,
    LedgerEntry? voidForSale,
  }) {
    final entry = bundle.entry;
    final isRefund = entry.type == 'refund';
    final isVoid = entry.type == 'void';
    final isReversal = isRefund || isVoid;
    final sign = isReversal ? '-' : '';
    final headerText = _cleanText(template?.headerText);
    final footerText = _cleanText(template?.footerText);
    
    final sb = StringBuffer();
    sb.writeln(outlet?.name ?? 'Soko 24');
    if (outlet != null && (outlet.address?.trim().isNotEmpty ?? false)) {
      sb.writeln(outlet.address!.trim());
    }
    if (outlet != null && (outlet.phone?.trim().isNotEmpty ?? false)) {
      sb.writeln(outlet.phone!.trim());
    }
    
    // Template header message
    if (headerText != null) {
      sb.writeln('');
      sb.writeln(headerText);
    }
    
    sb.writeln('');
    sb.writeln('Receipt');
    sb.writeln('Type: ${entry.type.toUpperCase()}');
    if (isVoid || voidForSale != null) {
      sb.writeln('STATUS: VOIDED');
    }
    if (isVoid && entry.originalEntryId?.trim().isNotEmpty == true) {
      sb.writeln('Original: ${entry.originalEntryId}');
    }
    if (voidForSale != null) {
      sb.writeln('Void entry: ${voidForSale.id}');
      if (voidForSale.note?.trim().isNotEmpty == true) {
        sb.writeln('Void note: ${voidForSale.note}');
      }
    }
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

    final paymentSettings = ShopPaymentSettingsCache.read(prefs);
    final paymentInstructions = paymentSettings.paymentInstructionsText();
    final showPaymentInstructions =
        !isReversal &&
        voidForSale == null &&
        paymentInstructions != null &&
        bundle.payments.any((p) {
          final method = p.method.toLowerCase();
          return method == 'mobile_money' ||
              method == 'bank_transfer' ||
              method == 'credit';
        });
    if (showPaymentInstructions) {
      sb.writeln('');
      sb.writeln(paymentInstructions);
    }
    
    // Template footer message
    if (footerText != null) {
      sb.writeln('');
      sb.writeln(footerText);
    }
    
    sb.writeln('');
    sb.writeln('Thank you!');
    sb.writeln('Powered by Soko 24');
    return sb.toString();
  }

  Future<Outlet?> _resolveOutlet(String? outletId) async {
    if (outletId != null && outletId.trim().isNotEmpty) {
      final outlet = await db.getOutletById(outletId);
      if (outlet != null) return outlet;
    }
    return db.getPrimaryOutlet();
  }

  Future<ReceiptTemplate?> _resolveTemplate() {
    return db.getLatestReceiptTemplate();
  }

  String? _cleanText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
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
