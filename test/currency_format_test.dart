import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/util/formatters.dart';
import 'package:soko_seller_terminal/src/features/ads/studio_product_utils.dart';

void main() {
  test('seller amounts use Ugandan suffix notation', () {
    expect(1000.toUgx(), '1,000 /=');
    expect(formatUgPrice(12000), '12,000 /=');
  });
}
