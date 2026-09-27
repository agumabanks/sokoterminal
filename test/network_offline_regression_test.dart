import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soko_seller_terminal/src/core/auth/offline_credentials.dart';
import 'package:soko_seller_terminal/src/core/network/api_client.dart';
import 'package:soko_seller_terminal/src/core/network/dio_auth_utils.dart';
import 'helpers/test_helpers.dart';

class Adapter implements HttpClientAdapter {
  Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  test('parallel reads with different queries never share a page', () async {
    final dio = Dio()..interceptors.add(RateLimitInterceptor());
    dio.httpClientAdapter = Adapter((options) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return jsonBody({'page': options.queryParameters['page']});
    });
    final result = await Future.wait([
      dio.get('https://example.test/pull', queryParameters: {'page': 1}),
      dio.get('https://example.test/pull', queryParameters: {'page': 2}),
    ]);
    expect(result.map((r) => r.data['page']), [1, 2]);
    dio.close();
  });

  test(
    'slow identical reads complete all callers without replacing their tracker',
    () async {
      var calls = 0;
      final pending = Completer<ResponseBody>();
      final dio = Dio()
        ..interceptors.add(RateLimitInterceptor(minIntervalMs: 1));
      dio.httpClientAdapter = Adapter((_) {
        calls++;
        return pending.future;
      });
      final first = dio.get('https://example.test/pull');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final second = dio.get('https://example.test/pull');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      pending.complete(jsonBody({'ok': true}));
      await Future.wait([first, second]).timeout(const Duration(seconds: 2));
      expect(calls, 1);
      dio.close();
    },
  );

  test(
    'failed read without duplicate callers does not leak an unhandled tracker error',
    () async {
      final dio = Dio()..interceptors.add(RateLimitInterceptor());
      dio.httpClientAdapter = Adapter(
        (_) async => jsonBody({'error': 'unavailable'}, 503),
      );
      await expectLater(
        dio.get('https://example.test/pull'),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);
      dio.close();
    },
  );

  test('403 is a permission failure, not an expired cloud login', () {
    expect(DioAuthUtils.isAuthStatus(401), isTrue);
    expect(DioAuthUtils.isAuthStatus(403), isFalse);
  });

  test(
    'expired cloud token preserves authenticated offline unlock and account isolation',
    () async {
      final storage = MockSecureStorage();
      final values = <String, String>{};
      when(
        () => storage.readAccessToken(),
      ).thenAnswer((_) async => 'expired-cloud-token');
      when(
        () => storage.readAccessTokenExpiresAt(),
      ).thenAnswer((_) async => DateTime(2020));
      when(
        () => storage.read(key: any(named: 'key')),
      ).thenAnswer((call) async => values[call.namedArguments[#key]]);
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((call) async {
        values[call.namedArguments[#key] as String] =
            call.namedArguments[#value] as String;
      });
      final credentials = OfflineCredentials(storage);
      await credentials.save('seller-a', 'correct-password', pin: false);
      expect(
        await credentials.verify('seller-a', 'correct-password', pin: false),
        isTrue,
      );
      expect(
        await credentials.verify('seller-b', 'correct-password', pin: false),
        isFalse,
      );
      values['login_type'] = 'staff';
      expect(
        await credentials.verify('seller-a', 'correct-password', pin: false),
        isFalse,
      );
      verifyNever(() => storage.deleteAccessToken());
    },
  );
}
