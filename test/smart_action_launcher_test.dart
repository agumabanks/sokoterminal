import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soko_seller_terminal/src/features/home/smart_action_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('manager defaults expose the six daily seller actions', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final actions = SmartActionLauncher.rankedFavorites(prefs, isManager: true);

    expect(actions.map((action) => action.id), [
      'scan-shop',
      'product',
      'service',
      'stock',
      'expense',
      'ad',
    ]);
  });

  test('launcher learns from use and protects manager-only actions', () async {
    SharedPreferences.setMockInitialValues({
      'seller_quick_action_use_scan-shop': 8,
      'seller_quick_action_use_expense': 3,
    });
    final prefs = await SharedPreferences.getInstance();

    final managerActions = SmartActionLauncher.rankedFavorites(
      prefs,
      isManager: true,
    );
    final staffActions = SmartActionLauncher.rankedFavorites(
      prefs,
      isManager: false,
    );

    expect(managerActions.first.id, 'scan-shop');
    expect(staffActions.map((action) => action.id), ['scan-shop', 'expense']);
  });
}
