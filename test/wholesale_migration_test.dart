import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/db/app_database.dart';

void main() {
  test(
    'v40 database upgrades without losing products and persists wholesale ranges',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'soko-wholesale-',
      );
      final file = File('${directory.path}/pos.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      await db.upsertItem(
        ItemsCompanion.insert(
          id: const Value('existing'),
          name: 'Rice',
          price: 10000,
        ),
      );
      await db.customStatement(
        'ALTER TABLE items DROP COLUMN wholesale_ranges_json',
      );
      await db.customStatement('PRAGMA user_version = 40');
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      final item = await db.getItemById('existing');
      expect(item?.name, 'Rice');
      expect(item?.wholesaleRangesJson, isNull);
      await db.upsertItem(
        item!
            .copyWith(
              wholesaleRangesJson: const Value(
                '[{"min_qty":10,"max_qty":20,"price":9000}]',
              ),
            )
            .toCompanion(false),
      );
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      expect(
        (await db.getItemById('existing'))?.wholesaleRangesJson,
        contains('9000'),
      );
      await db.close();
      await directory.delete(recursive: true);
    },
  );
}
