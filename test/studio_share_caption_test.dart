import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/db/app_database.dart';
import 'package:soko_seller_terminal/src/features/ads/brand_kit_screen.dart';
import 'package:soko_seller_terminal/src/features/ads/studio_product_utils.dart';

void main() {
  const kit = BrandKit(
    businessName: 'Sanaa Media',
    tagline: 'Made with care in Kampala',
    phone: '0200903222',
    whatsapp: '0706272481',
    location: 'Nasser Road, Kampala',
    website: 'https://www.soko24.co/shop/Sanaa-Media-128',
  );

  final product = Item(
    id: 'product-1',
    remoteId: 2684,
    name: 'Premium ID Card Holder',
    price: 12000,
    description:
        '<p>Durable branded holder with a clear window and safety lanyard.</p>',
    imageUrl: 'https://example.com/product.png',
    stockEnabled: true,
    stockQty: 10,
    publishedOnline: true,
    minPurchaseQty: 1,
    refundable: false,
    cashOnDelivery: true,
    synced: true,
    updatedAt: DateTime(2026),
  );

  test('campaign caption leads with offer and never leaks template name', () {
    final caption = buildShareCaption(
      kit: kit,
      templateName: 'Food Special Story',
      details: const StudioShareDetails(),
      product: product,
      productLink: 'https://www.soko24.co/p/2684',
    );

    expect(caption, startsWith('Premium ID Card Holder\nPrice: 12,000 /='));
    expect(
      caption,
      contains(
        'Durable branded holder with a clear window and safety lanyard.',
      ),
    );
    expect(caption, contains('Available from Sanaa Media'));
    expect(caption, isNot(contains('Made with care in Kampala')));
    expect(
      caption,
      contains('Discover trusted products and services on Soko24.'),
    );
    expect(caption, contains('Buy with confidence.'));
    expect(caption, isNot(contains('Food Special Story')));
  });

  test('service caption carries service details and exact buyer link', () {
    final service = Service(
      id: 'service-1',
      remoteId: 247,
      title: 'Custom Receipt Book Printing',
      summary: 'Branded duplicate receipt books with serial numbering.',
      price: 150000,
      publishedOnline: true,
      slug: 'custom-receipt-book-printing',
      updatedAt: DateTime(2026),
      synced: true,
    );
    final link = resolveServiceShareLink(service: service, kit: kit);
    final caption = buildShareCaption(
      kit: kit,
      templateName: 'Service Flyer',
      details: const StudioShareDetails(),
      service: service,
      productLink: link,
    );

    expect(
      caption,
      startsWith('Custom Receipt Book Printing\nPrice: 150,000 /='),
    );
    expect(caption, contains('Branded duplicate receipt books'));
    expect(
      caption,
      contains(
        'View / order: https://www.soko24.co/service/custom-receipt-book-printing',
      ),
    );
    expect(caption, isNot(contains('Made with care in Kampala')));
  });

  test('different products cannot produce the same campaign caption', () {
    final printer = Item(
      id: 'product-2',
      remoteId: 2682,
      name: 'Thermal Mini Printer',
      price: 120000,
      description: 'Portable receipt printer with Bluetooth connectivity.',
      stockEnabled: true,
      stockQty: 12,
      publishedOnline: true,
      minPurchaseQty: 1,
      refundable: false,
      cashOnDelivery: true,
      synced: true,
      updatedAt: DateTime(2026),
    );
    final holderCaption = buildShareCaption(
      kit: kit,
      templateName: 'Campaign A',
      details: const StudioShareDetails(),
      product: product,
      productLink: 'https://www.soko24.co/p/2684',
    );
    final printerCaption = buildShareCaption(
      kit: kit,
      templateName: 'Campaign B',
      details: const StudioShareDetails(),
      product: printer,
      productLink: 'https://www.soko24.co/p/2682',
    );

    expect(printerCaption, isNot(holderCaption));
    expect(printerCaption, contains('Thermal Mini Printer'));
    expect(printerCaption, contains('https://www.soko24.co/p/2682'));
    expect(printerCaption, isNot(contains('Premium ID Card Holder')));
    expect(printerCaption, isNot(contains('https://www.soko24.co/p/2684')));
  });
}
