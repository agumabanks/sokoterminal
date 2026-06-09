import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_providers.dart';
import 'ad_templates.dart';

const _recentDesignsKey = 'studio_recent_designs_v1';
const maxRecentDesigns = 12;

final recentDesignsProvider =
    StateNotifierProvider<RecentDesignsNotifier, List<AdTemplate>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return RecentDesignsNotifier(prefs);
});

class RecentDesignsNotifier extends StateNotifier<List<AdTemplate>> {
  RecentDesignsNotifier(this._prefs) : super([]) {
    _load();
  }

  final SharedPreferences _prefs;

  void _load() {
    final raw = _prefs.getStringList(_recentDesignsKey) ?? [];
    state = raw
        .map((entry) {
          try {
            return AdTemplate.fromJson(
              jsonDecode(entry) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<AdTemplate>()
        .toList();
  }

  Future<void> add(AdTemplate template) async {
    final withoutDupes = [
      template,
      ...state.where((t) => t.id != template.id),
    ].take(maxRecentDesigns).toList();
    state = withoutDupes;
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((t) => t.id != id).toList();
    await _persist();
  }

  Future<void> _persist() async {
    final raw = state.map((t) => jsonEncode(t.toJson())).toList();
    await _prefs.setStringList(_recentDesignsKey, raw);
  }
}