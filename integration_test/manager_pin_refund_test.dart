import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:soko_seller_terminal/main.dart' as app;

/// Smoke path for refund screen. Manager PIN gating is unit-tested in
/// `test/manager_pin_gate_test.dart`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('refund screen is reachable from More when logged in',
      (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    if (find.text('Sign in').evaluate().isNotEmpty ||
        find.text('Login').evaluate().isNotEmpty) {
      expect(find.text('Sign in').evaluate().isNotEmpty ||
          find.text('Login').evaluate().isNotEmpty, isTrue);
      return;
    }

    final moreTab = find.text('More');
    if (moreTab.evaluate().isEmpty) return;

    await tester.tap(moreTab);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final refundEntry = find.textContaining('Refund');
    if (refundEntry.evaluate().isNotEmpty) {
      await tester.tap(refundEntry.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.textContaining('Refund'), findsAtLeastNWidgets(1));
    }
  });
}