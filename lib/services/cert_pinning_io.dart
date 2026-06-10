import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'spki_pinning.dart';

/// Enforces SPKI (public-key) pinning on [dio] for native (mobile/desktop)
/// platforms.
///
/// Each fingerprint is the hex-encoded SHA-256 of the certificate's
/// DER-encoded SubjectPublicKeyInfo, so the pin survives certificate renewals
/// as long as the server keeps its key pair. Pinning is enforced only for
/// [pinnedHost]; other hosts get normal TLS validation. If
/// [sha256Fingerprints] is empty, pinning is disabled and TLS validation
/// proceeds normally — so this is safe to call unconditionally.
///
/// Note: the pin is checked on top of normal chain validation, not instead of
/// it — a certificate must be CA-valid AND match a pin.
void configureCertPinning(
  Dio dio,
  List<String> sha256Fingerprints, {
  required String pinnedHost,
}) {
  final pins = normalizePins(sha256Fingerprints);

  if (pins.isEmpty || pinnedHost.isEmpty) {
    return;
  }

  dio.httpClientAdapter = IOHttpClientAdapter(
    validateCertificate: (X509Certificate? certificate, String host, int port) {
      if (host != pinnedHost) {
        return true;
      }
      // A null certificate means the connection is not TLS; with pins
      // configured the backend must be reached over HTTPS.
      if (certificate == null) {
        return false;
      }
      return certMatchesSpkiPins(certificate.der, pins);
    },
  );
}
