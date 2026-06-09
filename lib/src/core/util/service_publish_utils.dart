import '../db/app_database.dart';
import 'formatters.dart';
import 'service_html_utils.dart';
import 'service_pricing_utils.dart';

/// Builds the API/sync payload for a local [Service] row.
Map<String, dynamic> buildServiceSyncPayload(Service service) {
  final packages = pricingPackagesForApi(
    decodePricingPackages(service.pricingPackages),
  );
  final description = service.description?.trim();
  return {
    'local_id': service.id,
    if (service.remoteId != null) 'remote_id': service.remoteId,
    'title': service.title,
    if ((service.summary ?? '').trim().isNotEmpty) 'summary': service.summary!.trim(),
    if (description != null && description.isNotEmpty) 'description': description,
    'base_price': service.price,
    if (service.cost != null) 'purchase_price': service.cost,
    if (service.categoryId != null) 'category_id': service.categoryId,
    if ((service.serviceType ?? '').trim().isNotEmpty)
      'service_type': service.serviceType!.trim(),
    if ((service.deliveryTimeframe ?? '').trim().isNotEmpty)
      'delivery_timeframe': service.deliveryTimeframe!.trim(),
    'duration_minutes': service.durationMinutes,
    if (packages.isNotEmpty) 'packages': packages,
    'is_published': service.publishedOnline,
  };
}

bool serviceHasCover(Service service) {
  final raw = service.imageUrl?.trim();
  return raw != null && raw.isNotEmpty;
}

bool isServicePublishReady(Service service) {
  if (!service.publishedOnline) return true;
  final description = normalizeServiceDescriptionHtml(service.description);
  return service.categoryId != null &&
      (service.summary ?? '').trim().length >= 10 &&
      (service.deliveryTimeframe ?? '').trim().isNotEmpty &&
      serviceHasCover(service) &&
      description.plainText.trim().length >= 20;
}

String? servicePublishBlockReason(Service service, {required bool wantsPublish}) {
  if (!wantsPublish) return null;
  if (service.categoryId == null) {
    return 'Choose a category before going live';
  }
  if ((service.summary ?? '').trim().length < 10) {
    return 'Add a short summary (10+ characters)';
  }
  if ((service.deliveryTimeframe ?? '').trim().isEmpty) {
    return 'Select a delivery timeframe';
  }
  if (!serviceHasCover(service)) {
    return 'Add a cover photo to publish online';
  }
  final description = normalizeServiceDescriptionHtml(service.description);
  if (description.plainText.trim().length < 20) {
    return 'Add at least 20 characters of description';
  }
  return null;
}

bool isServicePendingModeration(Service service) =>
    service.moderationStatus == 'pending';

String servicePublishSnackbarMessage({
  required bool publishing,
  String? moderationStatus,
}) {
  if (!publishing) return 'Service saved on this device';
  if (moderationStatus == 'pending') {
    return 'Submitted for review — your service will appear on the shop once approved';
  }
  return 'Publishing service — syncing to your shop…';
}

class ServiceModerationUpdate {
  const ServiceModerationUpdate({
    this.moderationStatus,
    this.publishedOnline,
  });

  final String? moderationStatus;
  final bool? publishedOnline;

  bool get hasChanges =>
      moderationStatus != null || publishedOnline != null;
}

bool parsePublishedFlag(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final normalized = raw?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

ServiceModerationUpdate parseServiceModerationFromApiResponse(
  Map<String, dynamic> body,
) {
  final data = body['data'];
  if (data is! Map) return const ServiceModerationUpdate();

  final dataMap = Map<String, dynamic>.from(data);
  final pendingApproval = body['pending_approval'] == true;
  final moderationStatus = dataMap['moderation_status']?.toString();
  final publishedRaw = dataMap['is_published'];

  return ServiceModerationUpdate(
    moderationStatus: moderationStatus ?? (pendingApproval ? 'pending' : null),
    publishedOnline: publishedRaw != null ? parsePublishedFlag(publishedRaw) : null,
  );
}

String? serviceListSubtitle(Service service) {
  final summary = service.summary?.trim();
  if (summary != null && summary.isNotEmpty) return summary;
  final category = service.category?.trim();
  if (category != null && category.isNotEmpty) return category;
  final packages = pricingPackagesLabel(service.pricingPackages);
  if (packages != null) return packages;
  if (service.durationMinutes != null) {
    return '${service.durationMinutes} min';
  }
  return null;
}

String? pricingPackagesLabel(String? raw) {
  final tiers = decodePricingPackages(raw).where((t) => t.hasPrice).toList();
  if (tiers.isEmpty) return null;
  final prices = tiers.map((t) => t.price!).toList()..sort();
  if (prices.length == 1) {
    return 'From ${prices.first.toUgx()}';
  }
  return '${prices.first.toUgx()} – ${prices.last.toUgx()}';
}