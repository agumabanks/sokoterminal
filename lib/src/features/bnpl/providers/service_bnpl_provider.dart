import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_providers.dart';
import '../models/service_bnpl_payload.dart';

/// Fetches BNPL settings for a single service.
///
/// Falls back to `null` when the backend endpoint is unavailable so that the
/// editor can safely show default (disabled) settings.
final serviceBnplProvider =
    FutureProvider.family.autoDispose<ServiceBnplPayload?, int>(
  (ref, serviceId) async {
    final api = ref.watch(sellerApiProvider);
    try {
      return await api.getServiceBnpl(serviceId);
    } catch (_) {
      return null;
    }
  },
);
