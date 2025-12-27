import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_seller_terminal/src/core/app_providers.dart';
import 'package:soko_seller_terminal/src/core/auth/pos_session_controller.dart';
import 'package:soko_seller_terminal/src/core/auth/pos_staff_prefs.dart';
import 'package:soko_seller_terminal/src/core/sync/sync_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    // Start auth check and sync after a brief delay to show logo
    Future.delayed(const Duration(milliseconds: 500), _checkAuthAndSync);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndSync() async {
    final secureStorage = ref.read(secureStorageProvider);
    final token = await secureStorage.readAccessToken();

    if (token == null) {
      if (mounted) context.go('/login');
      return;
    }

    // Start background sync pump for already-authenticated sessions.
    final syncService = ref.read(syncServiceProvider);
    syncService.start();

    // POS staff session check (only required when staff is initialized on backend).
    setState(() => _status = 'Checking staff session…');
    await ref.read(posSessionProvider.notifier).load();
    final posSession = ref.read(posSessionProvider);

    final prefs = ref.read(sharedPreferencesProvider);
    bool staffInitialized = prefs.getBool(posStaffInitializedPrefKey) ?? false;
    final connectivity = await Connectivity().checkConnectivity();
    final online = connectivity.any((r) => r != ConnectivityResult.none);
    if (online) {
      setState(() => _status = 'Checking staff setup…');
      try {
        final res = await ref.read(sellerApiProvider).fetchStaff();
        final data = res.data;
        final listRaw = data is Map
            ? (data['data'] is List ? data['data'] as List : const [])
            : (data is List ? data : const []);
        staffInitialized = listRaw.isNotEmpty;
        await prefs.setBool(posStaffInitializedPrefKey, staffInitialized);
      } catch (_) {
        // Keep last-known value when offline/intermittent.
      }
    }

    if (staffInitialized && !posSession.isActive) {
      if (!mounted) return;
      context.go('/pos-login?redirect=/home/checkout');
      return;
    }

    // Subscribe to status updates
    final sub = syncService.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() => _status = status);
      }
    });

    try {
      // Force sync or normal sync depending on state
      // We'll use syncNow which handles logic (or explicit full resync if preferred)
      // User wanted "immediate sync from backend".
      // We can use primeOfflineData or syncNow.
      await syncService.syncNow();
    } catch (e) {
      // Proceed even if sync fails (offline mode)
      debugPrint('Splash sync failed: $e');
    } finally {
      await sub.cancel();
      if (mounted) {
        context.go('/home/checkout');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo placeholder - using text for now or asset if available
                  const Text(
                    'Soko 24',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                children: [
                   SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.grey[900],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _status,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
