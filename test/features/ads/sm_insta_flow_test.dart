import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:soko_seller_terminal/src/features/ads/brand_kit_screen.dart';
import 'package:soko_seller_terminal/src/features/ads/sm_insta_flow.dart';

void main() {
  group('SM Insta helpers', () {
    test(
        'buildSmInstaTemplate uses captured photo and applies brand variables',
        () {
      final template = buildSmInstaTemplate(
        photoSrc: 'file:///tmp/test_photo.jpg',
        style: SmInstaStyle.smart,
        kit: const BrandKit(
          businessName: 'Test Shop',
          whatsapp: '0700 123 456',
        ),
      );

      expect(template.canvasWidth, 1080);
      expect(template.canvasHeight, 1350);
      expect(
        template.elements.where((e) => e.type == 'image').length,
        greaterThanOrEqualTo(1),
      );

      final photo = template.elements.firstWhere((e) => e.type == 'image');
      expect(photo.src, 'file:///tmp/test_photo.jpg');

      final businessText = template.elements
          .where((e) => e.text?.contains('Test Shop') ?? false);
      expect(businessText, isNotEmpty);
    });

    test('buildSmInstaTemplate appends a contextual overlay', () {
      final template = buildSmInstaTemplate(
        photoSrc: 'file:///tmp/test_photo.jpg',
        style: SmInstaStyle.sale,
        kit: const BrandKit(businessName: 'Test Shop'),
      );

      expect(template.elements.length, greaterThan(1));
    });

    test('prepareSmInstaPhoto returns original file when flip is false',
        () async {
      final temp = await Directory.systemTemp.createTemp('sminsta_test');
      addTearDown(() => temp.delete(recursive: true));

      final src = File(p.join(temp.path, 'input.png'));
      await src.writeAsBytes(img.encodePng(img.Image(width: 4, height: 4)));

      final out = await prepareSmInstaPhoto(
        src.path,
        flip: false,
        outputDir: temp,
      );

      expect(out.path, src.path);
    });

    test('prepareSmInstaPhoto creates a flipped copy when flip is true',
        () async {
      final temp = await Directory.systemTemp.createTemp('sminsta_test');
      addTearDown(() => temp.delete(recursive: true));

      final src = File(p.join(temp.path, 'input.png'));
      final image = img.Image(width: 2, height: 2);
      image.setPixel(0, 0, img.ColorRgba8(255, 0, 0, 255));
      image.setPixel(1, 0, img.ColorRgba8(0, 255, 0, 255));
      await src.writeAsBytes(img.encodePng(image));

      final out = await prepareSmInstaPhoto(
        src.path,
        flip: true,
        outputDir: temp,
      );

      expect(out.path, isNot(src.path));
      expect(out.existsSync(), isTrue);

      final decoded = img.decodeImage(await out.readAsBytes());
      expect(decoded, isNotNull);

      // After horizontal flip, the green pixel from (1,0) should be at (0,0).
      final topLeft = decoded!.getPixel(0, 0);
      expect(topLeft.r, 0);
      expect(topLeft.g, 255);
    });
  });
}
