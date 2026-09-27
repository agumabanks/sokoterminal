import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/features/items/wholesale_pricing.dart';
import 'package:soko_seller_terminal/src/features/checkout/cart_controller.dart';

void main() {
  final ranges = [
    {'min_qty': 10, 'max_qty': 19, 'price': 9000},
    {'min_qty': 20, 'max_qty': 100, 'price': 8000},
  ];
  testWidgets('wholesale toggle exposes editable ranges on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var enabled = false;
    final entries = <Map<String, dynamic>>[{}];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => WholesaleEditor(
                enabled: enabled,
                ranges: entries,
                onToggle: (v) => setState(() => enabled = v),
                onChanged: () => setState(() {}),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('From quantity'), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('From quantity'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '10');
    await tester.enterText(find.byType(TextFormField).at(1), '20');
    await tester.enterText(find.byType(TextFormField).at(2), '9000');
    expect(validateWholesaleRanges(entries), isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('removing first wholesale range retains the next range values', (
    tester,
  ) async {
    final entries = <Map<String, dynamic>>[
      {'min_qty': 10, 'max_qty': 19, 'price': 9000},
      {'min_qty': 20, 'max_qty': 99, 'price': 8000},
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => WholesaleEditor(
                enabled: true,
                ranges: entries,
                onToggle: (_) {},
                onChanged: () => setState(() {}),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Remove range').first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '20'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '8000'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '10'), findsNothing);
  });
  test('inclusive boundaries and retail fallback when quantity decreases', () {
    final source = jsonEncode(ranges);
    expect(wholesaleUnitPrice(10000, source, 9), 10000);
    expect(wholesaleUnitPrice(10000, source, 10), 9000);
    expect(wholesaleUnitPrice(10000, source, 19), 9000);
    expect(wholesaleUnitPrice(10000, source, 20), 8000);
    expect(wholesaleUnitPrice(10000, source, 101), 10000);
    final line = CartLine(
      id: '1',
      title: 'Rice',
      price: 10000,
      retailPrice: 10000,
      wholesaleRangesJson: source,
    );
    expect(line.copyWith(quantity: 20).total, 160000);
    expect(line.copyWith(quantity: 20).copyWith(quantity: 2).total, 20000);
  });
  test('reject empty, overlapping and invalid ranges', () {
    expect(validateWholesaleRanges(ranges), isNull);
    expect(validateWholesaleRanges([]), isNotNull);
    expect(
      validateWholesaleRanges([
        ranges.first,
        {'min_qty': 19, 'max_qty': 30, 'price': 8000},
      ]),
      isNotNull,
    );
    expect(
      validateWholesaleRanges([
        {'min_qty': 10, 'max_qty': 5, 'price': 0},
      ]),
      isNotNull,
    );
  });
}
