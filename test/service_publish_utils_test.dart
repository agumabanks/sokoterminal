import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/db/app_database.dart';
import 'package:soko_seller_terminal/src/core/util/service_publish_utils.dart';

Service _service({
  bool published = false,
  int? categoryId,
  String? summary,
  String? deliveryTimeframe,
  String? imageUrl,
  String? description,
}) {
  return Service(
    id: 'svc-1',
    title: 'Logo Design',
    price: 100000,
    description: description,
    imageUrl: imageUrl,
    categoryId: categoryId,
    summary: summary,
    deliveryTimeframe: deliveryTimeframe,
    publishedOnline: published,
    synced: false,
    updatedAt: DateTime.utc(2026, 6, 9),
  );
}

void main() {
  test('servicePublishBlockReason requires marketplace fields when publishing', () {
    expect(
      servicePublishBlockReason(_service(published: true), wantsPublish: true),
      isNotNull,
    );
    expect(
      servicePublishBlockReason(
        _service(
          published: true,
          categoryId: 12,
          summary: 'Professional logos for SMEs',
          deliveryTimeframe: '7 days',
          imageUrl: 'https://cdn.example.com/cover.jpg',
          description: '<p>Full brand identity package with revisions.</p>',
        ),
        wantsPublish: true,
      ),
      isNull,
    );
  });

  test('buildServiceSyncPayload includes marketplace metadata', () {
    final payload = buildServiceSyncPayload(
      _service(
        categoryId: 9,
        summary: 'Quick turnaround',
        deliveryTimeframe: '3 days',
      ),
    );
    expect(payload['category_id'], 9);
    expect(payload['summary'], 'Quick turnaround');
    expect(payload['delivery_timeframe'], '3 days');
    expect(payload['is_published'], isFalse);
  });

  test('publish to sync payload marks service live for moderation queue', () {
    final ready = _service(
      published: true,
      categoryId: 12,
      summary: 'Professional logos for SMEs',
      deliveryTimeframe: '7 days',
      imageUrl: 'https://cdn.example.com/cover.jpg',
      description: '<p>Full brand identity package with revisions.</p>',
    );

    expect(servicePublishBlockReason(ready, wantsPublish: true), isNull);
    expect(buildServiceSyncPayload(ready)['is_published'], isTrue);
  });

  test('parseServiceModerationFromApiResponse maps pending approval', () {
    final update = parseServiceModerationFromApiResponse({
      'pending_approval': true,
      'data': {
        'is_published': true,
        'moderation_status': 'pending',
      },
    });

    expect(update.moderationStatus, 'pending');
    expect(update.publishedOnline, isTrue);
    expect(update.hasChanges, isTrue);
  });

  test('service publish sync applies pending moderation in Drift', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.upsertService(
      ServicesCompanion.insert(
        id: const Value('svc-1'),
        title: 'Logo Design',
        price: 100000,
        publishedOnline: const Value(true),
        synced: const Value(false),
        updatedAt: Value(DateTime.utc(2026, 6, 9)),
      ),
    );

    final update = parseServiceModerationFromApiResponse({
      'pending_approval': true,
      'data': {'is_published': true},
    });

    await db.updateServiceFields(
      'svc-1',
      ServicesCompanion(
        moderationStatus: Value(update.moderationStatus),
        publishedOnline: Value(update.publishedOnline ?? true),
        updatedAt: Value(DateTime.utc(2026, 6, 9, 12)),
      ),
    );

    final row = await db.getServiceById('svc-1');
    expect(row, isNotNull);
    expect(row!.moderationStatus, 'pending');
    expect(row.publishedOnline, isTrue);
    expect(isServicePendingModeration(row), isTrue);
  });
}