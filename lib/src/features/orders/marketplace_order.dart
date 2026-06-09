class OrderLine {
  const OrderLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.variant,
    this.productName,
  });

  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? variant;
  final String? productName;

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    final qty = int.tryParse(json['quantity']?.toString() ?? '0') ?? 0;
    final unitPrice = _parseAmount(json['unit_price']);
    final lineTotal = json['total'] is num
        ? (json['total'] as num).toDouble()
        : (unitPrice * qty);
    final name =
        json['product_name']?.toString() ??
        json['name']?.toString() ??
        'Item';

    return OrderLine(
      name: name,
      quantity: qty,
      unitPrice: unitPrice,
      lineTotal: lineTotal,
      variant: json['variation']?.toString(),
      productName: json['product_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'product_name': productName ?? name,
    'name': name,
    'quantity': quantity,
    'unit_price': unitPrice,
    'total': lineTotal,
    if (variant != null && variant!.isNotEmpty) 'variation': variant,
  };
}

class MarketplaceOrder {
  const MarketplaceOrder({
    required this.id,
    this.orderCode,
    this.code,
    this.customerName,
    this.customerPhone,
    this.deliveryStatus,
    this.deliveryStatusRaw,
    this.paymentStatus,
    this.grandTotal,
    this.total,
    this.createdAt,
    this.date,
    this.paymentType,
    this.shippingCost,
    this.shippingAddress,
    this.items = const [],
    this.orderItems = const [],
    this.sokoDeliveryRequest,
    this.pendingSync = false,
    this.orderFrom,
    this.source,
    this.numOfProducts,
    this.itemsCount,
    this.raw = const {},
  });

  final int id;
  final String? orderCode;
  final String? code;
  final String? customerName;
  final String? customerPhone;
  final String? deliveryStatus;
  final String? deliveryStatusRaw;
  final String? paymentStatus;
  final double? grandTotal;
  final double? total;
  final String? createdAt;
  final String? date;
  final String? paymentType;
  final dynamic shippingCost;
  final Map<String, dynamic>? shippingAddress;
  final List<OrderLine> items;
  final List<OrderLine> orderItems;
  final Map<String, dynamic>? sokoDeliveryRequest;
  final bool pendingSync;
  final String? orderFrom;
  final String? source;
  final int? numOfProducts;
  final int? itemsCount;
  final Map<String, dynamic> raw;

