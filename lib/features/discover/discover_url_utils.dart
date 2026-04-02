enum DiscoverInputType { url, webSearch }

class DiscoverNavigationTarget {
  const DiscoverNavigationTarget({
    required this.type,
    required this.uri,
    required this.displayQuery,
  });

  final DiscoverInputType type;
  final Uri uri;
  final String displayQuery;
}

Uri? normalizeDiscoverUri(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty || _looksLikeUnsupportedScheme(trimmed)) {
    return null;
  }

  final withScheme = trimmed.contains('://')
      ? trimmed
      : _shouldDefaultToHttp(trimmed)
      ? 'http://$trimmed'
      : 'https://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) {
    return null;
  }
  return uri;
}

DiscoverNavigationTarget? resolveDiscoverInput(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  if (_looksLikeUnsupportedScheme(trimmed)) {
    return null;
  }

  if (_looksLikeDiscoverUrl(trimmed)) {
    final uri = normalizeDiscoverUri(trimmed);
    if (uri != null && isSupportedDiscoverWebUri(uri)) {
      return DiscoverNavigationTarget(
        type: DiscoverInputType.url,
        uri: uri,
        displayQuery: trimmed,
      );
    }
    return null;
  }

  return DiscoverNavigationTarget(
    type: DiscoverInputType.webSearch,
    uri: buildDiscoverSearchUri(trimmed),
    displayQuery: trimmed,
  );
}

Uri buildDiscoverSearchUri(String query) {
  return Uri.https('duckduckgo.com', '/', {'q': query.trim()});
}

String? normalizeDiscoverOrigin(String value) {
  final uri = normalizeDiscoverUri(value);
  if (uri == null) {
    return null;
  }
  return normalizeOriginFromUri(uri);
}

String normalizeOriginFromUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  final portSegment =
      uri.hasPort &&
          !((scheme == 'https' && uri.port == 443) ||
              (scheme == 'http' && uri.port == 80))
      ? ':${uri.port}'
      : '';
  return '$scheme://$host$portSegment';
}

bool isSupportedDiscoverWebUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'https') {
    return uri.host.isNotEmpty;
  }
  if (scheme == 'http') {
    return uri.host.isNotEmpty;
  }
  return uri.toString() == 'about:blank';
}

bool isDiscoverInjectableUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'https') {
    return true;
  }
  if (scheme == 'http' && isLocalDiscoverHost(uri.host)) {
    return true;
  }
  return false;
}

bool isLocalDiscoverHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '10.0.2.2' ||
      normalized == '10.0.3.2';
}

bool _looksLikeDiscoverUrl(String input) {
  if (input.contains(RegExp(r'\s'))) {
    return false;
  }
  if (input.contains('://')) {
    final uri = Uri.tryParse(input);
    return uri != null && uri.scheme.isNotEmpty;
  }

  final normalized = input.toLowerCase();
  return normalized.startsWith('localhost') ||
      normalized.startsWith('127.0.0.1') ||
      normalized.startsWith('10.0.2.2') ||
      normalized.startsWith('10.0.3.2') ||
      normalized.contains('.') ||
      normalized.contains(':');
}

bool _shouldDefaultToHttp(String input) {
  final normalized = input.toLowerCase();
  return normalized.startsWith('localhost') ||
      normalized.startsWith('127.0.0.1') ||
      normalized.startsWith('10.0.2.2') ||
      normalized.startsWith('10.0.3.2');
}

bool _looksLikeUnsupportedScheme(String input) {
  if (input.contains('://')) {
    return false;
  }
  if (_shouldDefaultToHttp(input)) {
    return false;
  }
  return RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(input);
}
