import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/features/orders/marketplace_order.dart';

void main() {
  test('MarketplaceOrder parses API list payload and totals', () {
    final order = MarketplaceOrder.fromJson({
      'id': 42,
      'order_code': 'ORD-42',
      'customer_name': 'Jane Doe',
      'delivery_status': 'pending',
      'payment_status': 'paid',
      'grand_total': '125000',
      'created_at': '2026-06-09T10:00:00Z',
      'order_items': [
        {
          'product_name': 'Soap',
          'quantity': 2,
          'unit_price': 5000,
          'total': 10000,
        },
      ],
    });

    expect(order.id, 42);
    expect(order.displayCode, 'ORD-42');
    expect(order.displayCustomer, 'Jane Doe');
    expect(order.normalizedPaymentStatus, 'paid');
    expect(order.displayTotal, 125000);
    expect(order.lineItemCount, 1);
    expect(order.orderItems.first.name, 'Soap');
  });

  test('MarketplaceOrder copyWith supports optimistic status updates', () {
    final order = MarketplaceOrder.fromJson({
      'id': 7,
      'delivery_status': 'pending',
      'payment_status': 'unpaid',
    });

    final updated = order.copyWith(
      deliveryStatus: 'confirmed',
      deliveryStatusRaw: 'confirmed',
      paymentStatus: 'paid',
      pendingSync: true,
    );

    expect(updated.normalizedDeliveryStatus, 'confirmed');
    expect(updated.normalizedPaymentStatus, 'paid');
    expect(updated.pendingSync, isTrue);
    expect(updated.toJson()['pending_sync'], isTrue);
  });

  test('MarketplaceOrder merge keeps sparse list fields from detail payload', () {
    final listOrder = MarketplaceOrder.fromJson({
      'id': 9,
      'customer_name': 'Sam',
      'customer_phone': '+256700000000',
      'delivery_status': 'pending',
    });
    final detailOrder = MarketplaceOrder.fromJson({
      'id': 9,
      'payment_type': 'cash_on_delivery',
      'order_items': [
        {'name': 'Tea', 'quantity': 1, 'unit_price': 3000},
      ],
    });

    final merged = listOrder.merge(detailOrder);
    expect(merged.displayCustomer, 'Sam');
    expect(merged.displayPhone, '+256700000000');
    expect(merged.displayPaymentMethod, 'cash on delivery');
    expect(merged.lineItemCount, 1);
  });
}