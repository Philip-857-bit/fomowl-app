import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Enforces certificate pinning on [dio] for native (mobile/desktop) platforms.
///
/// Each fingerprint is the hex-encoded SHA-256 of the DER-encoded server
/// certificate. If [sha256Fingerprints] is empty, pinning is disabled and TLS
/// validation proceeds normally — so this is safe to call unconditionally.
void configureCertPinning(Dio dio, List<String> sha256Fingerprints) {
  final pins = sha256Fingerprints
      .map(
        (value) => value.replaceAll(':', '').replaceAll(' ', '').toLowerCase(),
      )
      .where((value) => value.isNotEmpty)
      .toSet();

  if (pins.isEmpty) {
    return;
  }

  dio.httpClientAdapter = IOHttpClientAdapter(
    validateCertificate: (X509Certificate? certificate, String host, int port) {
      if (certificate == null) {
        return false;
      }
      final fingerprint = sha256
          .convert(certificate.der)
          .toString()
          .toLowerCase();
      return pins.contains(fingerprint);
    },
  );
}
