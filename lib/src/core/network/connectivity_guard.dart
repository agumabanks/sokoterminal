import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_providers.dart';

class ConnectivityGuard {
  static Future<bool> check(WidgetRef ref, {bool showMessage = true, BuildContext? context}) async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.any((r) => r != ConnectivityResult.none);
    
    if (!isOnline && showMessage && context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This action requires an active internet connection.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    
    return isOnline;
  }

  /// Wait for connection to be available, or timeout
  static Future<bool> waitForConnection(WidgetRef ref, {Duration timeout = const Duration(seconds: 10)}) async {
    final connectivity = ref.read(connectivityProvider);
    
    if (connectivity.asData?.value.any((r) => r != ConnectivityResult.none) ?? false) {
      return true;
    }

    try {
      await ref.read(connectivityProvider.stream).firstWhere(
        (results) => results.any((r) => r != ConnectivityResult.none),
      ).timeout(timeout);
      return true;
    } catch (_) {
      return false;
    }
  }
}
