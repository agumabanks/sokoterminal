import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/app_providers.dart';
import 'widgets/swipe_back_wrapper.dart';
import 'core/firebase/fcm_service.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/sync/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/design_tokens.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/staff_login_screen.dart';
import 'features/auth/seller_registration_screen.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/post_registration_welcome_provider.dart';
import 'features/auth/pos_login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/home/home_shell.dart';
import 'features/contacts/contacts_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/items/items_screen.dart';
import 'features/services/services_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/ads/ads_screen.dart';
import 'features/ads/item_deep_link_screen.dart';
import 'features/ads/studio_deep_link_launcher.dart';
import 'features/ads/studio_notification_scheduler.dart';
import 'features/marketing/bulk_sms_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/staff_management_screen.dart';
import 'features/settings/staff_menu_access_screen.dart';
import 'features/settings/sync_health_screen.dart';
import 'features/settings/device_health_screen.dart';
import 'features/settings/export_screen.dart';
import 'features/settings/print_queue_screen.dart';
import 'features/settings/print_diagnostics_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/seller_profile_edit_screen.dart';
import 'features/profile/shop_info_screen.dart';
import 'features/profile/shop_seo_screen.dart';
import 'features/payments/payment_settings_screen.dart';
import 'features/wallet/seller_wallet_screen.dart';
import 'features/bnpl/bnpl_settings_screen.dart';
// import 'features/auctions/auctions_screen.dart';
// import 'features/chat/chat_screen.dart';
import 'features/coupons/coupons_screen.dart';
import 'features/refunds/refunds_screen.dart';
import 'features/verification/verification_screen.dart';
// import 'features/wholesale/wholesale_screen.dart';
import 'features/shifts/shifts_screen.dart';
import 'features/delivery/delivery_settings_screen.dart';
import 'features/quotations/quotations_screen.dart';
import 'features/settings/receipt_templates_screen.dart';
import 'features/settings/void_reason_codes_screen.dart';
import 'features/settings/tax_settings_screen.dart';
import 'features/expenses/expenses_screen.dart';
import 'features/backup/backup_screen.dart';
import 'features/procurement/suppliers_screen.dart';
import 'features/procurement/purchase_orders_screen.dart';
import 'features/procurement/receive_stock_screen.dart';
import 'features/procurement/stocktake_screen.dart';
import 'features/procurement/low_stock_screen.dart';
import 'features/setup/business_setup_wizard_screen.dart';
import 'core/settings/business_setup_prefs.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/catalog/catalog_screen.dart';
import 'features/accounting/accounting_screen.dart';

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

final routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier();
  ref.onDispose(notifier.dispose);

  void refresh<T>(T? _, T __) {
    notifier.refresh();
  }

  ref.listen<AuthState>(authControllerProvider, refresh);
  ref.listen<bool>(businessSetupCompletedProvider, refresh);
  ref.listen<bool>(postRegistrationWelcomePendingProvider, refresh);

  return notifier;
});

Page<dynamic> _buildPage({required Widget child, GoRouterState? state}) {
  return CustomTransitionPage(
    key: state?.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slideIn = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ));

      final slideOut = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.3, 0.0),
      ).animate(CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
      ));

      return SlideTransition(
        position: slideOut,
        child: SlideTransition(
          position: slideIn,
          child: SwipeBackWrapper(child: child),
        ),
      );
    },
    transitionDuration: DesignTokens.durationPageTransition,
    reverseTransitionDuration: DesignTokens.durationPageTransition,
  );
}

class SokoSellerApp extends ConsumerWidget {
  const SokoSellerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return _LifecycleAwareApp(router: router);
  }
}

/// Root-level lifecycle listener that survives navigation.
/// SplashScreen's listener is disposed after login; this one persists
/// for the entire app session so token refresh on resume always works.
class _LifecycleAwareApp extends ConsumerStatefulWidget {
  const _LifecycleAwareApp({required this.router});
  final GoRouter router;

