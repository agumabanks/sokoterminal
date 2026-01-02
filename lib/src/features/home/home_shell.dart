import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_providers.dart';
import '../checkout/checkout_screen.dart';
import '../notifications/notifications_entry_screen.dart';
import '../transactions/transactions_screen.dart';
import '../more/more_screen.dart';
import '../settings/staff_pin_controller.dart';
import '../notifications/notifications_controller.dart';
import '../../core/sync/sync_service.dart';
import '../../widgets/pin_prompt_sheet.dart';
import '../../widgets/connectivity_banner.dart';
import '../receipts/receipt_providers.dart';
import '../../core/firebase/remote_config_service.dart';
import '../../core/settings/business_setup_prefs.dart';
import '../../core/theme/design_tokens.dart';

final openStockAlertsCountProvider = StreamProvider<int>((ref) {
  return ref.watch(appDatabaseProvider).watchOpenStockAlertsCount();
});

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({required this.shell, super.key});
  final StatefulNavigationShell shell;

  static Widget checkoutTab() => const CheckoutScreen();
  static Widget transactionsTab() => const TransactionsScreen();
  static Widget notificationsTab() => const NotificationsEntryScreen();
  static Widget moreTab() => const MoreScreen();

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      final sync = ref.read(syncServiceProvider);
      sync.start();

      final printQueue = ref.read(printQueueServiceProvider);
      printQueue.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Warm up notifications/token registration in background.
    final notifications = ref.watch(notificationsControllerProvider);
    final staffState = ref.watch(staffPinProvider);
    final remoteConfig = ref.watch(remoteConfigProvider);
    final setupCompleted = ref.watch(businessSetupCompletedProvider);
    final stockAlertCount = ref.watch(openStockAlertsCountProvider).maybeWhen(
          data: (c) => c,
          orElse: () => 0,
        );
    final alertsBadgeCount = notifications.unreadCount + stockAlertCount;
    return Scaffold(
      body: Column(
        children: [
          const ConnectivityBanner(),
          if (remoteConfig.ffBusinessSetupWizard && !setupCompleted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceMd,
                vertical: DesignTokens.spaceSm,
              ),
              decoration: BoxDecoration(
                color: DesignTokens.warning.withValues(alpha: 0.12),
                border: Border(
                  bottom: BorderSide(color: DesignTokens.warning.withValues(alpha: 0.35)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.checklist_outlined, color: DesignTokens.warning),
                  const SizedBox(width: DesignTokens.spaceSm),
                  const Expanded(
                    child: Text(
                      'Finish setup: business, payments, receipts, printer, PIN',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/home/more/business-setup'),
                    child: const Text('Open'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                widget.shell,
                if (staffState.enabled && staffState.locked)
                  Container(
                    color: Colors.black.withValues(alpha: 0.6),
                    child: Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.lock_open),
                        label: const Text('Unlock staff PIN'),
                        onPressed: () => _promptUnlock(context, ref),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.shell.currentIndex,
        onTap: (index) => widget.shell.goBranch(
          index,
          initialLocation: index == widget.shell.currentIndex,
        ),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale),
            label: 'Checkout',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: alertsBadgeCount > 0
                ? Badge(
                    label: Text('$alertsBadgeCount'),
                    child: const Icon(Icons.notifications_none),
                  )
                : const Icon(Icons.notifications_none),
            label: 'Alerts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: 'More',
          ),
        ],
      ),
    );
  }

  void _promptUnlock(BuildContext context, WidgetRef ref) {
    final controller = ref.read(staffPinProvider.notifier);
    unawaited(() async {
      final pin = await PinPromptSheet.show(
        context: context,
        title: 'Enter staff PIN',
        pinLabel: 'Staff PIN',
        actionLabel: 'Unlock',
      );
      if (pin == null) return;
      final ok = await controller.unlock(pin);
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
      }
    }());
  }
}
