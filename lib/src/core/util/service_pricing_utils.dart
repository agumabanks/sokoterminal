import 'dart:convert';

/// Marketplace pricing tier (Basic / Standard / Premium) — mirrors web seller form.
class ServicePricingTier {
  const ServicePricingTier({
    required this.tier,
    this.price,
    this.deliveryDays,
    this.revisions,
    this.description,
    this.remoteId,
  });

  final String tier;
  final double? price;
  final int? deliveryDays;
  final int? revisions;
  final String? description;
  final int? remoteId;

  bool get hasPrice => price != null && price! > 0;

  ServicePricingTier copyWith({
    double? price,
    int? deliveryDays,
    int? revisions,
    String? description,
    int? remoteId,
  }) {
    return ServicePricingTier(
      tier: tier,
      price: price ?? this.price,
      deliveryDays: deliveryDays ?? this.deliveryDays,
      revisions: revisions ?? this.revisions,
      description: description ?? this.description,
      remoteId: remoteId ?? this.remoteId,
    );
  }

  Map<String, dynamic> toJson() => {
        'tier': tier,
        if (remoteId != null) 'remote_id': remoteId,
        if (price != null) 'price': price,
        if (deliveryDays != null) 'delivery_days': deliveryDays,
        if (revisions != null) 'revisions': revisions,
        if (description != null && description!.trim().isNotEmpty)
          'description': description,
      };

  factory ServicePricingTier.fromJson(Map<String, dynamic> json) {
    return ServicePricingTier(
      tier: (json['tier'] ?? '').toString(),
      remoteId: json['remote_id'] is int
          ? json['remote_id'] as int
          : int.tryParse(json['id']?.toString() ?? json['remote_id']?.toString() ?? ''),
      price: _asDouble(json['price']),
      deliveryDays: _asInt(json['delivery_days']),
      revisions: _asInt(json['revisions']),
      description: json['description']?.toString(),
    );
  }

  static List<ServicePricingTier> emptyTiers() => const [
        ServicePricingTier(tier: 'basic'),
        ServicePricingTier(tier: 'standard'),
        ServicePricingTier(tier: 'premium'),
      ];

  static List<ServicePricingTier> mergeWithDefaults(List<ServicePricingTier> existing) {
    final map = {for (final t in existing) t.tier: t};
    return [
      map['basic'] ?? const ServicePricingTier(tier: 'basic'),
      map['standard'] ?? const ServicePricingTier(tier: 'standard'),
      map['premium'] ?? const ServicePricingTier(tier: 'premium'),
    ];
  }
}

List<ServicePricingTier> decodePricingPackages(String? raw) {
  if (raw == null || raw.trim().isEmpty) return ServicePricingTier.emptyTiers();
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is! List) return ServicePricingTier.emptyTiers();
    final tiers = decoded
        .whereType<Map>()
        .map((e) => ServicePricingTier.fromJson(Map<String, dynamic>.from(e)))
        .where((t) => t.tier.isNotEmpty)
        .toList();
    return ServicePricingTier.mergeWithDefaults(tiers);
  } catch (_) {
    return ServicePricingTier.emptyTiers();
  }
}

String? encodePricingPackages(List<ServicePricingTier> tiers) {
  final active = tiers.where((t) => t.hasPrice).map((t) => t.toJson()).toList();
  if (active.isEmpty) return null;
  return jsonEncode(active);
}

Map<String, dynamic> pricingPackagesForApi(List<ServicePricingTier> tiers) {
  final out = <String, dynamic>{};
  for (final tier in tiers) {
    if (!tier.hasPrice) continue;
    out[tier.tier] = {
      'price': tier.price,
      if (tier.deliveryDays != null) 'delivery_days': tier.deliveryDays,
      if (tier.revisions != null) 'revisions': tier.revisions,
      if (tier.description != null && tier.description!.trim().isNotEmpty)
        'description': tier.description!.trim(),
    };
  }
  return out;
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}