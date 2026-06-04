import '../discover/discover_url_utils.dart';

class MiniAppDefinition {
  const MiniAppDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.launchUrl,
    this.allowedOrigins = const <String>[],
    this.requiresWalletSession = false,
  });

  final String id;
  final String title;
  final String description;
  final String? launchUrl;
  final List<String> allowedOrigins;

  /// When true, the host proactively mints a wallet-auth (`ws_`) session token
  /// (signing silently with the wallet key) before injecting the bridge, so the
  /// mini app can call wallet-scoped backend endpoints (e.g. the affiliate
  /// dashboard) immediately. When false, only a cached token is surfaced — used
  /// by mini apps that handle their own auth (e.g. cash-in).
  final bool requiresWalletSession;

  Uri? get configuredLaunchUri {
    final raw = launchUrl?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !isSupportedDiscoverWebUri(uri)) {
      return null;
    }
    return uri;
  }

  bool get isConfigured => configuredLaunchUri != null;

  List<String> get trustedOrigins {
    final origins = <String>{};
    final launchUri = configuredLaunchUri;
    if (launchUri != null) {
      origins.add(normalizeOriginFromUri(launchUri));
    }
    for (final origin in allowedOrigins) {
      final normalized = normalizeDiscoverOrigin(origin);
      if (normalized != null && normalized.isNotEmpty) {
        origins.add(normalized);
      }
    }
    return origins.toList(growable: false);
  }

  Uri? buildLaunchUri({
    String launchSource = 'mobile',
    Map<String, String> extraQueryParameters = const <String, String>{},
    Uri? overrideUri,
  }) {
    final base = configuredLaunchUri;
    if (base == null) {
      return null;
    }
    // Honor a deep-link override (e.g. opened from the in-app browser address
    // bar) only when it stays within this mini app's trusted origins. This lets
    // a URL like `<origin>/dashboard?wallet=...` load directly while keeping the
    // host's origin guarantee intact. Anything off-origin falls back to base.
    var uri = base;
    if (overrideUri != null &&
        isSupportedDiscoverWebUri(overrideUri) &&
        trustedOrigins.contains(normalizeOriginFromUri(overrideUri))) {
      uri = overrideUri;
    }
    final merged = <String, String>{...uri.queryParameters};
    merged['owllet_host'] = 'mobile';
    merged['owllet_mini_app'] = id;
    merged['owllet_source'] = launchSource;
    merged.addAll(extraQueryParameters);
    return uri.replace(queryParameters: merged);
  }
}
