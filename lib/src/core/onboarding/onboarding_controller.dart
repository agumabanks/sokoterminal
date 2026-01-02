import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_providers.dart';

/// Onboarding state tracking seller setup progress
class OnboardingState {
  const OnboardingState({
    this.currentStage = 2, // Start at stage 2 (after account creation)
    this.isComplete = false,
    this.shopData = const {},
  });

  final int currentStage;
  final bool isComplete;
  final Map<String, dynamic> shopData;

  OnboardingState copyWith({
    int? currentStage,
    bool? isComplete,
    Map<String, dynamic>? shopData,
  }) {
    return OnboardingState(
      currentStage: currentStage ?? this.currentStage,
      isComplete: isComplete ?? this.isComplete,
      shopData: shopData ?? this.shopData,
    );
  }

  // Stage completion checks
  bool get shopBasicsComplete => 
      shopData['name'] != null && shopData['name'].toString().isNotEmpty;
  
  bool get businessDetailsComplete => 
      shopData['address'] != null && shopData['address'].toString().isNotEmpty;
  
  bool get paymentConfigComplete =>
      shopData['cash_on_delivery_status'] == 1 ||
      shopData['bank_payment_status'] == 1;
}

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController(this._prefs) : super(const OnboardingState()) {
    _loadState();
  }

  final SharedPreferences _prefs;
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _shopDataKey = 'onboarding_shop_data';
  static const String _onboardingStageKey = 'onboarding_stage';

  Future<void> _loadState() async {
    final isComplete = _prefs.getBool(_onboardingCompleteKey) ?? false;
    final shopDataJson = _prefs.getString(_shopDataKey);
    final savedStage = _prefs.getInt(_onboardingStageKey);
    
    Map<String, dynamic> shopData = {};
    if (shopDataJson != null) {
      try {
        final decoded = jsonDecode(shopDataJson);
        if (decoded is Map<String, dynamic>) {
          shopData = Map<String, dynamic>.from(decoded);
        } else if (decoded is Map) {
          shopData = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    final stage = isComplete ? 5 : (savedStage ?? 2);

    state = OnboardingState(
      currentStage: stage.clamp(2, 5),
      isComplete: isComplete,
      shopData: shopData,
    );
  }

  void updateShopData(Map<String, dynamic> data) {
    state = state.copyWith(
      shopData: {...state.shopData, ...data},
    );
    _saveState();
  }

  void nextStage() {
    if (state.currentStage < 5) {
      state = state.copyWith(currentStage: state.currentStage + 1);
      _saveState();
    }
  }

  void previousStage() {
    if (state.currentStage > 2) {
      state = state.copyWith(currentStage: state.currentStage - 1);
      _saveState();
    }
  }

  void goToStage(int stage) {
    if (stage >= 2 && stage <= 5) {
      state = state.copyWith(currentStage: stage);
      _saveState();
    }
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(isComplete: true, currentStage: 5);
    await _prefs.setBool(_onboardingCompleteKey, true);
    await _prefs.remove(_shopDataKey); // Clear draft data
    await _prefs.remove(_onboardingStageKey);
  }

  Future<void> skip() async {
    // Allow skipping to dashboard but mark as incomplete
    state = state.copyWith(isComplete: false);
  }

  Future<void> _saveState() async {
    // Save shop data draft for resuming later
    if (state.shopData.isEmpty) {
      await _prefs.remove(_shopDataKey);
    } else {
      await _prefs.setString(_shopDataKey, jsonEncode(state.shopData));
    }
    await _prefs.setInt(_onboardingStageKey, state.currentStage);
  }

  Future<void> reset() async {
    await _prefs.remove(_onboardingCompleteKey);
    await _prefs.remove(_shopDataKey);
    await _prefs.remove(_onboardingStageKey);
    state = const OnboardingState();
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingController(prefs);
});

/// Check if user needs onboarding
final needsOnboardingProvider = Provider<bool>((ref) {
  final onboarding = ref.watch(onboardingControllerProvider);
  return !onboarding.isComplete;
});
