import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';
import '../../widgets/pin_prompt_sheet.dart';
import '../../features/settings/staff_pin_controller.dart';

Future<bool> requireManagerPin(
  BuildContext context,
  WidgetRef ref, {
  required String reason,
}) async {
  final pinState = ref.read(staffPinProvider);
  if (!pinState.enabled) return true;

  final expected = await ref.read(secureStorageProvider).readPin();
  if (expected == null || expected.isEmpty) return true;

  if (!context.mounted) return false;
  final entered = await PinPromptSheet.show(
    context: context,
    title: 'Manager approval required',
    subtitle: reason,
    actionLabel: 'Approve',
  );
  if (entered == null) return false;

  final ok = entered.trim() == expected;
  if (!context.mounted) return ok;
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Incorrect PIN')),
    );
  }
  return ok;
}

