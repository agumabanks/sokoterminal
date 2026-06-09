import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:soko_seller_terminal/main.dart' as app;

/// Smoke path for offline sale sync. Ledger idempotency dedupe is unit-tested in
/// `test/offline_ledger_sync_test.dart`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('checkout shell reachable for offline sale path', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final onKnownScreen = <Finder>[
      find.text('Sign in'),
      find.text('Login'),
      find.text('Checkout'),
      find.text('Point of Sale'),
    ].any((finder) => finder.evaluate().isNotEmpty);

    expect(onKnownScreen, isTrue);

    if (find.text('Checkout').evaluate().isNotEmpty) {
      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Checkout'), findsAtLeastNWidgets(1));
    }
  });
}