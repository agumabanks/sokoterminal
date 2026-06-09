import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/db/app_database.dart';
import 'package:soko_seller_terminal/src/features/ads/brand_kit_screen.dart';
import 'package:soko_seller_terminal/src/features/ads/studio_variable_context.dart';

void main() {
  test('StudioVariableContext resolves all core tokens', () {
    const kit = BrandKit(
      businessName: 'Sanaa Media',
      tagline: 'Design that sells',
      phone: '0706272481',
      whatsapp: '0706272481',
      location: 'Nasser Road',
      website: 'https://soko24.co/shop/sanaa',
    );
    final product = Item(
      id: 'local-1',
      remoteId: 99,
      name: 'Logo Design',
      price: 25000,
      imageUrl: 'https://example.com/p.png',
      stockEnabled: false,
      stockQty: 0,
      publishedOnline: true,
      minPurchaseQty: 1,
      refundable: false,
      cashOnDelivery: false,
      synced: true,
      updatedAt: DateTime.now(),
    );

    final ctx = StudioVariableContext(
      kit: kit,
      product: product,
      productLink: 'https://soko24.co/p/99',
    );

    final resolved = ctx.resolve(
      '{{BUSINESS}} · {{PRODUCT}} · {{PRICE}} · {{WHATSAPP}} · {{CTA_LINK}}',
    );

    expect(resolved, contains('Sanaa Media'));
    expect(resolved, contains('Logo Design'));
    expect(resolved, contains('UGX'));
    expect(resolved, contains('0706272481'));
    expect(resolved, contains('soko24.co/p/99'));
  });
}