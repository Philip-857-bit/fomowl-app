import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/app_environment.dart';
import 'pinned_http_client_stub.dart'
    if (dart.library.io) 'pinned_http_client_io.dart';

/// Centralized HTTP Client Service
/// Manages a persistent http.Client for connection pooling and provides retry logic.
class HttpClientService {
  static final HttpClientService _instance = HttpClientService._internal();
  factory HttpClientService() => _instance;

  // Cap per-attempt backoff so a long-running retry chain can't wait tens of
  // seconds between attempts on slow networks, and add a small random jitter
  // to avoid synchronized thundering-herd retries across clients.
  static const Duration _maxRetryDelay = Duration(seconds: 30);
  static final Random _jitterRng = Random();

  late final http.Client _client;
  http.Client get client => _client;

  HttpClientService._internal() {
    // Enforce SPKI pinning only when it has been explicitly enabled for an
    // endpoint with operationally controlled TLS keys. Production otherwise
    // uses the platform trust store and hostname validation, allowing normal
    // certificate/key rotation without taking every backend request offline.
    // Other hosts reached through this shared client (RPC nodes, CoinGecko,
    // swap aggregators, ...) keep normal TLS validation.
    _client = createPinnedHttpClient(
      AppEnvironment.backendCertSha256Pins,
      pinnedHost: AppEnvironment.backendHost,
    );
  }

  @visibleForTesting
  HttpClientService.internal();

  /// Sends a request with a simple retry strategy.
  ///
  /// Set [retryOnException] to false for non-idempotent POSTs (e.g. creating or
  /// cancelling an order): a request that reached the server and succeeded but
  /// whose response timed out must NOT be retried, or it would be applied twice.
  Future<http.Response> sendWithRetry(
    Future<http.Response> Function() request, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
    bool Function(http.Response)? retryIf,
    bool retryOnException = true,
  }) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        final response = await request();
        if (attempts < maxRetries &&
            (retryIf?.call(response) ??
                _isRetryableStatus(response.statusCode))) {
          await Future.delayed(_backoff(delay, attempts));
          continue;
        }
        return response;
      } catch (e) {
        if (!retryOnException ||
            attempts >= maxRetries ||
            !_isRetryableException(e)) {
          rethrow;
        }
        await Future.delayed(_backoff(delay, attempts));
      }
    }
  }

  static Duration _backoff(Duration base, int attempt) {
    final scaledMs = base.inMilliseconds * attempt;
    final cappedMs = scaledMs.clamp(0, _maxRetryDelay.inMilliseconds);
    // Up to +25% jitter on top of the capped delay.
    final jitterMs = (cappedMs * 0.25 * _jitterRng.nextDouble()).round();
    return Duration(milliseconds: cappedMs + jitterMs);
  }

  bool _isRetryableStatus(int statusCode) {
    // Retry transient server errors. 429 means the provider quota is exhausted:
    // retrying multiplies the pressure and delays the caller, so surface it and
    // let the caller decide when to come back.
    return statusCode >= 500 && statusCode <= 599;
  }

  bool _isRetryableException(Object e) {
    return e is http.ClientException || e is TimeoutException;
  }

  /// Close the client (usually called only on app shutdown if necessary)
  void dispose() {
    _client.close();
  }
}
