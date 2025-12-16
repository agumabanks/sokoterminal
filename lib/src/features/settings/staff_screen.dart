import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'staff_pin_controller.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/pin_prompt_sheet.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(staffPinProvider);
    final controller = ref.read(staffPinProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Staff & Roles')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Require PIN for staff login'),
            subtitle: Text(state.enabled ? (state.locked ? 'Locked' : 'Unlocked') : 'Disabled'),
            value: state.enabled,
            onChanged: (v) {
              if (v) {
                _showSetPin(context, controller);
              } else {
                controller.clear();
              }
            },
          ),
          if (state.enabled && state.locked)
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Unlock with PIN'),
              onTap: () => _showUnlock(context, controller),
            ),
          const ListTile(
            leading: Icon(Icons.badge_outlined),
            title: Text('Permissions'),
            subtitle: Text('Limit access to reports, items, or refunds'),
          ),
        ],
      ),
    );
  }

  void _showSetPin(BuildContext context, StaffPinController controller) {
    unawaited(() async {
      final pin = await PinPromptSheet.show(
        context: context,
        title: 'Set staff PIN',
        pinLabel: 'Staff PIN',
        actionLabel: 'Save',
      );
      if (pin == null) return;
      await controller.setPin(pin);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Staff PIN set'),
          backgroundColor: DesignTokens.brandAccent,
        ),
      );
    }());
  }

  void _showUnlock(BuildContext context, StaffPinController controller) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Unlocked' : 'Wrong PIN'),
          backgroundColor: ok ? DesignTokens.brandAccent : DesignTokens.error,
        ),
      );
    }());
  }
}
