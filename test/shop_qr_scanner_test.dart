import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/features/shop_scanner/shop_qr_scanner_screen.dart';

void main() {
  test('recognizes Soko short, canonical, and compact shop QR values', () {
    expect(parseSokoShopQr('https://soko24.co/s/ile')?.lookup, 'ile');
    expect(
      parseSokoShopQr('https://soko24.co/shop/ile-Gadgets-35')?.lookup,
      'ile-Gadgets-35',
    );
    expect(parseSokoShopQr('SOKO:SHOP:ile-35')?.lookup, 'ile-35');
    expect(
      parseSokoShopQr('Visit ILE\nhttps://soko24.co/s/ile-35')?.lookup,
      'ile-35',
    );
    expect(parseSokoShopQr('soko24.co/s/ile')?.lookup, 'ile');
  });

  test('rejects unsafe and non-shop QR values', () {
    expect(parseSokoShopQr('https://not-soko.example/s/ile'), isNull);
    expect(parseSokoShopQr('https://soko24.co/p/807'), isNull);
    expect(parseSokoShopQr('https://soko24.co/s/35'), isNull);
  });
}
