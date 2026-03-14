import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Centralized HTTP Client Service
/// Manages a persistent http.Client for connection pooling and provides retry logic.
class HttpClientService {
  static final HttpClientService _instance = HttpClientService._internal();
  factory HttpClientService() => _instance;

  late final http.Client _client;
  http.Client get client => _client;

  HttpClientService._internal() {
    _client = http.Client();
  }

  @visibleForTesting
  HttpClientService.internal();

  /// Sends a request with a simple retry strategy.
  Future<http.Response> sendWithRetry(
    Future<http.Response> Function() request, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
    bool Function(http.Response)? retryIf,
  }) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        final response = await request();
        if (attempts < maxRetries &&
            (retryIf?.call(response) ??
                _isRetryableStatus(response.statusCode))) {
          await Future.delayed(delay * attempts);
          continue;
        }
        return response;
      } catch (e) {
        if (attempts >= maxRetries || !_isRetryableException(e)) {
          rethrow;
        }
        await Future.delayed(delay * attempts);
      }
    }
  }

  bool _isRetryableStatus(int statusCode) {
    // Retry on 5xx server errors or 429 rate limits
    return (statusCode >= 500 && statusCode <= 599) || statusCode == 429;
  }

  bool _isRetryableException(Object e) {
    return e is http.ClientException || e is TimeoutException;
  }

  /// Close the client (usually called only on app shutdown if necessary)
  void dispose() {
    _client.close();
  }
}
