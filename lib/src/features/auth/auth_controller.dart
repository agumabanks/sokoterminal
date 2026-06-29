import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/auth/pos_staff_prefs.dart';
import '../../core/firebase/fcm_service.dart';
import '../../core/network/api_client.dart';
import '../../core/network/dio_auth_utils.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/sync/sync_service.dart';
import '../../core/util/phone_normalizer.dart';
import '../backup/migration_controller.dart';
import '../checkout/cart_controller.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, loading, error }

class AuthState {
  const AuthState({required this.status, this.message, this.token});

  final AuthStatus status;
  final String? token;
  final String? message;

  AuthState copyWith({AuthStatus? status, String? message, String? token}) {
    return AuthState(
      status: status ?? this.status,
      message: message ?? this.message,
      token: token ?? this.token,
    );
  }

  static const unknown = AuthState(status: AuthStatus.unknown);
  static const unauthenticated = AuthState(status: AuthStatus.unauthenticated);
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final client = ref.watch(apiClientProvider);
    final storage = ref.watch(secureStorageProvider);
    return AuthController(ref: ref, apiClient: client, storage: storage)
      ..bootstrap();
  },
);

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required this.ref,
    required ApiClient apiClient,
    required SecureStorage storage,
  }) : _apiClient = apiClient,
       _storage = storage,
       super(AuthState.unknown);

  final Ref ref;
  final ApiClient _apiClient;
  final SecureStorage _storage;

  Future<void> bootstrap() async {
    // Register the 401 logout callback so the API client can trigger logout.
    // Deferred to avoid modifying another provider during initialization.
    Future.microtask(() {
      ref.read(authLogoutCallbackProvider.notifier).state = () {
        logout();
      };
    });

    final token = await _storage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      debugPrint(
        '[Auth] Restored persisted access token (${token.length} chars)',
      );
      state = AuthState(status: AuthStatus.authenticated, token: token);
      // Subscribe to seller sync topic (best-effort; sellerId may not be stored yet)
      final sellerId = await _storage.readSellerId();
      if (sellerId != null && sellerId.isNotEmpty) {
        unawaited(FCMService.instance.subscribeToTopic('seller_${sellerId}_pos_sync'));
      }
      unawaited(
        FCMService.instance.init(sellerApi: ref.read(sellerApiProvider)),
      );
      // Trigger background sync on bootstrap
      unawaited(ref.read(syncServiceProvider).syncNow());
    } else {
      debugPrint('[Auth] No persisted access token found during bootstrap');
      state = AuthState.unauthenticated;
    }
  }

  Future<void> login({
    required String emailOrPhone,
    required String password,
    bool rememberDevice = false,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, message: null);
    try {
      final rawIdentifier = emailOrPhone.trim();
      final isEmail = emailOrPhone.contains('@');
      final normalizedPhone = isEmail ? null : normalizeUgPhone(emailOrPhone);
      final response = await _performSellerLoginRequest(
        isEmail: isEmail,
        identifier: isEmail ? emailOrPhone.trim() : (normalizedPhone ?? ''),
        rawIdentifier: rawIdentifier,
        password: password,
        rememberDevice: rememberDevice,
      );
      final data = response.data ?? {};
      final token = _extractAccessToken(data);
      final expiresAt = _extractExpiresAt(data);

      // Ensure local database is cleared before starting a new session
      // This prevents data bleeding between different users on the same device
      final db = ref.read(appDatabaseProvider);
      await db.clearAllData();

      final persistedToken = await _persistAccessToken(token);
      await _persistTokenMeta(expiresAt: expiresAt, rememberDevice: rememberDevice);

      // Store seller UUID for identity persistence
      final user = data['user'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['user'] as Map<String, dynamic>)
          : null;
      final sellerUUID = user?['seller_uuid']?.toString();
      if (sellerUUID != null && sellerUUID.isNotEmpty) {
        await _storage.writeSellerUUID(sellerUUID);
      }
      final sellerId = user?['id']?.toString();
      if (sellerId != null && sellerId.isNotEmpty) {
        await _storage.writeSellerId(sellerId);
        // Subscribe to real-time sync topic for this seller
        unawaited(FCMService.instance.subscribeToTopic('seller_${sellerId}_pos_sync'));
      }
      unawaited(
        FCMService.instance.init(sellerApi: ref.read(sellerApiProvider)),
      );

      if (normalizedPhone != null && normalizedPhone.isNotEmpty) {
        await _storage.writeLastLoginPhone(normalizedPhone);
      }
      debugPrint(
        '[Auth] Login succeeded for seller account; '
        'persistedToken=${persistedToken.isNotEmpty} '
        'sellerUuid=${sellerUUID != null && sellerUUID.isNotEmpty}',
      );
      _apiClient.resetLogoutGuard();
      state = AuthState(
        status: AuthStatus.authenticated,
        token: persistedToken,
      );
      // Trigger full sync after login
      unawaited(ref.read(syncServiceProvider).syncNow());
      unawaited(ref.read(migrationProvider.notifier).checkForBackups());
    } on DioException catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        message: e.response?.data?['message']?.toString() ?? 'Login failed',
      );
    } catch (e) {
      state = AuthState(status: AuthStatus.error, message: e.toString());
    }
  }

  Future<Map<String, dynamic>> checkUserExistence(String phone) async {
    final normalized = normalizeUgPhone(phone);
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/v2/seller/pos/auth/check',
        data: {'phone': normalized},
      );
      return response.data ?? {'exists': false};
    } on DioException catch (e) {
      final msg =
          e.response?.data?['message']?.toString() ??
          'Unable to verify account right now.';
      throw Exception(msg);
    } catch (_) {
      throw Exception('Unable to verify account right now.');
    }
  }

  Future<void> register({
    required String name,
    required String phone,
    required String pin,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, message: null);
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/v2/auth/signup',
        data: {
          'name': name.trim(),
          'email_or_phone': phone,
          'register_by': 'phone',
          'password': pin,
          'password_confirmation': pin,
          'pin': pin,
          'user_type': 'seller',
          'registered_via': 'terminal',
          'shop_name': name.trim(),
        },
      );
      final data = response.data ?? {};
      final token = _extractAccessToken(data, allowMissing: true);
      if (token.isEmpty) {
        // Check if registration succeeded but needs verification
        final result = data['result'];
        final message = data['message'];
        if (result == true || result == 'true') {
          // Account created, may need OTP verification
          state = AuthState(
            status: AuthStatus.unauthenticated,
            message:
                message?.toString() ??
                'Account created! Please verify your phone.',
          );
          return;
        }
        throw Exception(message ?? 'Registration failed');
      }
      final db = ref.read(appDatabaseProvider);
      await db.clearAllData();
      final persistedToken = await _persistAccessToken(token);
      await _storage.writeLastLoginPhone(phone);
      final user = data['user'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['user'] as Map<String, dynamic>)
          : null;
      final sellerUUID = user?['seller_uuid']?.toString();
      if (sellerUUID != null && sellerUUID.isNotEmpty) {
        await _storage.writeSellerUUID(sellerUUID);
      }
      debugPrint('[Auth] Registration created an authenticated session');
      _apiClient.resetLogoutGuard();
      state = AuthState(
        status: AuthStatus.authenticated,
        token: persistedToken,
      );
      unawaited(ref.read(syncServiceProvider).syncNow());
      unawaited(ref.read(migrationProvider.notifier).checkForBackups());
    } on DioException catch (e) {
      final errorData = e.response?.data;
      String errorMsg = 'Registration failed';
      if (errorData is Map) {
        final message = errorData['message'];
        if (message is List) {
          errorMsg = message.join('\n');
        } else if (message != null) {
          errorMsg = message.toString();
        }
      }
      state = AuthState(status: AuthStatus.error, message: errorMsg);
    } catch (e) {
      state = AuthState(status: AuthStatus.error, message: e.toString());
    }
  }

  Future<void> loginWithQuickPin({
    required String phone,
    required String pin,
    bool rememberDevice = false,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, message: null);
    final normalized = normalizeUgPhone(phone);

    try {
      // Try backend verification first
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/v2/seller/pos/pin/verify',
        data: {
          'phone': normalized,
          'pin': pin,
          'remember_me': rememberDevice,
        },
      );

      final data = response.data ?? {};
      if (data['result'] == true && data['access_token'] != null) {
        final token = _extractAccessToken(data);
        final expiresAt = _extractExpiresAt(data);

        // Ensure local database is cleared before starting a new session
        // This prevents data bleeding between different users on the same device
        final db = ref.read(appDatabaseProvider);
        await db.clearAllData();

        final persistedToken = await _persistAccessToken(token);
        await _persistTokenMeta(expiresAt: expiresAt, rememberDevice: rememberDevice);
        await _storage.writeLastLoginPhone(normalized);
        debugPrint('[Auth] Quick PIN login succeeded');
        _apiClient.resetLogoutGuard();
        state = AuthState(
          status: AuthStatus.authenticated,
          token: persistedToken,
        );
        unawaited(ref.read(syncServiceProvider).syncNow());
        // Quick PIN login check for backups
        unawaited(ref.read(migrationProvider.notifier).checkForBackups());
        return;
      }
    } catch (e) {
      // Fallback to local check if backend fails (e.g. offline) or returns specific error?
      // For now, let's stick to strict backend verification as requested "saved to backend too"

      // However, if we want to support offline PIN login later, we'd check _storage here.
      // Given the requirement "pin saved to backend... user to do more with less clicks",
      // backend verification is key for security and cross-device.

      String msg = 'PIN login failed';
      if (e is DioException) {
        msg = e.response?.data?['message']?.toString() ?? msg;
      }
      state = AuthState(status: AuthStatus.error, message: msg);
      return;
    }
  }

  Future<void> enableQuickPin({
    required String phone,
    required String password,
    required String pin,
  }) async {
    final normalized = normalizeUgPhone(phone);
    final p = pin.trim();
    // Enforce 6-digit PIN
    if (normalized.isEmpty || password.trim().isEmpty || p.length != 6) {
      return;
    }

    try {
      // Store PIN on backend
      await _apiClient.post(
        '/v2/seller/pos/pin',
        data: {'pin': p, 'password': password},
      );

      await Future.wait([
        _storage.writeSellerQuickPhone(normalized),
        _storage.writeSellerQuickPin(p),
        _storage.writeLastLoginPhone(normalized),
      ]);
    } catch (e) {
      // If backend fails, we might still want to fail or handle gracefullly
      // For now, let's propagate error or handle it in UI
      rethrow;
    }
  }

  Future<String?> getLastLoginPhone() => _storage.readLastLoginPhone();
  Future<String?> getQuickPinPhone() => _storage.readSellerQuickPhone();

  Future<void> logout() async {
    debugPrint('[Auth] Clearing local session state');

    // Reset the logout callback so late-fired interceptor errors
    // don't trigger a second logout.
    ref.read(authLogoutCallbackProvider.notifier).state = null;
    // Also reset the API client's internal guard so a fresh login
    // can trigger logout again if needed.
    _apiClient.resetLogoutGuard();

    // Unsubscribe from seller sync topic before clearing data
    final sellerId = await _storage.readSellerId();
    if (sellerId != null && sellerId.isNotEmpty) {
      unawaited(FCMService.instance.unsubscribeFromTopic('seller_${sellerId}_pos_sync'));
    }

    // Notify backend to revoke the token (best-effort)
    try {
      await _apiClient.get('/v2/auth/logout');
    } catch (e) {
      debugPrint('[Auth] Server logout failed or offline: $e');
    }

    // Stop sync timers and streams before clearing data to prevent
    // race conditions where sync pumps against a partially-cleared DB.
    await ref.read(syncServiceProvider).dispose();
    ref.invalidate(syncServiceProvider);

    // Clear cart in-memory state so the next seller doesn't see leftovers.
    ref.read(cartControllerProvider.notifier).clear();
    ref.invalidate(cartControllerProvider);

    // Clear all business data from the local database
    // This ensures complete data isolation between different sellers on the same device
    final db = ref.read(appDatabaseProvider);
    await db.clearAllData();

    // Clear all secure storage (tokens, credentials, POS sessions, quick login data)
    await _storage.clearAll();
    await _storage.deleteAccessTokenExpiresAt();
    await _storage.deleteRememberDevice();

    // Remove only auth-related SharedPreferences keys.
    // Keep printer settings, business setup flags, receipt templates, etc.
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove('login_type');
    await prefs.remove('staff_shop_id');
    await prefs.remove('staff_id');
    await prefs.remove('staff_name');
    await prefs.remove('staff_phone');
    await prefs.remove(posStaffInitializedPrefKey);

    state = AuthState.unauthenticated;
  }

  /// Attempts to refresh the access token immediately.
  /// Returns true if a new token was obtained.
  Future<bool> refreshToken() async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/v2/auth/refresh',
      );
      final newToken = response.data?['access_token'];
      final expiresAt = _extractExpiresAt(response.data ?? {});
      if (newToken != null && newToken is String && newToken.isNotEmpty) {
        await _storage.writeAccessToken(newToken);
        await _persistTokenMeta(expiresAt: expiresAt);
        state = state.copyWith(token: newToken);
        return true;
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (DioAuthUtils.isAuthStatus(statusCode)) {
        DioAuthUtils.notifyAuthExpired();
        await logout();
      }
      debugPrint('[Auth] Token refresh failed: $statusCode');
    } catch (e) {
      debugPrint('[Auth] Token refresh error: $e');
    }
    return false;
  }

  String _extractAccessToken(
    Map<String, dynamic> data, {
    bool allowMissing = false,
  }) {
    final token = (data['access_token'] ?? data['token'] ?? '')
        .toString()
        .trim();
    if (!allowMissing && token.isEmpty) {
      throw Exception('Missing token from API');
    }
    return token;
  }

  DateTime? _extractExpiresAt(Map<String, dynamic> data) {
    final raw = data['expires_at'];
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    final parsed = DateTime.tryParse(raw.toString())?.toUtc();
    return parsed;
  }

  Future<void> _persistTokenMeta({
    DateTime? expiresAt,
    bool? rememberDevice,
  }) async {
    if (expiresAt != null) {
      await _storage.writeAccessTokenExpiresAt(expiresAt);
    } else {
      await _storage.deleteAccessTokenExpiresAt();
    }
    if (rememberDevice != null) {
      await _storage.writeRememberDevice(rememberDevice);
    }
  }

  Future<String> _persistAccessToken(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      throw Exception('Missing token from API');
    }

    await _storage.writeAccessToken(normalized);
    final persisted = await _storage.readAccessToken();
    final stored = persisted?.trim() ?? '';
    if (stored.isEmpty) {
      debugPrint('[Auth] Access token write verification failed');
      throw Exception(
        'Unable to persist the access token on this device. Please try again.',
      );
    }

    debugPrint('[Auth] Access token persisted successfully');
    return stored;
  }

  Future<Response<Map<String, dynamic>>> _performSellerLoginRequest({
    required bool isEmail,
    required String identifier,
    required String rawIdentifier,
    required String password,
    bool rememberDevice = false,
  }) async {
    Future<Response<Map<String, dynamic>>> request(String loginIdentifier) {
      return _apiClient.post<Map<String, dynamic>>(
        '/v2/auth/login',
        data: {
          'login_by': isEmail ? 'email' : 'phone',
          // Backend expects the identifier under the `email` key.
          'email': loginIdentifier,
          'password': password,
          'user_type': 'seller',
          'remember_me': rememberDevice,
        },
      );
    }

    final candidates = _loginIdentifierCandidates(
      isEmail: isEmail,
      identifier: identifier,
      rawIdentifier: rawIdentifier,
    );
    DioException? lastDioError;
    Exception? lastBusinessError;

    for (var index = 0; index < candidates.length; index++) {
      final loginIdentifier = candidates[index];
      if (index > 0) {
        debugPrint(
          '[Auth] Retrying seller password login with alternate phone format',
        );
      }

      try {
        final response = await request(loginIdentifier);
        final failureMessage = _loginFailureMessage(response.data);
        if (failureMessage != null) {
          if (_shouldRetryPhoneVariant(
            isEmail: isEmail,
            message: failureMessage,
          )) {
            lastBusinessError = Exception(failureMessage);
            continue;
          }
          throw Exception(failureMessage);
        }
        return response;
      } on DioException catch (error) {
        final failureMessage = _loginFailureMessage(error.response?.data);
        if (_shouldRetryPhoneVariant(
          isEmail: isEmail,
          message: failureMessage,
        )) {
          lastDioError = error;
          continue;
        }
        rethrow;
      }
    }

    if (lastBusinessError != null) throw lastBusinessError;
    if (lastDioError != null) throw lastDioError;

    return request(identifier);
  }

  List<String> _loginIdentifierCandidates({
    required bool isEmail,
    required String identifier,
    required String rawIdentifier,
  }) {
    if (isEmail) return [identifier];

    final candidates = <String>[];
    void addCandidate(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || candidates.contains(trimmed)) return;
      candidates.add(trimmed);
    }

    addCandidate(identifier);

    final digits = identifier.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('256') && digits.length == 12) {
      addCandidate('+$digits');
      addCandidate('0${digits.substring(3)}');
    }

    final raw = rawIdentifier.trim();
    addCandidate(raw);
    if (raw.startsWith('+')) {
      addCandidate(raw.substring(1));
    }

    final rawDigits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    addCandidate(rawDigits);

    return candidates;
  }

  String? _loginFailureMessage(dynamic payload) {
    if (payload is! Map) return null;
    final data = Map<String, dynamic>.from(payload);
    final token = _extractAccessToken(data, allowMissing: true);
    final result = data['result'];
    final succeeded =
        token.isNotEmpty ||
        result == null ||
        result == true ||
        result == 'true';
    if (succeeded) return null;

    final message = data['message']?.toString().trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }

    return 'Login failed';
  }

  bool _shouldRetryPhoneVariant({
    required bool isEmail,
    required String? message,
  }) {
    if (isEmail) return false;

    final normalized = message?.toLowerCase().trim() ?? '';
    return normalized.contains('user not found');
  }
}
