import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:soko_seller_terminal/src/core/db/app_database.dart';
import 'package:soko_seller_terminal/src/core/sync/sync_service.dart';
import 'package:soko_seller_terminal/src/features/orders/marketplace_order.dart';

import 'helpers/test_helpers.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/orders'));
  });

  test('pullMarketplaceOrderDetail merges sparse list cache with detail payload',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    const orderId = 55;
    await db.upsertCachedOrder(
      orderId,
      jsonEncode({
        'id': orderId,
        'customer_name': 'Sam',
        'customer_phone': '+256700000000',
        'delivery_status': 'pending',
      }),
    );

    final api = MockSellerApi();
    when(() => api.fetchOrderDetails(orderId)).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/orders/$orderId'),
        data: {
          'data': [
            {
              'id': orderId,
              'payment_type': 'cash_on_delivery',
              'order_items': [
                {'product_name': 'Soap', 'quantity': 1, 'unit_price': 5000},
              ],
            },
          ],
        },
      ),
    );

    final sync = SyncService(
      db: db,
      sellerApi: api,
      secureStorage: MockSecureStorage(),
    );

    final merged = await sync.pullMarketplaceOrderDetail(orderId);
    expect(merged, isNotNull);
    expect(merged!.displayCustomer, 'Sam');
    expect(merged.displayPhone, '+256700000000');
    expect(merged.displayPaymentMethod, 'cash on delivery');
    expect(merged.lineItemCount, 1);

    final row = await db.getCachedOrder(orderId);
    expect(row, isNotNull);
    final cached = MarketplaceOrder.fromJson(
      jsonDecode(row!.payloadJson) as Map<String, dynamic>,
    );
    expect(cached.lineItemCount, 1);
    expect(cached.customerName, 'Sam');
  });
}