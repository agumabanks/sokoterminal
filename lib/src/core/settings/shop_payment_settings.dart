import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ShopPaymentSettings {
  const ShopPaymentSettings({
    required this.cashEnabled,
    required this.bankEnabled,
    required this.mobileMoneyEnabled,
    required this.bankName,
    required this.bankAccountName,
    required this.bankAccountNumber,
    required this.bankRoutingNumber,
    required this.mtnMerchantCode,
    required this.airtelMerchantCode,
    required this.paybillNumber,
    this.receiptPaymentMethods,
  });

  final bool cashEnabled;
  final bool bankEnabled;
  final bool mobileMoneyEnabled;
  final String bankName;
  final String bankAccountName;
  final String bankAccountNumber;
  final String bankRoutingNumber;
  final String mtnMerchantCode;
  final String airtelMerchantCode;
  final String paybillNumber;
  final Map<String, dynamic>? receiptPaymentMethods;

  factory ShopPaymentSettings.defaults() {
    return const ShopPaymentSettings(
      cashEnabled: true,
      bankEnabled: false,
      mobileMoneyEnabled: true,
      bankName: '',
      bankAccountName: '',
      bankAccountNumber: '',
      bankRoutingNumber: '',
      mtnMerchantCode: '',
      airtelMerchantCode: '',
      paybillNumber: '',
    );
  }

  factory ShopPaymentSettings.fromJson(Map<String, dynamic> json) {
    return ShopPaymentSettings(
      cashEnabled: _asBool(json['cash_enabled'], defaultValue: true),
      bankEnabled: _asBool(json['bank_enabled'], defaultValue: false),
      mobileMoneyEnabled: _asBool(json['mobile_money_enabled'], defaultValue: false),
      bankName: _asString(json['bank_name']),
      bankAccountName: _asString(json['bank_account_name']),
      bankAccountNumber: _asString(json['bank_account_number']),
      bankRoutingNumber: _asString(json['bank_routing_number']),
      mtnMerchantCode: _asString(json['mtn_merchant_code']),
      airtelMerchantCode: _asString(json['airtel_merchant_code']),
      paybillNumber: _asString(json['paybill_number']),
      receiptPaymentMethods: json['receipt_payment_methods'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['receipt_payment_methods'] as Map<String, dynamic>)
          : null,
    );
  }

  factory ShopPaymentSettings.fromShopInfo(Map<String, dynamic> data) {
    final methods = data['receipt_payment_methods'] is Map
        ? Map<String, dynamic>.from(data['receipt_payment_methods'] as Map)
        : null;

    return ShopPaymentSettings(
      cashEnabled: methods == null
          ? _asBool(data['cash_on_delivery_status'], defaultValue: true)
          : _asBool(methods['cash'], defaultValue: true),
      bankEnabled: methods == null
          ? _asBool(data['bank_payment_status'], defaultValue: false)
          : _asBool(methods['bank_transfer'], defaultValue: false),
      mobileMoneyEnabled: methods == null
          ? true
          : _asBool(methods['mobile_money'], defaultValue: true),
      bankName: _asString(data['bank_name']),
      bankAccountName: _asString(data['bank_acc_name']),
      bankAccountNumber: _asString(data['bank_acc_no']),
      bankRoutingNumber: _asString(data['bank_routing_no']),
      mtnMerchantCode: _asString(data['mtn_merchant_code']),
      airtelMerchantCode: _asString(data['airtel_merchant_code']),
      paybillNumber: _asString(data['paybill_number']),
      receiptPaymentMethods: data['receipt_payment_methods'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['receipt_payment_methods'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get hasMobileMoneyCodes =>
      mtnMerchantCode.trim().isNotEmpty ||
      airtelMerchantCode.trim().isNotEmpty ||
      paybillNumber.trim().isNotEmpty;

  bool get hasBankDetails =>
      bankName.trim().isNotEmpty ||
      bankAccountName.trim().isNotEmpty ||
      bankAccountNumber.trim().isNotEmpty ||
      bankRoutingNumber.trim().isNotEmpty;

  String? paymentInstructionsText() {
    final blocks = <String>[];

    if (mobileMoneyEnabled && hasMobileMoneyCodes) {
      final parts = <String>[];
      if (mtnMerchantCode.trim().isNotEmpty) {
        parts.add('MTN: ${mtnMerchantCode.trim()}');
      }
      if (airtelMerchantCode.trim().isNotEmpty) {
        parts.add('Airtel: ${airtelMerchantCode.trim()}');
      }
      if (paybillNumber.trim().isNotEmpty) {
        parts.add('Paybill: ${paybillNumber.trim()}');
      }
      if (parts.isNotEmpty) {
        blocks.add('Pay via Mobile Money:\n${parts.join(' | ')}');
      }
    }

    if (bankEnabled && hasBankDetails) {
      final lines = <String>['Bank transfer details:'];
      if (bankName.trim().isNotEmpty) lines.add('Bank: ${bankName.trim()}');
      if (bankAccountName.trim().isNotEmpty) {
        lines.add('A/C Name: ${bankAccountName.trim()}');
      }
      if (bankAccountNumber.trim().isNotEmpty) {
        lines.add('A/C No: ${bankAccountNumber.trim()}');
      }
      if (bankRoutingNumber.trim().isNotEmpty) {
        lines.add('Routing: ${bankRoutingNumber.trim()}');
      }
      blocks.add(lines.join('\n'));
    }

    if (blocks.isEmpty) return null;
    return blocks.join('\n\n');
  }

  Map<String, dynamic> toJson() {
    return {
      'cash_enabled': cashEnabled,
      'bank_enabled': bankEnabled,
      'mobile_money_enabled': mobileMoneyEnabled,
      'bank_name': bankName,
      'bank_account_name': bankAccountName,
      'bank_account_number': bankAccountNumber,
      'bank_routing_number': bankRoutingNumber,
      'mtn_merchant_code': mtnMerchantCode,
      'airtel_merchant_code': airtelMerchantCode,
      'paybill_number': paybillNumber,
      if (receiptPaymentMethods != null) 'receipt_payment_methods': receiptPaymentMethods,
    };
  }

  Map<String, dynamic> toUpdatePayload() {
    return {
      'cash_on_delivery_status': cashEnabled ? 1 : 0,
      'bank_payment_status': bankEnabled ? 1 : 0,
      'bank_name': bankName.trim(),
      'bank_acc_name': bankAccountName.trim(),
      'bank_acc_no': bankAccountNumber.trim(),
      'bank_routing_no': bankRoutingNumber.trim(),
      'mtn_merchant_code': mtnMerchantCode.trim(),
      'airtel_merchant_code': airtelMerchantCode.trim(),
      'paybill_number': paybillNumber.trim(),
      'receipt_payment_methods': {
        'cash': cashEnabled,
        'bank_transfer': bankEnabled,
        'mobile_money': mobileMoneyEnabled,
      },
    };
  }

  ShopPaymentSettings copyWith({
    bool? cashEnabled,
    bool? bankEnabled,
    bool? mobileMoneyEnabled,
    String? bankName,
    String? bankAccountName,
    String? bankAccountNumber,
    String? bankRoutingNumber,
    String? mtnMerchantCode,
    String? airtelMerchantCode,
    String? paybillNumber,
    Map<String, dynamic>? receiptPaymentMethods,
  }) {
    return ShopPaymentSettings(
      cashEnabled: cashEnabled ?? this.cashEnabled,
      bankEnabled: bankEnabled ?? this.bankEnabled,
      mobileMoneyEnabled: mobileMoneyEnabled ?? this.mobileMoneyEnabled,
      bankName: bankName ?? this.bankName,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankRoutingNumber: bankRoutingNumber ?? this.bankRoutingNumber,
      mtnMerchantCode: mtnMerchantCode ?? this.mtnMerchantCode,
      airtelMerchantCode: airtelMerchantCode ?? this.airtelMerchantCode,
      paybillNumber: paybillNumber ?? this.paybillNumber,
      receiptPaymentMethods: receiptPaymentMethods ?? this.receiptPaymentMethods,
    );
  }
}

class ShopPaymentSettingsCache {
  static const String _prefsKey = 'shop.payment_settings.v1';

  static ShopPaymentSettings? tryRead(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ShopPaymentSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return ShopPaymentSettings.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return null;
  }

  static ShopPaymentSettings read(SharedPreferences prefs) {
    return tryRead(prefs) ?? ShopPaymentSettings.defaults();
  }

  static Future<void> write(SharedPreferences prefs, ShopPaymentSettings settings) async {
    await prefs.setString(_prefsKey, jsonEncode(settings.toJson()));
  }
}

String _asString(dynamic value) => (value ?? '').toString();

bool _asBool(dynamic value, {required bool defaultValue}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = value.toString().toLowerCase().trim();
  if (s == '1' || s == 'true' || s == 'yes') return true;
  if (s == '0' || s == 'false' || s == 'no') return false;
  return defaultValue;
}
