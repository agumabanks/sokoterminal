import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_providers.dart';
import 'campaign_models.dart';

// ---------------------------------------------------------------------------
// Campaign Manager — local persistence via SharedPreferences
// ---------------------------------------------------------------------------

final campaignManagerProvider = Provider<CampaignManager>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CampaignManager(prefs);
});

final campaignsProvider = StateNotifierProvider<CampaignsNotifier, List<Campaign>>((ref) {
  final manager = ref.watch(campaignManagerProvider);
  return CampaignsNotifier(manager);
});

final scheduledPostsProvider = StateNotifierProvider<ScheduledPostsNotifier, List<ScheduledPost>>((ref) {
  final manager = ref.watch(campaignManagerProvider);
  return ScheduledPostsNotifier(manager);
});

final marketingAnalyticsProvider = Provider<MarketingAnalytics>((ref) {
  final campaigns = ref.watch(campaignsProvider);
  // In a real implementation, we'd track designs/shares/downloads separately
  return MarketingAnalytics(
    designsCreatedThisMonth: 0, // populated from actual design tracking
    activeCampaigns: campaigns.where((c) => c.isActive).length,
    completedCampaigns: campaigns.where((c) => c.isCompleted).length,
    brandKitScore: 50, // placeholder
  );
});

class CampaignsNotifier extends StateNotifier<List<Campaign>> {
  CampaignsNotifier(this._manager) : super([]) {
    _load();
  }

  final CampaignManager _manager;

  void _load() {
    state = _manager.loadCampaigns();
  }

  Future<void> add(Campaign campaign) async {
    await _manager.saveCampaign(campaign);
    state = [...state, campaign];
  }

  Future<void> update(Campaign campaign) async {
    await _manager.saveCampaign(campaign);
    state = [for (final c in state) if (c.id == campaign.id) campaign else c];
  }

  Future<void> delete(String id) async {
    await _manager.deleteCampaign(id);
    state = state.where((c) => c.id != id).toList();
  }

  Future<void> refresh() async {
    state = _manager.loadCampaigns();
  }
}

class ScheduledPostsNotifier extends StateNotifier<List<ScheduledPost>> {
  ScheduledPostsNotifier(this._manager) : super([]) {
    _load();
  }

  final CampaignManager _manager;

  void _load() {
    state = _manager.loadScheduledPosts();
  }

  Future<void> add(ScheduledPost post) async {
    await _manager.saveScheduledPost(post);
    state = [...state, post];
  }

  Future<void> toggleComplete(String id) async {
    final updated = state.map((p) {
      if (p.id == id) {
        final np = ScheduledPost(
          id: p.id,
          campaignId: p.campaignId,
          title: p.title,
          scheduledDate: p.scheduledDate,
          platform: p.platform,
          templateId: p.templateId,
          caption: p.caption,
          isCompleted: !p.isCompleted,
        );
        _manager.saveScheduledPost(np);
        return np;
      }
      return p;
    }).toList();
    state = updated;
  }

  Future<void> delete(String id) async {
    await _manager.deleteScheduledPost(id);
    state = state.where((p) => p.id != id).toList();
  }
}

class CampaignManager {
  CampaignManager(this._prefs);

  final SharedPreferences _prefs;
  static const _campaignsKey = 'studio_campaigns_v1';
  static const _postsKey = 'studio_scheduled_posts_v1';

  List<Campaign> loadCampaigns() {
    final raw = _prefs.getStringList(_campaignsKey) ?? [];
    return raw.map((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return Campaign.fromJson(m);
      } catch (_) {
        return null;
      }
    }).whereType<Campaign>().toList();
  }

  Future<void> saveCampaign(Campaign campaign) async {
    final existing = loadCampaigns();
    final updated = [
      for (final c in existing)
        if (c.id == campaign.id) campaign else c,
    ];
    if (!existing.any((c) => c.id == campaign.id)) {
      updated.add(campaign);
    }
    final raw = updated.map((c) => jsonEncode(c.toJson())).toList();
    await _prefs.setStringList(_campaignsKey, raw);
  }

  Future<void> deleteCampaign(String id) async {
    final existing = loadCampaigns();
    final updated = existing.where((c) => c.id != id).toList();
    final raw = updated.map((c) => jsonEncode(c.toJson())).toList();
    await _prefs.setStringList(_campaignsKey, raw);
  }

  List<ScheduledPost> loadScheduledPosts() {
    final raw = _prefs.getStringList(_postsKey) ?? [];
    return raw.map((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return ScheduledPost.fromJson(m);
      } catch (_) {
        return null;
      }
    }).whereType<ScheduledPost>().toList();
  }

  Future<void> saveScheduledPost(ScheduledPost post) async {
    final existing = loadScheduledPosts();
    final updated = [
      for (final p in existing)
        if (p.id == post.id) post else p,
    ];
    if (!existing.any((p) => p.id == post.id)) {
      updated.add(post);
    }
    final raw = updated.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs.setStringList(_postsKey, raw);
  }

  Future<void> deleteScheduledPost(String id) async {
    final existing = loadScheduledPosts();
    final updated = existing.where((p) => p.id != id).toList();
    final raw = updated.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs.setStringList(_postsKey, raw);
  }

  List<ScheduledPost> postsForCampaign(String campaignId) {
    return loadScheduledPosts().where((p) => p.campaignId == campaignId).toList();
  }

  List<ScheduledPost> postsForDate(DateTime date) {
    final all = loadScheduledPosts();
    return all.where((p) {
      return p.scheduledDate.year == date.year &&
          p.scheduledDate.month == date.month &&
          p.scheduledDate.day == date.day;
    }).toList();
  }
}
