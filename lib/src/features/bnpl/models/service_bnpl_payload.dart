/// BNPL settings for an individual service.
class ServiceBnplPayload {
  const ServiceBnplPayload({
    this.enabled = false,
    this.minOrderAmount,
    this.maxOrderAmount,
    this.installmentCount,
  });

  factory ServiceBnplPayload.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return ServiceBnplPayload(
      enabled: json['enabled'] == true || json['enabled'] == 1,
      minOrderAmount: parseDouble(json['min_order_amount']),
      maxOrderAmount: parseDouble(json['max_order_amount']),
      installmentCount: json['installment_count'] == null
          ? null
          : int.tryParse(json['installment_count'].toString()),
    );
  }

  final bool enabled;
  final double? minOrderAmount;
  final double? maxOrderAmount;
  final int? installmentCount;

  Map<String, dynamic> toJson() => {
        'enabled': enabled ? 1 : 0,
        if (minOrderAmount != null) 'min_order_amount': minOrderAmount,
        if (maxOrderAmount != null) 'max_order_amount': maxOrderAmount,
        if (installmentCount != null) 'installment_count': installmentCount,
      };
}
