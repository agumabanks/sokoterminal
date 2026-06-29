import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Enables edge-swipe-to-go-back on Android and other non-iOS platforms.
///
/// Drag from the left edge (within [edgeWidth]) to the right to pop the route.
/// Visual feedback is provided by a subtle shadow that follows the finger.
class SwipeBackWrapper extends StatefulWidget {
  const SwipeBackWrapper({
    super.key,
    required this.child,
    this.edgeWidth = 24.0,
    this.dragThreshold = 100.0,
  });

  final Widget child;
  final double edgeWidth;
  final double dragThreshold;

  @override
  State<SwipeBackWrapper> createState() => _SwipeBackWrapperState();
}

class _SwipeBackWrapperState extends State<SwipeBackWrapper>
    with SingleTickerProviderStateMixin {
  double _dragDelta = 0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        Transform.translate(
          offset: Offset(_dragDelta, 0),
          child: widget.child,
        ),

        // Left edge gesture detector
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: widget.edgeWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) {
              setState(() {
                _isDragging = true;
                _dragDelta = 0;
              });
            },
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragDelta += details.delta.dx;
                if (_dragDelta < 0) _dragDelta = 0;
              });
            },
            onHorizontalDragEnd: (_) {
              if (_dragDelta > widget.dragThreshold) {
                if (GoRouter.of(context).canPop()) {
                  GoRouter.of(context).pop();
                } else if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              }
              setState(() {
                _isDragging = false;
                _dragDelta = 0;
              });
            },
            onHorizontalDragCancel: () {
              setState(() {
                _isDragging = false;
                _dragDelta = 0;
              });
            },
          ),
        ),

        // Visual shadow feedback during drag
        if (_isDragging && _dragDelta > 0)
          Positioned(
            left: _dragDelta - 8,
            top: 0,
            bottom: 0,
            width: 8,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
