import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/util/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Haptics', () {
    final List<MethodCall> methodCalls = [];

    setUp(() {
      methodCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('selection triggers HapticFeedback.selectionClick', () {
      Haptics.selection();
      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, 'HapticFeedback.vibrate');
      expect(methodCalls.first.arguments, 'HapticFeedbackType.selectionClick');
    });

    test('impact triggers HapticFeedback.mediumImpact', () {
      Haptics.impact();
      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, 'HapticFeedback.vibrate');
      expect(methodCalls.first.arguments, 'HapticFeedbackType.mediumImpact');
    });

    test('soft triggers HapticFeedback.lightImpact', () {
      Haptics.soft();
      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, 'HapticFeedback.vibrate');
      expect(methodCalls.first.arguments, 'HapticFeedbackType.lightImpact');
    });

    test('warning triggers HapticFeedback.heavyImpact', () {
      Haptics.warning();
      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, 'HapticFeedback.vibrate');
      expect(methodCalls.first.arguments, 'HapticFeedbackType.heavyImpact');
    });

    test('success triggers HapticFeedback.mediumImpact', () {
      Haptics.success();
      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, 'HapticFeedback.vibrate');
      expect(methodCalls.first.arguments, 'HapticFeedbackType.mediumImpact');
    });

    test('does not cause stack overflow or infinite recursion', () {
      // Regression guard for the bug where Haptics.soft() called itself.
      // Each call should complete exactly once and map to the platform channel.
      Haptics.selection();
      Haptics.impact();
      Haptics.soft();
      Haptics.warning();
      Haptics.success();
      expect(methodCalls, hasLength(5));
    });
  });
}
