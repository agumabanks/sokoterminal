import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/db/app_database.dart';
import 'package:soko_seller_terminal/src/core/sync/sync_service.dart';

import 'helpers/test_helpers.dart';

void main() {
  group('SyncService.unblockRetriableCatalogOps', () {
    late AppDatabase db;
    late SyncService syncService;

    setUp(() async {
      db = createTestDatabase();
      syncService = SyncService(
        db: db,
        sellerApi: MockSellerApi(),
        secureStorage: MockSecureStorage(),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('unblocks old blocked item_create ops', () async {
      final twoHoursAgo = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      await db.enqueueSync('item_create', '{"name":"Test"}');

      // Manually mark the op as blocked with an old lastTriedAt
      final ops = await db.pendingSyncOps();
      expect(ops, hasLength(1));
      final op = ops.first;
      await db.markSyncBlocked(
        op.id,
        retryCount: 2,
        lastError: 'Duplicate SKU',
      );
      // Update lastTriedAt to be old by directly updating the row.
      // Drift stores DateTime as Unix epoch SECONDS in SQLite.
      await db.customStatement(
        'UPDATE sync_ops SET last_tried_at = ? WHERE id = ?',
        [twoHoursAgo.millisecondsSinceEpoch ~/ 1000, op.id],
      );

      // Verify it's blocked
      var blocked = await db.blockedSyncOps();
      expect(blocked, hasLength(1));

      // Run unblock
      await syncService.unblockRetriableCatalogOps();

      // Verify it's now pending
      blocked = await db.blockedSyncOps();
      expect(blocked, isEmpty);
      final pending = await db.pendingSyncOps();
      expect(pending, hasLength(1));
      expect(pending.first.status, 'pending');
    });

    test('does not unblock recent blocked ops', () async {
      final fiveMinutesAgo = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
      await db.enqueueSync('item_create', '{"name":"Test"}');

      final ops = await db.pendingSyncOps();
      final op = ops.first;
      await db.markSyncBlocked(
        op.id,
        retryCount: 2,
        lastError: 'Duplicate SKU',
      );
      await db.customStatement(
        'UPDATE sync_ops SET last_tried_at = ? WHERE id = ?',
        [fiveMinutesAgo.millisecondsSinceEpoch ~/ 1000, op.id],
      );

      await syncService.unblockRetriableCatalogOps();

      // Should still be blocked because less than 1 hour old
      final blocked = await db.blockedSyncOps();
      expect(blocked, hasLength(1));
    });

    test('does not unblock ops that exceeded max retries', () async {
      final twoHoursAgo = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      await db.enqueueSync('item_create', '{"name":"Test"}');

      final ops = await db.pendingSyncOps();
      final op = ops.first;
      await db.markSyncBlocked(
        op.id,
        retryCount: 25,
        lastError: 'Duplicate SKU',
      );
      await db.customStatement(
        'UPDATE sync_ops SET last_tried_at = ? WHERE id = ?',
        [twoHoursAgo.millisecondsSinceEpoch ~/ 1000, op.id],
      );

      await syncService.unblockRetriableCatalogOps();

      // Should still be blocked because retryCount >= 20
      final blocked = await db.blockedSyncOps();
      expect(blocked, hasLength(1));
    });

    test('does not unblock non-catalog ops like ledger_push', () async {
      final twoHoursAgo = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      await db.enqueueSync('ledger_push', '{"total":100}');

      final ops = await db.pendingSyncOps();
      final op = ops.first;
      await db.markSyncBlocked(
        op.id,
        retryCount: 2,
        lastError: 'POS session required',
      );
      await db.customStatement(
        'UPDATE sync_ops SET last_tried_at = ? WHERE id = ?',
        [twoHoursAgo.millisecondsSinceEpoch ~/ 1000, op.id],
      );

      await syncService.unblockRetriableCatalogOps();

      // Should still be blocked because ledger_push is not a catalog op
      final blocked = await db.blockedSyncOps();
      expect(blocked, hasLength(1));
    });

    test('unblocks old blocked item_update and service_create ops', () async {
      final twoHoursAgo = DateTime.now().toUtc().subtract(const Duration(hours: 2));

      await db.enqueueSync('item_update', '{"name":"Updated"}');
      await db.enqueueSync('service_create', '{"title":"Haircut"}');

      final ops = await db.pendingSyncOps();
      for (final op in ops) {
        await db.markSyncBlocked(op.id, retryCount: 1, lastError: 'Error');
        await db.customStatement(
          'UPDATE sync_ops SET last_tried_at = ? WHERE id = ?',
          [twoHoursAgo.millisecondsSinceEpoch ~/ 1000, op.id],
        );
      }

      await syncService.unblockRetriableCatalogOps();

      final blocked = await db.blockedSyncOps();
      expect(blocked, isEmpty);
      final pending = await db.pendingSyncOps();
      expect(pending, hasLength(2));
    });
  });
}
