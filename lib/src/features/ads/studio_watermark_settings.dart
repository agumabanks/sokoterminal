import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_providers.dart';
import 'brand_kit_screen.dart';

/// Where the watermark should be placed on exported artwork.
enum WatermarkPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  center,
}

extension WatermarkPositionLabel on WatermarkPosition {
  String get label => switch (this) {
        WatermarkPosition.topLeft => 'Top-left',
        WatermarkPosition.topRight => 'Top-right',
        WatermarkPosition.bottomLeft => 'Bottom-left',
        WatermarkPosition.bottomRight => 'Bottom-right',
        WatermarkPosition.center => 'Center',
      };
}

/// User-configurable watermark behaviour for Studio exports.
@immutable
class WatermarkSettings {
  const WatermarkSettings({
    this.enabled = true,
    this.opacity = 0.08,
    this.blendMode = 'modulate',
    this.position = WatermarkPosition.bottomRight,
    this.scale = 0.14,
    this.useBusinessLogo = false,
    this.prominentBrandStamp = false,
  });

  final bool enabled;
  final double opacity;
  final String blendMode;
  final WatermarkPosition position;
  final double scale;
  final bool useBusinessLogo;
  final bool prominentBrandStamp;

  WatermarkSettings copyWith({
    bool? enabled,
    double? opacity,
    String? blendMode,
    WatermarkPosition? position,
    double? scale,
    bool? useBusinessLogo,
    bool? prominentBrandStamp,
  }) =>
      WatermarkSettings(
        enabled: enabled ?? this.enabled,
        opacity: opacity ?? this.opacity,
        blendMode: blendMode ?? this.blendMode,
        position: position ?? this.position,
        scale: scale ?? this.scale,
        useBusinessLogo: useBusinessLogo ?? this.useBusinessLogo,
        prominentBrandStamp: prominentBrandStamp ?? this.prominentBrandStamp,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'opacity': opacity,
        'blendMode': blendMode,
        'position': position.name,
        'scale': scale,
        'useBusinessLogo': useBusinessLogo,
        'prominentBrandStamp': prominentBrandStamp,
      };

  factory WatermarkSettings.fromJson(Map<String, dynamic> json) {
    WatermarkPosition parsePosition(String? raw) =>
        WatermarkPosition.values.firstWhere(
          (p) => p.name == raw,
          orElse: () => WatermarkPosition.bottomRight,
        );

    return WatermarkSettings(
      enabled: json['enabled'] as bool? ?? true,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.08,
      blendMode: json['blendMode']?.toString() ?? 'modulate',
      position: parsePosition(json['position']?.toString()),
      scale: (json['scale'] as num?)?.toDouble() ?? 0.14,
      useBusinessLogo: json['useBusinessLogo'] as bool? ?? false,
      prominentBrandStamp: json['prominentBrandStamp'] as bool? ?? false,
    );
  }

  factory WatermarkSettings.fromPreset({bool prominent = false}) => prominent
      ? const WatermarkSettings(
          enabled: true,
          opacity: 0.80,
          blendMode: 'normal',
          position: WatermarkPosition.bottomRight,
          scale: 0.18,
          useBusinessLogo: false,
          prominentBrandStamp: true,
        )
      : const WatermarkSettings();
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

class WatermarkSettingsNotifier extends StateNotifier<WatermarkSettings> {
  WatermarkSettingsNotifier(this._prefs)
      : super(_load(_prefs));

  final SharedPreferences _prefs;
  static const _key = 'studio_watermark_settings_v1';

  static WatermarkSettings _load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return const WatermarkSettings();
    try {
      return WatermarkSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const WatermarkSettings();
    }
  }

  Future<void> update(WatermarkSettings value) async {
    state = value;
    await _persist();
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await _persist();
  }

  Future<void> setProminentBrandStamp(bool value) async {
    state = WatermarkSettings.fromPreset(prominent: value).copyWith(
      useBusinessLogo: state.useBusinessLogo,
      enabled: state.enabled,
    );
    await _persist();
  }

  Future<void> setOpacity(double value) async {
    state = state.copyWith(opacity: value.clamp(0.0, 1.0));
    await _persist();
  }

  Future<void> setScale(double value) async {
    state = state.copyWith(scale: value.clamp(0.02, 0.5));
    await _persist();
  }

  Future<void> setBlendMode(String value) async {
    state = state.copyWith(blendMode: value);
    await _persist();
  }

  Future<void> setPosition(WatermarkPosition value) async {
    state = state.copyWith(position: value);
    await _persist();
  }

  Future<void> setUseBusinessLogo(bool value) async {
    state = state.copyWith(useBusinessLogo: value);
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs.setString(_key, jsonEncode(state.toJson()));
  }
}

final watermarkSettingsProvider =
    StateNotifierProvider<WatermarkSettingsNotifier, WatermarkSettings>((ref) {
  return WatermarkSettingsNotifier(ref.read(sharedPreferencesProvider));
});

/// Non-destructive preview toggle for the editor canvas. Does NOT affect exports.
final watermarkPreviewProvider = StateProvider<bool>((ref) => false);

/// Blend modes supported by the watermark renderer.
const List<(String id, String label)> kWatermarkBlendModes = [
  ('normal', 'Normal'),
  ('overlay', 'Overlay'),
  ('multiply', 'Multiply'),
  ('screen', 'Screen'),
  ('softLight', 'Soft light'),
  ('colorBurn', 'Color burn'),
  ('modulate', 'Modulate'),
];

/// Resolve a user-facing blend-mode id to a Flutter [BlendMode].
BlendMode? watermarkBlendMode(String id) => switch (id) {
      'normal' => BlendMode.srcOver,
      'overlay' => BlendMode.overlay,
      'multiply' => BlendMode.multiply,
      'screen' => BlendMode.screen,
      'softLight' => BlendMode.softLight,
      'colorBurn' => BlendMode.colorBurn,
      'modulate' => BlendMode.modulate,
      _ => null,
    };

/// Returns the best available watermark source for the current settings.
///
/// If [useBusinessLogo] is true and the [BrandKit] has a logo, the local file
/// path is preferred; otherwise the network URL is returned. When neither is
/// available the Soko app logo asset is used.
String watermarkAssetPath({
  required WatermarkSettings settings,
  required BrandKit brandKit,
}) {
  if (settings.useBusinessLogo && brandKit.hasLogo) {
    return brandKit.effectiveLogoUrl;
  }
  return 'assets/images/app_logo.png';
}
