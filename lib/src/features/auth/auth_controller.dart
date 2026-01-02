import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/sync/sync_service.dart';
import '../../core/auth/pos_staff_prefs.dart';
import '../../core/util/phone_normalizer.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, loading, error }

class AuthState {
  const AuthState({
    required this.status,
    this.message,
    this.token,
  });

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

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final client = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthController(ref: ref, apiClient: client, storage: storage)..bootstrap();
});

class AuthController extends StateNotifier<AuthState> {
  AuthController({required this.ref, required ApiClient apiClient, required SecureStorage storage})
      : _apiClient = apiClient,
        _storage = storage,
        super(AuthState.unknown);

  final Ref ref;
  final ApiClient _apiClient;
  final SecureStorage _storage;
  Timer? _refreshTimer;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> bootstrap() async {
    final token = await _storage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      state = AuthState(status: AuthStatus.authenticated, token: token);
      _scheduleTokenRefresh();
      // Trigger background sync on bootstrap
      unawaited(ref.read(syncServiceProvider).syncNow());
    } else {
      state = AuthState.unauthenticated;
    }
  }

  Future<void> login({required String emailOrPhone, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading, message: null);
    try {
      final isEmail = emailOrPhone.contains('@');
      final normalizedPhone = isEmail ? null : normalizeUgPhone(emailOrPhone);
      final payload = <String, dynamic>{
        'login_by': isEmail ? 'email' : 'phone',
        // Backend always expects 'email' key for the identifier (email or phone)
        'email': (isEmail ? emailOrPhone.trim() : normalizedPhone),
        'password': password,
        'user_type': 'seller',
      };
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/v2/auth/login',
        data: payload,
      );
      final data = response.data ?? {};
      final token = data['access_token'] ?? data['token'] ?? '';
      if (token.isEmpty) {
        throw Exception('Missing token from API');
      }
      await _storage.writeAccessToken(token);
      if (normalizedPhone != null && normalizedPhone.isNotEmpty) {
        await _storage.writeLastLoginPhone(normalizedPhone);
      }
      state = AuthState(status: AuthStatus.authenticated, token: token);
      _scheduleTokenRefresh();
      // Trigger full sync after login
      unawaited(ref.read(syncServiceProvider).syncNow());
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
    } catch (e) {
      return {'exists': false, 'error': e.toString()};
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
          'user_type': 'seller',
          'registered_via': 'terminal',
        },
      );
      final data = response.data ?? {};
      final token = data['access_token'] ?? data['token'] ?? '';
      if (token.isEmpty) {
        // Check if registration succeeded but needs verification
        final result = data['result'];
        final message = data['message'];
        if (result == true || result == 'true') {
          // Account created, may need OTP verification
          state = AuthState(
            status: AuthStatus.unauthenticated,
            message: message?.toString() ?? 'Account created! Please verify your phone.',
          );
          return;
        }
        throw Exception(message ?? 'Registration failed');
      }
      await _storage.writeAccessToken(token);
      await _storage.writeLastLoginPhone(phone);
      state = AuthState(status: AuthStatus.authenticated, token: token);
      _scheduleTokenRefresh();
      unawaited(ref.read(syncServiceProvider).syncNow());
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
  }) async {
    state = state.copyWith(status: AuthStatus.loading, message: null);
    final normalized = normalizeUgPhone(phone);
    
    try {
      // Try backend verification first
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/v2/seller/pos/pin/verify',
        data: {'phone': normalized, 'pin': pin},
      );
      
      final data = response.data ?? {};
      if (data['result'] == true && data['access_token'] != null) {
        final token = data['access_token'];
        await _storage.writeAccessToken(token);
        await _storage.writeLastLoginPhone(normalized);
        state = AuthState(status: AuthStatus.authenticated, token: token);
        _scheduleTokenRefresh();
        unawaited(ref.read(syncServiceProvider).syncNow());
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

      // Also cache locally for offline/fallback scenarios (optional, but good for UX)
      await Future.wait([
        _storage.writeSellerQuickPhone(normalized),
        _storage.writeSellerQuickPassword(password.trim()),
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
    _refreshTimer?.cancel();
    
    // Clear all business data from the local database
    // This ensures complete data isolation between different sellers on the same device
    final db = ref.read(appDatabaseProvider);
    await db.clearAllData();
    
    // Clear all secure storage (tokens, credentials, POS sessions, quick login data)
    await _storage.clearAll();
    
    // Clear SharedPreferences (POS staff initialization flag and other prefs)
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.clear();
    
    state = AuthState.unauthenticated;
  }

  void _scheduleTokenRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 55), (timer) async {
      try {
        final response = await _apiClient.post<Map<String, dynamic>>('/v2/auth/refresh');
        final newToken = response.data?['access_token'];
        if (newToken != null && newToken is String && newToken.isNotEmpty) {
          await _storage.writeAccessToken(newToken);
          state = state.copyWith(token: newToken);
        }
      } catch (_) {
        // If refresh fails, we keep the old token and try again next loop
        // or user will eventually be logged out by 401 interceptor
      }
    });
  }
}
