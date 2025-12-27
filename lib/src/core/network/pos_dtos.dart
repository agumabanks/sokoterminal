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
    required this.suppliers,
    required this.receiptTemplates,
    required this.quotationTemplates,
    required this.ledgerEntries,
    required this.sellerProfile,
    required this.outlet,
  });

  final DateTime receivedAt;
  final DateTime since;
  final String outletId;
  final List<PosSyncProduct> products;
  final List<PosSyncService> services;
  final List<PosSyncCustomer> customers;
  final List<PosSyncSupplier> suppliers;
  final List<PosSyncReceiptTemplate> receiptTemplates;
  final List<PosSyncQuotationTemplate> quotationTemplates;
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
    final suppliersRaw = json['suppliers'];
    final receiptTemplatesRaw = json['receipt_templates'];
    final quotationTemplatesRaw = json['quotation_templates'];
    final ledgerEntriesRaw = json['ledger_entries'];
    final sellerProfileRaw = json['seller_profile'];

    final config = json['config'];
    final outletRaw = config is Map<String, dynamic> ? config['outlet'] : null;

    return PosSyncPullResponse(
      receivedAt: DateTime.parse(receivedAtRaw.toString()).toUtc(),
      since: DateTime.parse(sinceRaw.toString()).toUtc(),
      outletId: outletId,
      products: _parseList(productsRaw, PosSyncProduct.fromJson),
      services: _parseList(servicesRaw, PosSyncService.fromJson),
      customers: _parseList(customersRaw, PosSyncCustomer.fromJson),
      suppliers: _parseList(suppliersRaw, PosSyncSupplier.fromJson),
      receiptTemplates: _parseList(receiptTemplatesRaw, PosSyncReceiptTemplate.fromJson),
      quotationTemplates: _parseList(quotationTemplatesRaw, PosSyncQuotationTemplate.fromJson),
      ledgerEntries: _parseList(ledgerEntriesRaw, PosSyncLedgerEntry.fromJson),
      sellerProfile: sellerProfileRaw is Map<String, dynamic>
          ? PosSyncSellerProfile.fromJson(sellerProfileRaw)
          : null,
      outlet: outletRaw is Map<String, dynamic> ? PosSyncOutlet.fromJson(outletRaw) : null,
    );
  }

  final List<PosSyncLedgerEntry> ledgerEntries;
  final PosSyncSellerProfile? sellerProfile;
}

class PosSyncProduct {
  PosSyncProduct({
    required this.id,
    required this.name,
    required this.unitPrice,
    required this.currentStock,
    required this.published,
    required this.updatedAt,
    this.categoryId,
    this.brandId,
    this.unit,
    this.weight,
    this.minQty,
    this.lowStockQuantity,
    this.discount,
    this.discountType,
    this.shippingCost,
    this.estShippingDays,
    this.refundable,
    this.cashOnDelivery,
    this.tags,
    this.description,
    this.barcode,
    this.imageUrl,
    this.thumbnailUploadId,
    this.thumbnailUrl,
    this.photoUploadIds = const [],
    this.galleryUrls = const [],
    this.stocks = const [],
  });

  final String id;
  final String name;
  final double unitPrice;
  final int currentStock;
  final bool published;
  final DateTime? updatedAt;
  final int? categoryId;
  final int? brandId;
  final String? unit;
  final double? weight;
  final int? minQty;
  final int? lowStockQuantity;
  final double? discount;
  final String? discountType;
  final double? shippingCost;
  final int? estShippingDays;
  final bool? refundable;
  final bool? cashOnDelivery;
  final String? tags;
  final String? description;
  final String? barcode;
  final String? imageUrl;
  final int? thumbnailUploadId;
  final String? thumbnailUrl;
  final List<int> photoUploadIds;
  final List<String> galleryUrls;
  final List<PosSyncProductStock> stocks;

