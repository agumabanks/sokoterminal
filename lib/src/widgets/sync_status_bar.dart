import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/sync/sync_status_provider.dart';
import '../core/sync/sync_service.dart';
import '../core/theme/design_tokens.dart';

class SyncStatusBar extends ConsumerWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);

    final bool isVisible =
        status.state == SyncState.syncing || status.state == SyncState.error;

    Widget bar;
    switch (status.state) {
      case SyncState.syncing:
        bar = const LinearProgressIndicator(
          minHeight: 2,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(DesignTokens.brandAccent),
        );
        break;
      case SyncState.error:
        bar = const _PulsingErrorBar();
        break;
      case SyncState.offline:
      case SyncState.idle:
        bar = const SizedBox.shrink();
        break;
    }

    return GestureDetector(
      onTap: () => ref.read(syncServiceProvider).syncNow(),
      child: AnimatedContainer(
        duration: DesignTokens.durationFast,
        curve: DesignTokens.curveStandard,
        height: isVisible ? 2 : 0,
        width: double.infinity,
        color: Colors.transparent,
        child: isVisible ? bar : null,
      ),
    );
  }
}

class _PulsingErrorBar extends StatefulWidget {
  const _PulsingErrorBar();

  @override
  State<_PulsingErrorBar> createState() => _PulsingErrorBarState();
}

class _PulsingErrorBarState extends State<_PulsingErrorBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller.drive(Tween<double>(begin: 0.4, end: 1.0)),
      child: Container(
        height: 2,
        color: DesignTokens.error,
      ),
    );
  }
}
