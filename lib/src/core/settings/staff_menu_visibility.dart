import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_providers.dart';

const staffMenuVisibilityPrefKey = 'staff_menu_visible_feature_ids_v1';

class StaffMenuAccessState {
  const StaffMenuAccessState({
    this.visibleFeatureIds = const <String>{},
    this.loaded = false,
  });

  final Set<String> visibleFeatureIds;
  final bool loaded;

  bool isVisible(String featureId) => visibleFeatureIds.contains(featureId);

  StaffMenuAccessState copyWith({
    Set<String>? visibleFeatureIds,
    bool? loaded,
  }) {
    return StaffMenuAccessState(
      visibleFeatureIds: visibleFeatureIds ?? this.visibleFeatureIds,
      loaded: loaded ?? this.loaded,
    );
  }
}

const Set<String> defaultStaffVisibleFeatureIds = {
  'dashboard',
  'customers',
  'products',
  'services',
  'quotations',
  'shifts',
  'orders',
  'refunds',
  'profile',
  'expenses',
};

final staffMenuAccessProvider =
    StateNotifierProvider<StaffMenuAccessController, StaffMenuAccessState>((
      ref,
    ) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StaffMenuAccessController(prefs)..load();
    });

class StaffMenuAccessController extends StateNotifier<StaffMenuAccessState> {
  StaffMenuAccessController(this._prefs) : super(const StaffMenuAccessState());

  final SharedPreferences _prefs;

  Future<void> load() async {
    final saved = _prefs.getStringList(staffMenuVisibilityPrefKey);
    state = StaffMenuAccessState(
      visibleFeatureIds: saved == null || saved.isEmpty
          ? defaultStaffVisibleFeatureIds
          : saved.toSet(),
      loaded: true,
    );
  }

  Future<void> toggleFeature(String featureId, bool visible) async {
    final next = {...state.visibleFeatureIds};
    if (visible) {
      next.add(featureId);
    } else {
      next.remove(featureId);
    }
    await _prefs.setStringList(
      staffMenuVisibilityPrefKey,
      next.toList()..sort(),
    );
    state = state.copyWith(visibleFeatureIds: next);
  }

  Future<void> resetDefaults() async {
    final next = {...defaultStaffVisibleFeatureIds};
    await _prefs.setStringList(
      staffMenuVisibilityPrefKey,
      next.toList()..sort(),
    );
    state = state.copyWith(visibleFeatureIds: next, loaded: true);
  }
}
