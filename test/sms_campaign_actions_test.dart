import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/features/marketing/bulk_sms_screen.dart';

void main() {
  testWidgets('SMS actions stay readable on narrow screens with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var saves = 0;
    var sends = 0;
    Future<void> show({bool busy = false}) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SmsCampaignActions(
                  saving: busy,
                  sending: busy,
                  onSave: () => saves++,
                  onSend: () => sends++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await show();
    expect(tester.takeException(), isNull);
    final queue = tester.getRect(
      find.byWidgetPredicate((w) => w is ElevatedButton),
    );
    final save = tester.getRect(
      find.byWidgetPredicate((w) => w is OutlinedButton),
    );
    expect(queue.width, 272);
    expect(save.top, greaterThan(queue.bottom));
    expect(queue.height, lessThan(110));
    expect(save.height, lessThan(110));
    await tester.tap(find.text('Queue campaign'));
    await tester.tap(find.text('Save template'));
    expect([saves, sends], [1, 1]);
    await show(busy: true);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byWidgetPredicate((w) => w is ElevatedButton),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byWidgetPredicate((w) => w is OutlinedButton),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
