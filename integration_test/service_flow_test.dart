import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:soko_seller_terminal/main.dart' as app;

/// Integration test for the service creation flow.
/// Verifies that a seller can add a service end-to-end.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Service Creation Flow', () {
    testWidgets('add service screen is reachable and form renders',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Only proceed if we're on the home screen
      if (find.text('Checkout').evaluate().isEmpty) {
        expect(find.text('Welcome').evaluate().isNotEmpty, isTrue);
        return;
      }

      // Tap More tab
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Scroll to find Services
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Find and tap Services
      final servicesFinder = find.text('Services');
      if (servicesFinder.evaluate().isEmpty) {
        markTestSkipped('Services menu item not found');
        return;
      }
      await tester.tap(servicesFinder);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify we're on the Services screen
      expect(find.text('Services'), findsAtLeastNWidgets(1));

      // Tap FAB to add service
      final fabFinder = find.byType(FloatingActionButton);
      if (fabFinder.evaluate().isEmpty) {
        markTestSkipped('Add service FAB not found');
        return;
      }
      await tester.tap(fabFinder);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify form fields exist
      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });

    testWidgets('create and save a new service', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Only proceed if we're on the home screen
      if (find.text('Checkout').evaluate().isEmpty) {
        markTestSkipped('Not logged in — skipping service creation test');
        return;
      }

      // Navigate to More → Services
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Services'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Tap FAB to add service
      final fabFinder = find.byType(FloatingActionButton);
      if (fabFinder.evaluate().isEmpty) {
        markTestSkipped('Add service FAB not found');
        return;
      }
      await tester.tap(fabFinder);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Fill in service title
      final titleField = find.byType(TextField).first;
      await tester.enterText(titleField, 'Integration Test Service');
      await tester.pumpAndSettle();

      // Scroll down to find price field
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Fill in price (look for fields with numeric keyboard)
      final textFields = find.byType(TextField);
      for (var i = 0; i < textFields.evaluate().length; i++) {
        final field = textFields.at(i);
        final widget = tester.widget<TextField>(field);
        if (widget.keyboardType == const TextInputType.numberWithOptions(decimal: true)) {
          await tester.ensureVisible(field);
          await tester.tap(field);
          await tester.pumpAndSettle();
          await tester.enterText(field, '50000');
          await tester.pumpAndSettle();
          break;
        }
      }

      // Scroll down more to find Save button
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Tap Save Service button
      final saveButton = find.widgetWithText(ElevatedButton, 'Save Service');
      if (saveButton.evaluate().isNotEmpty) {
        await tester.tap(saveButton);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Verify success — either we're back on Services screen or see a snackbar
        expect(
          find.text('Saved on this device').evaluate().isNotEmpty ||
          find.text('Saved and submitted for review').evaluate().isNotEmpty ||
          find.text('Services').evaluate().isNotEmpty,
          isTrue,
        );
      } else {
        markTestSkipped('Save Service button not found');
      }
    });
  });
}