  factory PosSyncProduct.fromJson(Map<String, dynamic> json) {
    return PosSyncProduct(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      unitPrice: _asDouble(json['unit_price']),
      currentStock: _asInt(json['current_stock']),
      published: _asBool(json['published']),
      updatedAt: _asDateTime(json['updated_at']),
      categoryId: _asNullableInt(json['category_id']),
      brandId: _asNullableInt(json['brand_id']),
      unit: json['unit']?.toString(),
      weight: _asNullableDouble(json['weight']),
      minQty: _asNullableInt(json['min_qty']),
      lowStockQuantity: _asNullableInt(json['low_stock_quantity']),
      discount: _asNullableDouble(json['discount']),
      discountType: json['discount_type']?.toString(),
      shippingCost: _asNullableDouble(json['shipping_cost']),
      estShippingDays: _asNullableInt(json['est_shipping_days']),
      refundable: _asNullableBool(json['refundable']),
      cashOnDelivery: _asNullableBool(json['cash_on_delivery']),
      tags: json['tags']?.toString(),
      description: json['description']?.toString(),
      barcode: json['barcode']?.toString(),
      imageUrl: json['image_url']?.toString() ?? json['image']?.toString(),
      thumbnailUploadId: _asNullableInt(json['thumbnail_upload_id']),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      photoUploadIds: (json['photo_upload_ids'] is List)
          ? (json['photo_upload_ids'] as List)
              .map((e) => _asNullableInt(e))
              .whereType<int>()
              .toList()
          : const [],
      galleryUrls: (json['gallery_urls'] is List)
          ? (json['gallery_urls'] as List)
              .map((e) => e?.toString() ?? '')
              .where((e) => e.trim().isNotEmpty)
              .toList()
          : const [],
      stocks: (json['stocks'] is List)
          ? (json['stocks'] as List)
              .whereType<Map>()
              .map((e) => PosSyncProductStock.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

class PosSyncProductStock {
  PosSyncProductStock({
    required this.id,
    required this.variant,
    required this.price,
    required this.qty,
    this.sku,
    this.imageUploadId,
    this.imageUrl,
    this.updatedAt,
  });

  final int id;
  final String variant;
  final double price;
  final int qty;
  final String? sku;
  final int? imageUploadId;
  final String? imageUrl;
  final DateTime? updatedAt;

  factory PosSyncProductStock.fromJson(Map<String, dynamic> json) {
    return PosSyncProductStock(
      id: _asInt(json['id']),
      variant: (json['variant'] ?? '').toString(),
      price: _asDouble(json['price']),
      qty: _asInt(json['qty']),
      sku: json['sku']?.toString(),
      imageUploadId: _asNullableInt(json['image_upload_id']),
      imageUrl: json['image_url']?.toString(),
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
    required this.category,
    required this.published,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final double price;
  final String? description;
  final int? durationMinutes;
  final String? category;
  final bool published;
  final DateTime? updatedAt;

  factory PosSyncService.fromJson(Map<String, dynamic> json) {
    return PosSyncService(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      price: _asDouble(json['price']),
      description: json['description']?.toString(),
      durationMinutes: _asNullableInt(json['duration_minutes']),
      category: json['category']?.toString(),
      published: _asBool(json['published']),
      updatedAt: _asDateTime(json['updated_at']),
    );
  }
}

class PosSyncSupplier {
  PosSyncSupplier({
    required this.id,
    required this.name,
    required this.active,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final bool active;
  final DateTime? updatedAt;

  factory PosSyncSupplier.fromJson(Map<String, dynamic> json) {
    return PosSyncSupplier(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      contactName: json['contact_name']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      notes: json['notes']?.toString(),
      active: _asBool(json['active']),
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

class PosSyncLedgerEntry {
  PosSyncLedgerEntry({
    required this.id,
    required this.clientEntryId,
    required this.customerId,
    required this.type,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.note,
    required this.occurredAt,
    required this.updatedAt,
    required this.lines,
    required this.payments,
  });

  final String id;
  final String clientEntryId;
  final String? customerId;
  final String type;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String? note;
  final DateTime? occurredAt;
  final DateTime? updatedAt;
  final List<PosSyncLedgerLine> lines;
  final List<PosSyncLedgerPayment> payments;

  factory PosSyncLedgerEntry.fromJson(Map<String, dynamic> json) {
    return PosSyncLedgerEntry(
      id: (json['id'] ?? '').toString(),
      clientEntryId: (json['client_entry_id'] ?? '').toString(),
      customerId: json['customer_id']?.toString(),
      type: (json['type'] ?? '').toString(),
      subtotal: _asDouble(json['subtotal']),
      discount: _asDouble(json['discount']),
      tax: _asDouble(json['tax']),
      total: _asDouble(json['total']),
      note: json['note']?.toString(),
      occurredAt: _asDateTime(json['occurred_at']),
      updatedAt: _asDateTime(json['updated_at']),
      lines: _parseList(json['lines'], PosSyncLedgerLine.fromJson),
      payments: _parseList(json['payments'], PosSyncLedgerPayment.fromJson),
    );
  }
}

class PosSyncLedgerLine {
  PosSyncLedgerLine({
    required this.id,
    required this.itemId,
    required this.title,
    required this.price,
    required this.quantity,
    required this.total,
  });

  final String id;
  final String? itemId;
  final String title;
  final double price;
  final int quantity;
  final double total;

  factory PosSyncLedgerLine.fromJson(Map<String, dynamic> json) {
    return PosSyncLedgerLine(
      id: (json['id'] ?? '').toString(),
      itemId: json['item_id']?.toString(),
      title: (json['title'] ?? '').toString(),
      price: _asDouble(json['price']),
      quantity: _asInt(json['quantity']),
      total: _asDouble(json['total']),
    );
  }
}

class PosSyncLedgerPayment {
  PosSyncLedgerPayment({
    required this.id,
    required this.method,
    required this.amount,
  });

  final String id;
  final String method;
  final double amount;

  factory PosSyncLedgerPayment.fromJson(Map<String, dynamic> json) {
    return PosSyncLedgerPayment(
      id: (json['id'] ?? '').toString(),
      method: (json['method'] ?? '').toString(),
      amount: _asDouble(json['amount']),
    );
  }
}

class PosSyncSellerProfile {
  PosSyncSellerProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.businessName,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? businessName;

  factory PosSyncSellerProfile.fromJson(Map<String, dynamic> json) {
    return PosSyncSellerProfile(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      businessName: json['business_name']?.toString(),
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

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
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

bool? _asNullableBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final str = value.toString().toLowerCase();
  if (str == '1' || str == 'true' || str == 'yes') return true;
  if (str == '0' || str == 'false' || str == 'no') return false;
  return null;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  try {
    return DateTime.parse(value.toString()).toUtc();
  } catch (_) {
    return null;
  }
}

class PosSyncReceiptTemplate {
  PosSyncReceiptTemplate({
    required this.id,
    required this.name,
    required this.style,
    this.headerMessage,
    this.headerColor,
    this.footerMessage,
    required this.showLogo,
    required this.showQr,
    required this.isActive,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String style;
  final String? headerMessage;
  final String? headerColor;
  final String? footerMessage;
  final bool showLogo;
  final bool showQr;
  final bool isActive;
  final DateTime updatedAt;

  factory PosSyncReceiptTemplate.fromJson(Map<String, dynamic> json) {
    return PosSyncReceiptTemplate(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      style: (json['style'] ?? 'minimal').toString(),
      headerMessage: json['header_message']?.toString(),
      headerColor: json['header_color']?.toString(),
      footerMessage: json['footer_message']?.toString(),
      showLogo: _asBool(json['show_logo']),
      showQr: _asBool(json['show_qr']),
      isActive: _asBool(json['is_active']),
      updatedAt: _asDateTime(json['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class PosSyncQuotationTemplate {
  PosSyncQuotationTemplate({
    required this.id,
    required this.name,
    required this.style,
    this.headerMessage,
    this.headerColor,
    this.footerMessage,
    required this.showLogo,
    required this.showQr,
    required this.isActive,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String style;
  final String? headerMessage;
  final String? headerColor;
  final String? footerMessage;
  final bool showLogo;
  final bool showQr;
  final bool isActive;
  final DateTime updatedAt;

  factory PosSyncQuotationTemplate.fromJson(Map<String, dynamic> json) {
    return PosSyncQuotationTemplate(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      style: (json['style'] ?? 'minimal').toString(),
      headerMessage: json['header_message']?.toString(),
      headerColor: json['header_color']?.toString(),
      footerMessage: json['footer_message']?.toString(),
      showLogo: _asBool(json['show_logo']),
      showQr: _asBool(json['show_qr']),
      isActive: _asBool(json['is_active']),
      updatedAt: _asDateTime(json['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
