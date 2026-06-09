import '../../core/db/app_database.dart';
import 'brand_kit_screen.dart';
import 'studio_product_utils.dart';

/// All insertable template variables for the text panel.
const studioVariableChips = <({String token, String label})>[
  (token: '{{PRODUCT}}', label: 'Product'),
  (token: '{{PRICE}}', label: 'Price'),
  (token: '{{WHATSAPP}}', label: 'WhatsApp'),
  (token: '{{PHONE}}', label: 'Phone'),
  (token: '{{CTA_LINK}}', label: 'Shop link'),
  (token: '{{BUSINESS}}', label: 'Business'),
  (token: '{{LOCATION}}', label: 'Location'),
  (token: '{{TAGLINE}}', label: 'Tagline'),
];

/// Replace template variables with live shop/product values for editor preview.
String resolveStudioVariables(
  String? raw, {
  required BrandKit kit,
  Item? product,
  String? productLink,
}) {
  if (raw == null || raw.isEmpty) return '';

  final wa = kit.whatsapp.isNotEmpty ? kit.whatsapp : '0700 000 000';
  final phone = kit.phone.isNotEmpty ? kit.phone : wa;
  final biz = kit.businessName.isNotEmpty ? kit.businessName : 'Your Business';
  final loc = kit.location.isNotEmpty ? kit.location : 'Kampala, Uganda';
  final link = productLink?.isNotEmpty == true
      ? normalizeShareUrl(productLink!)
      : (kit.website.isNotEmpty ? normalizeShareUrl(kit.website) : 'soko24.co');
  final productName = product?.name ?? 'Product Name';
  final price = product != null ? formatUgPrice(product.price) : 'UGX 0';
  final tagline = kit.tagline.isNotEmpty ? kit.tagline : '';

  return raw
      .replaceAll('{{PRODUCT}}', productName)
      .replaceAll('{{PRICE}}', price)
      .replaceAll('{{WHATSAPP}}', wa)
      .replaceAll('{{PHONE}}', phone)
      .replaceAll('{{CTA_LINK}}', link)
      .replaceAll('{{BUSINESS}}', biz)
      .replaceAll('{{LOCATION}}', loc)
      .replaceAll('{{TAGLINE}}', tagline)
      .replaceAll('{{WA}}', wa)
      .replaceAll('PRODUCT NAME', productName)
      .replaceAll('Product Name', productName)
      .replaceAll('UGX 99,000', price)
      .replaceAll('UGX 150,000', price)
      .replaceAll('UGX 75,000', price)
      .replaceAll('UGX 49,000', price)
      .replaceAll('UGX 25,000', price)
      .replaceAll('UGX 120,000', price)
      .replaceAll('UGX 200,000', price);
}