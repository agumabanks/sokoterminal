import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/db/app_database.dart';

void main() {
  test('upgrading an installed v41 database keeps products, stock and unknown cost', () async {
    final dir = await Directory.systemTemp.createTemp('soko-coverage-migration-');
    final file = File('${dir.path}/seller.sqlite');
    var db = AppDatabase.forTesting(NativeDatabase(file));
    await db.upsertItem(ItemsCompanion.insert(id: const Value('existing'), name: 'Rice', price: 5000, stockQty: const Value(9)));
    await db.customStatement('ALTER TABLE items DROP COLUMN selling_coverage_json');
    await db.customStatement('PRAGMA user_version = 41');
    await db.close();
    db = AppDatabase.forTesting(NativeDatabase(file));
    final item = (await db.getItemById('existing'))!;
    expect(item.name, 'Rice'); expect(item.stockQty, 9); expect(item.cost, isNull); expect(item.sellingCoverageJson, isNull);
    await db.updateItemFields(item.id, const ItemsCompanion(sellingCoverageJson: Value('{"mode":"unrestricted"}')));
    await db.close();
    db = AppDatabase.forTesting(NativeDatabase(file));
    expect((await db.getItemById('existing'))?.sellingCoverageJson, contains('unrestricted'));
    await db.close(); await dir.delete(recursive: true);
  });
}
