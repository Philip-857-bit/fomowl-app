import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Builds an [http.Client] that enforces SHA-256 certificate pinning on native
/// (mobile/desktop) platforms.
///
/// Each fingerprint is the hex-encoded SHA-256 of the DER-encoded server
/// certificate. If [sha256Fingerprints] is empty, pinning is disabled and a
/// plain [http.Client] is returned — so this is safe to call unconditionally.
http.Client createPinnedHttpClient(List<String> sha256Fingerprints) {
  final pins = sha256Fingerprints
      .map(
        (value) => value.replaceAll(':', '').replaceAll(' ', '').toLowerCase(),
      )
      .where((value) => value.isNotEmpty)
      .toSet();

  if (pins.isEmpty) {
    return http.Client();
  }

  final httpClient = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) {
      final fingerprint = sha256.convert(cert.der).toString().toLowerCase();
      return pins.contains(fingerprint);
    };

  return IOClient(httpClient);
}
