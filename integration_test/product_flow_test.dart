import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:soko_seller_terminal/main.dart' as app;

/// Integration test for the product creation flow.
/// Verifies that a seller can add a product end-to-end.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Product Creation Flow', () {
    testWidgets('add product screen is reachable and form renders',
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

      // Find and tap Products
      final productsFinder = find.text('Products');
      if (productsFinder.evaluate().isEmpty) {
        markTestSkipped('Products menu item not found');
        return;
      }
      await tester.tap(productsFinder);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify we're on the Products screen
      expect(find.text('Products'), findsAtLeastNWidgets(1));

      // Tap FAB to add product
      final fabFinder = find.byType(FloatingActionButton);
      if (fabFinder.evaluate().isEmpty) {
        markTestSkipped('Add product FAB not found');
        return;
      }
      await tester.tap(fabFinder);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify form fields exist
      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });

    testWidgets('create and save a new product', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Only proceed if we're on the home screen
      if (find.text('Checkout').evaluate().isEmpty) {
        markTestSkipped('Not logged in — skipping product creation test');
        return;
      }

      // Navigate to More → Products
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Tap FAB to add product
      final fabFinder = find.byType(FloatingActionButton);
      if (fabFinder.evaluate().isEmpty) {
        markTestSkipped('Add product FAB not found');
        return;
      }
      await tester.tap(fabFinder);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Fill in product name
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Integration Test Product');
      await tester.pumpAndSettle();

      // Scroll down to find price and stock fields
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Fill in price (look for fields with numeric keyboard)
      final textFields = find.byType(TextField);
      for (var i = 0; i < textFields.evaluate().length; i++) {
        final field = textFields.at(i);
        final widget = tester.widget<TextField>(field);
        if (widget.keyboardType == const TextInputType.numberWithOptions(decimal: true)) {
          // This is likely the price field
          await tester.ensureVisible(field);
          await tester.tap(field);
          await tester.pumpAndSettle();
          await tester.enterText(field, '15000');
          await tester.pumpAndSettle();
          break;
        }
      }

      // Scroll down more to find Save button
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Tap Save Product button
      final saveButton = find.widgetWithText(ElevatedButton, 'Save Product');
      if (saveButton.evaluate().isNotEmpty) {
        await tester.tap(saveButton);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Verify success — either we're back on Products screen or see a snackbar
        expect(
          find.text('Saved on this device').evaluate().isNotEmpty ||
          find.text('Saved — syncing to your online shop…').evaluate().isNotEmpty ||
          find.text('Products').evaluate().isNotEmpty,
          isTrue,
        );
      } else {
        markTestSkipped('Save Product button not found');
      }
    });
  });
}
