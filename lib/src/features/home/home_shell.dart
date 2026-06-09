import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_providers.dart';
import '../../core/auth/pos_session_controller.dart';
import '../../core/audio/pos_sound_service.dart';
import '../../core/firebase/remote_config_service.dart';
import '../../core/settings/business_setup_prefs.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/haptics.dart';
import '../../widgets/connectivity_banner.dart';
import '../../widgets/logout_dialog.dart';
import '../../widgets/pin_prompt_sheet.dart';
import '../../widgets/sync_status_bar.dart';
import '../backup/migration_controller.dart';
import '../backup/restore_prompt_dialog.dart';
import '../checkout/checkout_screen.dart';
import '../more/more_screen.dart';
import '../notifications/notifications_controller.dart';
import '../notifications/notifications_entry_screen.dart';
import '../receipts/receipt_providers.dart';
import '../settings/staff_pin_controller.dart';
import '../transactions/transactions_screen.dart';


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
  final ValueNotifier<int> _lockWiggleNotifier = ValueNotifier<int>(0);

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
  void dispose() {
    _lockWiggleNotifier.dispose();
    super.dispose();
  }

  void _listenForMigration(WidgetRef ref) {
    ref.listen(migrationProvider, (previous, next) {
      if (next.pendingBackup != null && previous?.pendingBackup == null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const RestorePromptDialog(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _listenForMigration(ref);
    // Warm up notifications/token registration in background.
    final notifications = ref.watch(notificationsControllerProvider);
    final staffState = ref.watch(staffPinProvider);
    final remoteConfig = ref.watch(remoteConfigProvider);
    final setupCompleted = ref.watch(businessSetupCompletedProvider);
    final stockAlertCount = ref
        .watch(openStockAlertsCountProvider)
        .maybeWhen(data: (c) => c, orElse: () => 0);
    final alertsBadgeCount = notifications.unreadCount + stockAlertCount;
    return Scaffold(
      body: Column(
        children: [
          const ConnectivityBanner(),
          const SyncStatusBar(),
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
                  bottom: BorderSide(
                    color: DesignTokens.warning.withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.checklist_outlined,
                    color: DesignTokens.warning,
                  ),
                  const SizedBox(width: DesignTokens.spaceSm),
                  const Expanded(
                    child: Text(
                      'Finish setup: business, payments, receipts. Printer and PIN are recommended next.',
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: Container(
                    key: ValueKey<int>(widget.shell.currentIndex),
                    child: widget.shell,
                  ),
                ),
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
                if (ref.watch(screenLockedProvider))
                  _ScreenLockOverlay(
                    onUnlock: () => _promptScreenUnlock(context, ref),
                    wiggleNotifier: _lockWiggleNotifier,
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _IOSTabBar(
        currentIndex: widget.shell.currentIndex,
        alertsBadgeCount: alertsBadgeCount,
        onTap: (index) {
          if (index == widget.shell.currentIndex) {
            if (index == 3) {
              final loc = GoRouterState.of(context).matchedLocation;
              if (loc != '/home/more') {
                context.go('/home/more');
                return;
              }
            }
            return;
          }
          Haptics.selection();
          PosSoundService().playClick();
          widget.shell.goBranch(
            index,
            initialLocation: index == widget.shell.currentIndex,
          );
        },
      ),
    );
  }

  void _promptScreenUnlock(BuildContext context, WidgetRef ref) {
    unawaited(() async {
      final pin = await PinPromptSheet.show(
        context: context,
        title: 'Unlock Screen',
        pinLabel: 'Enter PIN',
        actionLabel: 'Unlock',
      );
      if (pin == null || !context.mounted) return;
      // Try POS session PIN or staff PIN
      final posSession = ref.read(posSessionProvider.notifier);
      final ok = await posSession.startWithPin(pin);
      if (ok) {
        ref.read(screenLockedProvider.notifier).state = false;
        return;
      }
      if (!context.mounted) return;
      _lockWiggleNotifier.value++;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
    }());
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

class _ScreenLockOverlay extends StatefulWidget {
  const _ScreenLockOverlay({required this.onUnlock, this.wiggleNotifier});
  final VoidCallback onUnlock;
  final ValueNotifier<int>? wiggleNotifier;

  @override
  State<_ScreenLockOverlay> createState() => _ScreenLockOverlayState();
}

class _ScreenLockOverlayState extends State<_ScreenLockOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    widget.wiggleNotifier?.addListener(_onWiggle);
  }

  void _onWiggle() {
    if (mounted) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    widget.wiggleNotifier?.removeListener(_onWiggle);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          decoration: BoxDecoration(
            color: DesignTokens.surfaceRaised,
            borderRadius: BorderRadius.circular(24),
          ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final value = _controller.value;
                    final offset =
                        math.sin(value * math.pi * 6) * 8 * (1 - value);
                    return Transform.translate(
                      offset: Offset(offset, 0),
                      child: child,
                    );
                  },
                  child: const Icon(Icons.lock, size: 56, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text(
                  'Tap to unlock',
                  style: DesignTokens.textHeadline.copyWith(
                    color: DesignTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your PIN to continue',
                  style: DesignTokens.textBody.copyWith(
                    color: DesignTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: widget.onUnlock,
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: const Text('Unlock'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: DesignTokens.brandPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}

class _IOSTabBar extends StatelessWidget {
  const _IOSTabBar({
    required this.currentIndex,
    required this.alertsBadgeCount,
    required this.onTap,
  });

  final int currentIndex;
  final int alertsBadgeCount;
  final ValueChanged<int> onTap;

  static const _tabs = [
    _TabItem(
      iconOutlined: Icons.point_of_sale_outlined,
      iconFilled: Icons.point_of_sale,
      label: 'Checkout',
    ),
    _TabItem(
      iconOutlined: Icons.receipt_long_outlined,
      iconFilled: Icons.receipt_long,
      label: 'Transactions',
    ),
    _TabItem(
      iconOutlined: Icons.notifications_none_outlined,
      iconFilled: Icons.notifications,
      label: 'Alerts',
    ),
    _TabItem(
      iconOutlined: Icons.grid_view_outlined,
      iconFilled: Icons.grid_view,
      label: 'More',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.tabBarBackground,
        border: const Border(
          top: BorderSide(color: DesignTokens.tabBarBorder, width: 0.5),
        ),
        boxShadow: DesignTokens.shadowBar,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: _tabs.asMap().entries.map((entry) {
              final index = entry.key;
              final tab = entry.value;
              final isSelected = index == currentIndex;
              final hasBadge = index == 2 && alertsBadgeCount > 0;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(index),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                              child: Icon(
                                isSelected ? tab.iconFilled : tab.iconOutlined,
                                key: ValueKey<bool>(isSelected),
                                size: 24,
                                color: isSelected
                                    ? DesignTokens.brandAccent
                                    : DesignTokens.textTertiary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tab.label,
                            style: DesignTokens.textCaption.copyWith(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? DesignTokens.brandAccent
                                  : DesignTokens.textTertiary,
                            ),
                          ),
                          // Active indicator dot
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.only(top: 3),
                            width: isSelected ? 4 : 0,
                            height: 4,
                            decoration: BoxDecoration(
                              color: DesignTokens.brandAccent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                      if (hasBadge)
                        Positioned(
                          top: 2,
                          right: 14,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: DesignTokens.error,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Center(
                              child: Text(
                                alertsBadgeCount > 99 ? '99+' : '$alertsBadgeCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({
    required this.iconOutlined,
    required this.iconFilled,
    required this.label,
  });
  final IconData iconOutlined;
  final IconData iconFilled;
  final String label;
}
