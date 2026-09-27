import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

/// Paints before disk/plugin initialization and owns a recoverable boot attempt.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key, required this.initialize});
  final Future<Widget> Function() initialize;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  Widget? _app;
  bool _failed = false;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  Future<void> _start() async {
    if (_running) return;
    setState(() {
      _running = true;
      _failed = false;
    });
    try {
      final app = await widget.initialize();
      if (mounted) setState(() => _app = app);
    } catch (error, stack) {
      debugPrint('[Startup] Local initialization failed: $error\n$stack');
      if (mounted) setState(() => _failed = true);
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      _app ??
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: StartupView(
          status: 'Opening your workspace…',
          failed: _failed,
          onRetry: _start,
        ),
      );
}

/// Shared, inexpensive splash for dependency loading and session restore.
class StartupView extends StatelessWidget {
  const StartupView({
    super.key,
    required this.status,
    this.failed = false,
    this.onRetry,
  });
  final String status;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DesignTokens.brandPrimary,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  size: 64,
                  color: DesignTokens.brandAccent,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Soko24',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your business, ready for the day.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 36),
                if (!failed)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DesignTokens.brandAccent,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  failed
                      ? 'We couldn’t open your workspace. Please try again.'
                      : status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                if (failed) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Your saved business data has not been cleared.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
