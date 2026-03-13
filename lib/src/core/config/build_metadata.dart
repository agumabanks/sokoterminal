import 'package:flutter/foundation.dart';

class BuildMetadata {
  const BuildMetadata._();

  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'unknown',
  );

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  static String notificationPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'android';
    }
  }
}
