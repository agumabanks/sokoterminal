import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../checkout/checkout_screen.dart';
import '../notifications/notifications_screen.dart';
import '../transactions/transactions_screen.dart';
import '../more/more_screen.dart';
import '../settings/staff_pin_controller.dart';
import '../notifications/notifications_controller.dart';
import '../../core/sync/sync_service.dart';
import '../../widgets/pin_prompt_sheet.dart';
import '../receipts/receipt_providers.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({required this.shell, super.key});
  final StatefulNavigationShell shell;

  static Widget checkoutTab() => const CheckoutScreen();
  static Widget transactionsTab() => const TransactionsScreen();
  static Widget notificationsTab() => const NotificationsScreen();
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
  Widget build(BuildContext context, WidgetRef ref) {
    // Warm up notifications/token registration in background.
    ref.watch(notificationsControllerProvider);
    final staffState = ref.watch(staffPinProvider);
    return Scaffold(
      body: Stack(
        children: [
          widget.shell,
          if (staffState.enabled && staffState.locked)
            Container(
              color: Colors.black.withOpacity(0.6),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.shell.currentIndex,
        onTap: (index) => widget.shell.goBranch(
          index,
          initialLocation: index == widget.shell.currentIndex,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale),
            label: 'Checkout',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'More'),
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
