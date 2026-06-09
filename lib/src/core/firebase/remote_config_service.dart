import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_runtime.dart';

/// Firebase Remote Config service for dynamic configuration
class RemoteConfigService {
  RemoteConfigService._();
  static final instance = RemoteConfigService._();

  static const Map<String, Object> _defaults = {
    'require_phone_verification': false,
    'min_sale_amount': 0,
    'maintenance_mode': false,
    'max_offline_days': 7,
    'sync_interval_seconds': 30,
    'ff_pos_voids': true,
    'ff_product_variants_editor': true,
    'ff_print_diagnostics': true,
    'ff_delivery_radius_settings_v2': true,
    'ff_unified_inbox': true,
    'ff_customer_profile': false,
    'ff_contacts_enrichment': true,
    'ff_soko_studio': false,
    'ff_business_setup_wizard': false,
    'ff_expenses_v1': false,
  };

  FirebaseRemoteConfig? _config;
  bool _initialized = false;

  /// Initialize remote config with defaults
  Future<void> init() async {
    if (_initialized) return;

    if (!FirebaseRuntime.instance.firebaseEnabled) {
      _initialized = true;
      return;
    }

    final config = FirebaseRemoteConfig.instance;
    _config = config;

    await config.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );

    // Set defaults
    await config.setDefaults(_defaults);

    // Fetch and activate
    try {
      await config.fetchAndActivate();
    } catch (_) {
      // Use defaults on failure
    }

    _initialized = true;
  }

  /// Whether phone verification is required (admin controlled)
  bool get requirePhoneVerification => _getBool('require_phone_verification');

  /// Minimum sale amount
  int get minSaleAmount => _getInt('min_sale_amount');

  /// Maintenance mode flag
  bool get maintenanceMode => _getBool('maintenance_mode');

  /// Max days data can be offline before warning
  int get maxOfflineDays => _getInt('max_offline_days');

  /// Sync interval in seconds
  int get syncIntervalSeconds => _getInt('sync_interval_seconds');

  bool get ffPosVoids => _getBool('ff_pos_voids');
  bool get ffProductVariantsEditor => _getBool('ff_product_variants_editor');
  bool get ffPrintDiagnostics => _getBool('ff_print_diagnostics');
  bool get ffDeliveryRadiusSettingsV2 =>
      _getBool('ff_delivery_radius_settings_v2');
  bool get ffUnifiedInbox => _getBool('ff_unified_inbox');
  bool get ffCustomerProfile => _getBool('ff_customer_profile');
  bool get ffContactsEnrichment => _getBool('ff_contacts_enrichment');
  bool get ffSokoStudio => _getBool('ff_soko_studio');
  bool get ffBusinessSetupWizard => _getBool('ff_business_setup_wizard');
  bool get ffExpensesV1 => _getBool('ff_expenses_v1');

  /// Force refresh config
  Future<void> refresh() async {
    final config = _config;
    if (config == null) return;
    try {
      await config.fetchAndActivate();
    } catch (_) {}
  }

  bool _getBool(String key) {
    final config = _config;
    if (config != null) return config.getBool(key);
    final fallback = _defaults[key];
    return fallback is bool ? fallback : false;
  }

  int _getInt(String key) {
    final config = _config;
    if (config != null) return config.getInt(key);
    final fallback = _defaults[key];
    return fallback is int ? fallback : 0;
  }
}

/// Provider for remote config service
final remoteConfigProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService.instance;
});
