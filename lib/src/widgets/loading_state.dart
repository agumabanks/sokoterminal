import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';

/// A quiet, consistent loading surface for full-page data.
///
/// It communicates structure without blocking the screen with a large spinner.
class LoadingState extends StatefulWidget {
  const LoadingState({this.label = 'Getting things ready…', super.key});

  final String label;

  @override
  State<LoadingState> createState() => _LoadingStateState();
}

class _LoadingStateState extends State<LoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: DesignTokens.paddingScreen,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final opacity = 0.38 + (_controller.value * 0.34);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final width in <double>[220, 280, 250]) ...[
                  Opacity(
                    opacity: opacity,
                    child: Container(
                      width: width,
                      height: 14,
                      decoration: BoxDecoration(
                        color: DesignTokens.grayLight,
                        borderRadius: DesignTokens.borderRadiusFull,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                Text(widget.label, style: DesignTokens.textCaption),
              ],
            );
          },
        ),
      ),
    );
  }
}
