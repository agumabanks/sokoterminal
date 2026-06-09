import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio/pos_sound_service.dart';
import '../../core/util/haptics.dart';

/// Cinematic Soko Studio opening — ~4s with sound, haptics, and anticipation.
class StudioSplashScreen extends StatefulWidget {
  const StudioSplashScreen({super.key, required this.onReady});
  final VoidCallback onReady;

  @override
  State<StudioSplashScreen> createState() => _StudioSplashScreenState();
}

class _StudioSplashScreenState extends State<StudioSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late AnimationController _logoCtrl;
  late AnimationController _orbitsCtrl;
  late AnimationController _modulesCtrl;
  late AnimationController _exitCtrl;
  late AnimationController _breatheCtrl;

  late Animation<double> _bgOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<double> _exitOpacity;

  static const _modules = [
    (Icons.campaign_rounded, 'Today\'s Ads'),
    (Icons.auto_awesome_outlined, 'AI Studio'),
    (Icons.palette_outlined, 'Brand Kit'),
    (Icons.storefront_outlined, 'Business Hub'),
    (Icons.share_rounded, 'Share'),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _orbitsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _modulesCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _bgOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _bgCtrl, curve: Curves.easeIn),
    );
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0, 0.55, curve: Curves.easeIn),
      ),
    );
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.45, 1, curve: Curves.easeIn),
      ),
    );
    _exitOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOut),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    Haptics.soft();
    unawaited(PosSoundService().playStudioReveal());

    await _bgCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 120));
    Haptics.selection();
    await _logoCtrl.forward();
    Haptics.impact();

    _orbitsCtrl.forward();
    _modulesCtrl.forward();
    for (var i = 0; i < _modules.length; i++) {
      await Future.delayed(const Duration(milliseconds: 140));
      if (mounted) Haptics.selection();
    }

    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      Haptics.success();
    }
    await Future.delayed(const Duration(milliseconds: 350));
    await _exitCtrl.forward();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    widget.onReady();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _bgCtrl.dispose();
    _logoCtrl.dispose();
    _orbitsCtrl.dispose();
    _modulesCtrl.dispose();
    _exitCtrl.dispose();
    _breatheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _exitOpacity,
      builder: (context, child) => Opacity(
        opacity: _exitOpacity.value,
        child: child,
      ),
      child: AnimatedBuilder(
        animation: _bgOpacity,
        builder: (context, child) =>
            Opacity(opacity: _bgOpacity.value, child: child),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF000000), Color(0xFF0A0A0A), Color(0xFF18181B)],
            ),
          ),
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _orbitsCtrl,
                builder: (_, __) {
                  final t = _orbitsCtrl.value * math.pi;
                  return Positioned(
                    left: size.width * 0.5 + math.cos(t) * 90 - 100,
                    top: size.height * 0.38 + math.sin(t) * 40 - 100,
                    child: _GlowOrb(
                      color: Colors.white,
                      size: 200,
                      opacity: 0.06,
                    ),
                  );
                },
              ),
              ...List.generate(18, (i) {
                final r = math.Random(i * 41);
                return Positioned(
                  left: r.nextDouble() * size.width,
                  top: r.nextDouble() * size.height,
                  child: AnimatedBuilder(
                    animation: _logoCtrl,
                    builder: (_, __) => Opacity(
                      opacity: _logoOpacity.value * 0.35,
                      child: Container(
                        width: 1.5,
                        height: 1.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              }),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([_logoCtrl, _breatheCtrl]),
                      builder: (_, child) {
                        final breathe = 1 + _breatheCtrl.value * 0.03;
                        return Transform.scale(
                          scale: _logoScale.value * breathe,
                          child: Opacity(
                            opacity: _logoOpacity.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.15),
                              blurRadius: 48,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF09090B),
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    AnimatedBuilder(
                      animation: _logoCtrl,
                      builder: (_, child) =>
                          Opacity(opacity: _logoOpacity.value, child: child),
                      child: const Text(
                        'SOKO STUDIO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedBuilder(
                      animation: _logoCtrl,
                      builder: (_, child) =>
                          Opacity(opacity: _textOpacity.value, child: child),
                      child: Text(
                        'Something great is ready for you',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 52),
                    AnimatedBuilder(
                      animation: _modulesCtrl,
                      builder: (context, _) {
                        return Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(_modules.length, (i) {
                            final delay = i / (_modules.length + 1);
                            final progress = (((_modulesCtrl.value - delay) /
                                    (1 - delay))
                                .clamp(0.0, 1.0));
                            final eased =
                                Curves.easeOutCubic.transform(progress);
                            return Transform.scale(
                              scale: 0.85 + eased * 0.15,
                              child: Opacity(
                                opacity: eased,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.12),
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _modules[i].$1,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _modules[i].$2,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 56,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _modulesCtrl,
                  builder: (_, __) => Column(
                    children: [
                      Text(
                        'Preparing today\'s ads…',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 72),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(1),
                          child: LinearProgressIndicator(
                            value: _modulesCtrl.value,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            valueColor: const AlwaysStoppedAnimation(
                              Colors.white,
                            ),
                            minHeight: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.color,
    required this.size,
    required this.opacity,
  });

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
        ),
      ),
    );
  }
}