import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/rbac_provider.dart';
import '../../core/theme/design_tokens.dart';

// Re-export Permission for convenience
export '../../core/auth/rbac_provider.dart' show Permission;

/// A reusable widget that prompts for manager PIN before allowing an action
class ManagerPinGate extends ConsumerStatefulWidget {
  const ManagerPinGate({
    super.key,
    required this.permission,
    required this.actionLabel,
    required this.onAuthorized,
    this.child,
  });

  /// The permission required
  final Permission permission;

  /// Label shown to user (e.g., "Process Refund")
  final String actionLabel;

  /// Callback when authorized
  final VoidCallback onAuthorized;

  /// Optional child widget (if null, shows as button)
  final Widget? child;

  @override
  ConsumerState<ManagerPinGate> createState() => _ManagerPinGateState();
}

class _ManagerPinGateState extends ConsumerState<ManagerPinGate> {
  void _handleTap() {
    final rbac = ref.read(rbacProvider);

    // If already authorized, proceed
    if (rbac.can(widget.permission)) {
      widget.onAuthorized();
      return;
    }

    // Otherwise prompt for manager PIN
    _showPinPrompt();
  }

  void _showPinPrompt() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ManagerPinSheet(
        actionLabel: widget.actionLabel,
        onSuccess: () {
          Navigator.pop(ctx);
          widget.onAuthorized();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.child != null) {
      return GestureDetector(
        onTap: _handleTap,
        child: widget.child,
      );
    }

    return ElevatedButton(
      onPressed: _handleTap,
      child: Text(widget.actionLabel),
    );
  }
}

class _ManagerPinSheet extends ConsumerStatefulWidget {
  const _ManagerPinSheet({
    required this.actionLabel,
    required this.onSuccess,
  });

  final String actionLabel;
  final VoidCallback onSuccess;

  @override
  ConsumerState<_ManagerPinSheet> createState() => _ManagerPinSheetState();
}

class _ManagerPinSheetState extends ConsumerState<_ManagerPinSheet> {
  final _pinController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final rbacController = ref.read(rbacProvider.notifier);
    final success = await rbacController.requestManagerOverride(pin);

    if (!mounted) return;

    if (success) {
      widget.onSuccess();
    } else {
      setState(() {
        _loading = false;
        _error = 'Invalid manager PIN';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: DesignTokens.grayLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: DesignTokens.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.admin_panel_settings,
              size: 32,
              color: DesignTokens.warning,
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            'Manager Authorization',
            style: DesignTokens.textTitle,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter manager PIN to ${widget.actionLabel.toLowerCase()}',
            style: DesignTokens.textBody.copyWith(
              color: DesignTokens.grayMedium,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // PIN input
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 8,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Manager PIN',
              prefixIcon: const Icon(Icons.lock_outline),
              counterText: '',
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            autofocus: true,
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: 24),
          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verify,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Authorize'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Helper function to check permission before action
Future<bool> checkPermissionWithPin({
  required BuildContext context,
  required WidgetRef ref,
  required Permission permission,
  required String actionLabel,
}) async {
  final rbac = ref.read(rbacProvider);

  // If already authorized, proceed
  if (rbac.can(permission)) {
    return true;
  }

  // Otherwise prompt for manager PIN
  final completer = Completer<bool>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _ManagerPinSheet(
      actionLabel: actionLabel,
      onSuccess: () {
        Navigator.pop(ctx);
        completer.complete(true);
      },
    ),
  ).then((_) {
    if (!completer.isCompleted) {
      completer.complete(false);
    }
  });

  return completer.future;
}
