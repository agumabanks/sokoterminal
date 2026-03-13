import 'dart:convert';

import '../db/app_database.dart';
import 'shop_payment_settings.dart';

const String kPrimaryBusinessProfileId = 'primary';

Map<String, dynamic>? decodeJsonObject(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return null;
}

ShopPaymentSettings businessProfileToPaymentSettings(BusinessProfile profile) {
  final receiptMethods =
      decodeJsonObject(profile.receiptPaymentMethodsJson) ?? const {};
  final cashEnabled = receiptMethods.isEmpty
      ? profile.cashOnDeliveryEnabled
      : _resolveBool(receiptMethods['cash'], profile.cashOnDeliveryEnabled);
  final bankEnabled = receiptMethods.isEmpty
      ? profile.bankPaymentEnabled
      : _resolveBool(
          receiptMethods['bank_transfer'],
          profile.bankPaymentEnabled,
        );
  final mobileMoneyEnabled = receiptMethods.isEmpty
      ? profile.mobileMoneyEnabled
      : _resolveBool(
          receiptMethods['mobile_money'],
          profile.mobileMoneyEnabled,
        );

  return ShopPaymentSettings(
    cashEnabled: cashEnabled,
    bankEnabled: bankEnabled,
    mobileMoneyEnabled: mobileMoneyEnabled,
    bankName: profile.bankName ?? '',
    bankAccountName: profile.bankAccName ?? '',
    bankAccountNumber: profile.bankAccNo ?? '',
    bankRoutingNumber: profile.bankRoutingNo ?? '',
    mtnMerchantCode: profile.mtnMerchantCode ?? '',
    airtelMerchantCode: profile.airtelMerchantCode ?? '',
    paybillNumber: profile.paybillNumber ?? '',
    receiptPaymentMethods: receiptMethods,
  );
}

bool _resolveBool(dynamic value, bool fallback) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().trim().toLowerCase();
  if (text == '1' || text == 'true' || text == 'yes') return true;
  if (text == '0' || text == 'false' || text == 'no') return false;
  return fallback;
}
