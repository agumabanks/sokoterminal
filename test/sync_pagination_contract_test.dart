import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soko_seller_terminal/src/core/config/app_config.dart';
import 'package:soko_seller_terminal/src/core/network/api_client.dart';
import 'package:soko_seller_terminal/src/core/network/seller_api.dart';
import 'helpers/test_helpers.dart';

class MockClient extends Mock implements ApiClient {}

void main() {
  late MockClient client;
  late SellerApi api;
  setUp(() {
    client = MockClient();
    api = SellerApi(
      client: client,
      storage: MockSecureStorage(),
      config: const AppConfig(
        apiBaseUrl: 'https://example.test/api/',
        connectTimeoutMs: 1000,
        receiveTimeoutMs: 1000,
        logLevel: 'none',
      ),
    );
  });
  test(
    'all pages share the same server window and retain every product',
    () async {
      final queries = <Map<String, dynamic>>[];
      when(
        () => client.get<dynamic>(any(), query: any(named: 'query')),
      ).thenAnswer((call) async {
        final query = Map<String, dynamic>.from(
          call.namedArguments[#query] as Map,
        );
        queries.add(query);
        final page = queries.length;
        return Response(
          requestOptions: RequestOptions(path: '/pull'),
          data: {
            'received_at': '2026-09-14T10:00:00Z',
            'since': query['since'],
            'products': [
              {'id': '$page'},
            ],
            'pagination': {
              'mode': 'cursor',
              'has_more_products': page < 3,
              'next_products': '$page',
            },
          },
        );
      });
      final result = await api.pullPosSync(since: DateTime.utc(2026, 9, 1));
      expect((result.data['products'] as List).map((p) => p['id']), [
        '1',
        '2',
        '3',
      ]);
      expect(queries[1]['until'], queries[2]['until']);
      expect(queries[1]['after_products'], '1');
      expect(queries[2]['after_products'], '2');
    },
  );
  test('a failed later page never returns a partial snapshot', () async {
    var calls = 0;
    when(
      () => client.get<dynamic>(any(), query: any(named: 'query')),
    ).thenAnswer((_) async {
      if (++calls == 2) {
        throw DioException(requestOptions: RequestOptions(path: '/pull'));
      }
      return Response(
        requestOptions: RequestOptions(path: '/pull'),
        data: {
          'received_at': '2026-09-14T10:00:00Z',
          'products': [
            {'id': '1'},
          ],
          'pagination': {
            'mode': 'cursor',
            'has_more_products': true,
            'next_products': '1',
          },
        },
      );
    });
    await expectLater(
      api.pullPosSync(since: DateTime.utc(2026)),
      throwsA(isA<DioException>()),
    );
    expect(calls, 2);
  });
  test(
    'nonadvancing server cursor fails instead of looping or advancing local state',
    () async {
      when(
        () => client.get<dynamic>(any(), query: any(named: 'query')),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/pull'),
          data: {
            'received_at': '2026-09-14T10:00:00Z',
            'products': [],
            'pagination': {
              'mode': 'cursor',
              'has_more_products': true,
              'next_products': '1',
            },
          },
        ),
      );
      await expectLater(
        api.pullPosSync(since: DateTime.utc(2026)),
        throwsFormatException,
      );
    },
  );
}
