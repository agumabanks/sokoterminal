import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/util/phone_normalizer.dart';

void main() {
  group('normalizeUgPhone', () {
    test('accepts full 256… number', () {
      expect(normalizeUgPhone('256200903221'), '256200903221');
    });

    test('accepts +256… number', () {
      expect(normalizeUgPhone('+256200903221'), '256200903221');
    });

    test('accepts local 9-digit number', () {
      expect(normalizeUgPhone('200903221'), '256200903221');
    });

    test('accepts 0-prefixed 10-digit number', () {
      expect(normalizeUgPhone('0200903221'), '256200903221');
    });

    test('strips spaces and symbols', () {
      expect(normalizeUgPhone('  256 200-903-221 '), '256200903221');
    });
  });
}

