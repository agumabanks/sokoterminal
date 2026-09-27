import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/features/payment_links/payment_links_screen.dart';
import 'package:soko_seller_terminal/src/features/payment_links/payment_link_share.dart';

void main() {
  testWidgets(
    'picker shows products on a narrow phone and services while keyboard is open',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        const MaterialApp(
          home: PaymentLinkItemPicker(
            choices: [
              (type: 'product', id: 1, title: 'Coffee', price: 10000),
              (type: 'service', id: 2, title: 'Logo design', price: 20000),
            ],
          ),
        ),
      );
      expect(find.text('Coffee').hitTestable(), findsOneWidget);
      expect(find.text('Logo design').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Services'));
      await tester.pumpAndSettle();
      expect(find.text('Coffee'), findsNothing);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.enterText(find.byType(TextField), 'logo');
      await tester.pumpAndSettle();
      expect(find.text('Logo design').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('share card renders an actual PNG for a browser payment URL', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final proofFont = File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
      if (await proofFont.exists()) {
        final fontBytes = await proofFont.readAsBytes();
        await (FontLoader(
          'Roboto',
        )..addFont(Future.value(ByteData.sublistView(fontBytes)))).load();
      }
      final bytes = await paymentLinkQrCard({
        'url': 'https://soko24.co/pay/QRTEST123',
        'title': 'Coffee × 3',
        'currency': 'UGX',
        'amount': 31500,
        'pricing': {'service_fee': 1500, 'service_fee_percent': 5},
      });
      expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
      await File('/tmp/soko-payment-qr-proof.png').writeAsBytes(bytes);
    });
  });

  test('sharing rejects a non-web payment target', () async {
    await expectLater(
      paymentLinkQrCard({'url': 'javascript:alert(1)'}),
      throwsFormatException,
    );
  });
}
