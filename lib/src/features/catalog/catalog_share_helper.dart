/// Enhanced catalog sharing with WhatsApp-rich formatting and QR codes.
library;

import 'dart:io';

import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/db/app_database.dart';
import 'catalog_template.dart';
import 'shop_share_link.dart';

class CatalogShareHelper {
  CatalogShareHelper(this.db);
  final AppDatabase db;

  static final _currencyFormat = NumberFormat('#,###');

  /// Build rich WhatsApp text with shop info, MoMo/Airtel codes, phone.
  Future<String> buildRichWhatsAppText({
    required List<Item> items,
    List<Service> services = const [],
    required String shopName,
    String? shopId,
    String? phone,
    CatalogCampaign? campaign,
  }) async {
    final profile = await (db.select(db.businessProfiles)..limit(1)).getSingleOrNull();
    final buffer = StringBuffer();

    final title = campaign?.title.isNotEmpty == true
        ? campaign!.title
        : 'Product Catalog';
    buffer.writeln('*$title* 🛍️');
    buffer.writeln('*$shopName*');
    if (profile?.shopAddress != null && profile!.shopAddress!.isNotEmpty) {
      buffer.writeln('📍 ${profile.shopAddress}');
    }
    if (phone != null && phone.isNotEmpty) {
      buffer.writeln('📞 $phone');
    } else if (profile?.shopPhone != null && profile!.shopPhone!.isNotEmpty) {
      buffer.writeln('📞 ${profile.shopPhone}');
    }
    buffer.writeln();

    if (campaign != null && campaign.promo != CatalogPromo.none) {
      buffer.writeln('🏷️ *${campaign.promo.bannerText}*');
      buffer.writeln();
    }

    if (items.isNotEmpty) {
      buffer.writeln('*📦 Products:*');
      for (final item in items) {
        final price = '${_currencyFormat.format(item.price.round())} /=';
        buffer.writeln('• ${item.name} — *$price*');
        if (item.unit != null && item.unit!.isNotEmpty) {
          buffer.writeln('  per ${item.unit}');
        }
      }
      buffer.writeln();
    }

    if (services.isNotEmpty) {
      buffer.writeln('*🔧 Services:*');
      for (final svc in services) {
        final dur = svc.durationMinutes != null ? ' (${svc.durationMinutes} min)' : '';
        final price = '${_currencyFormat.format(svc.price.round())} /=';
        buffer.writeln('• ${svc.title} — *$price*$dur');
      }
      buffer.writeln();
    }

    if (profile != null) {
      final paymentLines = <String>[];
      if (profile.mobileMoneyEnabled && profile.mtnMerchantCode != null) {
        paymentLines.add('📲 MTN MoMo: *${profile.mtnMerchantCode}*');
      }
      if (profile.airtelMerchantCode != null && profile.airtelMerchantCode!.isNotEmpty) {
        paymentLines.add('📲 Airtel Money: *${profile.airtelMerchantCode}*');
      }
      if (profile.bankPaymentEnabled && profile.bankAccNo != null) {
        paymentLines.add('🏦 ${profile.bankName ?? 'Bank'}: ${profile.bankAccNo}');
      }
      if (paymentLines.isNotEmpty) {
        buffer.writeln('*💳 Payment:*');
        for (final line in paymentLines) {
          buffer.writeln(line);
        }
        buffer.writeln();
      }
    }

    final shopLink = buildShopShareLink(shopId: shopId, shopName: shopName);
    if (shopLink != null) {
      buffer.writeln('🛒 *Shop online:* $shopLink');
    }
    buffer.writeln('📲 *Call or WhatsApp to order*');
    buffer.writeln();
    buffer.writeln('_Powered by Soko24_ 🚀');

    return buffer.toString();
  }

  /// Share catalog to WhatsApp with rich text.
  Future<void> shareToWhatsApp({
    required List<Item> items,
    List<Service> services = const [],
    required String shopName,
    String? shopId,
    String? phone,
    CatalogCampaign? campaign,
  }) async {
    final text = await buildRichWhatsAppText(
      items: items,
      services: services,
      shopName: shopName,
      shopId: shopId,
      phone: phone,
      campaign: campaign,
    );

    final uri = Uri.parse('https://wa.me/${phone ?? ''}?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Share.share(text, subject: shopName);
      }
    } catch (_) {
      await Share.share(text, subject: shopName);
    }
  }

  /// Generate image catalog (9:16 story format) for WhatsApp sharing.
  Future<File?> generateImageCatalog({
    required List<Item> items,
    List<Service> services = const [],
    required String shopName,
    String? logoUrl,
    CatalogCampaign? campaign,
  }) async {
    try {
      // Note: Full implementation requires widget-to-image conversion
      // (e.g., screenshot package or CustomPainter to PNG).
      return null;
    } catch (_) {
      return null;
    }
  }
}
