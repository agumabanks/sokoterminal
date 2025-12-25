import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/sync/sync_service.dart';
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

  Future<void> loginWithQuickPin({
    required String phone,
    required String pin,
  }) async {
    final normalized = normalizeUgPhone(phone);
    final savedPhone = await _storage.readSellerQuickPhone();
    final savedPin = await _storage.readSellerQuickPin();
    final savedPassword = await _storage.readSellerQuickPassword();

    if (savedPhone == null ||
        savedPin == null ||
        savedPassword == null ||
        savedPhone.isEmpty ||
        savedPassword.isEmpty) {
      state = const AuthState(
        status: AuthStatus.error,
        message: 'PIN login not set up on this device.',
      );
      return;
    }

    if (normalizeUgPhone(savedPhone) != normalized) {
      state = const AuthState(
        status: AuthStatus.error,
        message: 'PIN is set for a different phone number.',
      );
      return;
    }

    if (savedPin != pin.trim()) {
      state = const AuthState(status: AuthStatus.error, message: 'Incorrect PIN');
      return;
    }

    await login(emailOrPhone: normalized, password: savedPassword);
  }

  Future<void> enableQuickPin({
    required String phone,
    required String password,
    required String pin,
  }) async {
    final normalized = normalizeUgPhone(phone);
    final p = pin.trim();
    if (normalized.isEmpty || password.trim().isEmpty || p.isEmpty) return;
    await Future.wait([
      _storage.writeSellerQuickPhone(normalized),
      _storage.writeSellerQuickPassword(password.trim()),
      _storage.writeSellerQuickPin(p),
      _storage.writeLastLoginPhone(normalized),
    ]);
  }

  Future<String?> getLastLoginPhone() => _storage.readLastLoginPhone();
  Future<String?> getQuickPinPhone() => _storage.readSellerQuickPhone();

  Future<void> logout() async {
    _refreshTimer?.cancel();
    await _storage.deleteAccessToken();
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
