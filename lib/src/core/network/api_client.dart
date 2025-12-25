import 'dart:async';

import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  ApiClient({required AppConfig config, required SecureStorage secureStorage})
      : _secureStorage = secureStorage {
    _dio = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl,
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
          return handler.next(options);
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
    return _dio.get<T>(path, queryParameters: query);
  }

  Future<Response<T>> post<T>(
    String path, {
    Map<String, dynamic>? query,
    Object? data,
    Options? options,
  }) async {
    return _dio.post<T>(path, data: data, queryParameters: query, options: options);
  }

  Future<Response<T>> patch<T>(
    String path, {
    Map<String, dynamic>? query,
    Object? data,
    Options? options,
  }) async {
    return _dio.patch<T>(path, data: data, queryParameters: query, options: options);
  }

  Future<Response<T>> put<T>(
    String path, {
    Map<String, dynamic>? query,
    Object? data,
    Options? options,
  }) async {
    return _dio.put<T>(path, data: data, queryParameters: query, options: options);
  }

  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? query,
    Object? data,
    Options? options,
  }) async {
    return _dio.delete<T>(path, data: data, queryParameters: query, options: options);
  }
}
