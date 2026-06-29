import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:soko_seller_terminal/src/core/db/app_database.dart';

/// Simulates product/service creation as the UI would do it,
/// verifying that production clients can add catalog items without issues.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Product Save Simulation', () {
    test('saves a new product with all required fields', () async {
      final companion = ItemsCompanion(
        id: Value('test-product-001'),
        name: Value('Test Product'),
        price: Value(15000),
        stockQty: Value(10),
        unit: Value('pc'),
        sku: Value('TEST-001'),
        publishedOnline: Value(true),
        synced: Value(false),
      );

      await db.saveItemAndEnqueueSync(
        item: companion,
        opType: 'item_create',
        syncPayload: {
          'local_id': 'test-product-001',
          'name': 'Test Product',
          'unit_price': 15000,
          'current_stock': 10,
          'published': 1,
          'unit': 'pc',
          'sku': 'TEST-001',
        },
      );

      final saved = await db.getItemById('test-product-001');
      expect(saved, isNotNull);
      expect(saved!.name, 'Test Product');
      expect(saved.price, 15000);
      expect(saved.stockQty, 10);
      expect(saved.unit, 'pc');
      expect(saved.synced, false);
    });

    test('saves a product with minimal fields (no SKU, no stock tracking)', () async {
      final companion = ItemsCompanion(
        id: Value('test-product-002'),
        name: Value('Minimal Product'),
        price: Value(5000),
        stockQty: Value(0),
        unit: Value('pc'),
        publishedOnline: Value(false),
        synced: Value(false),
      );

      await db.saveItemAndEnqueueSync(
        item: companion,
        opType: 'item_create',
        syncPayload: {
          'local_id': 'test-product-002',
          'name': 'Minimal Product',
          'unit_price': 5000,
          'current_stock': 0,
          'published': 0,
          'unit': 'pc',
        },
      );

      final saved = await db.getItemById('test-product-002');
      expect(saved, isNotNull);
      expect(saved!.name, 'Minimal Product');
      expect(saved.price, 5000);
      expect(saved.sku, isNull);
    });

    test('enqueues sync operation after product save', () async {
      final companion = ItemsCompanion(
        id: Value('test-product-003'),
        name: Value('Sync Test Product'),
        price: Value(25000),
        stockQty: Value(5),
        unit: Value('box'),
        publishedOnline: Value(true),
        synced: Value(false),
      );

      await db.saveItemAndEnqueueSync(
        item: companion,
        opType: 'item_create',
        syncPayload: {
          'local_id': 'test-product-003',
          'name': 'Sync Test Product',
          'unit_price': 25000,
        },
      );

      final ops = await db.pendingSyncOps();
      expect(ops, isNotEmpty);
      expect(ops.any((op) => op.opType == 'item_create' && op.payload.contains('test-product-003')), isTrue);
    });
  });

  group('Service Save Simulation', () {
    test('saves a new service with all required fields', () async {
      final companion = ServicesCompanion(
        id: Value('test-service-001'),
        title: Value('Test Service'),
        price: Value(50000),
        serviceType: Value('virtual'),
        deliveryTimeframe: Value('7 days'),
        publishedOnline: Value(true),
        synced: Value(false),
      );

      await db.saveServiceAndEnqueueSync(
        service: companion,
        syncPayload: {
          'local_id': 'test-service-001',
          'title': 'Test Service',
          'price': 50000,
          'service_type': 'virtual',
          'duration': '7 days',
        },
        opType: 'service_create',
      );

      final saved = await db.getServiceById('test-service-001');
      expect(saved, isNotNull);
      expect(saved!.title, 'Test Service');
      expect(saved.price, 50000);
      expect(saved.serviceType, 'virtual');
      expect(saved.synced, false);
    });

    test('saves a service with minimal fields', () async {
      final companion = ServicesCompanion(
        id: Value('test-service-002'),
        title: Value('Minimal Service'),
        price: Value(10000),
        serviceType: Value('onsite'),
        publishedOnline: Value(false),
        synced: Value(false),
      );

      await db.saveServiceAndEnqueueSync(
        service: companion,
        syncPayload: {
          'local_id': 'test-service-002',
          'title': 'Minimal Service',
          'price': 10000,
        },
        opType: 'service_create',
      );

      final saved = await db.getServiceById('test-service-002');
      expect(saved, isNotNull);
      expect(saved!.title, 'Minimal Service');
      expect(saved.price, 10000);
    });

    test('enqueues sync operation after service save', () async {
      final companion = ServicesCompanion(
        id: Value('test-service-003'),
        title: Value('Sync Test Service'),
        price: Value(75000),
        serviceType: Value('hybrid'),
        publishedOnline: Value(true),
        synced: Value(false),
      );

      await db.saveServiceAndEnqueueSync(
        service: companion,
        syncPayload: {
          'local_id': 'test-service-003',
          'title': 'Sync Test Service',
          'price': 75000,
        },
        opType: 'service_create',
      );

      final ops = await db.pendingSyncOps();
      expect(ops, isNotEmpty);
      expect(ops.any((op) => op.opType == 'service_create' && op.payload.contains('test-service-003')), isTrue);
    });
  });

  group('Catalog Save Edge Cases', () {
    test('handles product with very long name', () async {
      final longName = 'A' * 200;
      final companion = ItemsCompanion(
        id: Value('test-product-long'),
        name: Value(longName),
        price: Value(1000),
        stockQty: Value(1),
        unit: Value('pc'),
        publishedOnline: Value(false),
        synced: Value(false),
      );

      await db.saveItemAndEnqueueSync(
        item: companion,
        opType: 'item_create',
        syncPayload: {
          'local_id': 'test-product-long',
          'name': longName,
          'unit_price': 1000,
        },
      );

      final saved = await db.getItemById('test-product-long');
      expect(saved, isNotNull);
      expect(saved!.name, longName);
    });

    test('handles product with zero price', () async {
      final companion = ItemsCompanion(
        id: Value('test-product-free'),
        name: Value('Free Sample'),
        price: Value(0),
        stockQty: Value(100),
        unit: Value('pc'),
        publishedOnline: Value(true),
        synced: Value(false),
      );

      await db.saveItemAndEnqueueSync(
        item: companion,
        opType: 'item_create',
        syncPayload: {
          'local_id': 'test-product-free',
          'name': 'Free Sample',
          'unit_price': 0,
        },
      );

      final saved = await db.getItemById('test-product-free');
      expect(saved, isNotNull);
      expect(saved!.price, 0);
    });

    test('handles service with special characters in title', () async {
      final companion = ServicesCompanion(
        id: Value('test-service-special'),
        title: Value('Service with émojis 🎨 & symbols!'),
        price: Value(30000),
        serviceType: Value('virtual'),
        publishedOnline: Value(false),
        synced: Value(false),
      );

      await db.saveServiceAndEnqueueSync(
        service: companion,
        syncPayload: {
          'local_id': 'test-service-special',
          'title': 'Service with émojis 🎨 & symbols!',
          'price': 30000,
        },
        opType: 'service_create',
      );

      final saved = await db.getServiceById('test-service-special');
      expect(saved, isNotNull);
      expect(saved!.title, 'Service with émojis 🎨 & symbols!');
    });
  });
}
