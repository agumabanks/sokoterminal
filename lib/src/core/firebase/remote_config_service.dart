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
