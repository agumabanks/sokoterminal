
import 'package:flutter/services.dart';

/// Centralized haptic feedback — the app's physical voice.
///
/// Every tap, toggle, and transition has a specific haptic signature.
/// This isn't random buzzing. It's choreography.
class Haptics {
  Haptics._();

  /// Selection: tab bar tap, list item pick, toggle change.
  /// A light tick — "I acknowledged your choice."
  static void selection() => HapticFeedback.selectionClick();

  /// Impact: primary button press, checkout confirm, successful save.
  /// A confident thud — "Done."
  static void impact() => HapticFeedback.mediumImpact();

  /// Soft: toggle on/off, switch flip, minor state change.
  /// A gentle nudge — "Changed."
  static void soft() => HapticFeedback.lightImpact();

  /// Warning: destructive action, validation error, failed attempt.
  /// A firm buzz — "Wait. Are you sure?"
  static void warning() => HapticFeedback.heavyImpact();

  /// Success: payment complete, order placed, sync finished.
  /// Same as impact — confident, final.
  static void success() => HapticFeedback.mediumImpact();
}
