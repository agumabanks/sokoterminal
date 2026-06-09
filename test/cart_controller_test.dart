import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/db/app_database.dart';
import 'package:soko_seller_terminal/src/features/checkout/cart_controller.dart';

import 'helpers/test_helpers.dart';

void main() {
  setUpAll(registerTestFallbacks);

  group('CartLine', () {
    test('total equals price * quantity', () {
      final line = CartLine(
        id: '1',
        title: 'Test Item',
        price: 1500.0,
        quantity: 3,
      );
      expect(line.total, 4500.0);
    });

    test('copyWith updates quantity while preserving other fields', () {
      final line = CartLine(
        id: '1',
        title: 'Test Item',
        price: 1000.0,
        quantity: 1,
        itemId: 'item-1',
        variant: 'Red',
      );
      final updated = line.copyWith(quantity: 5);
      expect(updated.quantity, 5);
      expect(updated.price, 1000.0);
      expect(updated.itemId, 'item-1');
      expect(updated.variant, 'Red');
    });
  });

  group('CartState', () {
    test('subtotal sums all line totals', () {
      final state = CartState(lines: [
        CartLine(id: '1', title: 'A', price: 1000.0, quantity: 2),
        CartLine(id: '2', title: 'B', price: 500.0, quantity: 1),
      ]);
      expect(state.subtotal, 2500.0);
    });

    test('empty cart has zero subtotal', () {
      const state = CartState();
      expect(state.subtotal, 0.0);
    });

    test('copyWith replaces customer', () {
      final customer = Customer(
        id: 'c1',
        name: 'Alice',
        updatedAt: DateTime(2024, 1, 1),
        synced: false,
        isWalkIn: false,
      );
      final state = CartState(customer: customer);
      final cleared = state.copyWith(customer: () => null);
      expect(cleared.customer, isNull);
    });
  });

  group('CartController - addItem', () {
    late CartController controller;

    setUp(() {
      controller = CartController(
        db: MockAppDatabase(),
        syncService: MockSyncService(),
        secureStorage: MockSecureStorage(),
      );
    });

    test('adds item to empty cart', () {
      final item = _item('item-1', 'Bananas', 3000.0, stockQty: 10);
      final error = controller.addItem(item: item, quantity: 2);
      expect(error, isNull);
      expect(controller.state.lines, hasLength(1));
      expect(controller.state.lines.first.title, 'Bananas');
      expect(controller.state.lines.first.quantity, 2);
      expect(controller.state.subtotal, 6000.0);
    });

    test('increments quantity for existing item', () {
      final item = _item('item-1', 'Bananas', 3000.0, stockQty: 10);
      controller.addItem(item: item, quantity: 1);
      final error = controller.addItem(item: item, quantity: 2);
      expect(error, isNull);
      expect(controller.state.lines, hasLength(1));
      expect(controller.state.lines.first.quantity, 3);
    });

    test('rejects out-of-stock item', () {
      final item = _item('item-1', 'Bananas', 3000.0, stockQty: 0);
      final error = controller.addItem(item: item, quantity: 1);
      expect(error, isNotNull);
      expect(controller.state.lines, isEmpty);
    });

    test('clamps quantity to available stock', () {
      final item = _item('item-1', 'Bananas', 3000.0, stockQty: 5);
      final error = controller.addItem(item: item, quantity: 10);
      expect(error, isNotNull);
      expect(controller.state.lines.first.quantity, 5);
    });

    test('does not enforce stock when stockEnabled is false', () {
      final item = _item('item-1', 'Bananas', 3000.0,
          stockEnabled: false, stockQty: 0);
      final error = controller.addItem(item: item, quantity: 100);
      expect(error, isNull);
      expect(controller.state.lines.first.quantity, 100);
    });
  });

  group('CartController - addItemVariant', () {
    late CartController controller;

    setUp(() {
      controller = CartController(
        db: MockAppDatabase(),
        syncService: MockSyncService(),
        secureStorage: MockSecureStorage(),
      );
    });

    test('adds variant as separate line', () {
      final item = _item('item-1', 'T-Shirt', 15000.0, stockEnabled: false);
      controller.addItemVariant(
        item: item,
        variant: 'Red',
        price: 15000.0,
        quantity: 1,
      );
      controller.addItemVariant(
        item: item,
        variant: 'Blue',
        price: 15000.0,
        quantity: 1,
      );
      expect(controller.state.lines, hasLength(2));
      expect(controller.state.subtotal, 30000.0);
    });

    test('increments quantity for same variant', () {
      final item = _item('item-1', 'T-Shirt', 15000.0, stockEnabled: false);
      controller.addItemVariant(
        item: item,
        variant: 'Red',
        price: 15000.0,
        quantity: 1,
      );
      controller.addItemVariant(
        item: item,
        variant: 'Red',
        price: 15000.0,
        quantity: 2,
      );
      expect(controller.state.lines, hasLength(1));
      expect(controller.state.lines.first.quantity, 3);
    });

    test('rejects out-of-stock variant', () {
      final item = _item('item-1', 'T-Shirt', 15000.0, stockQty: 5);
      final error = controller.addItemVariant(
        item: item,
        variant: 'Red',
        price: 15000.0,
        quantity: 1,
        availableStock: 0,
      );
      expect(error, isNotNull);
      expect(controller.state.lines, isEmpty);
    });
  });

  group('CartController - addService', () {
    late CartController controller;

    setUp(() {
      controller = CartController(
        db: MockAppDatabase(),
        syncService: MockSyncService(),
        secureStorage: MockSecureStorage(),
      );
    });

    test('adds service to cart', () {
      final service = _service('svc-1', 'Haircut', 10000.0);
      controller.addService(service: service, quantity: 1);
      expect(controller.state.lines, hasLength(1));
      expect(controller.state.lines.first.title, 'Haircut');
      expect(controller.state.lines.first.serviceId, 'svc-1');
      expect(controller.state.lines.first.itemId, isNull);
    });

    test('increments quantity for same service', () {
      final service = _service('svc-1', 'Haircut', 10000.0);
      controller.addService(service: service, quantity: 1);
      controller.addService(service: service, quantity: 2);
      expect(controller.state.lines, hasLength(1));
      expect(controller.state.lines.first.quantity, 3);
    });
  });

  group('CartController - updateQuantity', () {
    late CartController controller;

    setUp(() {
      controller = CartController(
        db: MockAppDatabase(),
        syncService: MockSyncService(),
        secureStorage: MockSecureStorage(),
      );
    });

    test('updates quantity', () {
      final item = _item('item-1', 'Bananas', 3000.0, stockEnabled: false);
      controller.addItem(item: item, quantity: 1);
      final lineId = controller.state.lines.first.id;
      final error = controller.updateQuantity(lineId, 5);
      expect(error, isNull);
      expect(controller.state.lines.first.quantity, 5);
    });

    test('removes line when quantity <= 0', () {
      final item = _item('item-1', 'Bananas', 3000.0, stockEnabled: false);
      controller.addItem(item: item, quantity: 1);
      final lineId = controller.state.lines.first.id;
      controller.updateQuantity(lineId, 0);
      expect(controller.state.lines, isEmpty);
    });

    test('clamps to available stock', () {
      final item = _item('item-1', 'Bananas', 3000.0, stockQty: 5);
      controller.addItem(item: item, quantity: 1);
      final lineId = controller.state.lines.first.id;
      final error = controller.updateQuantity(lineId, 10);
      expect(controller.state.lines.first.quantity, 5);
      expect(error, isNotNull);
    });
  });

  group('CartController - removeLine & clear', () {
    late CartController controller;

    setUp(() {
      controller = CartController(
        db: MockAppDatabase(),
        syncService: MockSyncService(),
        secureStorage: MockSecureStorage(),
      );
    });

    test('removeLine deletes specific line', () {
      final item1 = _item('item-1', 'A', 1000.0, stockEnabled: false);
      final item2 = _item('item-2', 'B', 2000.0, stockEnabled: false);
      controller.addItem(item: item1, quantity: 1);
      controller.addItem(item: item2, quantity: 1);
      final idToRemove = controller.state.lines.first.id;
      controller.removeLine(idToRemove);
      expect(controller.state.lines, hasLength(1));
      expect(controller.state.lines.first.title, 'B');
    });

    test('clear empties the cart', () {
      final item = _item('item-1', 'A', 1000.0, stockEnabled: false);
      controller.addItem(item: item, quantity: 5);
      controller.clear();
      expect(controller.state.lines, isEmpty);
      expect(controller.state.subtotal, 0.0);
    });
  });

  group('CartController - snapshot & apply', () {
    late CartController controller;

    setUp(() {
      controller = CartController(
        db: MockAppDatabase(),
        syncService: MockSyncService(),
        secureStorage: MockSecureStorage(),
      );
    });

    test('snapshot captures current state', () {
      final item = _item('item-1', 'A', 1000.0, stockEnabled: false);
      controller.addItem(item: item, quantity: 3);
      final snap = controller.snapshot();
      expect(snap.lines, hasLength(1));
      expect(snap.lines.first.quantity, 3);
    });

    test('apply restores saved state', () {
      final item = _item('item-1', 'A', 1000.0, stockEnabled: false);
      controller.addItem(item: item, quantity: 3);
      final snap = controller.snapshot();
      controller.clear();
      controller.apply(snap);
      expect(controller.state.lines, hasLength(1));
      expect(controller.state.lines.first.quantity, 3);
    });
  });

  group('CartController - setCustomer', () {
    late CartController controller;

    setUp(() {
      controller = CartController(
        db: MockAppDatabase(),
        syncService: MockSyncService(),
        secureStorage: MockSecureStorage(),
      );
    });

    test('sets and clears customer', () {
      final customer = Customer(
        id: 'c1',
        name: 'Bob',
        updatedAt: DateTime(2024, 1, 1),
        synced: false,
        isWalkIn: false,
      );
      controller.setCustomer(customer);
      expect(controller.state.customer?.name, 'Bob');
      controller.setCustomer(null);
      expect(controller.state.customer, isNull);
    });
  });

  group('CartController - updatePrice', () {
    late CartController controller;

    setUp(() {
      controller = CartController(
        db: MockAppDatabase(),
        syncService: MockSyncService(),
        secureStorage: MockSecureStorage(),
      );
    });

    test('updates line price', () {
      final item = _item('item-1', 'A', 1000.0, stockEnabled: false);
      controller.addItem(item: item, quantity: 1);
      final lineId = controller.state.lines.first.id;
      controller.updatePrice(lineId, 1500.0);
      expect(controller.state.lines.first.price, 1500.0);
      expect(controller.state.subtotal, 1500.0);
    });

    test('ignores zero or negative price', () {
      final item = _item('item-1', 'A', 1000.0, stockEnabled: false);
      controller.addItem(item: item, quantity: 1);
      final lineId = controller.state.lines.first.id;
      controller.updatePrice(lineId, 0.0);
      expect(controller.state.lines.first.price, 1000.0);
      controller.updatePrice(lineId, -50.0);
      expect(controller.state.lines.first.price, 1000.0);
    });
  });
}

Item _item(
  String id,
  String name,
  double price, {
  bool stockEnabled = true,
  int stockQty = 0,
}) {
  return Item(
    id: id,
    name: name,
    price: price,
    stockEnabled: stockEnabled,
    stockQty: stockQty,
    publishedOnline: false,
    minPurchaseQty: 1,
    refundable: false,
    cashOnDelivery: true,
    updatedAt: DateTime.now(),
    synced: false,
  );
}

Service _service(String id, String title, double price) {
  return Service(
    id: id,
    title: title,
    price: price,
    publishedOnline: false,
    updatedAt: DateTime.now(),
    synced: false,
  );
}
