import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soko_seller_terminal/src/core/db/app_database.dart';
import 'package:soko_seller_terminal/src/features/checkout/cart_controller.dart';
import 'package:soko_seller_terminal/src/features/checkout/parked_sales_controller.dart';

void main() {
  test('parked sales persist to Drift and restore on controller init', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final writer = ParkedSalesController(database: db);
    writer.parkSale(
      CartState(
        lines: [
          CartLine(
            id: 'line-1',
            title: 'Soap',
            price: 5000,
            itemId: 'item-1',
            quantity: 2,
          ),
        ],
      ),
      label: 'Table 3',
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final rows = await db.getNamedParkedSales();
    expect(rows, hasLength(1));
    expect(rows.first.label, 'Table 3');
    expect(rows.first.saleKind, AppDatabase.namedParkedSaleKind);

    final reader = ParkedSalesController(database: db);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(reader.state, hasLength(1));
    expect(reader.state.first.label, 'Table 3');
    expect(reader.state.first.lines.first.title, 'Soap');
  });
}