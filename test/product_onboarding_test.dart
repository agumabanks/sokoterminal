import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soko_seller_terminal/src/core/app_providers.dart';
import 'package:soko_seller_terminal/src/core/config/app_config.dart';
import 'package:soko_seller_terminal/src/features/bnpl/models/bnpl_seller_status.dart';
import 'package:soko_seller_terminal/src/features/bnpl/providers/bnpl_seller_status_provider.dart';
import 'package:soko_seller_terminal/src/features/items/add_product_screen.dart';
import 'package:soko_seller_terminal/src/features/items/product_form_controller.dart';
import 'package:soko_seller_terminal/src/widgets/app_button.dart';
import 'package:soko_seller_terminal/src/widgets/app_input.dart';
import 'helpers/test_helpers.dart';

class OfflineFormController extends ProductFormController {
  OfflineFormController(super.ref);
  @override
  Future<void> setPublishOnline(bool value) async {
    state = state.copyWith(publishOnline: value);
  }
}

Future<void> enter(WidgetTester tester, String label, String value) async {
  await tester.scrollUntilVisible(
    find.text(label),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  final input = find.byWidgetPredicate(
    (w) => w is AppInput && w.label == label,
  );
  await tester.enterText(
    find.descendant(of: input, matching: find.byType(TextField)),
    value,
  );
  await tester.pumpAndSettle();
}

void main() {
  Future<void> openForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final db = createTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          appConfigProvider.overrideWithValue(AppConfig.fromEnv(const {})),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          productFormProvider.overrideWith((ref) => OfflineFormController(ref)),
          bnplSellerStatusProvider.overrideWith(
            (ref) async => const BnplSellerStatus(status: 'not_enrolled'),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: const AddProductScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shop flow validates basics and keeps them when going back', (
    tester,
  ) async {
    await openForm(tester);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Each (one item)'), findsOneWidget);
    expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNull);
    await enter(tester, 'What is the product called?', 'Sugar');
    await enter(tester, 'Buying price (UGX)', '3000');
    await enter(tester, 'Selling price (UGX)', '5000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review product'));
    await tester.pumpAndSettle();
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(
      tester.widget<AppButton>(find.byType(AppButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Edit product details'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Sugar',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'online requirements do not block basics and are shown on the final step',
    (tester) async {
      await openForm(tester);
      await tester.tap(find.text('In my shop + online'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await enter(tester, 'What is the product called?', 'Rice');
      await enter(tester, 'Buying price (UGX)', '6000');
      await enter(tester, 'Selling price (UGX)', '8000');
      await tester.pumpAndSettle();
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Next: online'));
      await tester.pumpAndSettle();
      expect(find.text('Get ready for online buyers'), findsOneWidget);
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In my shop'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review product'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
