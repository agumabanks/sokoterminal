import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  ApiClient({required AppConfig config, required SecureStorage secureStorage})
      : _secureStorage = secureStorage {
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
        onError: (error, handler) {
          _logError(error);
          return handler.next(error);
        },
      ),
    );

    if (config.logLevel != 'none') {
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
    debugPrint('[HTTP] <- ${response.statusCode} ${response.requestOptions.uri}');
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
