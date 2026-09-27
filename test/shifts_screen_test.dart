import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/app_providers.dart';
import 'package:soko_seller_terminal/src/features/shifts/shifts_screen.dart';
import 'helpers/test_helpers.dart';

void main() {
  testWidgets(
    'cash summary fits a narrow phone and refreshes after a cash movement',
    (tester) async {
      final db = createTestDatabase();

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await db.openShift(openingFloat: 10000);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: ShiftsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Expected cash in the till'), findsOneWidget);
      expect(find.textContaining('10,000'), findsWidgets);
      await db.recordCashMovement(type: 'float', amount: 5000);
      await tester.pumpAndSettle();
      expect(find.textContaining('15,000'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(db.close);
    },
  );

  testWidgets(
    'empty opening cash is rejected instead of silently recording zero',
    (tester) async {
      final db = createTestDatabase();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: ShiftsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 20 && find.text('Start shift').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.ensureVisible(find.text('Start shift'));
      await tester.tap(find.text('Start shift'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Start shift'));
      await tester.pump();
      expect(
        find.text('Enter the amount you counted, including 0.'),
        findsOneWidget,
      );
      expect(await db.getOpenShift(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(db.close);
    },
  );
}
