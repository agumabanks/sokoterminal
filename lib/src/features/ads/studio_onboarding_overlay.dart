import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/haptics.dart';
import 'studio_onboarding_prefs.dart';
import 'studio_theme.dart';

/// Coach-mark style onboarding overlay for the Studio hub.
///
/// Highlights 4 key areas: mode picker, product pill, create-design CTA, and
/// brand-kit indicator. Uses a dark scrim + simple tooltip cards positioned
/// over the screen.
class StudioOnboardingOverlay extends ConsumerStatefulWidget {
  const StudioOnboardingOverlay({super.key});

  @override
  ConsumerState<StudioOnboardingOverlay> createState() =>
      _StudioOnboardingOverlayState();
}

class _StudioOnboardingOverlayState
    extends ConsumerState<StudioOnboardingOverlay> {
  int _step = 0;

  static const _steps = [
    _CoachStep(
      title: 'Switch Studio modes',
      body: 'Pick between templates, AI tools, graphics, and campaigns.',
      alignment: Alignment.topLeft,
      offset: Offset(24, 120),
    ),
    _CoachStep(
      title: 'Product pill',
      body: 'Tap here to choose which product or service powers your designs.',
      alignment: Alignment.topRight,
      offset: Offset(-24, 172),
    ),
    _CoachStep(
      title: 'Create a design',
      body: 'Start from a blank canvas or pick a format.',
      alignment: Alignment.center,
      offset: Offset(0, -40),
    ),
    _CoachStep(
      title: 'Brand Kit',
      body: 'Keep your colours, fonts, and logo consistent everywhere.',
      alignment: Alignment.bottomCenter,
      offset: Offset(0, -180),
    ),
  ];

  void _next() {
    Haptics.selection();
    if (_step >= _steps.length - 1) {
      ref.read(hasSeenStudioOnboardingProvider.notifier).markSeen();
    } else {
      setState(() => _step++);
    }
  }

  void _dismiss() {
    Haptics.soft();
    ref.read(hasSeenStudioOnboardingProvider.notifier).markSeen();
  }

  @override
  Widget build(BuildContext context) {
    final hasSeen = ref.watch(hasSeenStudioOnboardingProvider);
    if (hasSeen) return const SizedBox.shrink();

    final theme = ref.watch(studioThemeProvider);
    final step = _steps[_step];
    final isLast = _step == _steps.length - 1;

    return GestureDetector(
      onTap: _dismiss,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        child: Stack(
          children: [
            Align(
              alignment: step.alignment,
              child: Transform.translate(
                offset: step.offset,
                child: GestureDetector(
                  onTap: _next,
                  child: Container(
                    width: 260,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.accent.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accent.withValues(alpha: 0.25),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: theme.accent,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${_step + 1}',
                                  style: TextStyle(
                                    color: theme.scaffold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                step.title,
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          step.body,
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _DotProgress(
                                count: _steps.length,
                                current: _step,
                                accent: theme.accent,
                                muted: theme.border,
                              ),
                            ),
                            TextButton(
                              onPressed: _next,
                              style: TextButton.styleFrom(
                                foregroundColor: theme.accent,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                isLast ? 'Got it' : 'Next',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachStep {
  const _CoachStep({
    required this.title,
    required this.body,
    required this.alignment,
    required this.offset,
  });

  final String title;
  final String body;
  final Alignment alignment;
  final Offset offset;
}

class _DotProgress extends StatelessWidget {
  const _DotProgress({
    required this.count,
    required this.current,
    required this.accent,
    required this.muted,
  });

  final int count;
  final int current;
  final Color accent;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        return Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: i == current ? accent : muted,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
