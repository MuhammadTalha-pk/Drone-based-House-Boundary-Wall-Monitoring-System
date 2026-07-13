// lib/core/network/dio_client.dart
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../errors/api_exception.dart';
import '../services/secure_storage_service.dart';

class DioClient {
  late final Dio _dio;
  // ✅ FIXED: made optional with default so AppProviders can call DioClient()
  final SecureStorageService secureStorage;

  DioClient({SecureStorageService? secureStorage})
      : secureStorage = secureStorage ?? SecureStorageService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectionTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await this.secureStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> put(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  ApiException _handleError(DioException e) {
    String message = 'Something went wrong';
    int? statusCode = e.response?.statusCode;

    if (e.response?.data != null && e.response?.data is Map) {
      message = e.response?.data['detail'] ?? message;
    } else if (e.type == DioExceptionType.connectionTimeout) {
      message = 'Connection timeout. Please check your internet.';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      message = 'Server took too long to respond.';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'Cannot connect to server. Please check your connection.';
    }

    return ApiException(
      message: message,
      statusCode: statusCode,
      data: e.response?.data,
    );
  }
}