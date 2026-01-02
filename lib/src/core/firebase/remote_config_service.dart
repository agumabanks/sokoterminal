import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase Remote Config service for dynamic configuration
class RemoteConfigService {
  RemoteConfigService._();
  static final instance = RemoteConfigService._();
  
  final FirebaseRemoteConfig _config = FirebaseRemoteConfig.instance;
  bool _initialized = false;
  
  /// Initialize remote config with defaults
  Future<void> init() async {
    if (_initialized) return;
    
    await _config.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    
    // Set defaults
    await _config.setDefaults({
      'require_phone_verification': false,
      'min_sale_amount': 0,
      'maintenance_mode': false,
      'max_offline_days': 7,
      'sync_interval_seconds': 30,
      // Feature flags (GA rollout)
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
    });
    
    // Fetch and activate
    try {
      await _config.fetchAndActivate();
    } catch (_) {
      // Use defaults on failure
    }
    
    _initialized = true;
  }
  
  /// Whether phone verification is required (admin controlled)
  bool get requirePhoneVerification => _config.getBool('require_phone_verification');
  
  /// Minimum sale amount
  int get minSaleAmount => _config.getInt('min_sale_amount');
  
  /// Maintenance mode flag
  bool get maintenanceMode => _config.getBool('maintenance_mode');
  
  /// Max days data can be offline before warning
  int get maxOfflineDays => _config.getInt('max_offline_days');
  
  /// Sync interval in seconds
  int get syncIntervalSeconds => _config.getInt('sync_interval_seconds');

  bool get ffPosVoids => _config.getBool('ff_pos_voids');
  bool get ffProductVariantsEditor => _config.getBool('ff_product_variants_editor');
  bool get ffPrintDiagnostics => _config.getBool('ff_print_diagnostics');
  bool get ffDeliveryRadiusSettingsV2 => _config.getBool('ff_delivery_radius_settings_v2');
  bool get ffUnifiedInbox => _config.getBool('ff_unified_inbox');
  bool get ffCustomerProfile => _config.getBool('ff_customer_profile');
  bool get ffContactsEnrichment => _config.getBool('ff_contacts_enrichment');
  bool get ffSokoStudio => _config.getBool('ff_soko_studio');
  bool get ffBusinessSetupWizard => _config.getBool('ff_business_setup_wizard');
  bool get ffExpensesV1 => _config.getBool('ff_expenses_v1');
  
  /// Force refresh config
  Future<void> refresh() async {
    try {
      await _config.fetchAndActivate();
    } catch (_) {}
  }
}

/// Provider for remote config service
final remoteConfigProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService.instance;
});
