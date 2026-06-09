import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'dio_auth_utils.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';

typedef AuthExpiredCallback = void Function();

// ---------------------------------------------------------------------------
// RateLimitInterceptor
// ---------------------------------------------------------------------------
// Protects the client from:
//   1. Burst duplicates — same method+path called < 400 ms apart → returns the
//      in-flight response (fan-out) instead of firing a second request.
//   2. HTTP 429 responses — respects Retry-After header (or backs off 5 s).
//      After 3 consecutive 429s on the same endpoint, circuit opens for 30 s.
// ---------------------------------------------------------------------------

class RateLimitInterceptor extends Interceptor {
  RateLimitInterceptor({
    this.minIntervalMs = 400,
    this.circuitOpenMs = 30000,
    this.max429BeforeCircuitOpen = 3,
  });

  final int minIntervalMs;
  final int circuitOpenMs;
  final int max429BeforeCircuitOpen;

  // Track in-flight requests: key → completer that receives the response
  final _inflight = <String, Completer<Response<dynamic>>>{};

  // Track last successful call time per key (for debounce on reads)
  final _lastCall = <String, int>{};

  // 429 counters and circuit-open timestamps per endpoint
  final _count429 = <String, int>{};
  final _circuitOpenUntil = <String, int>{};

  String _key(RequestOptions opts) => '${opts.method}:${opts.path}';

  bool _isMutation(String method) {
    final m = method.toUpperCase();
    return m == 'POST' || m == 'PUT' || m == 'PATCH' || m == 'DELETE';
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final key = _key(options);
    final now = DateTime.now().millisecondsSinceEpoch;

    // ── Circuit breaker check ─────────────────────────────────────────────
    final openUntil = _circuitOpenUntil[key];
    if (openUntil != null && now < openUntil) {
      final wait = ((openUntil - now) / 1000).ceil();
      debugPrint('[RateLimit] Circuit open for $key — retry in ${wait}s');
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          message: 'Circuit open: too many 429s on $key. Retry in ${wait}s.',
        ),
      );
    }

    // ── Mutation pass-through (no debounce) ───────────────────────────────
    // Mutations (POST/PUT/PATCH/DELETE) are always forwarded — idempotency
    // keys on the server handle accidental duplicates, not us.
    if (_isMutation(options.method)) {
      return handler.next(options);
    }

    // ── GET / READ debounce ───────────────────────────────────────────────
    final last = _lastCall[key];
    if (last != null && (now - last) < minIntervalMs) {
      // If a request for this key is already in-flight, wait for it.
      final completer = _inflight[key];
      if (completer != null) {
        debugPrint('[RateLimit] Fan-out: waiting for in-flight $key');
        completer.future.then(
          (r) => handler.resolve(r),
          onError: (e) => handler.reject(e as DioException),
        );
        return;
      }
    }

    // Record timestamp and register in-flight tracker for GETs
    _lastCall[key] = now;
    final completer = Completer<Response<dynamic>>();
    _inflight[key] = completer;

    // Attach a tag so onResponse/onError can complete the completer
    options.extra['_rate_limit_key'] = key;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final key = response.requestOptions.extra['_rate_limit_key'] as String?;
    if (key != null) {
      _inflight.remove(key)?.complete(response);
      _count429.remove(key); // reset 429 counter on success
      _circuitOpenUntil.remove(key); // reset circuit on success
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final key = err.requestOptions.extra['_rate_limit_key'] as String?;

    if (err.response?.statusCode == 429 && key != null) {
      // Track 429s per endpoint
      final count = (_count429[key] ?? 0) + 1;
      _count429[key] = count;
      debugPrint('[RateLimit] 429 on $key (count=$count)');

      // Parse Retry-After header and log it — the sync service's own
      // exponential backoff will handle the actual retry.
      final retryAfterHeader = err.response?.headers.value('Retry-After');
      final retryAfterSec = int.tryParse(retryAfterHeader ?? '') ?? 5;
      debugPrint('[RateLimit] Retry-After: ${retryAfterSec}s');

      // Open circuit after repeated 429s
      if (count >= max429BeforeCircuitOpen) {
        final openUntil = DateTime.now().millisecondsSinceEpoch + circuitOpenMs;
        _circuitOpenUntil[key] = openUntil;
        debugPrint(
          '[RateLimit] Circuit opened for $key for ${circuitOpenMs ~/ 1000}s',
        );
      }
    }

    if (key != null) {
      _inflight.remove(key)?.completeError(err);
    }
    handler.next(err);
  }
}

