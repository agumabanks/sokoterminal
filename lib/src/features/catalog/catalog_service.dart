import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/db/app_database.dart';
import '../../core/media/offline_media_cache.dart';
import 'catalog_template.dart';

class CatalogService {
  CatalogService(this.db);
  final AppDatabase db;

  static final _currencyFormat = NumberFormat('#,###');
  static const _primaryColor = PdfColor.fromInt(0xFF1A1A2E);
  static const _accentColor = PdfColor.fromInt(0xFF00A884);
  static const _grayLight = PdfColor.fromInt(0xFFF5F5F5);
  static const _grayMedium = PdfColor.fromInt(0xFF666666);
  static const _maxOfflinePdfImages = 60;

  Future<Uint8List> buildCatalogPdf({
    required List<Item> items,
    List<Service> services = const [],
    required String shopName,
    String? shopPhone,
    String? shopAddress,
    String? logoUrl,
    String? shopId,
    CatalogCampaign? campaign,
  }) async {
    // Load fonts with graceful fallback when offline
    pw.Font? baseFont, boldFont;
    try {
      baseFont = await PdfGoogleFonts.nunitoRegular();
      boldFont = await PdfGoogleFonts.nunitoBold();
    } catch (_) {}
    final doc = pw.Document(
      theme: baseFont != null && boldFont != null
          ? pw.ThemeData.withFont(base: baseFont, bold: boldFont)
          : pw.ThemeData(),
    );

    final shopLink = shopId != null ? 'https://soko24.co/shop/$shopId' : null;

    final allUrls = <String>{};
    for (final item in items) {
      final url = item.thumbnailUrl ?? item.imageUrl;
      final raw = url?.trim();
      if (_isSupportedMediaSource(raw)) {
        allUrls.add(raw!);
      }
    }
    for (final svc in services) {
      final raw = svc.imageUrl?.trim();
      if (_isSupportedMediaSource(raw)) {
        allUrls.add(raw!);
      }
    }
    final trimmedLogoUrl = logoUrl?.trim();
    if (_isSupportedMediaSource(trimmedLogoUrl)) {
      allUrls.add(trimmedLogoUrl!);
    }
    final imageCache = await _loadPdfImages(allUrls);
    final logoImage = trimmedLogoUrl == null
        ? null
        : imageCache[trimmedLogoUrl];

    // Build catalog entries
    final allEntries = <_CatalogEntry>[];
    for (final item in items) {
      final url = item.thumbnailUrl ?? item.imageUrl;
      allEntries.add(
        _CatalogEntry(
          name: item.name,
          price: item.price,
          unit: item.unit,
          image: url != null ? imageCache[url.trim()] : null,
          isService: false,
          duration: null,
        ),
      );
    }
    for (final svc in services) {
      allEntries.add(
        _CatalogEntry(
          name: svc.title,
          price: svc.price,
          unit: null,
          image: svc.imageUrl != null ? imageCache[svc.imageUrl!.trim()] : null,
          isService: true,
          duration: svc.durationMinutes,
        ),
      );
    }

    final itemsPerPage = campaign?.layout == CatalogLayout.story ? 4 : 6;
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
                if (page == 0)
                  _buildHeader(
                    shopName,
                    shopPhone,
                    shopAddress,
                    shopLink,
                    logo: logoImage,
                    campaign: campaign,
                  ),
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

  Future<Map<String, pw.MemoryImage>> _loadPdfImages(
    Iterable<String> sources,
  ) async {
    final imageCache = <String, pw.MemoryImage>{};
    final jobs = sources.take(_maxOfflinePdfImages).map((source) async {
      final raw = source.trim();
      if (raw.isEmpty) return;
      try {
        final bytes = await OfflineMediaCache.instance.resolveBytes(raw);
        if (bytes != null && bytes.isNotEmpty) {
          imageCache[raw] = pw.MemoryImage(Uint8List.fromList(bytes));
        }
      } catch (_) {}
    });
    await Future.wait(jobs);
    return imageCache;
  }

  bool _isSupportedMediaSource(String? value) {
    if (value == null) return false;
    final raw = value.trim();
    if (raw.isEmpty) return false;
    final uri = Uri.tryParse(raw);
    final scheme = (uri?.scheme ?? '').toLowerCase();
    return scheme.isEmpty ||
        scheme == 'file' ||
        scheme == 'http' ||
        scheme == 'https';
  }

  pw.Widget _buildHeader(
    String shopName,
    String? shopPhone,
    String? shopAddress,
    String? shopLink, {
    pw.MemoryImage? logo,
    CatalogCampaign? campaign,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _primaryColor,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null) ...[
                pw.Container(
                  width: 56,
                  height: 56,
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Center(child: pw.Image(logo, fit: pw.BoxFit.contain)),
                ),
                pw.SizedBox(width: 14),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      shopName,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      campaign?.title.isNotEmpty == true
                          ? campaign!.title
                          : 'Product & Service Catalog',
                      style: const pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        if (shopPhone != null && shopPhone.isNotEmpty)
                          pw.Text(
                            shopPhone,
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey300,
                            ),
                          ),
                        if (shopPhone != null && shopAddress != null)
                          pw.Text(
                            '  |  ',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey300,
                            ),
                          ),
                        if (shopAddress != null && shopAddress.isNotEmpty)
                          pw.Expanded(
                            child: pw.Text(
                              shopAddress,
                              style: const pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey300,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (shopLink != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        shopLink,
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColor.fromHex('#00A884'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (campaign != null && campaign.promo != CatalogPromo.none) ...[
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(campaign.promo.badgeColor.toARGB32()),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                campaign.promo.bannerText,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
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
                      child: pw.Image(
                        entry.image!,
                        fit: pw.BoxFit.cover,
                        width: double.infinity,
                      ),
                    )
                  : pw.Center(
                      child: pw.Text(
                        entry.isService ? 'SERVICE' : 'PRODUCT',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: _grayMedium,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
          pw.SizedBox(height: 6),
          if (entry.isService)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 1,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#E8F5E9'),
                borderRadius: pw.BorderRadius.circular(2),
              ),
              child: pw.Text(
                'Service',
                style: pw.TextStyle(
                  fontSize: 7,
                  color: _accentColor,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          pw.Text(
            entry.name,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            maxLines: 2,
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            priceStr,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _accentColor,
            ),
          ),
          if (entry.unit != null && entry.unit!.isNotEmpty)
            pw.Text(
              'per ${entry.unit}',
              style: const pw.TextStyle(fontSize: 8, color: _grayMedium),
            ),
          if (entry.duration != null)
            pw.Text(
              '${entry.duration} min',
              style: const pw.TextStyle(fontSize: 8, color: _grayMedium),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(int current, int total, String? shopLink) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Generated by Soko24 Seller Terminal',
          style: const pw.TextStyle(fontSize: 8, color: _grayMedium),
        ),
        pw.Text(
          'Page $current of $total',
          style: const pw.TextStyle(fontSize: 8, color: _grayMedium),
        ),
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
    CatalogCampaign? campaign,
  }) async {
    final bytes = await buildCatalogPdf(
      items: items,
      services: services,
      shopName: shopName,
      shopPhone: shopPhone,
      shopAddress: shopAddress,
      logoUrl: logoUrl,
      shopId: shopId,
      campaign: campaign,
    );
    final suffix = campaign != null ? '-${campaign.layout.displayName.toLowerCase()}' : '';
    await Printing.sharePdf(bytes: bytes, filename: '$shopName$suffix-catalog.pdf');
  }

  Future<void> shareWhatsApp({
    required List<Item> items,
    List<Service> services = const [],
    required String shopName,
    String? shopId,
    String? phone,
    CatalogCampaign? campaign,
  }) async {
    final buffer = StringBuffer();
    final title = campaign?.title.isNotEmpty == true ? campaign!.title : '$shopName — Catalog';
    buffer.writeln('*${title.replaceAll('*', '')}*');
    if (campaign?.promo != null && campaign!.promo != CatalogPromo.none) {
      buffer.writeln('🏷 *${campaign.promo.bannerText}*');
    }
    buffer.writeln();
    if (items.isNotEmpty) {
      buffer.writeln('*Products:*');
      for (final item in items) {
        buffer.writeln(
          '▸ ${item.name} — UGX ${_currencyFormat.format(item.price.round())}',
        );
      }
    }
    if (services.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('*Services:*');
      for (final svc in services) {
        final dur = svc.durationMinutes != null
            ? ' (${svc.durationMinutes} min)'
            : '';
        buffer.writeln(
          '▸ ${svc.title} — UGX ${_currencyFormat.format(svc.price.round())}$dur',
        );
      }
    }
    buffer.writeln();
    if (shopId != null) {
      buffer.writeln('🛒 Shop online: https://soko24.co/shop/$shopId');
    }
    buffer.writeln('📞 Call or WhatsApp to order');
    buffer.writeln();
    buffer.writeln('Powered by Soko24');

    final text = buffer.toString();
    final uri = Uri.parse(
      'https://wa.me/${phone ?? ''}?text=${Uri.encodeComponent(text)}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Share.share(text, subject: title);
      }
    } catch (_) {
      await Share.share(text, subject: title);
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