  @override
  ConsumerState<_LifecycleAwareApp> createState() => _LifecycleAwareAppState();
}

class _LifecycleAwareAppState extends ConsumerState<_LifecycleAwareApp> {
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        final auth = ref.read(authControllerProvider.notifier);
        unawaited(auth.refreshToken());
        // Resume contact background sync when app comes to foreground.
        unawaited(_backgroundContactSync());
      },
    );
    // Kick off contact sync shortly after the widget tree settles.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_backgroundContactSync());
      _configurePushNavigation();
      _configureLocalNotifications();
      _initDeepLinks();
    });
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null && mounted) _handleDeepLink(initial);
    } catch (_) {}

    appLinks.uriLinkStream.listen(
      (uri) {
        if (mounted) _handleDeepLink(uri);
      },
      onError: (_) {},
    );
  }

  void _handleDeepLink(Uri uri) {
    final host = uri.host.toLowerCase();
    if (!host.endsWith('soko24.co') && host != 'soko24.co') return;
    final path = uri.path;
    if (path.startsWith('/p/')) {
      final id = int.tryParse(path.split('/').last);
      if (id != null) widget.router.go('/p/$id');
    } else if (path.startsWith('/s/')) {
      final id = int.tryParse(path.split('/').last);
      if (id != null) widget.router.go('/s/$id');
    } else if (path == '/studio' || path.startsWith('/studio?')) {
      widget.router.go(uri.toString().replaceFirst('https://soko24.co', ''));
    }
  }

  Future<void> _configureLocalNotifications() async {
    await LocalNotificationService.instance.init();
    configureLocalNotificationTapRouting(ref);

    // Schedule/cancel Studio smart reminders based on current prefs once the
    // notification plugin is initialized and the seller is signed in.
    final auth = ref.read(authControllerProvider);
    if (auth.status == AuthStatus.authenticated) {
      unawaited(
        ref.read(studioNotificationPrefsProvider.notifier).refreshReminders(),
      );
    }

    // If the app was launched from a local notification tap, route there.
    final launchPayload =
        await LocalNotificationService.instance.getLaunchPayload();
    if (launchPayload != null && mounted) {
      widget.router.go(launchPayload);
    }
  }

  void _configurePushNavigation() {
    FCMService.instance.configureHandlers(
      onNavigate: (route) {
        if (!mounted) return;
        widget.router.go(route);
      },
      onForegroundBanner: ({
        required title,
        body,
        actionLabel,
        onAction,
      }) {
        final messenger = rootScaffoldMessengerKey.currentState;
        if (messenger == null) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              body == null || body.isEmpty ? title : '$title\n$body',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            action: actionLabel == null || onAction == null
                ? null
                : SnackBarAction(label: actionLabel, onPressed: onAction),
          ),
        );
      },
      onSyncHint: () async {
        try {
          await ref.read(syncServiceProvider).syncNow();
        } catch (_) {}
      },
    );
  }

  /// Silently syncs device contacts if permission is already granted and the
  /// user has opted in. Never shows a dialog — the contacts screen owns the
  /// first-time permission request UX.
  Future<void> _backgroundContactSync() async {
    try {
      final sync = ref.read(syncServiceProvider);
      final optedIn = await sync.isDeviceContactsOptedIn();

      if (!optedIn) {
        // Auto-opt-in if the OS contact permission was granted at some point
        // (e.g., from a previous session or device restore) but the in-app
        // opt-in flag was never persisted.
        final status = await Permission.contacts.status;
        if (status.isGranted) {
          await sync.setDeviceContactsOptIn(true);
          unawaited(sync.syncDeviceContacts(force: false));
          unawaited(sync.pullCrmContacts());
        }
        return;
      }

      final status = await Permission.contacts.status;
      if (!status.isGranted) return;

      // Let the sync service's throttle logic decide if a sync is due.
      unawaited(sync.syncDeviceContacts(force: false));
      unawaited(sync.pullCrmContacts());
    } catch (_) {
      // Background sync must never crash the app.
    }
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StudioNotificationInitializer(
      child: MaterialApp.router(
        title: 'Soko 24 Seller Terminal',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        routerConfig: widget.router,
      ),
    );
  }
}

