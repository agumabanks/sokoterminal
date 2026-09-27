import 'dart:async';
import 'dart:convert';
import 'package:soko_seller_terminal/src/features/inbox/inbox_screen.dart';
import 'package:soko_seller_terminal/src/features/refunds/refunds_screen.dart';
import 'package:soko_seller_terminal/src/core/db/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/features/notifications/notifications_controller.dart';
import 'package:soko_seller_terminal/src/features/notifications/notifications_screen.dart';
import 'package:soko_seller_terminal/src/features/orders/orders_controller.dart';
import 'package:soko_seller_terminal/src/features/orders/orders_screen.dart';
import 'package:soko_seller_terminal/src/features/orders/marketplace_order.dart';
import 'helpers/test_helpers.dart';

class TestAlerts extends NotificationsController {
  TestAlerts(super.ref, super.api) {
    state = NotificationsState(
      items: [
        NotificationDto(
          id: '1',
          title: 'Shop update',
          body: '<p>Your stock has changed.</p>',
          dateLabel: 'Today',
          image: null,
          data: {},
          isRead: false,
        ),
      ],
      unreadCount: 1,
    );
  }
  final readRequest = Completer<void>();
  @override
  Future<void> markRead(String id) => readRequest.future;
}

class TestOrders extends OrdersController {
  TestOrders() : super(MockSellerApi(), MockAppDatabase(), MockSyncService()) {
    state = const OrdersState(
      orders: [
        MarketplaceOrder(
          id: 1,
          code: 'ORDER-1',
          customerName: 'Alice',
          deliveryStatus: 'pending',
          paymentStatus: 'unpaid',
          grandTotal: 10000000,
        ),
        MarketplaceOrder(
          id: 2,
          code: 'ORDER-2',
          customerName: 'Bob',
          deliveryStatus: 'cancelled',
          paymentStatus: 'unpaid',
          grandTotal: 90000000,
        ),
      ],
    );
  }
}

class TestRefunds extends RefundsController {
  TestRefunds() : super(MockSellerApi());
  @override
  Future<void> load() async {}
}

void main() {
  setUpAll(registerTestFallbacks);
  testWidgets('visible unified Alerts tab opens an order summary on row tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cachedOrdersStreamProvider.overrideWith(
            (ref) => Stream.value([
              CachedOrder(
                orderId: 8,
                payloadJson: jsonEncode({
                  'id': 8,
                  'code': 'EIGHT',
                  'customer_name': 'Miriam',
                  'delivery_status': 'pending',
                }),
                updatedAt: DateTime.now(),
              ),
            ]),
          ),
          cachedBookingsStreamProvider.overrideWith((ref) => Stream.value([])),
          pendingSyncOpsStreamProvider.overrideWith((ref) => Stream.value([])),
          stockAlertsStreamProvider.overrideWith((ref) => Stream.value([])),
          notificationsControllerProvider.overrideWith(
            (ref) => TestAlerts(ref, MockSellerApi()),
          ),
          refundsControllerProvider.overrideWith((ref) => TestRefunds()),
        ],
        child: const MaterialApp(home: InboxScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Order EIGHT'));
    await tester.pumpAndSettle();
    expect(find.text('View order'), findsOneWidget);
    expect(find.text('Status: pending'), findsOneWidget);
    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
      Colors.white,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'alert details open before backend mark-read finishes, on an opaque sheet',
    (tester) async {
      late TestAlerts controller;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsControllerProvider.overrideWith(
              (ref) => controller = TestAlerts(ref, MockSellerApi()),
            ),
            lowStockAlertsProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: ThemeData(
              bottomSheetTheme: const BottomSheetThemeData(
                backgroundColor: Colors.transparent,
              ),
            ),
            home: const NotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shop update'));
      await tester.pumpAndSettle();
      expect(controller.readRequest.isCompleted, isFalse);
      expect(find.text('Your stock has changed.'), findsOneWidget);
      expect(
        tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
        Colors.white,
      );
      expect(find.text('Open related page'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      controller.readRequest.complete();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'orders fit a narrow screen and filter cancelled orders from action and value',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersControllerProvider.overrideWith((ref) => TestOrders()),
          ],
          child: const MaterialApp(home: OrdersScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('UGX 10M'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      await tester.tap(find.text('Needs action (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
