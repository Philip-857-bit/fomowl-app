Uri? normalizeDiscoverUri(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) {
    return null;
  }
  return uri;
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
