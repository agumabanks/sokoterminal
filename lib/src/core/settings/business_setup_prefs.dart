import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_providers.dart';

const businessSetupCompletedPrefKey = 'pos.setup.completed.v1';

final businessSetupCompletedProvider =
    StateNotifierProvider<BusinessSetupCompletedController, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BusinessSetupCompletedController(prefs);
});

class BusinessSetupCompletedController extends StateNotifier<bool> {
  BusinessSetupCompletedController(this._prefs)
      : super(_prefs.getBool(businessSetupCompletedPrefKey) ?? false);

  final SharedPreferences _prefs;

  Future<void> setCompleted(bool completed) async {
    await _prefs.setBool(businessSetupCompletedPrefKey, completed);
    state = completed;
  }

  Future<void> reset() => setCompleted(false);
}

