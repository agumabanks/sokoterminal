import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/features/catalog/shop_share_link.dart';

void main() {
  test('builds a collision-safe short storefront link', () {
    expect(
      buildShopShareLink(shopId: '128', shopName: 'Sanaa Media'),
      'https://soko24.co/s/sanaa-128',
    );
  });

  test('does not produce a broken shop link without identity data', () {
    expect(buildShopShareLink(shopId: '128', shopName: null), isNull);
    expect(buildShopShareLink(shopId: null, shopName: 'Sanaa Media'), isNull);
  });
}
