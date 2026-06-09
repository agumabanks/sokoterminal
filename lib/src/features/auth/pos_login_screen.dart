import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/pos_session_controller.dart';
import '../../core/theme/design_tokens.dart';

class PosLoginScreen extends ConsumerStatefulWidget {
  const PosLoginScreen({super.key, this.redirectTo});

  final String? redirectTo;

  @override
  ConsumerState<PosLoginScreen> createState() => _PosLoginScreenState();
}

class _PosLoginScreenState extends ConsumerState<PosLoginScreen> {
  final _pinCtrl = TextEditingController();
  int _failedAttempts = 0;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownSeconds = 30;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) timer.cancel();
      });
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(posSessionProvider);
    final ctrl = ref.read(posSessionProvider.notifier);

    if (session.isActive && !session.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(widget.redirectTo ?? '/home/checkout');
      });
    }

    final isLocked = _cooldownSeconds > 0 || session.loading;

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Staff Login'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: DesignTokens.paddingScreen,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: DesignTokens.spaceLg),
              Text('Enter staff PIN', style: DesignTokens.textTitle),
              const SizedBox(height: DesignTokens.spaceXs),
              Text(
                'This is required to sync sales, cash movements, and privileged actions.',
                style: DesignTokens.textSmall,
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              TextField(
                controller: _pinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                enabled: _cooldownSeconds <= 0,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                onSubmitted: (_) => isLocked ? null : _submit(ctrl),
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              if ((session.error ?? '').trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMd,
                    vertical: DesignTokens.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    color: DesignTokens.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: DesignTokens.error.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: DesignTokens.error,
                        size: 18,
                      ),
                      const SizedBox(width: DesignTokens.spaceSm),
                      Expanded(
                        child: Text(
                          session.error!,
                          style: DesignTokens.textSmall.copyWith(
                            color: DesignTokens.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: DesignTokens.spaceXl),
              ElevatedButton.icon(
                onPressed: isLocked ? null : () => _submit(ctrl),
                icon: session.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(
                  session.loading
                      ? 'Signing in…'
                      : _cooldownSeconds > 0
                          ? 'Wait $_cooldownSeconds s'
                          : 'Sign in',
                ),
              ),
              const SizedBox(height: DesignTokens.spaceSm),
              Text(
                "If you're offline, enter your staff PIN and tap Sign in. "
                'Limited mode will activate automatically.',
                textAlign: TextAlign.center,
                style: DesignTokens.textSmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceLg),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(PosSessionController ctrl) async {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) return;
    final ok = await ctrl.startWithPin(pin);
    if (!mounted) return;
    if (ok) {
      _failedAttempts = 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Signed in'),
          backgroundColor: DesignTokens.brandAccent,
        ),
      );
      context.go(widget.redirectTo ?? '/home/checkout');
    } else {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        _startCooldown();
      }
    }
  }
}
