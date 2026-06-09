import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// A reusable empty state widget for consistent "no data" UI across the app.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: DesignTokens.paddingPage,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: DesignTokens.textTertiary,
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            Text(
              title,
              style: DesignTokens.textHeadline,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: DesignTokens.spaceXs),
              SizedBox(
                width: 260,
                child: Text(
                  subtitle!,
                  style: DesignTokens.textBody.copyWith(
                    color: DesignTokens.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: DesignTokens.spaceLg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
