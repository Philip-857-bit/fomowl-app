import 'package:http/http.dart' as http;

/// Web / non-IO fallback: certificate pinning is a no-op because the browser
/// manages TLS trust. Present so callers can import unconditionally.
http.Client createPinnedHttpClient(List<String> sha256Fingerprints) {
  return http.Client();
}
