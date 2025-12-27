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

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
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

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Staff Login'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: DesignTokens.paddingScreen,
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
              decoration: const InputDecoration(
                labelText: 'PIN',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              onSubmitted: (_) => _submit(ctrl),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            if ((session.error ?? '').trim().isNotEmpty)
              Text(
                session.error!,
                style: DesignTokens.textSmall.copyWith(color: DesignTokens.error),
              ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: session.loading ? null : () => _submit(ctrl),
              icon: session.loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(session.loading ? 'Signing in…' : 'Sign in'),
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            OutlinedButton(
              onPressed: () => context.go(widget.redirectTo ?? '/home/checkout'),
              child: const Text('Continue offline'),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
          ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Signed in'),
          backgroundColor: DesignTokens.brandAccent,
        ),
      );
      context.go(widget.redirectTo ?? '/home/checkout');
    }
  }
}

