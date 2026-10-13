import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/app_providers.dart';
import 'package:soko_seller_terminal/src/core/config/app_config.dart';
import 'package:soko_seller_terminal/src/core/storage/secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soko_seller_terminal/src/features/accounting/accounting_screen.dart';
import 'package:soko_seller_terminal/src/features/ads/ads_screen.dart';
import 'package:soko_seller_terminal/src/features/ads/studio_deep_link_launcher.dart';
import 'package:soko_seller_terminal/src/features/analytics/analytics_screen.dart';
import 'package:soko_seller_terminal/src/features/auth/forgot_password_screen.dart';
import 'package:soko_seller_terminal/src/features/auth/login_screen.dart';
import 'package:soko_seller_terminal/src/features/auth/pos_login_screen.dart';
import 'package:soko_seller_terminal/src/features/auth/seller_registration_screen.dart';
import 'package:soko_seller_terminal/src/features/auth/staff_login_screen.dart';
import 'package:soko_seller_terminal/src/features/backup/backup_screen.dart';
import 'package:soko_seller_terminal/src/features/bnpl/bnpl_settings_screen.dart';
import 'package:soko_seller_terminal/src/features/catalog/catalog_screen.dart';
import 'package:soko_seller_terminal/src/features/chat/chat_screen.dart';
import 'package:soko_seller_terminal/src/features/contacts/contacts_screen.dart';
import 'package:soko_seller_terminal/src/features/coupons/coupons_screen.dart';
import 'package:soko_seller_terminal/src/features/dashboard/dashboard_screen.dart';
import 'package:soko_seller_terminal/src/features/delivery/delivery_settings_screen.dart';
import 'package:soko_seller_terminal/src/features/expenses/expenses_screen.dart';
import 'package:soko_seller_terminal/src/features/items/items_screen.dart';
import 'package:soko_seller_terminal/src/features/madeni/madeni_screen.dart';
import 'package:soko_seller_terminal/src/features/madeni/morning_briefing_screen.dart';
import 'package:soko_seller_terminal/src/features/marketing/bulk_sms_screen.dart';
import 'package:soko_seller_terminal/src/features/marketing/marketing_generator_screen.dart';
import 'package:soko_seller_terminal/src/features/marketing/marketing_hub_screen.dart';
import 'package:soko_seller_terminal/src/features/money/evening_close_screen.dart';
import 'package:soko_seller_terminal/src/features/orders/orders_screen.dart';
import 'package:soko_seller_terminal/src/features/payment_links/payment_links_screen.dart';
import 'package:soko_seller_terminal/src/features/payments/payment_settings_screen.dart';
import 'package:soko_seller_terminal/src/features/procurement/low_stock_screen.dart';
import 'package:soko_seller_terminal/src/features/procurement/purchase_orders_screen.dart';
import 'package:soko_seller_terminal/src/features/procurement/receive_stock_screen.dart';
import 'package:soko_seller_terminal/src/features/procurement/stocktake_screen.dart';
import 'package:soko_seller_terminal/src/features/procurement/suppliers_screen.dart';
import 'package:soko_seller_terminal/src/features/profile/brand_media_screen.dart';
import 'package:soko_seller_terminal/src/features/profile/profile_screen.dart';
import 'package:soko_seller_terminal/src/features/profile/seller_profile_edit_screen.dart';
import 'package:soko_seller_terminal/src/features/profile/shop_info_screen.dart';
import 'package:soko_seller_terminal/src/features/profile/shop_seo_screen.dart';
import 'package:soko_seller_terminal/src/features/quotations/quotations_screen.dart';
import 'package:soko_seller_terminal/src/features/refunds/refunds_screen.dart';
import 'package:soko_seller_terminal/src/features/reports/reports_screen.dart';
import 'package:soko_seller_terminal/src/features/services/services_screen.dart';
import 'package:soko_seller_terminal/src/features/settings/device_health_screen.dart';
import 'package:soko_seller_terminal/src/features/settings/export_screen.dart';
import 'package:soko_seller_terminal/src/features/settings/print_diagnostics_screen.dart';
import 'package:soko_seller_terminal/src/features/settings/print_queue_screen.dart';
import 'package:soko_seller_terminal/src/features/settings/receipt_templates_screen.dart';
import 'package:soko_seller_terminal/src/features/settings/settings_screen.dart';
import 'package:soko_seller_terminal/src/features/settings/staff_management_screen.dart';
import 'package:soko_seller_terminal/src/features/settings/staff_menu_access_screen.dart';
import 'package:soko_seller_terminal/src/features/settings/sync_health_screen.dart';
import 'package:soko_seller_terminal/src/features/settings/tax_settings_screen.dart';
import 'package:soko_seller_terminal/src/features/settings/void_reason_codes_screen.dart';
import 'package:soko_seller_terminal/src/features/setup/business_setup_wizard_screen.dart';
import 'package:soko_seller_terminal/src/features/shifts/shifts_screen.dart';
import 'package:soko_seller_terminal/src/features/splash/splash_screen.dart';
import 'package:soko_seller_terminal/src/features/verification/verification_screen.dart';
import 'package:soko_seller_terminal/src/features/wallet/seller_wallet_screen.dart';

