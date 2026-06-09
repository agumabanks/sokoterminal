import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../app.dart';

/// Shared helpers for auth-related HTTP errors across the Seller Terminal.
class DioAuthUtils {
  DioAuthUtils._();

  static bool isAuthError(DioException error) {
    final status = error.response?.statusCode;
    return status == 401 || status == 403;
  }

  static bool isAuthStatus(int? status) => status == 401 || status == 403;

  static String userMessage(DioException error) {
    if (isAuthError(error)) {
      return 'Session expired — please sign in again';
    }
    final status = error.response?.statusCode;
    if (status == 429) return 'Too many requests — try again shortly';
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out — check your network';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'No internet — changes saved locally and will sync';
    }
    return error.message ?? 'Something went wrong';
  }

  /// Show a brief snackbar for auth failures so sellers never miss them.
  static void notifyAuthExpired({String? detail}) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(detail ?? 'Session expired — signing you out'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void notifySyncDeferred() {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Sign in to sync your latest changes'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  static void notifyCatalogQueued() {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Saved offline — catalog will sync when you\'re online'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  static void notifyCatalogSynced() {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Catalog synced to cloud'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Use in catch blocks: returns true when the error was an auth failure.
  static bool handleCatch(
    Object error, {
    bool showSnack = true,
    VoidCallback? onAuth,
  }) {
    if (error is! DioException) return false;
    if (!isAuthError(error)) return false;
    if (showSnack) notifyAuthExpired();
    onAuth?.call();
    return true;
  }
}