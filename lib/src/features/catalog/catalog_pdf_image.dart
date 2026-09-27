import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Limits apply before decoding, when a compressed photo can expand dramatically.
const catalogImageByteLimit = 16 * 1024 * 1024;
const catalogImagePixelLimit = 16 * 1024 * 1024;

/// Runs in a worker isolate. Invalid or excessive images use the PDF placeholder.
Uint8List? prepareCatalogPdfImage(Uint8List source) {
  if (source.isEmpty || source.length > catalogImageByteLimit) return null;
  try {
    final decoder = img.findDecoderForData(source);
    final info = decoder?.startDecode(source);
    if (info == null ||
        info.width <= 0 ||
        info.height <= 0 ||
        info.width * info.height > catalogImagePixelLimit) {
      return null;
    }
    // Catalogs need one still frame, even when the source is animated.
    final decoded = decoder!.decodeFrame(0);
    if (decoded == null) return null;
    final baked = img.bakeOrientation(decoded);
    final ready = baked.width > 1000 || baked.height > 1000
        ? img.copyResize(
            baked,
            width: baked.width >= baked.height ? 1000 : null,
            height: baked.height > baked.width ? 1000 : null,
            interpolation: img.Interpolation.linear,
          )
        : baked;
    return Uint8List.fromList(img.encodeJpg(ready, quality: 85));
  } catch (_) {
    return null;
  }
}
