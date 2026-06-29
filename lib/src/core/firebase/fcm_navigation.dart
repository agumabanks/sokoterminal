/// Resolves push notification payloads to in-app routes.
class FcmNavigation {
  const FcmNavigation._();

  /// Returns a GoRouter location, or null when no navigation is needed.
  static String? routeForMessageData(Map<String, dynamic> data) {
    final explicitRoute = _firstNonEmpty([
      data['route']?.toString(),
      data['deep_link']?.toString(),
      data['screen']?.toString(),
    ]);
    if (explicitRoute != null) {
      return _normalizeRoute(explicitRoute);
    }

    final type = data['type']?.toString().toLowerCase().trim() ?? '';
    final category = data['category']?.toString().toLowerCase().trim() ?? '';

    if (type == 'sync_hint') {
      return null;
    }

    if (_matches(type, category, const ['order', 'orders', 'marketplace_order'])) {
      final orderId = data['order_id']?.toString();
      if (orderId != null && orderId.isNotEmpty) {
        return '/home/more/orders?order_id=$orderId';
      }
      return '/home/more/orders';
    }

    if (_matches(type, category, const [
      'booking',
      'service_booking',
      'service-booking',
      'service_bookings',
    ])) {
      return '/home/notifications';
    }

    if (_matches(type, category, const [
      'notification',
      'notifications',
      'alert',
      'alerts',
      'inbox',
    ])) {
      return '/home/notifications';
    }

    if (_matches(type, category, const ['sync', 'sync_health', 'sync-failed'])) {
      return '/home/more/sync-health';
    }

    if (_matches(type, category, const ['low_stock', 'stock_alert', 'inventory'])) {
      return '/home/more/low-stock';
    }

    if (type == 'studio') {
      final params = <String, String>{
        if (data['product_id'] != null && data['product_id'].toString().isNotEmpty)
          'product_id': data['product_id'].toString(),
        if (data['service_id'] != null && data['service_id'].toString().isNotEmpty)
          'service_id': data['service_id'].toString(),
        if (data['quotation_id'] != null && data['quotation_id'].toString().isNotEmpty)
          'quotation_id': data['quotation_id'].toString(),
        if (data['receipt_id'] != null && data['receipt_id'].toString().isNotEmpty)
          'receipt_id': data['receipt_id'].toString(),
        if (data['brand_kit']?.toString() == '1') 'brand_kit': '1',
        if (data['open_panel'] != null && data['open_panel'].toString().isNotEmpty)
          'open_panel': data['open_panel'].toString(),
      };
      final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      return query.isEmpty ? '/studio' : '/studio?$query';
    }

    return null;
  }

  static bool shouldTriggerSync(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase().trim() ?? '';
    return type == 'sync_hint' || data['sync']?.toString() == '1';
  }

  static String? foregroundTitle(Map<String, dynamic> data, {String? notificationTitle}) {
    if (notificationTitle != null && notificationTitle.trim().isNotEmpty) {
      return notificationTitle.trim();
    }
    return data['title']?.toString();
  }

  static String? foregroundBody(Map<String, dynamic> data, {String? notificationBody}) {
    if (notificationBody != null && notificationBody.trim().isNotEmpty) {
      return notificationBody.trim();
    }
    return data['body']?.toString();
  }

  static String _normalizeRoute(String raw) {
    var route = raw.trim();
    if (route.isEmpty) return '/home/checkout';
    if (!route.startsWith('/')) route = '/$route';
    const aliases = <String, String>{
      '/checkout': '/home/checkout',
      '/orders': '/home/more/orders',
      '/services': '/home/more/services',
      '/notifications': '/home/notifications',
      '/inbox': '/home/notifications',
      '/alerts': '/home/notifications',
      '/sync': '/home/more/sync-health',
      '/sync-health': '/home/more/sync-health',
    };
    return aliases[route] ?? route;
  }

  static bool _matches(String type, String category, List<String> values) {
    return values.contains(type) || values.contains(category);
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}