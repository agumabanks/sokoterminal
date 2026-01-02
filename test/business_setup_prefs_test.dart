import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soko_seller_terminal/src/core/app_providers.dart';
import 'package:soko_seller_terminal/src/core/settings/business_setup_prefs.dart';

void main() {
  test('businessSetupCompletedProvider persists to SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({businessSetupCompletedPrefKey: false});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(businessSetupCompletedProvider), isFalse);

    await container.read(businessSetupCompletedProvider.notifier).setCompleted(true);

    expect(container.read(businessSetupCompletedProvider), isTrue);
    expect(prefs.getBool(businessSetupCompletedPrefKey), isTrue);
  });
}

