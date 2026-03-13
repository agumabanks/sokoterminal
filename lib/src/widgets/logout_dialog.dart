import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_providers.dart';
import '../core/auth/pos_session_controller.dart';
import '../core/theme/design_tokens.dart';
import '../features/auth/auth_controller.dart';

/// Shows a logout dialog with three options:
/// 1. Lock Screen (require same user PIN to unlock)
/// 2. Switch Staff (end POS session, go to POS login)
/// 3. Full Logout (clear DB, go to login)
class LogoutDialog extends ConsumerWidget {
  const LogoutDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const LogoutDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(_pendingSyncCountProvider).maybeWhen(
      data: (count) => count,
      orElse: () => 0,
    );

    return AlertDialog(
      title: const Text('Sign Out'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pendingCount > 0)
            Container(
              padding: const EdgeInsets.all(DesignTokens.spaceSm),
              margin: const EdgeInsets.only(bottom: DesignTokens.spaceMd),
              decoration: BoxDecoration(
                color: DesignTokens.warning.withValues(alpha: 0.12),
                borderRadius: DesignTokens.borderRadiusSm,
                border: Border.all(
                  color: DesignTokens.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_upload, color: DesignTokens.warning, size: 20),
                  const SizedBox(width: DesignTokens.spaceSm),
                  Expanded(
                    child: Text(
                      '$pendingCount unsynced transaction${pendingCount == 1 ? '' : 's'} will be lost if you sign out completely.',
                      style: DesignTokens.textSmall.copyWith(color: DesignTokens.warning),
                    ),
                  ),
                ],
              ),
            ),
          _OptionTile(
            icon: Icons.lock_outline,
            iconColor: DesignTokens.brandPrimary,
            title: 'Lock my screen',
            subtitle: 'Keep logged in, require PIN to resume',
            onTap: () => _lockScreen(context, ref),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          _OptionTile(
            icon: Icons.swap_horiz,
            iconColor: DesignTokens.info,
            title: 'Switch staff',
            subtitle: 'End shift, let another staff sign in',
            onTap: () => _switchStaff(context, ref),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          _OptionTile(
            icon: Icons.logout,
            iconColor: DesignTokens.error,
            title: 'Sign out completely',
            subtitle: 'Clear all data from this device',
            onTap: () => _fullLogout(context, ref, pendingCount),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  void _lockScreen(BuildContext context, WidgetRef ref) {
    Navigator.of(context).pop();
    ref.read(screenLockedProvider.notifier).state = true;
  }

  Future<void> _switchStaff(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop();
    await ref.read(posSessionProvider.notifier).end();
    if (!context.mounted) return;
    context.go('/pos-login');
  }

  Future<void> _fullLogout(BuildContext context, WidgetRef ref, int pendingCount) async {
    if (pendingCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Are you sure?'),
          content: Text(
            'You have $pendingCount unsynced transaction${pendingCount == 1 ? '' : 's'}. '
            'Signing out will permanently delete them from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: DesignTokens.error),
              child: const Text('Sign out anyway'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    Navigator.of(context).pop();
    await ref.read(authControllerProvider.notifier).logout();
    if (!context.mounted) return;
    context.go('/login');
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMd,
          vertical: DesignTokens.spaceSm,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: DesignTokens.grayLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: DesignTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DesignTokens.textBody.copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: DesignTokens.textSmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: DesignTokens.grayMedium),
          ],
        ),
      ),
    );
  }
}

/// Global state for screen lock
final screenLockedProvider = StateProvider<bool>((ref) => false);

/// Provider that counts pending sync operations
final _pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final ops = await db.pendingSyncOps();
  return ops.length;
});
