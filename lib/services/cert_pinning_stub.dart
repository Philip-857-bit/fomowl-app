import 'package:dio/dio.dart';

/// Web / non-IO fallback: certificate pinning is a no-op because the browser
/// manages TLS trust. Present so [Dio] callers can import unconditionally.
void configureCertPinning(
  Dio dio,
  List<String> sha256Fingerprints, {
  required String pinnedHost,
}) {}
