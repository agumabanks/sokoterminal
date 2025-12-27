import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/db/app_database.dart';
import '../../core/settings/shop_payment_settings.dart';

class InvoiceService {
  InvoiceService(this.db, {required this.prefs});
  final AppDatabase db;
  final SharedPreferences prefs;

  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _timeFormat = DateFormat('HH:mm');
  static final _moneyFormat = NumberFormat('#,###');

  Future<void> sharePosInvoicePdf(String entryId) async {
    final bundle = await db.fetchLedgerEntryBundle(entryId);
    if (bundle == null) return;
    final pdf = await buildPosInvoicePdf(bundle);
    final fileId = bundle.entry.receiptNumber?.toString() ?? bundle.entry.id;
    await Printing.sharePdf(bytes: pdf, filename: 'invoice-$fileId.pdf');
  }

  Future<void> shareOrderInvoicePdf(Map<String, dynamic> order) async {
    final pdf = await buildOrderInvoicePdf(order);
    final fileId =
        (order['code'] ?? order['order_code'] ?? order['id'] ?? 'order').toString().trim().isEmpty
            ? 'order'
            : (order['code'] ?? order['order_code'] ?? order['id']).toString();
    await Printing.sharePdf(bytes: pdf, filename: 'invoice-$fileId.pdf');
  }

