import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/home/home_shell.dart';
import 'features/items/items_screen.dart';
import 'features/services/services_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/ads/ads_screen.dart';
import 'features/customers/customers_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/staff_screen.dart';
import 'features/settings/sync_health_screen.dart';
import 'features/settings/export_screen.dart';
import 'features/settings/print_queue_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/seller_profile_edit_screen.dart';
import 'features/profile/shop_info_screen.dart';
import 'features/profile/shop_seo_screen.dart';
import 'features/payments/payment_settings_screen.dart';
import 'features/auctions/auctions_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/coupons/coupons_screen.dart';
import 'features/refunds/refunds_screen.dart';
import 'features/verification/verification_screen.dart';
import 'features/wholesale/wholesale_screen.dart';
import 'features/shifts/shifts_screen.dart';
import 'features/delivery/delivery_settings_screen.dart';

class SokoSellerApp extends ConsumerWidget {
  const SokoSellerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Soko 24 Seller Terminal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final refresh = GoRouterRefreshStream(
    ref.watch(authControllerProvider.notifier).stream,
  );

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = authState.status == AuthStatus.authenticated;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/home/checkout';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(shell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/checkout',
                name: 'checkout',
                builder: (context, state) => HomeShell.checkoutTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/transactions',
                name: 'transactions',
                builder: (context, state) => HomeShell.transactionsTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/notifications',
                name: 'notifications',
                builder: (context, state) => HomeShell.notificationsTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/more',
                name: 'more',
                builder: (context, state) => HomeShell.moreTab(),
                routes: [
                  GoRoute(
                    path: 'dashboard',
                    name: 'dashboard',
                    builder: (context, state) => const DashboardScreen(),
                  ),
                  GoRoute(
                    path: 'items',
                    name: 'items',
                    builder: (context, state) => const ItemsScreen(),
                  ),
                  GoRoute(
                    path: 'services',
                    name: 'services',
                    builder: (context, state) => const ServicesScreen(),
                  ),
                  GoRoute(
                    path: 'auctions',
                    name: 'auctions',
                    builder: (context, state) => const AuctionsScreen(),
                  ),
                  GoRoute(
                    path: 'chat',
                    name: 'chat',
                    builder: (context, state) => const ChatScreen(),
                  ),
                  GoRoute(
                    path: 'coupons',
                    name: 'coupons',
                    builder: (context, state) => const CouponsScreen(),
                  ),
                  GoRoute(
                    path: 'orders',
                    name: 'orders',
                    builder: (context, state) => const OrdersScreen(),
                  ),
                  GoRoute(
                    path: 'wholesale',
                    name: 'wholesale',
                    builder: (context, state) => const WholesaleScreen(),
                  ),
                  GoRoute(
                    path: 'ads',
                    name: 'ads',
                    builder: (context, state) => const AdsScreen(),
                  ),
                  GoRoute(
                    path: 'customers',
                    name: 'customers',
                    builder: (context, state) => const CustomersScreen(),
                  ),
                  GoRoute(
                    path: 'reports',
                    name: 'reports',
                    builder: (context, state) => const ReportsScreen(),
                  ),
                  GoRoute(
                    path: 'refunds',
                    name: 'refunds',
                    builder: (context, state) => const RefundsScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    name: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'delivery-settings',
                    name: 'delivery-settings',
                    builder: (context, state) => const DeliverySettingsScreen(),
                  ),
                  GoRoute(
                    path: 'print-queue',
                    name: 'print-queue',
                    builder: (context, state) => const PrintQueueScreen(),
                  ),
                  GoRoute(
                    path: 'sync-health',
                    name: 'sync-health',
                    builder: (context, state) => const SyncHealthScreen(),
                  ),
                  GoRoute(
                    path: 'export',
                    name: 'export',
                    builder: (context, state) => const ExportScreen(),
                  ),
                  GoRoute(
                    path: 'profile',
                    name: 'profile',
                    builder: (context, state) => const ProfileScreen(),
                  ),
                  GoRoute(
                    path: 'seller-profile',
                    name: 'seller-profile',
                    builder: (context, state) =>
                        const SellerProfileEditScreen(),
                  ),
                  GoRoute(
                    path: 'shop-info',
                    name: 'shop-info',
                    builder: (context, state) => const ShopInfoScreen(),
                  ),
                  GoRoute(
                    path: 'shop-seo',
                    name: 'shop-seo',
                    builder: (context, state) => const ShopSeoScreen(),
                  ),
                  GoRoute(
                    path: 'payment-settings',
                    name: 'payment-settings',
                    builder: (context, state) => const PaymentSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'verification',
                    name: 'verification',
                    builder: (context, state) => const VerificationScreen(),
                  ),
                  GoRoute(
                    path: 'staff',
                    name: 'staff',
                    builder: (context, state) => const StaffScreen(),
                  ),
                  GoRoute(
                    path: 'shifts',
                    name: 'shifts',
                    builder: (context, state) => const ShiftsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// Replacement for the removed GoRouterRefreshStream in go_router 14.x.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
