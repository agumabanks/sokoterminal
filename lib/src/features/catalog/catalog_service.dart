import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/db/app_database.dart';

class CatalogService {
  CatalogService(this.db);
  final AppDatabase db;

  static final _currencyFormat = NumberFormat('#,###');
  static const _primaryColor = PdfColor.fromInt(0xFF1A1A2E);
  static const _accentColor = PdfColor.fromInt(0xFF00A884);
  static const _grayLight = PdfColor.fromInt(0xFFF5F5F5);
  static const _grayMedium = PdfColor.fromInt(0xFF666666);

  Future<Uint8List> buildCatalogPdf({
    required List<Item> items,
    List<Service> services = const [],
    required String shopName,
    String? shopPhone,
    String? shopAddress,
    String? logoUrl,
    String? shopId,
  }) async {
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.nunitoRegular(),
        bold: await PdfGoogleFonts.nunitoBold(),
      ),
    );

    final shopLink = shopId != null ? 'https://soko24.co/shop/$shopId' : null;

    // Pre-download images (best effort, 2s timeout each)
    final imageCache = <String, pw.MemoryImage>{};
    final allUrls = <String>{};
    for (final item in items) {
      final url = item.thumbnailUrl ?? item.imageUrl;
      if (url != null && url.trim().isNotEmpty && url.startsWith('http')) {
        allUrls.add(url.trim());
      }
    }
    for (final svc in services) {
      if (svc.imageUrl != null && svc.imageUrl!.trim().isNotEmpty && svc.imageUrl!.startsWith('http')) {
        allUrls.add(svc.imageUrl!.trim());
      }
    }
    // Download up to 50 images concurrently
    final dio = Dio();
    final futures = allUrls.take(50).map((url) async {
      try {
        final response = await dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 3)),
        );
        final bytes = response.data;
        if (bytes != null && bytes.isNotEmpty) {
          imageCache[url] = pw.MemoryImage(Uint8List.fromList(bytes));
        }
      } catch (_) {}
    });
    await Future.wait(futures);
    dio.close();

    // Build catalog entries
    final allEntries = <_CatalogEntry>[];
    for (final item in items) {
      final url = item.thumbnailUrl ?? item.imageUrl;
      allEntries.add(_CatalogEntry(
        name: item.name,
        price: item.price,
        unit: item.unit,
        image: url != null ? imageCache[url.trim()] : null,
        isService: false,
        duration: null,
      ));
    }
    for (final svc in services) {
      allEntries.add(_CatalogEntry(
        name: svc.title,
        price: svc.price,
        unit: null,
        image: svc.imageUrl != null ? imageCache[svc.imageUrl!.trim()] : null,
        isService: true,
        duration: svc.durationMinutes,
      ));
    }

    final itemsPerPage = 6;
    final totalPages = (allEntries.length / itemsPerPage).ceil().clamp(1, 100);

    for (var page = 0; page < totalPages; page++) {
      final start = page * itemsPerPage;
      final end = (start + itemsPerPage).clamp(0, allEntries.length);
      final pageEntries = allEntries.sublist(start, end);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                if (page == 0) _buildHeader(shopName, shopPhone, shopAddress, shopLink),
                if (page == 0) pw.SizedBox(height: 16),
                pw.Expanded(
                  child: pw.GridView(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                    children: pageEntries.map((e) => _buildCard(e)).toList(),
                  ),
                ),
                pw.SizedBox(height: 8),
                _buildFooter(page + 1, totalPages, shopLink),
              ],
            );
          },
        ),
      );
    }

    return doc.save();
  }

  pw.Widget _buildHeader(String shopName, String? shopPhone, String? shopAddress, String? shopLink) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _primaryColor,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(shopName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          pw.SizedBox(height: 4),
          pw.Text('Product & Service Catalog', style: const pw.TextStyle(fontSize: 14, color: PdfColors.white)),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            if (shopPhone != null && shopPhone.isNotEmpty)
              pw.Text(shopPhone, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey300)),
            if (shopPhone != null && shopAddress != null)
              pw.Text('  |  ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey300)),
            if (shopAddress != null && shopAddress.isNotEmpty)
              pw.Expanded(child: pw.Text(shopAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey300))),
          ]),
          if (shopLink != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(shopLink, style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#00A884'))),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildCard(_CatalogEntry entry) {
    final priceStr = 'UGX ${_currencyFormat.format(entry.price.round())}';
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Container(
              width: double.infinity,
              decoration: pw.BoxDecoration(
                color: _grayLight,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              alignment: pw.Alignment.center,
              child: entry.image != null
                  ? pw.ClipRRect(
                      horizontalRadius: 4,
                      verticalRadius: 4,
                      child: pw.Image(entry.image!, fit: pw.BoxFit.cover, width: double.infinity),
                    )
                  : pw.Center(
                      child: pw.Text(
                        entry.isService ? 'SERVICE' : 'PRODUCT',
                        style: pw.TextStyle(fontSize: 10, color: _grayMedium, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
            ),
          ),
          pw.SizedBox(height: 6),
          if (entry.isService)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E8F5E9'), borderRadius: pw.BorderRadius.circular(2)),
              child: pw.Text('Service', style: pw.TextStyle(fontSize: 7, color: _accentColor, fontWeight: pw.FontWeight.bold)),
            ),
          pw.Text(entry.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold), maxLines: 2),
          pw.SizedBox(height: 2),
          pw.Text(priceStr, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _accentColor)),
          if (entry.unit != null && entry.unit!.isNotEmpty)
            pw.Text('per ${entry.unit}', style: const pw.TextStyle(fontSize: 8, color: _grayMedium)),
          if (entry.duration != null)
            pw.Text('${entry.duration} min', style: const pw.TextStyle(fontSize: 8, color: _grayMedium)),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(int current, int total, String? shopLink) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Generated by Soko24 Seller Terminal', style: const pw.TextStyle(fontSize: 8, color: _grayMedium)),
        pw.Text('Page $current of $total', style: const pw.TextStyle(fontSize: 8, color: _grayMedium)),
      ],
    );
  }

  Future<void> sharePdf({
    required List<Item> items,
    List<Service> services = const [],
    required String shopName,
    String? shopPhone,
    String? shopAddress,
    String? logoUrl,
    String? shopId,
  }) async {
    final bytes = await buildCatalogPdf(
      items: items,
      services: services,
      shopName: shopName,
      shopPhone: shopPhone,
      shopAddress: shopAddress,
      logoUrl: logoUrl,
      shopId: shopId,
    );
    await Printing.sharePdf(bytes: bytes, filename: '$shopName-catalog.pdf');
  }

  Future<void> shareWhatsApp({
    required List<Item> items,
    List<Service> services = const [],
    required String shopName,
    String? shopId,
    String? phone,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('*$shopName — Product Catalog*');
    buffer.writeln();
    if (items.isNotEmpty) {
      buffer.writeln('*Products:*');
      for (final item in items) {
        buffer.writeln('• ${item.name} — UGX ${_currencyFormat.format(item.price.round())}');
      }
    }
    if (services.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('*Services:*');
      for (final svc in services) {
        final dur = svc.durationMinutes != null ? ' (${svc.durationMinutes} min)' : '';
        buffer.writeln('• ${svc.title} — UGX ${_currencyFormat.format(svc.price.round())}$dur');
      }
    }
    if (shopId != null) {
      buffer.writeln();
      buffer.writeln('View full catalog: https://soko24.co/shop/$shopId');
    }
    buffer.writeln();
    buffer.writeln('Powered by Soko24');

    final text = buffer.toString();
    final uri = Uri.parse('https://wa.me/${phone ?? ''}?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Share.share(text, subject: '$shopName Catalog');
      }
    } catch (_) {
      await Share.share(text, subject: '$shopName Catalog');
    }
  }

  Future<void> openShopLink(String shopId) async {
    final uri = Uri.parse('https://soko24.co/shop/$shopId');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _CatalogEntry {
  final String name;
  final double price;
  final String? unit;
  final pw.MemoryImage? image;
  final bool isService;
  final int? duration;

  _CatalogEntry({
    required this.name,
    required this.price,
    this.unit,
    this.image,
    required this.isService,
    this.duration,
  });
}
