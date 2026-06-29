import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soko_seller_terminal/src/core/config/app_config.dart';
import 'package:soko_seller_terminal/src/core/network/api_client.dart';
import 'package:soko_seller_terminal/src/core/storage/secure_storage.dart';

class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  group('ApiClient 401 interceptor', () {
    late MockSecureStorage storage;
    late ApiClient client;
    var logoutCalled = false;

    setUp(() {
      storage = MockSecureStorage();
      logoutCalled = false;

      when(() => storage.readAccessToken())
          .thenAnswer((_) async => 'valid_token');
      when(() => storage.readPosSessionToken())
          .thenAnswer((_) async => null);
      when(() => storage.writeAccessToken(any()))
          .thenAnswer((_) async {});
      when(() => storage.deleteAccessToken())
          .thenAnswer((_) async {});
      when(() => storage.deletePosSessionToken())
          .thenAnswer((_) async {});

      client = ApiClient(
        config: const AppConfig(
          apiBaseUrl: 'https://example.com/api/',
          connectTimeoutMs: 5000,
          receiveTimeoutMs: 5000,
          logLevel: 'none',
        ),
        secureStorage: storage,
        onAuthExpired: () {
          logoutCalled = true;
        },
      );
    });

    test(
        'does NOT logout when retry fails with 401 after successful refresh',
        () async {
      // The key fix is in the onError interceptor: after a successful token
      // refresh, if the retry still 401s, the interceptor must NOT call
      // _performLogout. It should just pass the error through.
      final source =
          File('lib/src/core/network/api_client.dart').readAsStringSync();

      final refreshBlockStart = source.indexOf('if (refreshed) {');
      expect(refreshBlockStart, isNonNegative);
      // Find the matching else for the refreshed branch by looking for the
      // "Refresh failed" comment, which sits just above the else clause.
      final refreshBlockEnd = source.indexOf(
        '// Refresh failed or returned no token',
        refreshBlockStart,
      );
      expect(refreshBlockEnd, isNonNegative);
      final refreshBlock = source.substring(refreshBlockStart, refreshBlockEnd);

      expect(
        refreshBlock.contains('handler.next(retryErr)'),
        isTrue,
        reason: 'Retry 401 after successful refresh must not trigger logout',
      );
      expect(
        refreshBlock.contains('_performLogout'),
        isFalse,
        reason: 'Retry 401 must not call _performLogout',
      );

      // The public guard still resets correctly.
      client.resetLogoutGuard();
      expect(logoutCalled, isFalse);
    });

    test('logout guard resets even when callback is null or fails', () {
      final source =
          File('lib/src/core/network/api_client.dart').readAsStringSync();

      final logoutBlockStart = source.indexOf('Future<void> _performLogout(');
      final logoutBlockEnd = source.indexOf('\n  }', logoutBlockStart);
      expect(logoutBlockStart, isNonNegative);
      expect(logoutBlockEnd, isNonNegative);
      final logoutBlock = source.substring(logoutBlockStart, logoutBlockEnd);

      expect(
        logoutBlock.contains('_onAuthExpired?.call();'),
        isTrue,
        reason: '_performLogout must invoke the logout callback',
      );
      expect(
        logoutBlock.contains('if (_isLoggingOut)'),
        isTrue,
        reason: '_performLogout must reset _isLoggingOut if the callback '
            'did not (e.g. null callback)',
      );

      client.resetLogoutGuard();
      expect(logoutCalled, isFalse);
    });

    test('token refresh uses single-flight completer', () {
      final source =
          File('lib/src/core/network/api_client.dart').readAsStringSync();

      expect(
        source.contains('Completer<bool>? _refreshCompleter;'),
        isTrue,
        reason: 'Concurrent refresh attempts must be serialized',
      );
      expect(
        source.contains('return _refreshCompleter!.future;'),
        isTrue,
        reason: 'In-flight refresh requests must await the same future',
      );
      expect(
        source.contains("if (!_refreshCompleter!.isCompleted)"),
        isTrue,
        reason: 'Refresh completer must be guarded against double-complete',
      );
    });
  });
}
