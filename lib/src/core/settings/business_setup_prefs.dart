import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_providers.dart';
import '../db/app_database.dart';
import 'business_profile_cache.dart';
import 'shop_payment_settings.dart';

const businessSetupCompletedPrefKey = 'pos.setup.completed.v1';
const businessSetupRequiredPrefKey = 'pos.setup.required.v1';

bool hasRequiredBusinessProfile(BusinessProfile? profile) {
  if (profile == null) return false;
  return profile.shopName.trim().isNotEmpty;
}

bool hasRequiredPaymentSetup(ShopPaymentSettings? settings) {
  if (settings == null) return false;
  return settings.cashEnabled ||
      settings.bankEnabled ||
      settings.mobileMoneyEnabled;
}

bool inferBusinessSetupCompleted({
  required BusinessProfile? profile,
  required ShopPaymentSettings? settings,
  required bool hasReceiptTemplate,
}) {
  return hasRequiredBusinessProfile(profile) &&
      hasRequiredPaymentSetup(settings) &&
      hasReceiptTemplate;
}

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
    if (completed) {
      await _prefs.setBool(businessSetupRequiredPrefKey, false);
    }
    state = completed;
  }

  Future<void> markSetupRequired() async {
    await _prefs.setBool(businessSetupRequiredPrefKey, true);
    await _prefs.setBool(businessSetupCompletedPrefKey, false);
    state = false;
  }

  Future<bool> refreshFromLocalCache(AppDatabase db) async {
    final profile = await db.getBusinessProfile();
    final settings = profile != null
        ? businessProfileToPaymentSettings(profile)
        : null;
    final hasReceiptTemplate = await db.getLatestReceiptTemplate() != null;
    final completed = inferBusinessSetupCompleted(
      profile: profile,
      settings: settings,
      hasReceiptTemplate: hasReceiptTemplate,
    );
    await _prefs.setBool(businessSetupCompletedPrefKey, completed);
    if (completed) {
      await _prefs.setBool(businessSetupRequiredPrefKey, false);
    }
    state = completed;
    return completed;
  }

  Future<void> reset() => setCompleted(false);
}
