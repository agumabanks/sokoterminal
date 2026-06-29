import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/features/ads/studio_deep_link_launcher.dart';

void main() {
  testWidgets('StudioDeepLinkLauncher shows loading UI', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: StudioDeepLinkLauncher(
            productId: 123,
            openPanel: 'smart-ads',
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Opening Studio…'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
