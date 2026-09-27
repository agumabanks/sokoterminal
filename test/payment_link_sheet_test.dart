import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soko_seller_terminal/src/core/app_providers.dart';
import 'package:soko_seller_terminal/src/features/payment_links/payment_links_screen.dart';
import 'helpers/test_helpers.dart';

void main() {
  Future<void> openSheet(
    WidgetTester tester,
    MockSellerApi api, {
    bool checkout = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sellerApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showGeneratePaymentLinkSheet(
                  context,
                  ref,
                  type: 'product',
                  remoteId: 10,
                  title: 'Test product',
                  defaultAmount: checkout ? 30000 : 10000,
                  checkoutLines: checkout
                      ? [
                          {
                            'type': 'product',
                            'remote_id': 10,
                            'quantity': 3,
                            'unit_amount': 10000,
                          },
                        ]
                      : null,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('three items previews fee and submits quantity once', (
    tester,
  ) async {
    final api = MockSellerApi();
    when(
      () => api.generatePaymentLink(
        type: 'product',
        remoteId: 10,
        amount: 10000,
        quantity: 3,
        serviceFeePercent: 5,
      ),
    ).thenAnswer(
      (_) async => {'url': 'https://example.test/pay/test', 'amount': 31500},
    );
    await openSheet(tester, api);
    await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '3');
    await tester.pump();
    expect(find.textContaining('31,500'), findsOneWidget);
    await tester.ensureVisible(find.text('Generate Link'));
    await tester.tap(find.text('Generate Link'));
    await tester.pumpAndSettle();
    expect(find.text('Link generated!'), findsOneWidget);
    verify(
      () => api.generatePaymentLink(
        type: 'product',
        remoteId: 10,
        amount: 10000,
        quantity: 3,
        serviceFeePercent: 5,
      ),
    ).called(1);
    expect(find.text('Generate Link'), findsNothing);
    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('invalid quantity or nonfinite fee does not submit', (
    tester,
  ) async {
    final api = MockSellerApi();
    await openSheet(tester, api);
    await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '0');
    await tester.enterText(
      find.widgetWithText(TextField, 'Mobile money charges (%)'),
      'NaN',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Generate Link'));
    await tester.tap(find.text('Generate Link'));
    await tester.pump();
    expect(find.textContaining('Enter a positive price'), findsOneWidget);
    verifyZeroInteractions(api);
    await tester.ensureVisible(find.text('Close'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('checkout submits the entire cart and an idempotency key', (
    tester,
  ) async {
    final api = MockSellerApi();
    when(
      () => api.generateCheckoutPaymentLink(
        lines: any(named: 'lines'),
        taxAmount: 0,
        serviceFeePercent: 5,
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (_) async => {'url': 'https://example.test/pay/cart', 'amount': 31500},
    );
    await openSheet(tester, api, checkout: true);
    expect(find.widgetWithText(TextField, 'Quantity'), findsNothing);
    await tester.ensureVisible(find.text('Generate Link'));
    await tester.tap(find.text('Generate Link'));
    await tester.pumpAndSettle();
    final args = verify(
      () => api.generateCheckoutPaymentLink(
        lines: captureAny(named: 'lines'),
        taxAmount: 0,
        serviceFeePercent: 5,
        idempotencyKey: captureAny(named: 'idempotencyKey'),
      ),
    ).captured;
    expect((args[0] as List).single['quantity'], 3);
    expect(args[1], isNotEmpty);
    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
  });
}
