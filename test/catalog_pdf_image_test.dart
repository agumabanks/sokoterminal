import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:soko_seller_terminal/src/features/catalog/catalog_pdf_image.dart';

void main() {
  test('corrupt and excessive encoded images use a placeholder', () {
    expect(prepareCatalogPdfImage(Uint8List.fromList([1, 2, 3])), isNull);
    expect(
      prepareCatalogPdfImage(Uint8List(catalogImageByteLimit + 1)),
      isNull,
    );
  });

  test('phone photo becomes a bounded JPEG with preserved aspect ratio', () {
    final source = img.Image(width: 2400, height: 1200);
    final bytes = Uint8List.fromList(img.encodeJpg(source));
    final result = img.decodeJpg(prepareCatalogPdfImage(bytes)!);
    expect(result!.width, 1000);
    expect(result.height, 500);
  });

  test('oversized decoded dimensions are rejected before pixel allocation', () {
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 1, height: 1)),
    );
    // Rewrite IHDR dimensions and CRC to describe an enormous valid header.
    final data = ByteData.sublistView(bytes);
    data.setUint32(16, 20000);
    data.setUint32(20, 20000);
    var crc = 0xffffffff;
    for (final byte in bytes.sublist(12, 29)) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc >>> 1) ^ ((crc & 1) != 0 ? 0xedb88320 : 0);
      }
    }
    data.setUint32(29, crc ^ 0xffffffff);
    expect(img.findDecoderForData(bytes)!.startDecode(bytes)!.width, 20000);
    expect(prepareCatalogPdfImage(bytes), isNull);
  });
}
