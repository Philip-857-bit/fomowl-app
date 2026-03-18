import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import '../config/app_environment.dart';
import 'dart:io';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late final Dio dio;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: AppEnvironment.backendBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add smart retry logic
    dio.interceptors.add(RetryInterceptor(
      dio: dio,
      logPrint: print, // Use a better logger in production
      retries: 3,
      retryDelays: const [
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 5),
      ],
      retryableExtraStatuses: {429}, // Explicitly retry on rate limits
    ));

    // Add logging and error handling interceptors
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // You can add auth tokens here in the future
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        if (e.error is HandshakeException || e.type == DioExceptionType.connectionError) {
           // Log specifically for handshake issues to track frequency
           debugPrint('Network Handshake/Connection Error: ${e.message}');
        }
        return handler.next(e);
      },
    ));
  }

  // Helper methods for different request types
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    return await dio.get(path, queryParameters: queryParameters, options: options);
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    return await dio.post(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    return await dio.put(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    return await dio.delete(path, data: data, queryParameters: queryParameters, options: options);
  }
}