class ApiClient {
  ApiClient({
    required AppConfig config,
    required SecureStorage secureStorage,
    AuthExpiredCallback? onAuthExpired,
  }) : _secureStorage = secureStorage,
       _onAuthExpired = onAuthExpired {
    _dio = Dio(
      BaseOptions(
        baseUrl: _normalizeBaseUrl(config.apiBaseUrl),
        connectTimeout: Duration(milliseconds: config.connectTimeoutMs),
        receiveTimeout: Duration(milliseconds: config.receiveTimeoutMs),
        headers: {'Accept': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          final posToken = await _secureStorage.readPosSessionToken();
          if (posToken != null && posToken.isNotEmpty) {
            options.headers['X-POS-Session'] = posToken;
          }
          _logRequest(options);
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _logResponse(response);
          return handler.next(response);
        },
        onError: (error, handler) async {
          _logError(error);
          final statusCode = error.response?.statusCode;
          if (statusCode == 401) {
            final path = error.requestOptions.path;

            // Strict path matching for auth endpoints that should NEVER
            // trigger logout on 401 (prevents logout loops).
            final isAuthEndpoint = _pathEndsWithOneOf(path, const {
              'auth/login',
              'auth/refresh',
              'auth/signup',
              'auth/logout',
              'auth/user',
              'pos/auth/check',
              'pos/pin/verify',
              'seller/pos/sessions/me',
              'seller/pos/sessions/end',
              'seller/pos/pin',
            });

            // Pre-login POS endpoints also suppress 401 logout.
            final isPreLoginPosEndpoint = _pathEndsWithOneOf(path, const {
              'pos/auth/check',
              'pos/pin/verify',
              'pos/sessions/start',
              'pos/staff/login',
            });

            if (!isAuthEndpoint && !isPreLoginPosEndpoint) {
              // If logout is already in flight (e.g. from a concurrent 401),
              // pass through without attempting another refresh.
              if (_isLoggingOut) {
                debugPrint(
                  '[HTTP] Auth expired for $path; logout already in progress',
                );
                return handler.next(error);
              }

              // ── Proactive token refresh on 401 ──────────────────────────
              // Instead of immediately logging out, try to refresh the token
              // once. If refresh succeeds, retry the original request. This
              // fixes the common case where the access token expired but the
              // refresh token is still valid.
              // Skip refresh if there is no persisted token at all — nothing
              // to refresh, so go straight to logout.
              final currentToken = await _secureStorage.readAccessToken();
              final refreshed = currentToken != null && currentToken.isNotEmpty
                  ? await _attemptTokenRefresh()
                  : false;
              if (refreshed) {
                // Retry the original request with the new token.
                debugPrint('[HTTP] Retrying $path after token refresh');
                try {
                  final newToken = await _secureStorage.readAccessToken();
                  final newOptions = Options(
                    method: error.requestOptions.method,
                    headers: Map<String, dynamic>.from(
                      error.requestOptions.headers,
                    ),
                    contentType: error.requestOptions.contentType,
                    responseType: error.requestOptions.responseType,
                    extra: error.requestOptions.extra,
                  );
                  newOptions.headers?['Authorization'] = 'Bearer $newToken';
                  // Remove the old Authorization header if present
                  if (newToken != null && newToken.isNotEmpty) {
                    newOptions.headers?['Authorization'] = 'Bearer $newToken';
                  } else {
                    newOptions.headers?.remove('Authorization');
                  }

                  final retryResponse = await _dio.request<dynamic>(
                    error.requestOptions.path,
                    data: error.requestOptions.data,
                    queryParameters: error.requestOptions.queryParameters,
                    options: newOptions,
                  );
                  return handler.resolve(retryResponse);
                } on DioException catch (retryErr) {
                  debugPrint(
                    '[HTTP] Retry failed for $path: ${retryErr.message}',
                  );
                  // If retry also 401s, do NOT logout — the 401 is caused by
                  // something other than an expired token (e.g. missing POS
                  // session, missing permissions, etc.). Only logout when the
                  // refresh itself fails.
                  return handler.next(retryErr);
                } catch (retryErr) {
                  debugPrint('[HTTP] Retry error for $path: $retryErr');
                  return handler.next(error);
                }
              } else {
                // Refresh failed or returned no token → force logout.
                await _performLogout(path);
              }
            }
          }
          return handler.next(error);
        },
      ),
    );

    // Rate limiting: debounce burst GETs, circuit-break on repeated 429s
    _dio.interceptors.add(RateLimitInterceptor());

    if (!kReleaseMode && config.logLevel != 'none') {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: false,
          responseBody: config.logLevel == 'debug',
        ),
      );
    }
  }

  late final Dio _dio;
  final SecureStorage _secureStorage;
  final AuthExpiredCallback? _onAuthExpired;
  bool _isLoggingOut = false;
  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  Dio get client => _dio;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    return _dio.get<T>(_normalizePath(path), queryParameters: query);
  }

  Future<Response<T>> post<T>(
    String path, {
    Map<String, dynamic>? query,
    Object? data,
    Options? options,
  }) async {
    return _dio.post<T>(
      _normalizePath(path),
      data: data,
      queryParameters: query,
      options: options,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Map<String, dynamic>? query,
    Object? data,
    Options? options,
  }) async {
    return _dio.patch<T>(
      _normalizePath(path),
      data: data,
      queryParameters: query,
      options: options,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Map<String, dynamic>? query,
    Object? data,
    Options? options,
  }) async {
    return _dio.put<T>(
      _normalizePath(path),
      data: data,
      queryParameters: query,
      options: options,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? query,
    Object? data,
    Options? options,
  }) async {
    return _dio.delete<T>(
      _normalizePath(path),
      data: data,
      queryParameters: query,
      options: options,
    );
  }

  /// Resets the logout guard so the interceptor can fire again.
  /// Call this after a successful login or when constructing a fresh session.
  void resetLogoutGuard() => _isLoggingOut = false;

  /// Attempts to refresh the token by hitting the backend refresh endpoint.
  /// Returns true if a new token was obtained and persisted.
  /// Coordinates concurrent refresh attempts so only one request is fired.
  Future<bool> _attemptTokenRefresh() async {
    // If another request is already refreshing, wait for it.
    if (_isRefreshing && _refreshCompleter != null) {
      debugPrint('[HTTP] Waiting for in-flight token refresh...');
      return _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'v2/auth/refresh',
        options: Options(
          // Do not attach the normal auth interceptor logic for this call;
          // the interceptor already adds the current (possibly stale) token.
          // The refresh endpoint should accept the stale token or the refresh
          // cookie. If the backend uses a separate refresh mechanism, this
          // still works because the stale bearer is better than none.
          headers: {'Accept': 'application/json'},
        ),
      );
      final newToken = response.data?['access_token'];
      if (newToken != null && newToken is String && newToken.isNotEmpty) {
        await _secureStorage.writeAccessToken(newToken);
        debugPrint(
          '[HTTP] Token refreshed successfully (${newToken.length} chars)',
        );
        _refreshCompleter!.complete(true);
        return true;
      }
      debugPrint('[HTTP] Token refresh returned no token');
      _refreshCompleter!.complete(false);
      return false;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      debugPrint('[HTTP] Token refresh failed: HTTP $status');
      _refreshCompleter!.complete(false);
      return false;
    } catch (e) {
      debugPrint('[HTTP] Token refresh error: $e');
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _performLogout(String path) async {
    if (_isLoggingOut) {
      debugPrint(
        '[HTTP] Auth expired for $path; logout already in progress',
      );
      return;
    }
    _isLoggingOut = true;
    debugPrint(
      '[HTTP] Access token expired or missing for $path; '
      'clearing persisted session',
    );
    DioAuthUtils.notifyAuthExpired();
    await _secureStorage.deleteAccessToken();
    await _secureStorage.deletePosSessionToken();
    _onAuthExpired?.call();
  }

  static bool _pathEndsWithOneOf(String path, Set<String> suffixes) {
    for (final suffix in suffixes) {
      if (path.endsWith(suffix)) return true;
    }
    return false;
  }

  static String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  static String _normalizePath(String path) {
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return trimmed.substring(1);
    }
    return trimmed;
  }

  void _logRequest(RequestOptions options) {
    debugPrint('[HTTP] -> ${options.method} ${options.uri}');
    if (options.queryParameters.isNotEmpty) {
      debugPrint('[HTTP]    query: ${_redact(options.queryParameters)}');
    }
    if (options.data != null) {
      debugPrint('[HTTP]    data: ${_redact(options.data)}');
    }
  }

  void _logResponse(Response<dynamic> response) {
    debugPrint(
      '[HTTP] <- ${response.statusCode} ${response.requestOptions.uri}',
    );
    if (response.data != null) {
      debugPrint('[HTTP]    data: ${_redact(response.data)}');
    }
  }

  void _logError(DioException error) {
    debugPrint('[HTTP] !! ${error.requestOptions.uri} ${error.message}');
    final response = error.response;
    if (response?.data != null) {
      debugPrint('[HTTP]    data: ${_redact(response?.data)}');
    }
  }

  dynamic _redact(dynamic data) {
    if (data is Map) {
      final result = <String, dynamic>{};
      data.forEach((key, value) {
        final normalized = key.toString().toLowerCase();
        if (normalized.contains('password') ||
            normalized.contains('pin') ||
            normalized.contains('token') ||
            normalized.contains('authorization') ||
            normalized.contains('otp')) {
          result[key.toString()] = '***';
        } else {
          result[key.toString()] = value;
        }
      });
      return result;
    }
    if (data is List) {
      return data.map(_redact).toList();
    }
    return data;
  }
}
