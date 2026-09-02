import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// A reusable error state widget for consistent failure UI across the app.
class ErrorState extends StatelessWidget {
  const ErrorState({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: DesignTokens.paddingPage,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: DesignTokens.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 24,
                color: DesignTokens.warning,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            Text(
              'Couldn’t refresh this page',
              style: DesignTokens.textTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              message,
              style: DesignTokens.textBodyMuted,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: DesignTokens.spaceLg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
