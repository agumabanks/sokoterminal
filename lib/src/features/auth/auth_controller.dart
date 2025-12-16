import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';

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
  return AuthController(apiClient: client, storage: storage)..bootstrap();
});

class AuthController extends StateNotifier<AuthState> {
  AuthController({required ApiClient apiClient, required SecureStorage storage})
      : _apiClient = apiClient,
        _storage = storage,
        super(AuthState.unknown);

  final ApiClient _apiClient;
  final SecureStorage _storage;

  Future<void> bootstrap() async {
    final token = await _storage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      state = AuthState(status: AuthStatus.authenticated, token: token);
    } else {
      state = AuthState.unauthenticated;
    }
  }

  Future<void> login({required String emailOrPhone, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading, message: null);
    try {
      final isEmail = emailOrPhone.contains('@');
      final payload = <String, dynamic>{
        'login_by': isEmail ? 'email' : 'phone',
        isEmail ? 'email' : 'phone': emailOrPhone.trim(),
        'password': password,
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
      state = AuthState(status: AuthStatus.authenticated, token: token);
    } on DioException catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        message: e.response?.data?['message']?.toString() ?? 'Login failed',
      );
    } catch (e) {
      state = AuthState(status: AuthStatus.error, message: e.toString());
    }
  }

  Future<void> logout() async {
    await _storage.clearAll();
    state = AuthState.unauthenticated;
  }
}
