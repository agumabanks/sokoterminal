import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/theme/design_tokens.dart';

void main() {
  testWidgets('app shell smoke: design tokens render in Material tree', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          scaffoldBackgroundColor: DesignTokens.surface,
          colorScheme: ColorScheme.fromSeed(seedColor: DesignTokens.brandAccent),
        ),
        home: const _SmokeHome(),
      ),
    );

    expect(find.text('Soko Seller Terminal'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byIcon(Icons.point_of_sale_outlined), findsOneWidget);
  });
}

class _SmokeHome extends StatelessWidget {
  const _SmokeHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Soko Seller Terminal'),
        backgroundColor: DesignTokens.brandPrimary,
        foregroundColor: DesignTokens.canvas,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.point_of_sale_outlined,
              size: DesignTokens.iconLg,
              color: DesignTokens.brandAccent,
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            const Text('Ready for checkout'),
          ],
        ),
      ),
    );
  }
}