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
