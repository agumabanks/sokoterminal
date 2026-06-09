import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/app_providers.dart';
import '../core/theme/design_tokens.dart';

class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);

    return connectivity.when(
      data: (results) {
        final isOffline = results.contains(ConnectivityResult.none);
        return AnimatedContainer(
          duration: DesignTokens.durationNormal,
          curve: DesignTokens.curveStandard,
          height: isOffline ? 36 : 0,
          width: double.infinity,
          decoration: BoxDecoration(
            color: DesignTokens.warning.withValues(alpha: 0.15),
            border: Border(
              left: BorderSide(
                color: DesignTokens.warning,
                width: 4,
              ),
            ),
          ),
          child: isOffline
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.offline_bolt,
                      color: DesignTokens.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Working offline — changes will sync when connected',
                      style: DesignTokens.textSmall.copyWith(
                        color: DesignTokens.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : null,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
