import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:soko_seller_terminal/src/core/app_providers.dart';
import 'package:soko_seller_terminal/src/core/auth/pos_session_controller.dart';
import 'package:soko_seller_terminal/src/core/auth/pos_staff_prefs.dart';
import 'package:soko_seller_terminal/src/features/auth/auth_controller.dart';
import 'package:soko_seller_terminal/src/core/settings/business_setup_prefs.dart';
import 'package:soko_seller_terminal/src/core/sync/sync_service.dart';
import 'package:soko_seller_terminal/src/core/network/dio_auth_utils.dart';
import 'package:soko_seller_terminal/src/core/theme/design_tokens.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _ambientController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _logoFloatAnimation;
  String _status = 'Initializing…';

  int get _statusStage {
    final normalized = _status.toLowerCase();
    if (normalized.contains('staff session') ||
        normalized.contains('staff setup')) {
      return 1;
    }
    if (normalized.contains('sync') ||
        normalized.contains('data') ||
        normalized.contains('booting')) {
      return 2;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0, 0.6, curve: Curves.easeOutQuart),
    );
    _scaleAnimation = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutBack),
      ),
    );
    _logoFloatAnimation = Tween<double>(begin: 8, end: -8).animate(
      CurvedAnimation(parent: _ambientController, curve: Curves.easeInOut),
    );

    _introController.forward();
    Future.delayed(const Duration(milliseconds: 350), _bootstrap);
  }

  @override
  void dispose() {
    _introController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _requestPermissions();
    if (!mounted) return;
    await _checkAuthAndSync();
  }

  Future<void> _requestPermissions() async {
    try {
      if (mounted) setState(() => _status = 'Checking permissions…');

      // ── Step 1: silent permissions (never prompt the user) ────────────
      // These are considered pre-granted on a POS terminal and should be
      // silently granted via ADB for enrolled devices:
      //   adb shell pm grant com.soko24.soko_seller_terminal \
      //       android.permission.READ_CONTACTS
      //   adb shell pm grant com.soko24.soko_seller_terminal \
      //       android.permission.ACCESS_FINE_LOCATION
      //
      // We still request them here so a fresh install works without ADB.
      final corePermissions = <Permission>[
        Permission.contacts,
        Permission.locationWhenInUse,
        Permission.notification,
      ];
      for (final p in corePermissions) {
        final s = await p.status;
        if (s.isDenied || s.isRestricted) {
          await p.request();
        }
      }

      // ── Step 2: Bluetooth (Android 12+ runtime, needed for receipt printers)
      final btPermissions = <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ];
      for (final p in btPermissions) {
        final s = await p.status;
        if (s.isDenied || s.isRestricted) {
          await p.request();
        }
      }
    } catch (e) {
      debugPrint('[Splash] Permission request failed: $e');
    }
  }

  Future<void> _checkAuthAndSync() async {
    debugPrint('[Splash] _checkAuthAndSync START');
    if (!mounted) { debugPrint('[Splash] not mounted at start'); return; }
    final secureStorage = ref.read(secureStorageProvider);
    final token = await secureStorage.readAccessToken();
    debugPrint('[Splash] token=${token != null}');

    if (token == null) {
      if (mounted) context.go('/login');
      return;
    }

    // Validate token when online before proceeding
    final connectivity = await Connectivity().checkConnectivity();
    final online = connectivity.any((r) => r != ConnectivityResult.none);
    debugPrint('[Splash] online=$online');
    if (online) {
      try {
        final api = ref.read(apiClientProvider);
        await api.get('/v2/auth/user');
        debugPrint('[Splash] token validation OK');
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (DioAuthUtils.isAuthStatus(status)) {
          debugPrint('[Splash] Token invalid, redirecting to login');
          DioAuthUtils.notifyAuthExpired();
          await secureStorage.deleteAccessToken();
          if (mounted) context.go('/login');
          return;
        }
        // Other errors: allow offline-style fallback
      } catch (e) {
        debugPrint('[Splash] Token validation error: $e');
      }
    }

    if (!mounted) { debugPrint('[Splash] not mounted after token check'); return; }

    // Seed expense categories on first launch (no-op if already seeded)
    final db = ref.read(appDatabaseProvider);
    await db.seedExpenseCategoriesIfEmpty();

    final syncService = ref.read(syncServiceProvider);
    debugPrint('[Splash] calling syncService.start()');
    syncService.start();

    final loginType = await secureStorage.read(key: 'login_type');
    debugPrint('[Splash] loginType=$loginType');

    if (loginType == 'staff') {
      final shopId = await secureStorage.read(key: 'staff_shop_id');
      if (shopId == null) {
        if (mounted) context.go('/staff-login');
        return;
      }
      // Validate staff token online before proceeding, same as owner login.
      if (online) {
        try {
          final api = ref.read(apiClientProvider);
          await api.get('/v2/auth/user');
          debugPrint('[Splash] Staff token validation OK');
        } on DioException catch (e) {
          final status = e.response?.statusCode;
          if (DioAuthUtils.isAuthStatus(status)) {
            debugPrint('[Splash] Staff token invalid, redirecting to staff login');
            DioAuthUtils.notifyAuthExpired();
            await secureStorage.deleteAccessToken();
            if (mounted) context.go('/staff-login');
            return;
          }
        } catch (e) {
          debugPrint('[Splash] Staff token validation error: $e');
        }
      }
    } else {
      if (!mounted) { debugPrint('[Splash] not mounted before staff check'); return; }
      setState(() => _status = 'Checking staff session…');
      debugPrint('[Splash] POS session already loading via provider...');
      // PosSessionController already auto-loads in its provider constructor;
      // we just wait briefly for it to settle rather than firing a second load().
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) { debugPrint('[Splash] not mounted after pos session load'); return; }
      final posSession = ref.read(posSessionProvider);
      debugPrint('[Splash] posSession.isActive=${posSession.isActive}');

      final prefs = ref.read(sharedPreferencesProvider);
      bool staffInitialized =
          prefs.getBool(posStaffInitializedPrefKey) ?? false;
      final connectivity = await Connectivity().checkConnectivity();
      final online = connectivity.any((r) => r != ConnectivityResult.none);
      if (online) {
        if (!mounted) { debugPrint('[Splash] not mounted before fetchStaff'); return; }
        setState(() => _status = 'Checking staff setup…');
        debugPrint('[Splash] fetching staff...');
        try {
          final res = await ref.read(sellerApiProvider).fetchStaff();
          final data = res.data;
          final listRaw = data is Map
              ? (data['data'] is List ? data['data'] as List : const [])
              : (data is List ? data : const []);
          staffInitialized = listRaw.isNotEmpty;
          await prefs.setBool(posStaffInitializedPrefKey, staffInitialized);
          debugPrint('[Splash] staffInitialized=$staffInitialized');
        } catch (e) {
          debugPrint('[Splash] staff check failed: $e');
        }
      }

      if (staffInitialized && !posSession.isActive) {
        debugPrint('[Splash] redirecting to /pos-login');
        if (!mounted) return;
        context.go('/pos-login?redirect=/home/checkout');
        return;
      }
    }

    final sub = syncService.syncStatusStream.listen((status) {
      if (mounted) setState(() => _status = status);
    });

    debugPrint('[Splash] calling syncService.syncNow()...');
    try {
      await syncService.syncNow();
      debugPrint('[Splash] syncNow() COMPLETED');
    } catch (e) {
      debugPrint('[Splash] syncNow() FAILED: $e');
    }

    await sub.cancel();
    if (!mounted) { debugPrint('[Splash] not mounted after sync'); return; }

    debugPrint('[Splash] checking business setup...');
    bool setupCompleted = false;
    try {
      setupCompleted = await ref
          .read(businessSetupCompletedProvider.notifier)
          .refreshFromLocalCache(ref.read(appDatabaseProvider))
          .timeout(const Duration(seconds: 5));
      debugPrint('[Splash] setupCompleted=$setupCompleted');
    } on TimeoutException {
      debugPrint('[Splash] refreshFromLocalCache TIMEOUT after 5s');
    } catch (e) {
      debugPrint('[Splash] refreshFromLocalCache ERROR: $e');
    }
    if (!mounted) { debugPrint('[Splash] not mounted after setup check'); return; }

    final setupRequired =
        ref
            .read(sharedPreferencesProvider)
            .getBool(businessSetupRequiredPrefKey) ??
        false;
    final destination = setupRequired && !setupCompleted
        ? '/home/more/business-setup'
        : '/home/checkout';
    debugPrint('[Splash] setupRequired=$setupRequired destination=$destination');

    if (!mounted) { debugPrint('[Splash] not mounted before navigation'); return; }
    debugPrint('[Splash] NAVIGATING to $destination');
    context.go(destination);
    debugPrint('[Splash] _checkAuthAndSync END');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02040A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _Vignette(),
          AnimatedBuilder(
            animation: _ambientController,
            builder: (context, child) {
              return CustomPaint(
                painter: _BreathRings(
                  progress: _ambientController.value,
                  color: DesignTokens.brandAccent,
                ),
              );
            },
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  _Hero(
                    scaleAnimation: _scaleAnimation,
                    floatAnimation: _logoFloatAnimation,
                    stage: _statusStage,
                  ),
                  const SizedBox(height: 56),
                  _SplashStatus(
                    status: _status,
                    stage: _statusStage,
                  ),
                  const Spacer(flex: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.85,
          colors: [
            Color(0xFF0A1226),
            Color(0xFF02040A),
          ],
          stops: [0, 1],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.scaleAnimation,
    required this.floatAnimation,
    required this.stage,
  });

  final Animation<double> scaleAnimation;
  final Animation<double> floatAnimation;
  final int stage;

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: scaleAnimation,
      child: AnimatedBuilder(
        animation: floatAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, floatAnimation.value),
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LogoRing(stage: stage),
            const SizedBox(height: 32),
            Text(
              'Soko24',
              style: DesignTokens.textTitleLight.copyWith(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'SELLER TERMINAL',
              style: DesignTokens.textSmall.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.8,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'The operating system for African business',
              textAlign: TextAlign.center,
              style: DesignTokens.textSmall.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                color: Colors.white.withValues(alpha: 0.55),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            const _FeaturePills(),
          ],
        ),
      ),
    );
  }
}

