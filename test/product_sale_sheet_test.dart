import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/db/app_database.dart';
import 'package:soko_seller_terminal/src/features/checkout/product_sale_sheet.dart';

void main() {
  testWidgets('bulk sheet accepts 100 without repeated taps and blocks excess stock', (tester) async {
    final item = Item(id: 'x', name: 'Rice', price: 10000, stockEnabled: true, stockQty: 120, publishedOnline: false, minPurchaseQty: 1, refundable: false, cashOnDelivery: true, updatedAt: DateTime.now(), synced: true, wholesaleRangesJson: '[{"min_qty":10,"max_qty":120,"price":8000}]');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ProductSaleSheet(item: item, stocks: const []))));
    await tester.tap(find.widgetWithText(ActionChip, '100'));
    await tester.pumpAndSettle();
    expect(find.text('Add 100 to sale'), findsOneWidget);
    expect(find.textContaining('800,000'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '121');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
