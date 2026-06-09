import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_api_availability/google_api_availability.dart';

/// Tracks whether Firebase-backed services can be used on the current device.
class FirebaseRuntime {
  FirebaseRuntime._();
  static final instance = FirebaseRuntime._();

  bool _prepared = false;
  bool _firebaseEnabled = true;
  bool _googlePlayServicesAvailable = true;
  String? _disableReason;

  bool get firebaseEnabled => _firebaseEnabled;
  bool get googlePlayServicesAvailable => _googlePlayServicesAvailable;
  String? get disableReason => _disableReason;

  Future<bool> prepare() async {
    if (_prepared) return _firebaseEnabled;
    _prepared = true;

    if (kIsWeb || !Platform.isAndroid) {
      _firebaseEnabled = true;
      _googlePlayServicesAvailable = true;
      return _firebaseEnabled;
    }

    try {
      final availability = await GoogleApiAvailability.instance
          .checkGooglePlayServicesAvailability();
      _googlePlayServicesAvailable =
          availability == GooglePlayServicesAvailability.success;
      _firebaseEnabled = _googlePlayServicesAvailable;
      if (!_googlePlayServicesAvailable) {
        _disableReason = 'Google Play services unavailable: $availability';
      }
    } catch (e) {
      _googlePlayServicesAvailable = false;
      _firebaseEnabled = false;
      _disableReason = 'Google Play services check failed: $e';
    }

    return _firebaseEnabled;
  }

  void disable(String reason) {
    _firebaseEnabled = false;
    if (reason.trim().isNotEmpty) {
      _disableReason = reason;
    }
  }
}