class _FeaturePills extends StatelessWidget {
  const _FeaturePills();

  static const _pills = [
    (Icons.point_of_sale_rounded, 'POS'),
    (Icons.inventory_2_rounded, 'Catalog'),
    (Icons.brush_rounded, 'Studio'),
    (Icons.cloud_off_rounded, 'Offline'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: _pills
          .map(
            (pill) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: DesignTokens.brandAccent.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    pill.$1,
                    size: 14,
                    color: DesignTokens.brandAccent.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    pill.$2,
                    style: DesignTokens.textSmall.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _LogoRing extends StatelessWidget {
  const _LogoRing({required this.stage});

  final int stage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 172,
      height: 172,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow
          Container(
            width: 172,
            height: 172,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: DesignTokens.brandAccent.withValues(alpha: 0.22),
                  blurRadius: 64,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
          ),
          // Glass ring
          Container(
            width: 172,
            height: 172,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.2,
              ),
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.28),
                      Colors.white.withValues(alpha: 0.06),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: DesignTokens.brandGradient,
                          ),
                          child: const Icon(
                            Icons.storefront,
                            color: Colors.white,
                            size: 48,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Stage badges
          Positioned(
            top: 4,
            right: 4,
            child: _StageBadge(
              active: stage >= 2,
              label: stage >= 2 ? 'Live' : 'Sync',
            ),
          ),
          Positioned(
            bottom: 18,
            left: -6,
            child: _StageBadge(
              active: stage >= 1,
              label: stage >= 1 ? 'Secure' : 'Auth',
            ),
          ),
        ],
      ),
    );
  }
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.active, required this.label});

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? DesignTokens.brandAccent.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? DesignTokens.brandAccent.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: DesignTokens.textSmall.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.65),
        ),
      ),
    );
  }
}

