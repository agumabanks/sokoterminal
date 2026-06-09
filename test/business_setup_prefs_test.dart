import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soko_seller_terminal/src/core/app_providers.dart';
import 'package:soko_seller_terminal/src/core/db/app_database.dart';
import 'package:soko_seller_terminal/src/core/settings/business_setup_prefs.dart';
import 'package:soko_seller_terminal/src/core/settings/business_profile_cache.dart';
import 'package:soko_seller_terminal/src/core/settings/shop_payment_settings.dart';

void main() {
  test(
    'businessSetupCompletedProvider persists to SharedPreferences',
    () async {
      SharedPreferences.setMockInitialValues({
        businessSetupCompletedPrefKey: false,
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(businessSetupCompletedProvider), isFalse);

      await container
          .read(businessSetupCompletedProvider.notifier)
          .markSetupRequired();

      expect(container.read(businessSetupCompletedProvider), isFalse);
      expect(prefs.getBool(businessSetupRequiredPrefKey), isTrue);

      await container
          .read(businessSetupCompletedProvider.notifier)
          .setCompleted(true);

      expect(container.read(businessSetupCompletedProvider), isTrue);
      expect(prefs.getBool(businessSetupCompletedPrefKey), isTrue);
      expect(prefs.getBool(businessSetupRequiredPrefKey), isFalse);
    },
  );

  test(
    'inferBusinessSetupCompleted requires business, payments, and receipts',
    () {
      final profile = BusinessProfile(
        id: kPrimaryBusinessProfileId,
        sellerId: '1',
        sellerName: 'Seller',
        sellerEmail: null,
        sellerPhone: null,
        shopId: '10',
        shopName: 'Ready Shop',
        shopAddress: null,
        shopPhone: null,
        logoUploadId: null,
        logoUrl: null,
        metaTitle: null,
        metaDescription: null,
        thermalPrinterWidth: null,
        shippingCost: null,
        selfDeliveryActive: false,
        deliveryRadiusKm: null,
        deliveryPickupLatitude: null,
        deliveryPickupLongitude: null,
        cashOnDeliveryEnabled: true,
        bankPaymentEnabled: false,
        mobileMoneyEnabled: false,
        bankName: null,
        bankAccName: null,
        bankAccNo: null,
        bankRoutingNo: null,
        mtnMerchantCode: null,
        airtelMerchantCode: null,
        paybillNumber: null,
        receiptPaymentMethodsJson: '{"cash":true}',
        deliveryProfileJson: null,
        verificationStatus: 0,
        updatedAt: DateTime.utc(2026, 3, 7),
        synced: true,
      );
      const settings = ShopPaymentSettings(
        cashEnabled: true,
        bankEnabled: false,
        mobileMoneyEnabled: false,
        bankName: '',
        bankAccountName: '',
        bankAccountNumber: '',
        bankRoutingNumber: '',
        mtnMerchantCode: '',
        airtelMerchantCode: '',
        paybillNumber: '',
      );

      expect(
        inferBusinessSetupCompleted(
          profile: profile,
          settings: settings,
          hasReceiptTemplate: true,
        ),
        isTrue,
      );
      expect(
        inferBusinessSetupCompleted(
          profile: profile.copyWith(shopName: ''),
          settings: settings,
          hasReceiptTemplate: true,
        ),
        isFalse,
      );
      expect(
        inferBusinessSetupCompleted(
          profile: profile,
          settings: const ShopPaymentSettings(
            cashEnabled: false,
            bankEnabled: false,
            mobileMoneyEnabled: false,
            bankName: '',
            bankAccountName: '',
            bankAccountNumber: '',
            bankRoutingNumber: '',
            mtnMerchantCode: '',
            airtelMerchantCode: '',
            paybillNumber: '',
          ),
          hasReceiptTemplate: true,
        ),
        isFalse,
      );
      expect(
        inferBusinessSetupCompleted(
          profile: profile,
          settings: settings,
          hasReceiptTemplate: false,
        ),
        isFalse,
      );
    },
  );
}
