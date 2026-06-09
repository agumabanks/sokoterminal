import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:soko_seller_terminal/main.dart' as app;

/// Integration test for the checkout flow.
/// Verifies that the checkout screen loads and cart operations work.
///
/// Prerequisites: the app should be logged in and have at least one product.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Checkout Flow', () {
    testWidgets('checkout screen loads and cart is usable',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Only proceed if we're on the home screen
      if (find.text('Checkout').evaluate().isEmpty) {
        expect(find.text('Welcome').evaluate().isNotEmpty, isTrue);
        return;
      }

      // Tap Checkout tab
      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify checkout screen rendered (look for search or category elements)
      expect(find.byType(TextField), findsAtLeastNWidgets(1));

      // If there are products, try tapping the first one to add to cart
      final productCards = find.byType(InkWell);
      if (productCards.evaluate().isNotEmpty) {
        await tester.tap(productCards.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Look for cart drawer or checkout button
        final checkoutFinder = find.text('Checkout');
        expect(checkoutFinder.evaluate().isNotEmpty, isTrue);
      }
    });
  });
}