  factory MarketplaceOrder.fromJson(Map<String, dynamic> json) {
    final id = int.tryParse(json['id']?.toString() ?? '') ?? 0;
    final itemsRaw = json['items'] ?? json['order_items'];
    final parsedItems = _parseLines(itemsRaw);

    return MarketplaceOrder(
      id: id,
      orderCode: json['order_code']?.toString(),
      code: json['code']?.toString(),
      customerName: json['customer_name']?.toString(),
      customerPhone: json['customer_phone']?.toString(),
      deliveryStatus: json['delivery_status']?.toString(),
      deliveryStatusRaw: json['delivery_status_raw']?.toString(),
      paymentStatus: json['payment_status']?.toString(),
      grandTotal: _parseNullableAmount(json['grand_total']),
      total: _parseNullableAmount(json['total']),
      createdAt: json['created_at']?.toString(),
      date: json['date']?.toString(),
      paymentType: json['payment_type']?.toString(),
      shippingCost: json['shipping_cost'],
      shippingAddress: json['shipping_address'] is Map
          ? Map<String, dynamic>.from(json['shipping_address'] as Map)
          : null,
      items: parsedItems,
      orderItems: parsedItems,
      sokoDeliveryRequest: json['soko_delivery_request'] is Map
          ? Map<String, dynamic>.from(json['soko_delivery_request'] as Map)
          : null,
      pendingSync: json['pending_sync'] == true,
      orderFrom: json['order_from']?.toString(),
      source: json['source']?.toString(),
      numOfProducts: int.tryParse(json['num_of_products']?.toString() ?? ''),
      itemsCount: int.tryParse(json['items_count']?.toString() ?? ''),
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() {
    final map = Map<String, dynamic>.from(raw);
    map['id'] = id;
    if (orderCode != null) map['order_code'] = orderCode;
    if (code != null) map['code'] = code;
    if (customerName != null) map['customer_name'] = customerName;
    if (customerPhone != null) map['customer_phone'] = customerPhone;
    if (deliveryStatus != null) map['delivery_status'] = deliveryStatus;
    if (deliveryStatusRaw != null) {
      map['delivery_status_raw'] = deliveryStatusRaw;
    }
    if (paymentStatus != null) map['payment_status'] = paymentStatus;
    if (grandTotal != null) map['grand_total'] = grandTotal;
    if (total != null) map['total'] = total;
    if (createdAt != null) map['created_at'] = createdAt;
    if (date != null) map['date'] = date;
    if (paymentType != null) map['payment_type'] = paymentType;
    if (shippingCost != null) map['shipping_cost'] = shippingCost;
    if (shippingAddress != null) map['shipping_address'] = shippingAddress;
    if (sokoDeliveryRequest != null) {
      map['soko_delivery_request'] = sokoDeliveryRequest;
    }
    map['pending_sync'] = pendingSync;
    final lines = orderItems.map((line) => line.toJson()).toList();
    map['items'] = lines;
    map['order_items'] = lines;
    return map;
  }

  MarketplaceOrder copyWith({
    int? id,
    String? orderCode,
    String? code,
    String? customerName,
    String? customerPhone,
    String? deliveryStatus,
    String? deliveryStatusRaw,
    String? paymentStatus,
    double? grandTotal,
    double? total,
    String? createdAt,
    String? date,
    String? paymentType,
    dynamic shippingCost,
    Map<String, dynamic>? shippingAddress,
    List<OrderLine>? items,
    List<OrderLine>? orderItems,
    Map<String, dynamic>? sokoDeliveryRequest,
    bool? pendingSync,
    String? orderFrom,
    String? source,
    int? numOfProducts,
    int? itemsCount,
    Map<String, dynamic>? raw,
  }) {
    return MarketplaceOrder(
      id: id ?? this.id,
      orderCode: orderCode ?? this.orderCode,
      code: code ?? this.code,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      deliveryStatusRaw: deliveryStatusRaw ?? this.deliveryStatusRaw,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      grandTotal: grandTotal ?? this.grandTotal,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      date: date ?? this.date,
      paymentType: paymentType ?? this.paymentType,
      shippingCost: shippingCost ?? this.shippingCost,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      items: items ?? this.items,
      orderItems: orderItems ?? this.orderItems,
      sokoDeliveryRequest: sokoDeliveryRequest ?? this.sokoDeliveryRequest,
      pendingSync: pendingSync ?? this.pendingSync,
      orderFrom: orderFrom ?? this.orderFrom,
      source: source ?? this.source,
      numOfProducts: numOfProducts ?? this.numOfProducts,
      itemsCount: itemsCount ?? this.itemsCount,
      raw: raw ?? this.raw,
    );
  }

  MarketplaceOrder merge(MarketplaceOrder other) {
    final mergedRaw = {...raw, ...other.raw};
    return MarketplaceOrder.fromJson(mergedRaw).copyWith(
      id: other.id == 0 ? id : other.id,
      pendingSync: other.pendingSync || pendingSync,
      orderItems: other.orderItems.isNotEmpty ? other.orderItems : orderItems,
      items: other.items.isNotEmpty ? other.items : items,
    );
  }

  String get displayCode =>
      orderCode ?? code ?? (id == 0 ? 'N/A' : id.toString());

  String get displayCustomer =>
      customerName ?? shippingAddress?['name']?.toString() ?? 'Customer';

  String get displayPhone =>
      customerPhone ??
      shippingAddress?['phone']?.toString() ??
      'Not provided';

  String get normalizedDeliveryStatus =>
      (deliveryStatusRaw ?? deliveryStatus ?? 'pending')
          .trim()
          .toLowerCase()
          .replaceAll(' ', '_');

  String get normalizedPaymentStatus =>
      (paymentStatus ?? 'unpaid').trim().toLowerCase();

  String get displayPaymentMethod =>
      (paymentType ?? '').replaceAll('_', ' ').trim();

  String get displaySource => _humanizeStatus(
    orderFrom ?? source ?? 'marketplace',
  );

  double get displayTotal {
    final rawTotal = grandTotal ?? total;
    if (rawTotal != null) return rawTotal;
    return 0;
  }

  int get lineItemCount {
    if (orderItems.isNotEmpty) return orderItems.length;
    if (items.isNotEmpty) return items.length;
    return numOfProducts ?? itemsCount ?? 0;
  }

  DateTime? get orderedAt {
    final rawDate = createdAt ?? date;
    if (rawDate == null || rawDate.isEmpty) return null;
    return DateTime.tryParse(rawDate);
  }

  bool get hasSokoDeliveryRequest =>
      sokoDeliveryRequest != null && sokoDeliveryRequest!.isNotEmpty;

  bool get canRequestSokoDelivery {
    if (hasSokoDeliveryRequest) return false;
    final status = normalizedDeliveryStatus;
    return status != 'delivered' && status != 'cancelled';
  }

  static List<MarketplaceOrder> listFromJson(Iterable<dynamic> raw) {
    return raw
        .whereType<Map>()
        .map((entry) => MarketplaceOrder.fromJson(Map<String, dynamic>.from(entry)))
        .where((order) => order.id > 0)
        .toList();
  }
}

List<OrderLine> _parseLines(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((entry) => OrderLine.fromJson(Map<String, dynamic>.from(entry)))
      .toList();
}

double _parseAmount(dynamic raw) {
  if (raw == null) return 0;
  if (raw is num) return raw.toDouble();
  final cleaned = raw.toString().replaceAll(RegExp(r'[^0-9.]'), '');
  return double.tryParse(cleaned) ?? 0;
}

double? _parseNullableAmount(dynamic raw) {
  if (raw == null) return null;
  return _parseAmount(raw);
}

String _humanizeStatus(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}