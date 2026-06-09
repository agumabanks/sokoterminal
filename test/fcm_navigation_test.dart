import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/firebase/fcm_navigation.dart';

void main() {
  test('routeForMessageData maps order notifications to orders screen', () {
    expect(
      FcmNavigation.routeForMessageData({'type': 'order', 'order_id': '42'}),
      '/home/more/orders?order_id=42',
    );
  });

  test('routeForMessageData maps booking notifications to inbox tab', () {
    expect(
      FcmNavigation.routeForMessageData({'type': 'service_booking'}),
      '/home/notifications',
    );
  });

  test('routeForMessageData honors explicit route aliases', () {
    expect(
      FcmNavigation.routeForMessageData({'route': '/orders'}),
      '/home/more/orders',
    );
  });

  test('routeForMessageData returns null for sync hints', () {
    expect(
      FcmNavigation.routeForMessageData({'type': 'sync_hint'}),
      isNull,
    );
    expect(FcmNavigation.shouldTriggerSync({'type': 'sync_hint'}), isTrue);
  });
}