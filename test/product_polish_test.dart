import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soko_seller_terminal/src/core/app_providers.dart';
import 'package:soko_seller_terminal/src/features/items/product_form_controller.dart';
import 'package:soko_seller_terminal/src/features/items/product_photo_editor.dart';
import 'package:soko_seller_terminal/src/features/delivery/coverage_rules.dart';
import 'helpers/test_helpers.dart';

void main() {
  test('unknown buying price is explicit and never invents profit', () {
    const form = ProductFormState(name: 'Sugar', price: '5,000');
    expect(form.isPricingValid, isFalse);
    expect(form.copyWith(costUnknown: true).isPricingValid, isTrue);
    expect(form.copyWith(costUnknown: true).estimatedProfit, isNull);
    expect(form.copyWith(cost: '3,000').estimatedProfit, 2000);
    expect(form.copyWith(cost: '6,000').estimatedProfit, -1000);
    expect(form.copyWith(cost: '3,000', discount: '10', discountType: 'percent').estimatedProfit, 1500);
    expect(form.copyWith(price: '11,800', cost: '8,000', taxEnabled: true, taxRate: '18', taxInclusionMode: 'inclusive').estimatedProfit, closeTo(2000, .001));
  });
  test('online photo requirements permit incomplete in-shop drafts', () {
    final cover = File('/cover.jpg');
    final online = ProductFormState(publishOnline: true, thumbnailFile: cover, galleryFiles: [File('/a'), File('/b')]);
    expect(online.isImagesValid, isFalse);
    expect(online.copyWith(publishOnline: false).isImagesValid, isTrue);
    expect(online.copyWith(galleryFiles: [File('/a'), File('/b'), File('/c')]).isImagesValid, isTrue);
    expect(online.copyWith(galleryFiles: List.generate(7, (i) => File('/$i'))).isImagesValid, isFalse);
    expect(online.copyWith(thumbnailFile: null).hasCover, isFalse);
  });
  test('mixed gallery ordering and removing cover preserve unrelated settings', () {
    final container = ProviderContainer();
    final sub = container.listen(productFormProvider, (_, _) {});
    addTearDown(() { sub.close(); container.dispose(); });
    final ctrl = container.read(productFormProvider.notifier);
    ctrl.setExistingImages(thumbnailUrl: 'https://shop/cover', thumbnailUploadId: 1, galleryUrls: ['https://shop/a'], galleryUploadIds: [2], pendingGalleryFiles: [File('/b'), File('/c')], orderedPaths: ['https://shop/a','/b','/c']);
    ctrl.setTaxRate('18');
    ctrl.reorderGallery(2, 0);
    expect(container.read(productFormProvider).orderedGallery, ['/c','https://shop/a','/b']);
    ctrl.removeThumbnail();
    final state = container.read(productFormProvider);
    expect(state.thumbnailUrl, isNull);
    expect(state.thumbnailUploadId, isNull);
    expect(state.taxRate, '18');
    ctrl.replaceGalleryPhoto('https://shop/a', File('/replacement'));
    expect(container.read(productFormProvider).orderedGallery, ['/c','/replacement','/b']);
  });
  test('an interrupted form restores prices, channel and coverage locally', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = createTestDatabase();
    addTearDown(db.close);
    ProviderContainer makeContainer() => ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs), appDatabaseProvider.overrideWithValue(db)]);
    final first = makeContainer();
    final one = first.listen(productFormProvider, (_, _) {});
    final ctrl = first.read(productFormProvider.notifier);
    await ctrl.restoreDraft();
    ctrl.setName('Notebook'); ctrl.setPrice('5,000'); ctrl.setCostUnknown(true);
    ctrl.setSellingCoverage({'mode':'radius', 'center_lat': 0.3, 'center_lng':32.5, 'radius_km':5});
    await ctrl.saveDraft();
    one.close(); first.dispose();
    final second = makeContainer();
    final two = second.listen(productFormProvider, (_, _) {});
    addTearDown(() { two.close(); second.dispose(); });
    final restored = second.read(productFormProvider.notifier);
    expect(await restored.restoreDraft(), isTrue);
    expect(second.read(productFormProvider).name, 'Notebook');
    expect(second.read(productFormProvider).costValue, isNull);
    expect(second.read(productFormProvider).sellingCoverage?['radius_km'], 5);
    await restored.discardDraft();
    expect(prefs.getString('product_draft_v2_local'), isNull);
  });
  test('coverage rejects crossings and missing map locations', () {
    expect(coverageError({'mode':'radius','radius_km':5}), isNotNull);
    expect(coverageError({'mode':'radius','center_lat':0.3,'center_lng':32.5,'radius_km':5}), isNull);
    expect(coverageError({'mode':'polygon','polygon':[[0,0],[1,1],[1,0],[0,1]]}), isNotNull);
    expect(coverageError({'mode':'polygon','polygon':[[0,0],[0,1],[1,1],[1,0]]}), isNull);
    expect(coverageError({'mode':'polygon','polygon':[[0,0],[0,1],[0,2]]}), isNotNull);
  });
  test('photo rendering rotates and compresses without changing original bytes', () {
    final source = image.Image(width: 20, height: 10);
    image.fill(source, color: image.ColorRgb8(200, 80, 20));
    final bytes = Uint8List.fromList(image.encodePng(source));
    final original = [...bytes];
    final rendered = renderProductPhoto({'bytes':bytes, 'turns':1, 'filter':'mono'});
    final decoded = image.decodeJpg(rendered)!;
    expect(decoded.width, 10); expect(decoded.height, 20);
    expect(bytes, original);
    final pixel = decoded.getPixel(0,0);
    expect(pixel.r, closeTo(pixel.g, 2)); expect(pixel.g, closeTo(pixel.b, 2));
  });
}
