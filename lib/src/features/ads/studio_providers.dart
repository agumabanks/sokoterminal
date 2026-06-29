import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import 'studio_campaign_analytics.dart';

/// Product selected in Studio for template quick-apply and share flows.
final studioProductProvider = StateProvider<Item?>((ref) => null);

/// Lightweight local Studio usage analytics (exports, shares, edits, template uses).
final studioCampaignAnalyticsProvider =
    StateNotifierProvider<StudioCampaignAnalytics, StudioCampaignStats>(
  (ref) => StudioCampaignAnalytics(ref.read(sharedPreferencesProvider)),
);