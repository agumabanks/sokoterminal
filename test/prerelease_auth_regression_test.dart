import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pre-release auth regressions', () {
    test('GoRouter redirect does not use ref.watch', () {
      final source = File('lib/src/app.dart').readAsStringSync();
      final redirectStart = source.indexOf('redirect: (context, state) {');
      expect(
        redirectStart,
        isNonNegative,
        reason: 'Expected GoRouter redirect callback in lib/src/app.dart',
      );

      final routesStart = source.indexOf('routes: [', redirectStart);
      expect(
        routesStart,
        isNonNegative,
        reason: 'Expected routes list after GoRouter redirect callback',
      );

      final redirectBlock = source.substring(redirectStart, routesStart);
      expect(
        redirectBlock.contains('ref.watch('),
        isFalse,
        reason: 'ref.watch must not be used inside GoRouter redirect logic',
      );
      expect(
        redirectBlock.contains('ref.read('),
        isTrue,
        reason: 'redirect should read stable provider snapshots instead',
      );
    });

    test('auth controller verifies token persistence before authenticated', () {
      final source =
          File('lib/src/features/auth/auth_controller.dart').readAsStringSync();

      expect(source.contains('Future<String> _persistAccessToken('), isTrue);
      expect(source.contains('await _storage.writeAccessToken(normalized);'), isTrue);
      expect(source.contains('final persisted = await _storage.readAccessToken();'), isTrue);
      expect(
        source.contains("Unable to persist the access token on this device. Please try again."),
        isTrue,
      );

      final loginStart = source.indexOf('Future<void> login({');
      final loginEnd = source.indexOf(
        'Future<Map<String, dynamic>> checkUserExistence',
        loginStart,
      );
      expect(loginStart, isNonNegative);
      expect(loginEnd, isNonNegative);
      final loginBlock = source.substring(loginStart, loginEnd);

      final persistIndex =
          loginBlock.indexOf('final persistedToken = await _persistAccessToken(token);');
      final authIndex = loginBlock.indexOf('status: AuthStatus.authenticated');
      final persistedTokenUseIndex = loginBlock.indexOf('token: persistedToken');

      expect(
        persistIndex,
        isNonNegative,
        reason: 'Login must persist and verify the access token first',
      );
      expect(authIndex, greaterThan(persistIndex));
      expect(persistedTokenUseIndex, greaterThan(persistIndex));
    });

    test('auth controller no longer schedules a periodic token refresh', () {
      final source =
          File('lib/src/features/auth/auth_controller.dart').readAsStringSync();

      expect(
        source.contains('_scheduleTokenRefresh'),
        isFalse,
        reason: 'Proactive periodic refresh was removed because Sanctum '
            'tokens do not expire and the refresh endpoint deletes tokens',
      );
      expect(
        source.contains('Timer.periodic'),
        isFalse,
        reason: 'No periodic timer should be used for token refresh',
      );
      expect(
        source.contains('Future<bool> refreshToken()'),
        isTrue,
        reason: 'Manual/foreground refreshToken() must still exist',
      );
    });

    test('login and quick PIN support remember_device flag', () {
      final source =
          File('lib/src/features/auth/auth_controller.dart').readAsStringSync();

      expect(
        source.contains('bool rememberDevice = false'),
        isTrue,
        reason: 'login() and loginWithQuickPin() must accept rememberDevice',
      );
      expect(
        source.contains("'remember_me': rememberDevice,"),
        isTrue,
        reason: 'Seller password login must send remember_me to backend',
      );
      expect(
        source.contains("'remember_me': rememberDevice,"),
        isTrue,
        reason: 'PIN login must send remember_me to backend',
      );
      expect(
        source.contains('Future<void> _persistTokenMeta('),
        isTrue,
        reason: 'Token expiry and remember flag must be persisted together',
      );
    });

    test('secure storage exposes remember-device and token-expiry keys', () {
      final source =
          File('lib/src/core/storage/secure_storage.dart').readAsStringSync();

      expect(
        source.contains('remember_device'),
        isTrue,
        reason: 'Remember-device flag must be stored',
      );
      expect(
        source.contains('access_token_expires_at'),
        isTrue,
        reason: 'Token expiry must be stored for offline validation',
      );
    });

    test('splash screen rejects locally expired tokens before sync', () {
      final source =
          File('lib/src/features/splash/splash_screen.dart').readAsStringSync();

      expect(
        source.contains('readAccessTokenExpiresAt'),
        isTrue,
        reason: 'Splash must read the stored token expiry',
      );
      expect(
        source.contains('DateTime.now().toUtc().isAfter(expiresAt)'),
        isTrue,
        reason: 'Splash must reject tokens whose expiry has passed',
      );
    });

    test('phone fallback retries seller password login with multiple UG variants', () {
      final source =
          File('lib/src/features/auth/auth_controller.dart').readAsStringSync();

      expect(
        source.contains('List<String> _loginIdentifierCandidates({'),
        isTrue,
      );
      expect(
        source.contains("addCandidate('+\$digits');"),
        isTrue,
        reason: 'Password login fallback must retry with +256 E.164 format',
      );
      expect(
        source.contains(
          "addCandidate('0\${digits.substring(3)}');",
        ),
        isTrue,
        reason: 'Password login fallback must also retry with the local 0-prefixed format',
      );
      expect(
        source.contains(
          '[Auth] Retrying seller password login with alternate phone format',
        ),
        isTrue,
      );
    });
  });
}
