import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:soko_seller_terminal/src/core/db/app_database.dart';
import 'package:soko_seller_terminal/src/features/catalog/catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog PDF embeds the selected product image', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final temp = await Directory.systemTemp.createTemp('soko-catalog-proof-');
    addTearDown(() async {
      await db.close();
      await temp.delete(recursive: true);
    });

    final source = img.Image(width: 320, height: 240);
    img.fill(source, color: img.ColorRgb8(0, 168, 132));
    final imageFile = File('${temp.path}/product.png');
    await imageFile.writeAsBytes(img.encodePng(source));

    final item = Item(
      id: 'proof-product',
      name: 'Premium Product',
      price: 120000,
      stockEnabled: true,
      stockQty: 8,
      imageUrl: imageFile.path,
      publishedOnline: true,
      minPurchaseQty: 1,
      refundable: false,
      cashOnDelivery: true,
      updatedAt: DateTime(2026, 7, 30),
      synced: true,
    );

    final pdf = await CatalogService(
      db,
    ).buildCatalogPdf(items: [item], shopName: 'Sanaa Media');
    final artifacts = Directory('build/test-artifacts');
    await artifacts.create(recursive: true);
    await File('${artifacts.path}/catalog-proof.pdf').writeAsBytes(pdf);
    final raw = String.fromCharCodes(pdf);

    expect(pdf.length, greaterThan(5000));
    expect(raw, contains('/Subtype/Image'));
  });
}
