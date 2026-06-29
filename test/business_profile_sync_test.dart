import 'package:flutter_test/flutter_test.dart';

import 'package:soko_seller_terminal/src/core/db/app_database.dart';
import 'package:soko_seller_terminal/src/core/network/pos_dtos.dart';
import 'package:soko_seller_terminal/src/core/settings/business_profile_cache.dart';

void main() {
  test('PosSyncPullResponse parses canonical business profile payload', () {
    final json = <String, dynamic>{
      'received_at': '2026-03-07T00:00:00Z',
      'since': '2026-03-01T00:00:00Z',
      'outlet_id': '12',
      'products': const [],
      'services': const [],
      'service_variants': const [],
      'service_packages': const [],
      'customer_packages': const [],
      'package_redemptions': const [],
      'customers': const [],
      'suppliers': const [],
      'expenses': const [],
      'quotations': const [],
      'shifts': const [],
      'cash_movements': const [],
      'settings': const [],
      'receipt_templates': const [],
      'quotation_templates': const [],
      'ledger_entries': const [],
      'seller_profile': {
        'id': 44,
        'name': 'Seller User',
        'email': 'seller@example.com',
        'phone': '+256700000000',
        'business_name': 'Soko Print Hub',
      },
      'business_profile': {
        'seller': {
          'id': 44,
          'name': 'Seller User',
          'email': 'seller@example.com',
          'phone': '+256700000000',
        },
        'shop': {
          'id': 12,
          'name': 'Soko Print Hub',
          'address': 'Kampala Road',
          'phone': '+256701111111',
          'logo_upload_id': 77,
          'logo_url': 'https://example.com/logo.png',
          'meta_title': 'Print smarter',
          'meta_description': 'Branded print services',
          'updated_at': '2026-03-07T00:00:00Z',
        },
        'pos': {
          'outlet_id': 12,
          'outlet_name': 'Soko Print Hub',
          'thermal_printer_width': 80,
        },
        'payment_settings': {
          'cash_on_delivery_status': 1,
          'bank_payment_status': 1,
          'bank_name': 'DFCU',
          'bank_acc_name': 'Soko Print Hub',
          'bank_acc_no': '000123456',
          'bank_routing_no': 'DFCU001',
          'mtn_merchant_code': '123456',
          'airtel_merchant_code': '654321',
          'paybill_number': '200200',
          'receipt_payment_methods': {
            'cash': true,
            'bank_transfer': true,
            'mobile_money': true,
          },
        },
        'delivery_settings': {
          'shipping_cost': 15000,
          'self_delivery_active': true,
          'delivery_radius_km': 8,
          'delivery_pickup_latitude': 0.3475964,
          'delivery_pickup_longitude': 32.5825197,
          'profile': {
            'enabled': true,
            'pricing_mode': 'flat',
            'base_fee': 15000,
          },
        },
      },
      'config': {
        'outlet': {
          'id': '12',
          'name': 'Soko Print Hub',
          'address': 'Kampala Road',
          'phone': '+256701111111',
          'updated_at': '2026-03-07T00:00:00Z',
        },
      },
    };

    final parsed = PosSyncPullResponse.fromJson(json);

    expect(parsed.businessProfile, isNotNull);
    expect(parsed.businessProfile!.shopName, 'Soko Print Hub');
    expect(parsed.businessProfile!.logoUploadId, 77);
    expect(parsed.businessProfile!.bankName, 'DFCU');
    expect(parsed.businessProfile!.shippingCost, 15000);
    expect(
      parsed.businessProfile!.receiptPaymentMethods['mobile_money'],
      isTrue,
    );
    expect(parsed.businessProfile!.deliveryProfile['pricing_mode'], 'flat');
  });

  test('businessProfileToPaymentSettings maps cached profile fields', () {
    final profile = BusinessProfile(
      id: kPrimaryBusinessProfileId,
      sellerId: '44',
      sellerName: 'Seller User',
      sellerEmail: 'seller@example.com',
      sellerPhone: '+256700000000',
      shopId: '12',
      shopName: 'Soko Print Hub',
      shopAddress: 'Kampala Road',
      shopPhone: '+256701111111',
      logoUploadId: 77,
      logoUrl: 'https://example.com/logo.png',
      metaTitle: 'Print smarter',
      metaDescription: 'Branded print services',
      thermalPrinterWidth: 80,
      shippingCost: 15000,
      selfDeliveryActive: true,
      deliveryRadiusKm: 8,
      deliveryPickupLatitude: 0.3475964,
      deliveryPickupLongitude: 32.5825197,
      cashOnDeliveryEnabled: true,
      bankPaymentEnabled: true,
      mobileMoneyEnabled: true,
      bankName: 'DFCU',
      bankAccName: 'Soko Print Hub',
      bankAccNo: '000123456',
      bankRoutingNo: 'DFCU001',
      mtnMerchantCode: '123456',
      airtelMerchantCode: '654321',
      paybillNumber: '200200',
      receiptPaymentMethodsJson:
          '{"cash":true,"bank_transfer":true,"mobile_money":true}',
      deliveryProfileJson: '{"enabled":true,"pricing_mode":"flat"}',
      verificationStatus: 0,
      taxEnabled: false,
      taxRate: 0,
      taxLabel: 'VAT',
      taxInclusionMode: 'exclusive',
      updatedAt: DateTime.utc(2026, 3, 7),
      synced: true,
    );

    final settings = businessProfileToPaymentSettings(profile);

    expect(settings.cashEnabled, isTrue);
    expect(settings.bankEnabled, isTrue);
    expect(settings.mobileMoneyEnabled, isTrue);
    expect(settings.bankName, 'DFCU');
    expect(settings.mtnMerchantCode, '123456');
    expect(settings.receiptPaymentMethods?['bank_transfer'], isTrue);
  });
}