class _SplashStatus extends StatelessWidget {
  const _SplashStatus({required this.status, required this.stage});

  final String status;
  final int stage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stage dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StageDot(label: 'Session', state: _dotState(0)),
              _StageConnector(complete: stage > 0),
              _StageDot(label: 'Catalog', state: _dotState(1)),
              _StageConnector(complete: stage > 1),
              _StageDot(label: 'POS', state: _dotState(2)),
            ],
          ),
          const SizedBox(height: 20),
          // Progress bar (determinate by boot stage)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                value: (stage + 1) / 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  DesignTokens.brandAccent.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Status text
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              status,
              key: ValueKey(status),
              textAlign: TextAlign.center,
              style: DesignTokens.textSmall.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _DotState _dotState(int index) {
    if (stage > index) return _DotState.complete;
    if (stage == index) return _DotState.active;
    return _DotState.pending;
  }
}

enum _DotState { pending, active, complete }

class _StageDot extends StatelessWidget {
  const _StageDot({required this.label, required this.state});

  final String label;
  final _DotState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _DotState.complete => DesignTokens.brandAccent,
      _DotState.active => DesignTokens.info,
      _DotState.pending => Colors.white.withValues(alpha: 0.25),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: state == _DotState.active
                ? [
                    BoxShadow(
                      color: DesignTokens.info.withValues(alpha: 0.45),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: DesignTokens.textSmall.copyWith(
            fontSize: 11,
            fontWeight: state == _DotState.pending
                ? FontWeight.w500
                : FontWeight.w700,
            color: state == _DotState.pending
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _StageConnector extends StatelessWidget {
  const _StageConnector({required this.complete});

  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: complete
          ? DesignTokens.brandAccent.withValues(alpha: 0.5)
          : Colors.white.withValues(alpha: 0.12),
    );
  }
}

class _BreathRings extends CustomPainter {
  _BreathRings({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);

    for (int i = 0; i < 3; i++) {
      final offset = i / 3.0;
      final ringProgress = (progress + offset) % 1.0;
      final radius = 90 + (ringProgress * 140);
      final alpha = 0.12 * (1 - ringProgress);
      if (alpha <= 0) continue;

      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(center, radius, paint);
    }

    // Subtle crosshair
    final crosshair = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(size.width * 0.2, center.dy),
      Offset(size.width * 0.8, center.dy),
      crosshair,
    );
    canvas.drawLine(
      Offset(center.dx, size.height * 0.25),
      Offset(center.dx, size.height * 0.75),
      crosshair,
    );
  }

  @override
  bool shouldRepaint(covariant _BreathRings oldDelegate) => true;
}