import 'helpers/test_helpers.dart';

/// Every screen reachable from the router, keyed by its GoRouter path.
///
/// This is the crash sweep. Each screen is pumped against a real in-memory
/// Drift database at a narrow phone size, so build-time exceptions and the
/// layout overflows that only surface on small screens both fail the test.
/// Keep this list in sync with `lib/src/app.dart` when routes are added.
final Map<String, Widget Function()> kRouteScreens = {
  '/splash': () => const SplashScreen(),
  '/studio': () => const StudioDeepLinkLauncher(),
  '/p/:id': () => const SplashScreen(),
  '/s/:id': () => const SplashScreen(),
  '/pos-login': () => const PosLoginScreen(),
  '/login': () => const LoginScreen(),
  '/staff-login': () => const StaffLoginScreen(),
  '/register': () => const SellerRegistrationScreen(),
  '/forgot-password': () => const ForgotPasswordScreen(),
  '/home/more': () => const DashboardScreen(),
  'dashboard': () => const DashboardScreen(),
  'items': () => const ItemsScreen(),
  'suppliers': () => const SuppliersScreen(),
  'purchase-orders': () => const PurchaseOrdersScreen(),
  'receive-stock': () => const ReceiveStockScreen(),
  'stocktake': () => const StocktakeScreen(),
  'low-stock': () => const LowStockScreen(),
  'services': () => const ServicesScreen(),
  'chat': () => const ChatScreen(),
  'analytics': () => const AnalyticsScreen(),
  'coupons': () => const CouponsScreen(),
  'orders': () => const OrdersScreen(),
  'catalog': () => const CatalogScreen(),
  'ads': () => const AdsScreen(),
  'bulk-sms': () => const BulkSmsScreen(),
  'reports': () => const ReportsScreen(),
  'expenses': () => const ExpensesScreen(),
  'refunds': () => const RefundsScreen(),
  'settings': () => const SettingsScreen(),
  'backup': () => const BackupScreen(),
  'delivery-settings': () => const DeliverySettingsScreen(),
  'tax-settings': () => const TaxSettingsScreen(),
  'accounting': () => const AccountingScreen(),
  'payment-links': () => const PaymentLinksScreen(),
  ':id': () => const PaymentLinksScreen(),
  'evening-close': () => const EveningCloseScreen(),
  'morning-briefing': () => const MorningBriefingScreen(),
  'madeni': () => const MadeniScreen(),
  'marketing': () => const MarketingHubScreen(),
  'marketing-content': () => const MarketingGeneratorScreen(),
  'print-queue': () => const PrintQueueScreen(),
  'print-diagnostics': () => const PrintDiagnosticsScreen(),
  'sync-health': () => const SyncHealthScreen(),
  'device-health': () => const DeviceHealthScreen(),
  'export': () => const ExportScreen(),
  'profile': () => const ProfileScreen(),
  'brand-media': () => const BrandMediaScreen(),
  'seller-profile': () => const SellerProfileEditScreen(),
  'shop-info': () => const ShopInfoScreen(),
  'shop-seo': () => const ShopSeoScreen(),
  'payment-settings': () => const PaymentSettingsScreen(),
  'wallet': () => const SellerWalletScreen(),
  'bnpl-settings': () => const BnplSettingsScreen(),
  'verification': () => const VerificationScreen(),
  'staff': () => const StaffManagementScreen(),
  'staff-menu-access': () => const StaffMenuAccessScreen(),
  'shifts': () => const ShiftsScreen(),
  'contacts': () => const ContactsScreen(),
  'quotations': () => const QuotationsScreen(),
  'receipt-templates': () => const ReceiptTemplatesScreen(),
  'void-reason-codes': () => const VoidReasonCodesScreen(),
  'business-setup': () => const BusinessSetupWizardScreen(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('every routed screen builds without crashing', () {
    for (final entry in kRouteScreens.entries) {
      final route = entry.key;
      testWidgets(route, (tester) async {
        final db = createTestDatabase();
        addTearDown(db.close);

        // A small, dense phone: the size where overflow bugs actually show.
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              appConfigProvider.overrideWithValue(AppConfig.fromEnv(const {})),
              secureStorageProvider.overrideWithValue(SecureStorage()),
              sharedPreferencesProvider.overrideWithValue(
                await SharedPreferences.getInstance(),
              ),
            ],
            child: MaterialApp(home: entry.value()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          tester.takeException(),
          isNull,
          reason: 'route $route threw while building',
        );

        // Some screens (e.g. the Studio splash) schedule intro animation
        // timers. Unmount and pump past them so teardown is clean; a pending
        // timer is not a crash.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 7));
        await tester.pumpAndSettle();
      });
    }
  });
}
