import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

class AppEnvironment {
  AppEnvironment._();

  static const String _productionBackendBaseUrl =
      'https://fomowl-backend.onrender.com';

  static final String backendBaseUrl = _resolveBackendBaseUrl();
  static final String coinGeckoApiBaseUrl = _resolveConfiguredUrl(
    key: 'COINGECKO_API_BASE_URL',
    fallback: 'https://api.coingecko.com/api/v3',
  );
  static final String connectivityCheckUrl = _resolveConfiguredUrl(
    key: 'CONNECTIVITY_CHECK_URL',
    fallback: 'https://www.google.com',
  );
  static final bool pushNotificationsEnabled =
      _resolvePushNotificationsEnabled();
  static final FirebaseOptions? firebaseOptions =
      _resolveFirebaseOptionsForCurrentPlatform();

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
      key: 'BACKEND_BASE_URL',
      fallback: kReleaseMode
          ? _productionBackendBaseUrl
          : _defaultBackendBaseUrl(),
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

  static bool _resolvePushNotificationsEnabled() {
    final configured = const String.fromEnvironment(
      'PUSH_NOTIFICATIONS_ENABLED',
    ).trim();
    if (configured.isNotEmpty) {
      return configured.toLowerCase() == 'true';
    }
    return firebaseOptions != null;
  }

  static FirebaseOptions? _resolveFirebaseOptionsForCurrentPlatform() {
    if (kIsWeb) {
      return null;
    }

    final platformPrefix = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'ANDROID',
      TargetPlatform.iOS => 'IOS',
      _ => '',
    };
    if (platformPrefix.isEmpty) {
      return null;
    }

    final apiKey = _optionalEnv('FIREBASE_API_KEY');
    final appId = _optionalEnv('FIREBASE_${platformPrefix}_APP_ID');
    final senderId = _optionalEnv('FIREBASE_MESSAGING_SENDER_ID');
    final projectId = _optionalEnv('FIREBASE_PROJECT_ID');
    if (apiKey == null ||
        appId == null ||
        senderId == null ||
        projectId == null) {
      return null;
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      storageBucket: _optionalEnv('FIREBASE_STORAGE_BUCKET'),
      iosBundleId: defaultTargetPlatform == TargetPlatform.iOS
          ? _optionalEnv('FIREBASE_IOS_BUNDLE_ID')
          : null,
    );
  }

  static String? _optionalEnv(String key) {
    final value = String.fromEnvironment(key).trim();
    return value.isEmpty ? null : value;
  }
}
