import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_providers.dart';
import '../models/bnpl_seller_status.dart';

/// Fetches the current seller-level BNPL enrollment status.
///
/// If the backend endpoint is not deployed yet (e.g. returns 404), the provider
/// falls back to `not_enrolled` so the UI can still render without crashing.
final bnplSellerStatusProvider = FutureProvider.autoDispose<BnplSellerStatus>(
  (ref) async {
    final api = ref.watch(sellerApiProvider);
    try {
      return await api.getBnplSellerStatus();
    } catch (_) {
      return const BnplSellerStatus(status: 'not_enrolled');
    }
  },
);
