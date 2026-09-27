import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/features/ads/catalog_fact_extractor.dart';
import 'package:soko_seller_terminal/src/features/ads/catalog_ad_validator.dart';
import 'package:soko_seller_terminal/src/features/ads/ad_deduplicator.dart';
import 'package:soko_seller_terminal/src/features/ads/natural_copy_generator.dart';
import 'package:soko_seller_terminal/src/features/ads/ad_approval_workflow.dart';
import 'package:soko_seller_terminal/src/features/ads/video_scene_builder.dart';

void main() {
  group('UGX formatting', () {
    test('formats whole numbers with comma grouping', () {
      expect(formatUgxPrice(1500), '1,500 /=');
      expect(formatUgxPrice(1000000), '1,000,000 /=');
      expect(formatUgxPrice(500), '500 /=');
    });

    test('formats zero', () {
      expect(formatUgxPrice(0), '0 /=');
    });

    test('returns N/A for null', () {
      expect(formatUgxPrice(null), 'N/A');
    });

    test('returns N/A for negative', () {
      expect(formatUgxPrice(-100), 'N/A');
    });

    test('rounds decimals', () {
      expect(formatUgxPrice(1500.7), '1,501 /=');
    });
  });

  group('CatalogFacts', () {
    test('isComplete when all required fields present', () {
      const facts = CatalogFacts(
        id: '1',
        name: 'Test Product',
        price: 5000,
        description: 'A great product',
        imageUrl: 'https://example.com/img.jpg',
        isService: false,
        stockQty: 10,
        stockEnabled: true,
        isPublished: true,
        categoryName: 'Electronics',
        sellerName: 'Test Shop',
        sellerPhone: '0700 123 456',
        sellerWhatsapp: '0700 123 456',
        sellerLocation: 'Kampala',
        shopUrl: 'https://soko24.co/shop/test',
        brandPrimaryColor: '#0F1D40',
        brandAccentColor: '#0EBE7E',
        isDiscount: false,
      );
      expect(facts.isComplete, isTrue);
      expect(facts.missingFields, isEmpty);
    });

    test('isComplete false when missing image', () {
      const facts = CatalogFacts(
        id: '1',
        name: 'Test Product',
        price: 5000,
        description: null,
        imageUrl: null,
        isService: false,
        stockQty: 0,
        stockEnabled: false,
        isPublished: true,
        categoryName: null,
        sellerName: 'Test Shop',
        sellerPhone: null,
        sellerWhatsapp: null,
        sellerLocation: null,
        shopUrl: 'https://soko24.co',
        brandPrimaryColor: '#0F1D40',
        brandAccentColor: '#0EBE7E',
        isDiscount: false,
      );
      expect(facts.isComplete, isFalse);
      expect(facts.missingFields, contains('Product image'));
    });

    test('missingFields lists all missing required fields', () {
      const facts = CatalogFacts(
        id: '1',
        name: '',
        price: 0,
        description: null,
        imageUrl: null,
        isService: false,
        stockQty: 0,
        stockEnabled: false,
        isPublished: false,
        categoryName: null,
        sellerName: '',
        sellerPhone: null,
        sellerWhatsapp: null,
        sellerLocation: null,
        shopUrl: '',
        brandPrimaryColor: '#0F1D40',
        brandAccentColor: '#0EBE7E',
        isDiscount: false,
      );
      expect(facts.missingFields, containsAll([
        'Product name',
        'Price',
        'Product image',
        'Seller name',
      ]));
    });

    test('verifiedWasPrice returns null without discount', () {
      const facts = CatalogFacts(
        id: '1',
        name: 'Test',
        price: 5000,
        description: null,
        imageUrl: 'img.jpg',
        isService: false,
        stockQty: 10,
        stockEnabled: true,
        isPublished: true,
        categoryName: null,
        sellerName: 'Shop',
        sellerPhone: null,
        sellerWhatsapp: null,
        sellerLocation: null,
        shopUrl: 'url',
        brandPrimaryColor: '#000',
        brandAccentColor: '#000',
        isDiscount: false,
      );
      expect(facts.verifiedWasPrice, isNull);
    });

    test('verifiedWasPrice calculates percent discount', () {
      const facts = CatalogFacts(
        id: '1',
        name: 'Test',
        price: 8000,
        description: null,
        imageUrl: 'img.jpg',
        isService: false,
        stockQty: 10,
        stockEnabled: true,
        isPublished: true,
        categoryName: null,
        sellerName: 'Shop',
        sellerPhone: null,
        sellerWhatsapp: null,
        sellerLocation: null,
        shopUrl: 'url',
        brandPrimaryColor: '#000',
        brandAccentColor: '#000',
        isDiscount: true,
        discountAmount: 20,
        discountType: 'percent',
      );
      expect(facts.verifiedWasPrice, isNotNull);
      expect(facts.verifiedWasPrice, contains('10,000'));
    });
  });

  group('CatalogAdValidator', () {
    const validator = CatalogAdValidator();

    test('valid product passes validation', () {
      const facts = CatalogFacts(
        id: '1',
        name: 'Good Product',
        price: 5000,
        description: 'Nice item',
        imageUrl: 'https://example.com/img.jpg',
        isService: false,
        stockQty: 10,
        stockEnabled: true,
        isPublished: true,
        categoryName: 'Electronics',
        sellerName: 'Test Shop',
        sellerPhone: '0700 000 000',
        sellerWhatsapp: '0700 000 000',
        sellerLocation: 'Kampala',
        shopUrl: 'https://soko24.co',
        brandPrimaryColor: '#0F1D40',
        brandAccentColor: '#0EBE7E',
        isDiscount: false,
      );
      final result = validator.validate(facts);
      expect(result.isValid, isTrue);
      expect(result.reasons, isEmpty);
    });

    test('invalid product rejected for multiple reasons', () {
      const facts = CatalogFacts(
        id: '1',
        name: '',
        price: 0,
        description: null,
        imageUrl: null,
        isService: false,
        stockQty: 0,
        stockEnabled: false,
        isPublished: false,
        categoryName: null,
        sellerName: '',
        sellerPhone: null,
        sellerWhatsapp: null,
        sellerLocation: null,
        shopUrl: '',
        brandPrimaryColor: '#000',
        brandAccentColor: '#000',
        isDiscount: false,
      );
      final result = validator.validate(facts);
      expect(result.isValid, isFalse);
      expect(result.reasons.length, greaterThan(1));
    });

    test('out of stock item rejected', () {
      const facts = CatalogFacts(
        id: '1',
        name: 'Good Product',
        price: 5000,
        description: 'Nice',
        imageUrl: 'img.jpg',
        isService: false,
        stockQty: 0,
        stockEnabled: true,
        isPublished: true,
        categoryName: null,
        sellerName: 'Shop',
        sellerPhone: '0700',
        sellerWhatsapp: '0700',
        sellerLocation: 'Kla',
        shopUrl: 'url',
        brandPrimaryColor: '#000',
        brandAccentColor: '#000',
        isDiscount: false,
      );
      final result = validator.validate(facts);
      expect(result.isValid, isFalse);
      expect(result.reasons, contains('Out of stock'));
    });

    test('price below minimum rejected', () {
      const facts = CatalogFacts(
        id: '1',
        name: 'Cheap Item',
        price: 50,
        description: null,
        imageUrl: 'img.jpg',
        isService: false,
        stockQty: 10,
        stockEnabled: true,
        isPublished: true,
        categoryName: null,
        sellerName: 'Shop',
        sellerPhone: '0700',
        sellerWhatsapp: '0700',
        sellerLocation: 'Kla',
        shopUrl: 'url',
        brandPrimaryColor: '#000',
        brandAccentColor: '#000',
        isDiscount: false,
      );
      final result = validator.validate(facts);
      expect(result.isValid, isFalse);
      expect(result.reasons.any((r) => r.contains('below minimum')), isTrue);
    });

    test('unpublished item rejected', () {
      const facts = CatalogFacts(
        id: '1',
        name: 'Draft Product',
        price: 5000,
        description: null,
        imageUrl: 'img.jpg',
        isService: false,
        stockQty: 10,
        stockEnabled: true,
        isPublished: false,
        categoryName: null,
        sellerName: 'Shop',
        sellerPhone: '0700',
        sellerWhatsapp: '0700',
        sellerLocation: 'Kla',
        shopUrl: 'url',
        brandPrimaryColor: '#000',
        brandAccentColor: '#000',
        isDiscount: false,
      );
      final result = validator.validate(facts);
      expect(result.isValid, isFalse);
      expect(result.reasons, contains('Item not published online'));
    });
  });

  group('AdDeduplicator', () {
    test('detects duplicate by fingerprint', () {
      final dedup = AdDeduplicator();
      dedup.markSeen(
        catalogId: '1',
        platform: 'whatsapp',
        headline: 'Test Product',
        price: 5000,
      );
      expect(
        dedup.isDuplicate(
          catalogId: '1',
          platform: 'whatsapp',
          headline: 'Test Product',
          price: 5000,
        ),
        isTrue,
      );
    });

    test('different platforms are not duplicates', () {
      final dedup = AdDeduplicator();
      dedup.markSeen(
        catalogId: '1',
        platform: 'whatsapp',
        headline: 'Test Product',
        price: 5000,
      );
      expect(
        dedup.isDuplicate(
          catalogId: '1',
          platform: 'instagram',
          headline: 'Test Product',
          price: 5000,
        ),
        isFalse,
      );
    });

    test('different items are not duplicates', () {
      final dedup = AdDeduplicator();
      dedup.markSeen(
        catalogId: '1',
        platform: 'whatsapp',
        headline: 'Test Product',
        price: 5000,
      );
      expect(
        dedup.isDuplicate(
          catalogId: '2',
          platform: 'whatsapp',
          headline: 'Test Product',
          price: 5000,
        ),
        isFalse,
      );
    });

    test('reset clears all tracked fingerprints', () {
      final dedup = AdDeduplicator();
      dedup.markSeen(
        catalogId: '1',
        platform: 'whatsapp',
        headline: 'Test Product',
        price: 5000,
      );
      expect(dedup.count, 1);
      dedup.reset();
      expect(dedup.count, 0);
    });
  });

  group('NaturalCopyGenerator', () {
    const generator = NaturalCopyGenerator();

    test('headline uses product name, not clickbait', () {
      const facts = CatalogFacts(
        id: '1',
        name: 'Premium Headphones',
        price: 75000,
        description: 'Great sound quality',
        imageUrl: 'img.jpg',
        isService: false,
        stockQty: 5,
        stockEnabled: true,
        isPublished: true,
        categoryName: 'Electronics',
        sellerName: 'Audio Shop',
        sellerPhone: '0700 123 456',
        sellerWhatsapp: '0700 123 456',
        sellerLocation: 'Kampala',
        shopUrl: 'https://soko24.co/shop/audio',
        brandPrimaryColor: '#0F1D40',
        brandAccentColor: '#0EBE7E',
        isDiscount: false,
      );
      expect(generator.headline(facts), contains('Premium Headphones'));
      expect(generator.headline(facts), contains('Electronics'));
    });

    test('ctas only suggest verified contact methods', () {
      const factsWithWhatsapp = CatalogFacts(
        id: '1',
        name: 'Test',
        price: 5000,
        description: null,
        imageUrl: 'img.jpg',
        isService: false,
        stockQty: 10,
        stockEnabled: true,
        isPublished: true,
        categoryName: null,
        sellerName: 'Shop',
        sellerPhone: null,
        sellerWhatsapp: '0700 123 456',
        sellerLocation: null,
        shopUrl: 'url',
        brandPrimaryColor: '#000',
        brandAccentColor: '#000',
        isDiscount: false,
      );
      final ctas = generator.ctas(factsWithWhatsapp);
      expect(ctas.any((c) => c.toLowerCase().contains('whatsapp')), isTrue);
      expect(ctas.any((c) => c.toLowerCase().contains('call')), isFalse);
    });

    test('falls back to generic CTA when no contact methods', () {
      const factsNoContact = CatalogFacts(
        id: '1',
        name: 'Test',
        price: 5000,
        description: null,
        imageUrl: 'img.jpg',
        isService: false,
        stockQty: 10,
        stockEnabled: true,
        isPublished: true,
        categoryName: null,
        sellerName: 'Shop',
        sellerPhone: null,
        sellerWhatsapp: null,
        sellerLocation: null,
        shopUrl: 'url',
        brandPrimaryColor: '#000',
        brandAccentColor: '#000',
        isDiscount: false,
      );
      final ctas = generator.ctas(factsNoContact);
      expect(ctas, isNotEmpty);
      expect(ctas.first, contains('availability'));
    });

    test('caption never invents reviews or fake claims', () {
      const facts = CatalogFacts(
        id: '1',
        name: 'Leather Bag',
        price: 45000,
        description: 'Handcrafted genuine leather',
        imageUrl: 'img.jpg',
        isService: false,
        stockQty: 3,
        stockEnabled: true,
        isPublished: true,
        categoryName: 'Fashion',
        sellerName: 'Bag Shop',
        sellerPhone: '0700 111 222',
        sellerWhatsapp: '0700 111 222',
        sellerLocation: 'Kampala',
        shopUrl: 'https://soko24.co/shop/bags',
        brandPrimaryColor: '#0F1D40',
        brandAccentColor: '#0EBE7E',
        isDiscount: false,
      );
      final caption = generator.caption(
        facts: facts,
        platform: AdPlatform.whatsapp,
      );
      expect(caption, contains('Leather Bag'));
      expect(caption, contains('45,000 /='));
      expect(caption, contains('Handcrafted genuine leather'));
      // No invented claims
      expect(caption.contains('review'), isFalse);
      expect(caption.contains('⭐'), isFalse);
      expect(caption.contains('Loved by'), isFalse);
      expect(caption.contains('5-Star'), isFalse);
    });

    test('whatsapp caption omits missing contact methods', () {
      const facts = CatalogFacts(
        id: '1',
        name: 'Test',
        price: 5000,
        description: null,
        imageUrl: 'img.jpg',
        isService: false,
        stockQty: 10,
        stockEnabled: true,
        isPublished: true,
        categoryName: null,
        sellerName: 'Shop',
        sellerPhone: null,
        sellerWhatsapp: null,
        sellerLocation: null,
        shopUrl: 'url',
        brandPrimaryColor: '#000',
        brandAccentColor: '#000',
        isDiscount: false,
      );
      final caption = generator.caption(
        facts: facts,
        platform: AdPlatform.whatsapp,
      );
      expect(caption.contains('WhatsApp'), isFalse);
      expect(caption.contains('Call'), isFalse);
    });
  });

  group('AdApprovalWorkflow', () {
    test('starts with empty pending list', () {
      final workflow = AdApprovalWorkflow();
      expect(workflow.pending, isEmpty);
      expect(workflow.approved, isEmpty);
    });

    test('submit adds to pending', () {
      final workflow = AdApprovalWorkflow();
      workflow.submit(_makePendingAd('ad1'));
      expect(workflow.pending.length, 1);
      expect(workflow.approved, isEmpty);
    });

    test('approve moves ad to approved list', () {
      final workflow = AdApprovalWorkflow();
      workflow.submit(_makePendingAd('ad1'));
      expect(workflow.approve('ad1'), isTrue);
      expect(workflow.pending, isEmpty);
      expect(workflow.approved.length, 1);
    });

    test('reject removes ad', () {
      final workflow = AdApprovalWorkflow();
      workflow.submit(_makePendingAd('ad1'));
      expect(workflow.reject('ad1'), isTrue);
      expect(workflow.pending, isEmpty);
    });

    test('approve unknown id returns false', () {
      final workflow = AdApprovalWorkflow();
      expect(workflow.approve('nonexistent'), isFalse);
    });

    test('clearPending removes only unapproved', () {
      final workflow = AdApprovalWorkflow();
      workflow.submit(_makePendingAd('ad1'));
      workflow.submit(_makePendingAd('ad2'));
      workflow.approve('ad1');
      workflow.clearPending();
      expect(workflow.pending, isEmpty);
      expect(workflow.approved.length, 1);
    });
  });

  group('VideoSceneBuilder', () {
    const builder = VideoSceneBuilder();

    test('buildStructuredAd creates 4 scenes', () {
      const facts = CatalogFacts(
        id: '1',
        name: 'Smart Watch',
        price: 120000,
        description: 'Waterproof, long battery life',
        imageUrl: 'https://example.com/watch.jpg',
        isService: false,
        stockQty: 8,
        stockEnabled: true,
        isPublished: true,
        categoryName: 'Electronics',
        sellerName: 'Gadget Shop',
        sellerPhone: '0700 222 333',
        sellerWhatsapp: '0700 222 333',
        sellerLocation: 'Kampala',
        shopUrl: 'https://soko24.co/shop/gadgets',
        brandPrimaryColor: '#0F1D40',
        brandAccentColor: '#0EBE7E',
        isDiscount: false,
        imageCount: 1,
      );
      final spec = builder.buildStructuredAd(facts: facts);
      expect(spec.scenes.length, 4);
      expect(spec.scenes[0].textOverlays.first.text, 'Smart Watch');
      // All scenes use same image (single image path)
      expect(
        spec.scenes.every((s) => s.imagePath == 'https://example.com/watch.jpg'),
        isTrue,
      );
    });

    test('buildStructuredAd has Ken Burns on every scene', () {
      const facts = CatalogFacts(
        id: '1',
        name: 'Product',
        price: 5000,
        description: 'A product',
        imageUrl: 'img.jpg',
        isService: false,
        stockQty: 10,
        stockEnabled: true,
        isPublished: true,
        categoryName: null,
        sellerName: 'Shop',
        sellerPhone: '0700',
        sellerWhatsapp: '0700',
        sellerLocation: null,
        shopUrl: 'url',
        brandPrimaryColor: '#000',
        brandAccentColor: '#000',
        isDiscount: false,
        imageCount: 1,
      );
      final spec = builder.buildStructuredAd(facts: facts);
      expect(spec.scenes.every((s) => s.kenBurns != null), isTrue);
    });

    test('buildSimpleAd creates single scene', () {
      const facts = CatalogFacts(
        id: '1',
        name: 'Simple Item',
        price: 3000,
        description: null,
        imageUrl: 'img.jpg',
        isService: false,
        stockQty: 10,
        stockEnabled: true,
        isPublished: true,
        categoryName: null,
        sellerName: 'Shop',
        sellerPhone: null,
        sellerWhatsapp: null,
        sellerLocation: null,
        shopUrl: 'url',
        brandPrimaryColor: '#000',
        brandAccentColor: '#000',
        isDiscount: false,
        imageCount: 1,
      );
      final spec = builder.buildSimpleAd(facts: facts);
      expect(spec.scenes.length, 1);
      expect(spec.scenes.first.textOverlays.length, 2);
    });

    test('structured ad total duration is 14-16 seconds', () {
      const facts = CatalogFacts(
        id: '1',
        name: 'Product',
        price: 5000,
        description: 'Has description',
        imageUrl: 'img.jpg',
        isService: false,
        stockQty: 10,
        stockEnabled: true,
        isPublished: true,
        categoryName: null,
        sellerName: 'Shop',
        sellerPhone: '0700',
        sellerWhatsapp: '0700',
        sellerLocation: null,
        shopUrl: 'url',
        brandPrimaryColor: '#000',
        brandAccentColor: '#000',
        isDiscount: false,
        imageCount: 1,
      );
      final spec = builder.buildStructuredAd(facts: facts);
      final total = spec.totalDurationSeconds;
      expect(total, greaterThanOrEqualTo(14));
      expect(total, lessThanOrEqualTo(16));
    });
  });
}

PendingAd _makePendingAd(String id) => PendingAd(
      id: id,
      catalogId: 'cat1',
      catalogName: 'Test Product',
      platform: AdPlatform.whatsapp,
      headline: 'Test Headline',
      body: 'Test body',
      cta: 'Order',
      price: 5000,
      imageUrl: 'img.jpg',
      facts: const CatalogFacts(
        id: '1',
        name: 'Test',
        price: 5000,
        description: null,
        imageUrl: 'img.jpg',
        isService: false,
        stockQty: 10,
        stockEnabled: true,
        isPublished: true,
        categoryName: null,
        sellerName: 'Shop',
        sellerPhone: null,
        sellerWhatsapp: null,
        sellerLocation: null,
        shopUrl: 'url',
        brandPrimaryColor: '#000',
        brandAccentColor: '#000',
        isDiscount: false,
      ),
      warnings: const [],
      createdAt: DateTime(2026, 1, 1),
    );
