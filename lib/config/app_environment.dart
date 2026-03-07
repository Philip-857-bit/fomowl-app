import 'package:flutter/foundation.dart';

class AppEnvironment {
  AppEnvironment._();

  static final String backendBaseUrl = _resolveBackendBaseUrl();
  static final String coinGeckoApiBaseUrl = _resolveConfiguredUrl(
    key: 'COINGECKO_API_BASE_URL',
    fallback: 'https://api.coingecko.com/api/v3',
  );
  static final String connectivityCheckUrl = _resolveConfiguredUrl(
    key: 'CONNECTIVITY_CHECK_URL',
    fallback: 'https://www.google.com',
  );

  static Uri api(String path, [Map<String, String>? queryParameters]) {
    return _buildUri('/api$path', queryParameters);
  }

  static Uri swap(String path, [Map<String, String>? queryParameters]) {
    return api('/swap$path', queryParameters);
  }

  static Uri blockchain(String path, [Map<String, String>? queryParameters]) {
    return api('/blockchain$path', queryParameters);
  }

  static Uri settings(String path, [Map<String, String>? queryParameters]) {
    return api('/settings$path', queryParameters);
  }

  static Uri referrals(String path, [Map<String, String>? queryParameters]) {
    return api('/referrals$path', queryParameters);
  }

  static Uri feedback(String path, [Map<String, String>? queryParameters]) {
    return api('/feedback$path', queryParameters);
  }

  static Uri history(String path, [Map<String, String>? queryParameters]) {
    return api('/history$path', queryParameters);
  }

  static Uri notifications(
    String path, [
    Map<String, String>? queryParameters,
  ]) {
    return api('/notifications$path', queryParameters);
  }

  static Uri language(String path, [Map<String, String>? queryParameters]) {
    return api('/language$path', queryParameters);
  }

  static Uri profile(String path, [Map<String, String>? queryParameters]) {
    return api('/profile$path', queryParameters);
  }

  static Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    final base = Uri.parse(backendBaseUrl);
    final normalizedBasePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return base.replace(
      path: '$normalizedBasePath$normalizedPath',
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    );
  }

  static String _resolveBackendBaseUrl() {
    final configured = _resolveConfiguredUrl(
      key: 'https://fomowl-backend.onrender.com',
      fallback: _defaultBackendBaseUrl(),
    );
    return configured;
  }

  static String _defaultBackendBaseUrl() {
    if (kIsWeb) {
      return 'http://127.0.0.1:3000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 'http://127.0.0.1:3000';
      case TargetPlatform.fuchsia:
        return 'http://127.0.0.1:3000';
    }
  }

  static String _resolveConfiguredUrl({
    required String key,
    required String fallback,
  }) {
    final configured = String.fromEnvironment(key);
    final normalized = configured.trim();
    if (normalized.isEmpty) {
      return _normalizeUrl(fallback);
    }
    return _normalizeUrl(normalized);
  }

  static String _normalizeUrl(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
