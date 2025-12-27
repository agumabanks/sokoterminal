import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../app_providers.dart';
import '../auth/pos_session_controller.dart';
import '../auth/pos_staff_prefs.dart';
import '../../widgets/pin_prompt_sheet.dart';
import '../../features/settings/staff_pin_controller.dart';

Future<bool> requireManagerPin(
  BuildContext context,
  WidgetRef ref, {
  required String reason,
}) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final staffInitialized = prefs.getBool(posStaffInitializedPrefKey) ?? false;
  final posSession = ref.read(posSessionProvider);

  if (staffInitialized) {
    if (posSession.isManager) return true;

    if (!context.mounted) return false;
    final entered = await PinPromptSheet.show(
      context: context,
      title: 'Manager approval required',
      subtitle: reason,
      actionLabel: 'Approve',
    );
    if (entered == null) return false;

    final connectivity = await Connectivity().checkConnectivity();
    final online = connectivity.any((r) => r != ConnectivityResult.none);
    if (online) {
      final ok = await ref
          .read(posSessionProvider.notifier)
          .startWithPin(entered, requiredRole: 'manager');
      if (!context.mounted) return ok;
      if (!ok) {
        final msg =
            ref.read(posSessionProvider).error ?? 'Incorrect manager PIN';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
      return ok;
    }

    // Offline fallback: allow device-level PIN if configured, but syncing will
    // still require a manager POS session.
    final expected = await ref.read(secureStorageProvider).readPin();
    if (expected == null || expected.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Manager approval needs internet, or set an offline Staff PIN in Settings.',
            ),
          ),
        );
      }
      return false;
    }

    final ok = entered.trim() == expected.trim();
    if (!context.mounted) return ok;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
    }
    return ok;
  }

  // Legacy single-owner mode: optional device-level PIN lock.
  final pinState = ref.read(staffPinProvider);
  if (!pinState.enabled) return true;
  final expected = await ref.read(secureStorageProvider).readPin();
  if (expected == null || expected.trim().isEmpty) return true;

  if (!context.mounted) return false;
  final entered = await PinPromptSheet.show(
    context: context,
    title: 'Manager approval required',
    subtitle: reason,
    actionLabel: 'Approve',
  );
  if (entered == null) return false;

  final ok = entered.trim() == expected.trim();
  if (!context.mounted) return ok;
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Incorrect PIN')),
    );
  }
  return ok;
}
