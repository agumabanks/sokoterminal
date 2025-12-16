class PosLedgerAck {
  PosLedgerAck({
    required this.serverEntryId,
    required this.idempotencyKey,
    required this.receivedAt,
  });

  final String serverEntryId;
  final String idempotencyKey;
  final DateTime receivedAt;

  factory PosLedgerAck.fromJson(Map<String, dynamic> json) {
    final serverEntryId = json['server_entry_id'];
    final idempotencyKey = json['idempotency_key'];
    final receivedAt = json['received_at'];

    if (serverEntryId == null || idempotencyKey == null || receivedAt == null) {
      throw const FormatException('Missing required ledger ack fields.');
    }

    return PosLedgerAck(
      serverEntryId: serverEntryId.toString(),
      idempotencyKey: idempotencyKey.toString(),
      receivedAt: DateTime.parse(receivedAt.toString()).toUtc(),
    );
  }
}

class PosSyncPullResponse {
  PosSyncPullResponse({
    required this.receivedAt,
    required this.since,
    required this.outletId,
    required this.products,
    required this.services,
    required this.customers,
    required this.outlet,
  });

  final DateTime receivedAt;
  final DateTime since;
  final String outletId;
  final List<PosSyncProduct> products;
  final List<PosSyncService> services;
  final List<PosSyncCustomer> customers;
  final PosSyncOutlet? outlet;

  factory PosSyncPullResponse.fromJson(Map<String, dynamic> json) {
    final receivedAtRaw = json['received_at'];
    final sinceRaw = json['since'];

    if (receivedAtRaw == null || sinceRaw == null) {
      throw const FormatException('Missing required sync pull fields.');
    }

    final outletId = (json['outlet_id'] ?? '').toString();

    final productsRaw = json['products'];
    final servicesRaw = json['services'];
    final customersRaw = json['customers'];

    final config = json['config'];
    final outletRaw = config is Map<String, dynamic> ? config['outlet'] : null;

    return PosSyncPullResponse(
      receivedAt: DateTime.parse(receivedAtRaw.toString()).toUtc(),
      since: DateTime.parse(sinceRaw.toString()).toUtc(),
      outletId: outletId,
      products: _parseList(productsRaw, PosSyncProduct.fromJson),
      services: _parseList(servicesRaw, PosSyncService.fromJson),
      customers: _parseList(customersRaw, PosSyncCustomer.fromJson),
      outlet: outletRaw is Map<String, dynamic> ? PosSyncOutlet.fromJson(outletRaw) : null,
    );
  }
}

class PosSyncProduct {
  PosSyncProduct({
    required this.id,
    required this.name,
    required this.unitPrice,
    required this.currentStock,
    required this.published,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final double unitPrice;
  final int currentStock;
  final bool published;
  final DateTime? updatedAt;

  factory PosSyncProduct.fromJson(Map<String, dynamic> json) {
    return PosSyncProduct(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      unitPrice: _asDouble(json['unit_price']),
      currentStock: _asInt(json['current_stock']),
      published: _asBool(json['published']),
      updatedAt: _asDateTime(json['updated_at']),
    );
  }
}

class PosSyncService {
  PosSyncService({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    required this.durationMinutes,
    required this.published,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final double price;
  final String? description;
  final int? durationMinutes;
  final bool published;
  final DateTime? updatedAt;

  factory PosSyncService.fromJson(Map<String, dynamic> json) {
    return PosSyncService(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      price: _asDouble(json['price']),
      description: json['description']?.toString(),
      durationMinutes: _asNullableInt(json['duration_minutes']),
      published: _asBool(json['published']),
      updatedAt: _asDateTime(json['updated_at']),
    );
  }
}

class PosSyncCustomer {
  PosSyncCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final DateTime? updatedAt;

  factory PosSyncCustomer.fromJson(Map<String, dynamic> json) {
    return PosSyncCustomer(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      updatedAt: _asDateTime(json['updated_at']),
    );
  }
}

class PosSyncOutlet {
  PosSyncOutlet({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.thermalPrinterWidth,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? address;
  final String? phone;
  final int? thermalPrinterWidth;
  final DateTime? updatedAt;

  factory PosSyncOutlet.fromJson(Map<String, dynamic> json) {
    return PosSyncOutlet(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      thermalPrinterWidth: _asNullableInt(json['thermal_printer_width']),
      updatedAt: _asDateTime(json['updated_at']),
    );
  }
}

List<T> _parseList<T>(
  dynamic raw,
  T Function(Map<String, dynamic> json) fromJson,
) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final str = value?.toString().toLowerCase();
  return str == '1' || str == 'true' || str == 'yes';
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  try {
    return DateTime.parse(value.toString()).toUtc();
  } catch (_) {
    return null;
  }
}