/// Listens to authentication state and refreshes Studio reminder scheduling
/// when the seller logs in, or cancels reminders when they log out.
class _StudioNotificationInitializer extends ConsumerWidget {
  const _StudioNotificationInitializer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        unawaited(
          ref.read(studioNotificationPrefsProvider.notifier).refreshReminders(),
        );
      } else if (next.status == AuthStatus.unauthenticated) {
        unawaited(LocalNotificationService.instance.cancelStudioReminders());
      }
    });
    return child;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  ref.read(authControllerProvider.notifier);
  final refresh = ref.watch(routerRefreshProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final setupCompleted = ref.read(businessSetupCompletedProvider);
      final postRegistrationPending = ref.read(
        postRegistrationWelcomePendingProvider,
      );
      final prefs = ref.read(sharedPreferencesProvider);
      final setupRequired =
          prefs.getBool(businessSetupRequiredPrefKey) ?? false;
      final loggedIn = authState.status == AuthStatus.authenticated;
      final onLogin = state.matchedLocation == '/login';
      final onRegister = state.matchedLocation == '/register';
      final onSplash = state.matchedLocation == '/splash';
      final onOnboarding = state.matchedLocation.startsWith('/onboarding');
      final onBusinessSetup =
          state.matchedLocation == '/home/more/business-setup';

      if (onSplash) return null; // Let splash handle logic

      if (loggedIn && onOnboarding) {
        return '/home/more/business-setup';
      }

      if (!loggedIn && !onLogin && !onRegister) return '/login';
      if (loggedIn && setupRequired && !setupCompleted && !onBusinessSetup) {
        if (onRegister && postRegistrationPending) return null;
        return '/home/more/business-setup';
      }
      if (loggedIn && (onLogin || onRegister)) {
        if (onRegister && postRegistrationPending) return null;
        if (setupRequired && !setupCompleted) {
          return '/home/more/business-setup';
        }
        return '/home/checkout';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => _buildPage(state: state, child: const SplashScreen()),
      ),
      GoRoute(
        path: '/studio',
        name: 'studio',
        pageBuilder: (context, state) {
          final q = state.uri.queryParameters;
          return _buildPage(
            state: state,
            child: StudioDeepLinkLauncher(
              productId: int.tryParse(q['product_id'] ?? ''),
              serviceId: int.tryParse(q['service_id'] ?? ''),
              quotationId: q['quotation_id'],
              receiptId: int.tryParse(q['receipt_id'] ?? ''),
              brandKit: q['brand_kit'] == '1',
              openPanel: q['open_panel'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/p/:id',
        name: 'product-deep-link',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) return _buildPage(child: const SplashScreen());
          return _buildPage(
            child: ItemDeepLinkScreen(remoteId: id, isService: false),
          );
        },
      ),
      GoRoute(
        path: '/s/:id',
        name: 'service-deep-link',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) return _buildPage(child: const SplashScreen());
          return _buildPage(
            child: ItemDeepLinkScreen(remoteId: id, isService: true),
          );
        },
      ),
      GoRoute(
        path: '/pos-login',
        name: 'pos-login',
        pageBuilder: (context, state) {
          final redirectTo = state.uri.queryParameters['redirect'];
          return _buildPage(child: PosLoginScreen(redirectTo: redirectTo));
        },
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => _buildPage(state: state, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/staff-login',
        name: 'staff-login',
        pageBuilder: (context, state) => _buildPage(state: state, child: const StaffLoginScreen()),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _buildPage(child: SellerRegistrationScreen(initialPhone: extra?['phone']));
        },
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        pageBuilder: (context, state) => _buildPage(state: state, child: const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        redirect: (context, state) => '/home/more/business-setup',
      ),
      GoRoute(
        path: '/onboarding/shop-basics',
        name: 'onboarding-shop-basics',
        redirect: (context, state) => '/home/more/business-setup',
      ),
      GoRoute(
        path: '/onboarding/business-details',
        name: 'onboarding-business-details',
        redirect: (context, state) => '/home/more/business-setup',
      ),
      GoRoute(
        path: '/onboarding/payment-config',
        name: 'onboarding-payment-config',
        redirect: (context, state) => '/home/more/business-setup',
      ),
      GoRoute(
        path: '/onboarding/welcome',
        name: 'onboarding-welcome',
        redirect: (context, state) => '/home/more/business-setup',
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
                pageBuilder: (context, state) => _buildPage(state: state, child: HomeShell.checkoutTab()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/transactions',
                name: 'transactions',
                pageBuilder: (context, state) => _buildPage(state: state, child: HomeShell.transactionsTab()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/notifications',
                name: 'notifications',
                pageBuilder: (context, state) => _buildPage(state: state, child: HomeShell.notificationsTab()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/more',
                name: 'more',
                pageBuilder: (context, state) => _buildPage(state: state, child: HomeShell.moreTab()),
                routes: [
                  GoRoute(
                    path: 'dashboard',
                    name: 'dashboard',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const DashboardScreen()),
                  ),
                  GoRoute(
                    path: 'items',
                    name: 'items',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const ItemsScreen()),
                  ),
                  GoRoute(
                    path: 'suppliers',
                    name: 'suppliers',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const SuppliersScreen()),
                  ),
                  GoRoute(
                    path: 'purchase-orders',
                    name: 'purchase-orders',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const PurchaseOrdersScreen()),
                  ),
                  GoRoute(
                    path: 'receive-stock',
                    name: 'receive-stock',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const ReceiveStockScreen()),
                  ),
                  GoRoute(
                    path: 'stocktake',
                    name: 'stocktake',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const StocktakeScreen()),
                  ),
                  GoRoute(
                    path: 'low-stock',
                    name: 'low-stock',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const LowStockScreen()),
                  ),
                  GoRoute(
                    path: 'services',
                    name: 'services',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const ServicesScreen()),
                  ),
                  // Hidden: dead features (not MVP-ready)
                  // GoRoute(
                  //   path: 'auctions',
                  //   name: 'auctions',
                  //   builder: (context, state) => _buildPage(child: const AuctionsScreen()),
                  // ),
                  // GoRoute(
                  //   path: 'chat',
                  //   name: 'chat',
                  //   builder: (context, state) => _buildPage(child: const ChatScreen()),
                  // ),
                  GoRoute(
                    path: 'analytics',
                    name: 'analytics',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const AnalyticsScreen()),
                  ),
                  // GoRoute(
                  //   path: 'chat/:conversationId',
                  //   name: 'chat-detail',
                  //   builder: (context, state) {
                  //     final convoId = int.tryParse(
                  //       state.pathParameters['conversationId'] ?? '',
                  //     );
                  //     return ChatScreen(conversationId: convoId);
                  //   },
                  // ),
                  GoRoute(
                    path: 'coupons',
                    name: 'coupons',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const CouponsScreen()),
                  ),
                  GoRoute(
                    path: 'orders',
                    name: 'orders',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const OrdersScreen()),
                  ),
                  GoRoute(
                    path: 'catalog',
                    name: 'catalog',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const CatalogScreen()),
                  ),
                  // GoRoute(
                  //   path: 'wholesale',
                  //   name: 'wholesale',
                  //   builder: (context, state) => _buildPage(child: const WholesaleScreen()),
                  // ),
                  GoRoute(
                    path: 'ads',
                    name: 'ads',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const AdsScreen()),
                  ),
                  GoRoute(
                    path: 'bulk-sms',
                    name: 'bulk-sms',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const BulkSmsScreen()),
                  ),
                  GoRoute(
                    path: 'reports',
                    name: 'reports',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const ReportsScreen()),
                  ),
                  GoRoute(
                    path: 'expenses',
                    name: 'expenses',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const ExpensesScreen()),
                  ),
                  GoRoute(
                    path: 'refunds',
                    name: 'refunds',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const RefundsScreen()),
                  ),
                  GoRoute(
                    path: 'settings',
                    name: 'settings',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const SettingsScreen()),
                  ),
                  GoRoute(
                    path: 'backup',
                    name: 'backup',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const BackupScreen()),
                  ),
                  GoRoute(
                    path: 'delivery-settings',
                    name: 'delivery-settings',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const DeliverySettingsScreen()),
                  ),
                  GoRoute(
                    path: 'tax-settings',
                    name: 'tax-settings',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const TaxSettingsScreen()),
                  ),
                  GoRoute(
                    path: 'accounting',
                    name: 'accounting',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const AccountingScreen()),
                  ),
                  GoRoute(
                    path: 'print-queue',
                    name: 'print-queue',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const PrintQueueScreen()),
                  ),
                  GoRoute(
                    path: 'print-diagnostics',
                    name: 'print-diagnostics',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const PrintDiagnosticsScreen()),
                  ),
                  GoRoute(
                    path: 'sync-health',
                    name: 'sync-health',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const SyncHealthScreen()),
                  ),
                  GoRoute(
                    path: 'device-health',
                    name: 'device-health',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const DeviceHealthScreen()),
                  ),
                  GoRoute(
                    path: 'export',
                    name: 'export',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const ExportScreen()),
                  ),
                  GoRoute(
                    path: 'profile',
                    name: 'profile',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const ProfileScreen()),
                  ),
                  GoRoute(
                    path: 'seller-profile',
                    name: 'seller-profile',
                    pageBuilder: (context, state) => _buildPage(
                        child: const SellerProfileEditScreen()),
                  ),
                  GoRoute(
                    path: 'shop-info',
                    name: 'shop-info',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const ShopInfoScreen()),
                  ),
                  GoRoute(
                    path: 'shop-seo',
                    name: 'shop-seo',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const ShopSeoScreen()),
                  ),
                  GoRoute(
                    path: 'payment-settings',
                    name: 'payment-settings',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const PaymentSettingsScreen()),
                  ),
                  GoRoute(
                    path: 'wallet',
                    name: 'wallet',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const SellerWalletScreen()),
                  ),
                  GoRoute(
                    path: 'bnpl-settings',
                    name: 'bnpl-settings',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const BnplSettingsScreen()),
                  ),
                  GoRoute(
                    path: 'verification',
                    name: 'verification',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const VerificationScreen()),
                  ),
                  GoRoute(
                    path: 'staff',
                    name: 'staff',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const StaffManagementScreen()),
                  ),
                  GoRoute(
                    path: 'staff-menu-access',
                    name: 'staff-menu-access',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const StaffMenuAccessScreen()),
                  ),
                  GoRoute(
                    path: 'shifts',
                    name: 'shifts',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const ShiftsScreen()),
                  ),
                  GoRoute(
                    path: 'contacts',
                    name: 'contacts',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const ContactsScreen()),
                  ),
                  GoRoute(
                    path: 'quotations',
                    name: 'quotations',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const QuotationsScreen()),
                  ),
                  GoRoute(
                    path: 'receipt-templates',
                    name: 'receipt-templates',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const ReceiptTemplatesScreen()),
                  ),
                  GoRoute(
                    path: 'void-reason-codes',
                    name: 'void-reason-codes',
                    pageBuilder: (context, state) => _buildPage(state: state, child: const VoidReasonCodesScreen()),
                  ),
                  GoRoute(
                    path: 'business-setup',
                    name: 'business-setup',
                    pageBuilder: (context, state) => _buildPage(
                        child: const BusinessSetupWizardScreen()),
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

class RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
