import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_providers.dart';
import '../models/product_bnpl_payload.dart';

/// Fetches BNPL settings for a single product.
///
/// Falls back to `null` when the backend endpoint is unavailable so that the
/// editor can safely show default (disabled) settings.
final productBnplProvider =
    FutureProvider.family.autoDispose<ProductBnplPayload?, int>(
  (ref, productId) async {
    final api = ref.watch(sellerApiProvider);
    try {
      return await api.getProductBnpl(productId);
    } catch (_) {
      return null;
    }
  },
);
