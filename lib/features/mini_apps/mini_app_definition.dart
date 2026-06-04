import '../discover/discover_url_utils.dart';

class MiniAppDefinition {
  const MiniAppDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.launchUrl,
    this.allowedOrigins = const <String>[],
  });

  final String id;
  final String title;
  final String description;
  final String? launchUrl;
  final List<String> allowedOrigins;

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
