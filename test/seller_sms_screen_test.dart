import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soko_seller_terminal/src/core/app_providers.dart';
import 'package:soko_seller_terminal/src/features/marketing/bulk_sms_screen.dart';
import 'helpers/test_helpers.dart';

void main() {
  testWidgets(
    'SMS dashboard loads credits, exposes readable actions and validates before sending',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = MockSellerApi();
      when(() => api.fetchSmsDashboard()).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/sms'),
          data: {
            'data': {
              'credits': {'balance': 1250},
              'campaigns': [],
              'templates': [],
              'transactions': [],
            },
          },
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sellerApiProvider.overrideWithValue(api),
            customersStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(home: BulkSmsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('1250'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Queue campaign'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Queue campaign'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Queue campaign'));
      await tester.pump();
      expect(find.text('Message is required'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Activity'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('No SMS credit activity yet.'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No SMS credit activity yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      verifyNever(() => api.createSmsCampaign(any()));
    },
  );
}
