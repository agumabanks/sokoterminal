import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/telemetry/telemetry.dart';

/// Studio tier flags — drives Soko watermark on exports.
class StudioEntitlements {
  const StudioEntitlements({
    required this.needsSokoWatermark,
    required this.planLabel,
    this.isTrialing = false,
  });

  final bool needsSokoWatermark;
  final String planLabel;
  final bool isTrialing;

  static const free = StudioEntitlements(
    needsSokoWatermark: true,
    planLabel: 'Free',
  );
}

final studioEntitlementsProvider =
    FutureProvider<StudioEntitlements>((ref) async {
  try {
    final res = await ref.read(sellerApiProvider).fetchSellerWalletDashboard();
    final data = res.data;
    if (data is! Map) return StudioEntitlements.free;
    final wallet = data['data'] ?? data;
    if (wallet is! Map) return StudioEntitlements.free;
    final sub = wallet['subscription'];
    return _parseSubscription(sub);
  } catch (e, st) {
    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(telemetry.recordError(e, st, hint: 'studio_entitlements_fetch'));
    }
    return StudioEntitlements.free;
  }
});

StudioEntitlements _parseSubscription(dynamic sub) {
  if (sub is! Map) return StudioEntitlements.free;

  final status = (sub['status'] ?? '').toString().toLowerCase();
  final plan = sub['plan'];
  final planName = plan is Map
      ? (plan['name'] ?? 'Plan').toString()
      : 'Plan';
  final planSlug = plan is Map
      ? (plan['slug'] ?? '').toString().toLowerCase()
      : '';

  final isTrialing =
      status == 'trialing' || status == 'trial' || sub['trial_ends_at'] != null;

  // Non-paying, trial, or inactive → watermark required.
  if (status != 'active' || isTrialing) {
    return StudioEntitlements(
      needsSokoWatermark: true,
      planLabel: isTrialing ? '$planName (trial)' : planName,
      isTrialing: isTrialing,
    );
  }

  final isPremiumPlan = planSlug.contains('growth') ||
      planSlug.contains('enterprise') ||
      planSlug.contains('studio-pro') ||
      planSlug.contains('pro') ||
      planName.toLowerCase().contains('growth') ||
      planName.toLowerCase().contains('enterprise');

  return StudioEntitlements(
    needsSokoWatermark: !isPremiumPlan,
    planLabel: planName,
    isTrialing: false,
  );
}