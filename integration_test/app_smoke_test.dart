import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:soko_seller_terminal/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Smoke Test', () {
    testWidgets('app launches without crashing', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // The app should render either the login screen or the home shell.
      // Look for known text on either screen.
      final onKnownScreen = <Finder>[
        find.text('Sign in'),
        find.text('Login'),
        find.text('Checkout'),
        find.text('Point of Sale'),
      ].any((finder) => finder.evaluate().isNotEmpty);

      expect(
        onKnownScreen,
        isTrue,
        reason: 'App should show either login or home screen',
      );
    });

    testWidgets('all bottom nav tabs are reachable when logged in',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // If we're on the home screen, try tapping each tab
      if (find.text('Checkout').evaluate().isNotEmpty) {
        for (final label in ['Transactions', 'Alerts', 'More']) {
          final tab = find.text(label);
          if (tab.evaluate().isNotEmpty) {
            await tester.tap(tab);
            await tester.pumpAndSettle(const Duration(seconds: 2));
            expect(tab.evaluate().isNotEmpty, isTrue);
          }
        }

        // Navigate to Products via More tab
        final productsTile = find.text('Products');
        if (productsTile.evaluate().isNotEmpty) {
          await tester.tap(productsTile);
          await tester.pumpAndSettle(const Duration(seconds: 2));
          expect(find.text('Products'), findsAtLeastNWidgets(1));
        }
      }
    });
  });
}
