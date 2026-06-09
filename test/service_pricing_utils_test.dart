import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/util/service_pricing_utils.dart';

void main() {
  test('encodePricingPackages keeps only tiers with price', () {
    final tiers = [
      const ServicePricingTier(tier: 'basic', price: 50000),
      const ServicePricingTier(tier: 'standard'),
      const ServicePricingTier(
        tier: 'premium',
        price: 150000,
        deliveryDays: 14,
        revisions: 2,
        description: 'Full brand kit',
      ),
    ];

    final encoded = encodePricingPackages(tiers);
    expect(encoded, isNotNull);

    final decoded = decodePricingPackages(encoded);
    expect(decoded[0].price, 50000);
    expect(decoded[1].price, isNull);
    expect(decoded[2].price, 150000);
    expect(decoded[2].deliveryDays, 14);
    expect(decoded[2].revisions, 2);
    expect(decoded[2].description, 'Full brand kit');
  });

  test('pricingPackagesForApi maps tier keys for backend', () {
    final api = pricingPackagesForApi([
      const ServicePricingTier(tier: 'basic', price: 25000, deliveryDays: 3),
      const ServicePricingTier(tier: 'standard', price: 45000, revisions: 1),
    ]);

    expect(api.keys, containsAll(['basic', 'standard']));
    expect(api['basic']?['price'], 25000);
    expect(api['basic']?['delivery_days'], 3);
    expect(api['standard']?['revisions'], 1);
  });
}