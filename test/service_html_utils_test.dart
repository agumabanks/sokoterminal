import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/util/service_html_utils.dart';

void main() {
  group('normalizeServiceDescriptionHtml', () {
    test('strips inline font-size that causes giant text', () {
      const input =
          '<p><span style="font-size: 36px;">Big heading</span></p>';
      final out = normalizeServiceDescriptionHtml(input);
      expect(out, contains('Big heading'));
      expect(out, isNot(contains('font-size')));
      expect(out, isNot(contains('36px')));
    });

    test('downgrades h1 to h2', () {
      const input = '<h1>Title</h1><p>Body</p>';
      final out = normalizeServiceDescriptionHtml(input);
      expect(out, contains('<h2>Title</h2>'));
      expect(out, isNot(contains('<h1')));
    });

    test('preserves lists and emphasis', () {
      const input = '<ul><li><strong>Bold</strong> item</li></ul>';
      final out = normalizeServiceDescriptionHtml(input);
      expect(out, contains('<ul>'));
      expect(out, contains('<strong>Bold</strong>'));
    });

    test('removes script tags', () {
      const input = '<p>Safe</p><script>alert(1)</script>';
      final out = normalizeServiceDescriptionHtml(input);
      expect(out, contains('Safe'));
      expect(out, isNot(contains('script')));
    });
  });

  group('sanitizePastedServiceHtml', () {
    test('flattens simple table paste', () {
      const input = '<table><tr><td>Cell A</td><td>Cell B</td></tr></table>';
      final out = sanitizePastedServiceHtml(input);
      expect(out, contains('Cell A'));
      expect(out, isNot(contains('<table')));
    });
  });
}