  Future<Uint8List> buildPosInvoicePdf(LedgerEntryBundle bundle) async {
    final doc = pw.Document();
    final entry = bundle.entry;
    final outlet = await _resolveOutlet(entry.outletId);
    final template = await db.getLatestReceiptTemplate();
    final customer = entry.customerId == null
        ? null
        : await db.getCustomerById(entry.customerId!);

    final headerText = _cleanText(template?.headerText);
    final footerText = _cleanText(template?.footerText);

    final isRefund = entry.type == 'refund';
    final title = isRefund ? 'CREDIT NOTE' : 'INVOICE';
    final sign = isRefund ? '-' : '';

    final receiptNo = _formatReceiptNumber(entry.receiptNumber);
    final dateStr = _dateFormat.format(entry.createdAt.toLocal());
    final timeStr = _timeFormat.format(entry.createdAt.toLocal());

    final paymentSettings = ShopPaymentSettingsCache.read(prefs);
    final paymentInstructions = paymentSettings.paymentInstructionsText();
    final showPaymentInstructions =
        !isRefund &&
        paymentInstructions != null &&
        bundle.payments.any((p) {
          final method = p.method.toLowerCase();
          return method == 'mobile_money' ||
              method == 'bank_transfer' ||
              method == 'credit';
        });

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 36, 32, 36),
        build: (context) {
          return [
            _buildHeader(outlet, title: title),
            if (headerText != null) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                headerText,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey700,
                ),
              ),
            ],
            pw.SizedBox(height: 18),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _infoBox(
                    title: 'Invoice',
                    rows: [
                      _infoRow('Number', receiptNo),
                      _infoRow('Date', '$dateStr • $timeStr'),
                      _infoRow('Type', entry.type.toUpperCase()),
                      if (entry.originalEntryId != null &&
                          entry.originalEntryId!.trim().isNotEmpty)
                        _infoRow('Original', entry.originalEntryId!.trim()),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _infoBox(
                    title: 'Customer',
                    rows: [
                      _infoRow(
                        'Name',
                        customer?.name.trim().isNotEmpty == true
                            ? customer!.name.trim()
                            : 'Walk-in',
                      ),
                      if (customer?.phone != null &&
                          customer!.phone!.trim().isNotEmpty)
                        _infoRow('Phone', customer.phone!.trim()),
                      if (customer?.email != null &&
                          customer!.email!.trim().isNotEmpty)
                        _infoRow('Email', customer.email!.trim()),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            _buildItemsTable(
              bundle.lines
                  .map(
                    (l) => _InvoiceLine(
                      title: l.title,
                      quantity: l.quantity,
                      unitPrice: l.unitPrice,
                      lineTotal: l.lineTotal,
                    ),
                  )
                  .toList(),
              sign: sign,
            ),
            pw.SizedBox(height: 14),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: _totalsBox(
                rows: [
                  _totalRow('Subtotal', '$sign${_formatMoney(entry.subtotal)}'),
                  if (entry.discount.abs() > 0.01)
                    _totalRow('Discount', '$sign${_formatMoney(entry.discount)}'),
                  if (entry.tax.abs() > 0.01) _totalRow('Tax', '$sign${_formatMoney(entry.tax)}'),
                  _totalRow(
                    'TOTAL',
                    'UGX $sign${_formatMoney(entry.total)}',
                    isStrong: true,
                  ),
                ],
              ),
            ),
            if (bundle.payments.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                'Payments',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Column(
                children: bundle.payments
                    .map(
                      (p) => pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            _capitalize(p.method),
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.Text(
                            'UGX ${_formatMoney(p.amount)}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ],
            if (showPaymentInstructions) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                'Payment Instructions',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  paymentInstructions,
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ),
            ],
            if (footerText != null) ...[
              pw.SizedBox(height: 18),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Text(
                footerText,
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
            pw.SizedBox(height: 18),
            pw.Text(
              'Powered by Soko 24',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              textAlign: pw.TextAlign.center,
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  Future<Uint8List> buildOrderInvoicePdf(Map<String, dynamic> order) async {
    final doc = pw.Document();
    final outlet = await db.getPrimaryOutlet();
    final template = await db.getLatestReceiptTemplate();
    final headerText = _cleanText(template?.headerText);
    final footerText = _cleanText(template?.footerText);

    final code = (order['code'] ?? order['order_code'] ?? order['id'] ?? '').toString();
    final createdAt = DateTime.tryParse((order['created_at'] ?? '').toString());
    final dateStr = createdAt != null ? _dateFormat.format(createdAt.toLocal()) : '-';
    final timeStr = createdAt != null ? _timeFormat.format(createdAt.toLocal()) : '-';

    final shipping = order['shipping_address'] is Map<String, dynamic>
        ? (order['shipping_address'] as Map<String, dynamic>)
        : <String, dynamic>{};

    final customerName =
        (order['customer_name'] ?? shipping['name'] ?? 'Customer').toString();
    final customerPhone =
        (order['customer_phone'] ?? shipping['phone'] ?? '').toString();
    final customerAddress =
        (shipping['address'] ?? shipping['city'] ?? '').toString();

    final paymentStatus = (order['payment_status'] ?? 'unpaid').toString();
    final deliveryStatus = (order['delivery_status'] ?? 'pending').toString();
    final paymentMethod = (order['payment_type'] ?? order['payment_method'] ?? '').toString();

    final paymentSettings = ShopPaymentSettingsCache.read(prefs);
    final paymentInstructions = paymentSettings.paymentInstructionsText();
    final showPaymentInstructions =
        paymentInstructions != null &&
        paymentStatus.toLowerCase() != 'paid';

    final itemsRaw =
        (order['order_items'] is List)
            ? (order['order_items'] as List)
            : (order['items'] is List ? (order['items'] as List) : const []);
    final items = itemsRaw
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .map((i) {
          final name = (i['product_name'] ?? i['name'] ?? 'Item').toString();
          final variation = (i['variation'] ?? '').toString().trim();
          final qty = int.tryParse((i['quantity'] ?? i['qty'] ?? '1').toString()) ?? 1;
          final unitPrice = _toDouble(i['unit_price']) ?? _toDouble(i['price']) ?? 0;
          final total = _toDouble(i['total']) ?? (unitPrice * qty);
          final title =
              variation.isEmpty ? name : '$name • $variation';
          return _InvoiceLine(title: title, quantity: qty, unitPrice: unitPrice, lineTotal: total);
        })
        .toList();

    final subtotal =
        _toDouble(order['subtotal_raw']) ?? _toDouble(order['sub_total']) ?? _toDouble(order['subtotal']);
    final shippingCost =
        _toDouble(order['shipping_cost_raw']) ?? _toDouble(order['shipping_cost']) ?? _toDouble(order['shipping']);
    final discount =
        _toDouble(order['coupon_discount_raw']) ?? _toDouble(order['coupon_discount']);
    final tax = _toDouble(order['tax_raw']) ?? _toDouble(order['tax']) ?? _toDouble(order['vat']);
    final grandTotal = _toDouble(order['grand_total']) ?? _toDouble(order['total']) ?? 0;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 36, 32, 36),
        build: (context) {
          return [
            _buildHeader(outlet, title: 'INVOICE'),
            if (headerText != null) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                headerText,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey700,
                ),
              ),
            ],
            pw.SizedBox(height: 18),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _infoBox(
                    title: 'Order',
                    rows: [
                      _infoRow('Order', code.isEmpty ? '-' : code),
                      _infoRow('Date', '$dateStr • $timeStr'),
                      _infoRow('Payment', paymentStatus.toUpperCase()),
                      _infoRow('Delivery', deliveryStatus.toUpperCase()),
                      if (paymentMethod.trim().isNotEmpty)
                        _infoRow('Method', paymentMethod),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _infoBox(
                    title: 'Customer',
                    rows: [
                      _infoRow('Name', customerName),
                      if (customerPhone.trim().isNotEmpty)
                        _infoRow('Phone', customerPhone.trim()),
                      if (customerAddress.trim().isNotEmpty)
                        _infoRow('Address', customerAddress.trim()),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            _buildItemsTable(items),
            pw.SizedBox(height: 14),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: _totalsBox(
                rows: [
                  if (subtotal != null) _totalRow('Subtotal', _formatMoney(subtotal)),
                  if (shippingCost != null)
                    _totalRow('Shipping', _formatMoney(shippingCost)),
                  if (discount != null && discount.abs() > 0.01)
                    _totalRow('Discount', '-${_formatMoney(discount)}'),
                  if (tax != null) _totalRow('Tax', _formatMoney(tax)),
                  _totalRow('TOTAL', 'UGX ${_formatMoney(grandTotal)}', isStrong: true),
                ],
              ),
            ),
            if (showPaymentInstructions) ...[
              pw.SizedBox(height: 18),
              pw.Text(
                'Payment Instructions',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  paymentInstructions,
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ),
            ],
            if (footerText != null) ...[
              pw.SizedBox(height: 18),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Text(
                footerText,
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
            pw.SizedBox(height: 18),
            pw.Text(
              'Powered by Soko 24',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              textAlign: pw.TextAlign.center,
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _buildHeader(Outlet? outlet, {required String title}) {
    final name = outlet?.name.trim().isNotEmpty == true
        ? outlet!.name.trim()
        : 'Soko 24';
    final address = outlet?.address?.trim();
    final phone = outlet?.phone?.trim();

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                name,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              if (address != null && address.isNotEmpty)
                pw.Text(address, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              if (phone != null && phone.isNotEmpty)
                pw.Text('Tel: $phone', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: PdfColors.black,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildItemsTable(List<_InvoiceLine> lines, {String sign = ''}) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell('Item', isHeader: true),
            _cell('Qty', isHeader: true, align: pw.TextAlign.center),
            _cell('Unit', isHeader: true, align: pw.TextAlign.right),
            _cell('Total', isHeader: true, align: pw.TextAlign.right),
          ],
        ),
        ...lines.map(
          (l) => pw.TableRow(
              children: [
                _cell(l.title),
                _cell('${l.quantity}', align: pw.TextAlign.center),
              _cell('$sign${_formatMoney(l.unitPrice)}', align: pw.TextAlign.right),
              _cell('$sign${_formatMoney(l.lineTotal)}', align: pw.TextAlign.right),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _infoBox({
    required String title,
    required List<pw.Widget> rows,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          ...rows,
        ],
      ),
    );
  }

  pw.Widget _totalsBox({required List<pw.Widget> rows}) {
    return pw.Container(
      width: 240,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.grey50,
      ),
      child: pw.Column(children: rows),
    );
  }

  pw.Widget _totalRow(String label, String value, {bool isStrong = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isStrong ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isStrong ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 58,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }

  pw.Widget _cell(String text, {bool isHeader = false, pw.TextAlign? align}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  Future<Outlet?> _resolveOutlet(String? outletId) async {
    if (outletId != null && outletId.trim().isNotEmpty) {
      final outlet = await db.getOutletById(outletId);
      if (outlet != null) return outlet;
    }
    return db.getPrimaryOutlet();
  }

  String _formatReceiptNumber(int? number) {
    if (number == null || number <= 0) return '000-001';
    final numStr = number.toString().padLeft(3, '0');
    return '000-$numStr';
  }

  String _formatMoney(double amount) {
    return _moneyFormat.format(amount.round());
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  String? _cleanText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return double.tryParse(value?.toString() ?? '');
  }
}

class _InvoiceLine {
  const _InvoiceLine({
    required this.title,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String title;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
}
