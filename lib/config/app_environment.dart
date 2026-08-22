import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

class AppEnvironment {
  AppEnvironment._();

  static const String _productionBackendBaseUrl = 'https://core.owlletapp.com';

  // ---------------------------------------------------------------------------
  // Compile-time dart-define values.
  //
  // `String.fromEnvironment` only reads a `--dart-define` value when it is
  // invoked as `const` with a *literal* key. Calling it with a variable key (or
  // in a non-const context) returns the empty default at runtime on AOT/release
  // builds. So every supported define MUST be declared here as a `const` literal
  // and read through these fields — never via `String.fromEnvironment(someVar)`.
  // ---------------------------------------------------------------------------
  static const String _backendBaseUrlEnv = String.fromEnvironment(
    'BACKEND_BASE_URL',
  );
  static const String _coinGeckoApiBaseUrlEnv = String.fromEnvironment(
    'COINGECKO_API_BASE_URL',
  );
  static const String _connectivityCheckUrlEnv = String.fromEnvironment(
    'CONNECTIVITY_CHECK_URL',
  );
  static const String _pushNotificationsEnabledEnv = String.fromEnvironment(
    'PUSH_NOTIFICATIONS_ENABLED',
  );
  static const String _firebaseApiKeyEnv = String.fromEnvironment(
    'FIREBASE_API_KEY',
  );
  static const String _firebaseAndroidAppIdEnv = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const String _firebaseIosAppIdEnv = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
  );
  static const String _firebaseMessagingSenderIdEnv = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String _firebaseProjectIdEnv = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const String _firebaseStorageBucketEnv = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const String _firebaseIosBundleIdEnv = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
  );
  static const String _cashInMiniAppUrlEnv = String.fromEnvironment(
    'CASH_IN_MINI_APP_URL',
  );
  static const String _cashInMiniAppAllowedOriginsEnv = String.fromEnvironment(
    'CASH_IN_MINI_APP_ALLOWED_ORIGINS',
  );
  static const String _affiliateMiniAppUrlEnv = String.fromEnvironment(
    'AFFILIATE_MINI_APP_URL',
  );
  static const String _affiliateMiniAppAllowedOriginsEnv =
      String.fromEnvironment('AFFILIATE_MINI_APP_ALLOWED_ORIGINS');
  static const String _backendCertSha256PinsEnv = String.fromEnvironment(
    'BACKEND_CERT_SHA256_PINS',
  );
  static const bool _backendCertPinningEnabledEnv = bool.fromEnvironment(
    'BACKEND_CERT_PINNING_ENABLED',
    defaultValue: false,
  );
  static const String _walletConnectProjectIdEnv = String.fromEnvironment(
    'WALLETCONNECT_PROJECT_ID',
  );

  static final String backendBaseUrl = _resolveBackendBaseUrl();
  static final String coinGeckoApiBaseUrl = _resolveConfiguredUrl(
    rawValue: _coinGeckoApiBaseUrlEnv,
    fallback: 'https://api.coingecko.com/api/v3',
  );
  static final String connectivityCheckUrl = _resolveConfiguredUrl(
    rawValue: _connectivityCheckUrlEnv,
    fallback: 'https://www.google.com',
  );
  static final bool pushNotificationsEnabled =
    _resolvePushNotificationsEnabled();
  static final FirebaseOptions? firebaseOptions =
    _resolveFirebaseOptionsForCurrentPlatform();
  static final String? cashInMiniAppUrl = _optionalEnv(_cashInMiniAppUrlEnv);
  static final List<String> cashInMiniAppAllowedOrigins = _csvEnv(
    _cashInMiniAppAllowedOriginsEnv,
  );
  static final String? affiliateMiniAppUrl = _optionalEnv(
    _affiliateMiniAppUrlEnv,
  );
  static final List<String> affiliateMiniAppAllowedOrigins = _csvEnv(
    _affiliateMiniAppAllowedOriginsEnv,
  );
  static final String walletConnectProjectId = _resolveWalletConnectProjectId();

  static String _resolveWalletConnectProjectId() {
    final raw = _walletConnectProjectIdEnv.trim();
    if (raw.isNotEmpty) {
      return raw;
    }
    // Default fallback project id for development / testing
    return 'affc1a08513be5b8ff6c03bfab91158b';
  }

  /// Optional SPKI (public-key) pinning for the backend host.
  ///
  /// Pinning is deliberately disabled by default. The production endpoint uses
  /// an automatically renewed certificate whose key can rotate, so enforcing a
  /// leaf-key pin would turn a valid certificate renewal into a total API
  /// outage. Normal platform certificate-chain and hostname validation remains
  /// enabled when pinning is disabled.
  ///
  /// Only enable this for an endpoint whose TLS keys and backup rotation key
  /// are controlled operationally. Each entry is
  /// the lowercase hex SHA-256 of the certificate's DER-encoded
  /// SubjectPublicKeyInfo — NOT of the whole certificate — so the pin survives
  /// certificate renewals as long as the server keeps its key pair. When empty
  /// (the default), no pinning is enforced and TLS behaves normally. Supply via
  /// `--dart-define=BACKEND_CERT_SHA256_PINS=<fp1>,<fp2>` (include a backup pin
  /// for key rotation). Generate with:
  /// `openssl s_client -connect host:443 -servername host </dev/null |
  ///  openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER |
  ///  openssl dgst -sha256`
  static final List<String> backendCertSha256Pins =
      resolveBackendCertificatePins(
        rawPins: _backendCertSha256PinsEnv,
        pinningEnabled: _backendCertPinningEnabledEnv,
      );

  /// Host component of [backendBaseUrl]; pinning is scoped to this host so
  /// third-party endpoints are unaffected.
  static final String backendHost = Uri.parse(backendBaseUrl).host;

  static Future<void> initializeFirebaseApp() async {
    if (Firebase.apps.isNotEmpty) {
      return;
    }
    final options = firebaseOptions;
    if (options != null) {
      await Firebase.initializeApp(options: options);
      return;
    }
    await Firebase.initializeApp();
  }

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

  static Uri discover(String path, [Map<String, String>? queryParameters]) {
    return api('/discover$path', queryParameters);
  }

  static Uri content(String path, [Map<String, String>? queryParameters]) {
    return api('/content$path', queryParameters);
  }

  static Uri history(String path, [Map<String, String>? queryParameters]) {
    return api('/history$path', queryParameters);
  }

  static Uri prices(String path, [Map<String, String>? queryParameters]) {
    return api('/prices$path', queryParameters);
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
      rawValue: _backendBaseUrlEnv,
      fallback: kReleaseMode
          ? _productionBackendBaseUrl
          : _defaultBackendBaseUrl(),
    );
    // In release builds the backend MUST be HTTPS — a plaintext URL (from a
    // mis-set --dart-define) would expose every "trust the backend" path
    // (transaction calldata, approvals) to a trivial MITM. Refuse to downgrade.
    if (kReleaseMode && configured.startsWith('http://')) {
      final upgraded = configured.replaceFirst('http://', 'https://');
      debugPrint(
        'AppEnvironment: refusing plaintext backend URL in release; '
        'upgraded to HTTPS.',
      );
      return upgraded;
    }
    if (kReleaseMode &&
        _backendCertPinningEnabledEnv &&
        backendCertSha256Pins.isEmpty) {
      debugPrint(
        'AppEnvironment: WARNING — backend certificate pinning was enabled '
        'without any pins; standard TLS validation will be used.',
      );
    }
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
    required String rawValue,
    required String fallback,
  }) {
    final normalized = rawValue.trim();
    if (normalized.isEmpty) {
      return _normalizeUrl(fallback);
    }
    return _normalizeUrl(normalized);
  }

  static String _normalizeUrl(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  static bool _resolvePushNotificationsEnabled() {
    final configured = _pushNotificationsEnabledEnv.trim();
    if (configured.isNotEmpty) {
      return configured.toLowerCase() == 'true';
    }
    return !kIsWeb &&
        (firebaseOptions != null ||
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  static FirebaseOptions? _resolveFirebaseOptionsForCurrentPlatform() {
    if (kIsWeb) {
      return null;
    }

    final appId = switch (defaultTargetPlatform) {
      TargetPlatform.android => _optionalEnv(_firebaseAndroidAppIdEnv),
      TargetPlatform.iOS => _optionalEnv(_firebaseIosAppIdEnv),
      _ => null,
    };
    if (appId == null) {
      return null;
    }

    final apiKey = _optionalEnv(_firebaseApiKeyEnv);
    final senderId = _optionalEnv(_firebaseMessagingSenderIdEnv);
    final projectId = _optionalEnv(_firebaseProjectIdEnv);
    if (apiKey == null || senderId == null || projectId == null) {
      return null;
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      storageBucket: _optionalEnv(_firebaseStorageBucketEnv),
      iosBundleId: defaultTargetPlatform == TargetPlatform.iOS
          ? _optionalEnv(_firebaseIosBundleIdEnv)
          : null,
    );
  }

  /// Trims a compile-time define value (already read via a `const`
  /// `String.fromEnvironment` literal) and returns null when empty.
  static String? _optionalEnv(String rawValue) {
    final value = rawValue.trim();
    return value.isEmpty ? null : value;
  }

  /// Splits a comma-separated compile-time define value into a trimmed list.
  static List<String> _csvEnv(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      return const <String>[];
    }
    return value
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }
}

@visibleForTesting
List<String> resolveBackendCertificatePins({
  required String rawPins,
  required bool pinningEnabled,
}) {
  if (!pinningEnabled) {
    return const <String>[];
  }
  return rawPins
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}
