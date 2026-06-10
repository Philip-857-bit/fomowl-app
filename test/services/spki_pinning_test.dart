import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/spki_pinning.dart';

// Self-signed P-256 test certificate; expected hash produced with:
// openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256
const _ecCertDerBase64 =
    'MIIBeTCCAR+gAwIBAgIUWkAhTGBj6Rk9jEIWJtd/20Hq1RQwCgYIKoZIzj0EAwIwEjEQMA4GA1UEAwwHdGVzdC1lYzAeFw0yNjA2MTAyMTAyMDFaFw0yNjA2MTEyMTAyMDFaMBIxEDAOBgNVBAMMB3Rlc3QtZWMwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAASkRLlOL3qFYRfR//dsm0JClaXgiyK8MfqqGTwA8X6GxftDAF2vlL+eNzTfJoXrrzg0lbEcapvWPh+FUzDE9KiOo1MwUTAdBgNVHQ4EFgQUOyvVpPgahl7gS2WOs3aOYEXU/5swHwYDVR0jBBgwFoAUOyvVpPgahl7gS2WOs3aOYEXU/5swDwYDVR0TAQH/BAUwAwEB/zAKBggqhkjOPQQDAgNIADBFAiEAgArxnH/2by+qu1XLZRjTJTKLQf1ET5GcltjeRsZIU08CIH8aMiTDicmdryfsJwUyJ0WvaFDVFpqkqpXUsfhTDp6y';
const _ecExpectedSpkiSha256 =
    '9985df85f8f90f4867ed4b8920c69897406c0d6afbdce2091d0c34ce557a354e';

// Self-signed RSA-2048 test certificate (exercises the longer multi-byte DER
// lengths an RSA SPKI produces).
const _rsaCertDerBase64 =
    'MIIDBzCCAe+gAwIBAgIUFbnh1qhum2jTrMWHzyoW8BTV9dUwDQYJKoZIhvcNAQELBQAwEzERMA8GA1UEAwwIdGVzdC1yc2EwHhcNMjYwNjEwMjEwMjAyWhcNMjYwNjExMjEwMjAyWjATMREwDwYDVQQDDAh0ZXN0LXJzYTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMYoLyl1wUxGuvKnnswnLePwXqen6ZU1axSUcnjscUyb97RnlwcsQzz37vj04JQt/MXTSXUhSbplRDWfdPNugUwKfhwgZyo6RORTiVZ2/luPZ3d7dJg4tljfBjDYWSO2oZtTcDTDbw5OnNZl16en9+x5tH+TX8zrvnRMp0+7dikbiBfBaq9i7LAe73H0/J9KpESQFT3O9C6uYJbqhGHLR2Tc1lC9Uhoy1oNeMEaBDdimzyd8HW+Vqb57ucpm1EESEjr8yOErZZPeF1WmrQ0zhs7FpAcNvPcsaiZWkVWQm5mqRk2TOGiiitYLxwN/wUjsH4BwJddg90yYmfhBVphI7k0CAwEAAaNTMFEwHQYDVR0OBBYEFGTDo/VaGg743QOAHrkpsA315qMYMB8GA1UdIwQYMBaAFGTDo/VaGg743QOAHrkpsA315qMYMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBAKoXGsLtPFuNTFR+I5c0xFDpuHSJtjO+tgpZ+9LjibWJssHR+p41o4CbUJi6PjV84HLfoqK30zsqpu/rs+JbiZnjahHKPC/+V9FfI1dL/bBTU0dgFgQyUon3SpoyvPYIEVPkrOhp6G0tO6WygAeTn25ssJ3n0abYvB8S9gzQmJ/6WpRAM3kDgN03Qa8ZAhcZxmtIH8i7uCUnliviYBc/axWjgPL/YE2r3a5874M24/G75XKxK4neTlYMM9Phf6BTvo0uUXiFeIVaafRR0rhnariCu+63pdbuI9i6qKzVKV2sn8LZ4XDnZYNqPouPDYc8cYHoF39OyzxS4sE2O6Lxx2o=';
const _rsaExpectedSpkiSha256 =
    '3701ce448d6d0dd9a0186aec0f09f447233672b24d475c405c624034cb3f00ac';

// Production leaf for core.owlletapp.com captured 2026-06-10 (Let's Encrypt
// E7). A CA-issued certificate exercises the [0] EXPLICIT version field and
// a realistic extension set.
const _owlletCertDerBase64 =
    'MIIDlzCCAxygAwIBAgISBkBV7jZp8ecRx0fQU5FxWSEmMAoGCCqGSM49BAMDMDIxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MQswCQYDVQQDEwJFNzAeFw0yNjA1MjYxNzAxMTVaFw0yNjA4MjQxNzAxMTRaMBgxFjAUBgNVBAMTDW93bGxldGFwcC5jb20wWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAARSeBZSAABs+AOGyo1O+annMrhRmaGi1VhycNFpciwgBbHx/vAwO3qNYKw1mGXmG34sp6kBj3m76T+Ey2/bp0bjo4ICKjCCAiYwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMBMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFF6Eh40Y39NEoApHkJr4iIe4aHzQMB8GA1UdIwQYMBaAFK5IntyHHUSgb9qi5WB0BHjCnACAMDIGCCsGAQUFBwEBBCYwJDAiBggrBgEFBQcwAoYWaHR0cDovL2U3LmkubGVuY3Iub3JnLzApBgNVHREEIjAggg8qLm93bGxldGFwcC5jb22CDW93bGxldGFwcC5jb20wEwYDVR0gBAwwCjAIBgZngQwBAgEwLQYDVR0fBCYwJDAioCCgHoYcaHR0cDovL2U3LmMubGVuY3Iub3JnLzM5LmNybDCCAQwGCisGAQQB1nkCBAIEgf0EgfoA+AB2ANgJVTuUT3r/yBYZb5RPhauw+Pxeh1UmDxXRLnK7RUsUAAABnmVxUAEAAAQDAEcwRQIgddEkuAPQgSvKIsd0zLmrd2SjHspLD7ifLFrYqlofVWACIQDEkUlA/55TGCRosAKlcJVvxtWyg0RFxz6sGDlo/IDKjwB+AGz+UBlDqF6pFrxS0TPk3Mke8UEcfSWEINFzgJ4YGOs6AAABnmVxUxkACAAABQANc5ZHBAMARzBFAiEA4CkYV96wUNyYUvsBZHO9RIIuDssI+o7PujbZPBH9CXMCIFp/V+mQSgXhG9B6EeYPrFgDg/ZNLoZc5Y/0US+Pv0L1MAoGCCqGSM49BAMDA2kAMGYCMQCOEfeXV5C83gaLaGpsjRUzEm5Kn+bXNcj0YrxIufoYg1mMNMi94snTmUMgaQIa+BYCMQCAWFOnau2qvC7lg2UHGeLQX14HWSTrXlFTVmjVKXCjys2h7XhxsATZ9rnfZIUchgc=';
const _owlletExpectedSpkiSha256 =
    '14571e9f33f1257b501363d377566cd4e321f06d21834b20275c65495b22b0f4';

Uint8List _der(String b64) => Uint8List.fromList(base64.decode(b64));

void main() {
  group('spkiSha256Hex', () {
    test('matches openssl for an EC certificate', () {
      expect(spkiSha256Hex(_der(_ecCertDerBase64)), _ecExpectedSpkiSha256);
    });

    test('matches openssl for an RSA certificate', () {
      expect(spkiSha256Hex(_der(_rsaCertDerBase64)), _rsaExpectedSpkiSha256);
    });

    test('matches openssl for a CA-issued production certificate', () {
      expect(
        spkiSha256Hex(_der(_owlletCertDerBase64)),
        _owlletExpectedSpkiSha256,
      );
    });

    test('differs from the whole-certificate hash', () {
      final certDer = _der(_owlletCertDerBase64);
      expect(spkiSha256Hex(certDer), isNot(sha256.convert(certDer).toString()));
    });

    test('throws FormatException on malformed input', () {
      expect(() => spkiSha256Hex(Uint8List(0)), throwsFormatException);
      expect(
        () => spkiSha256Hex(Uint8List.fromList([0x30, 0x82])),
        throwsFormatException,
      );
      // Truncated real certificate: header lengths point past the buffer.
      final truncated = Uint8List.sublistView(_der(_ecCertDerBase64), 0, 40);
      expect(() => spkiSha256Hex(truncated), throwsFormatException);
    });
  });

  group('certMatchesSpkiPins', () {
    test('accepts a cert whose SPKI is pinned', () {
      expect(
        certMatchesSpkiPins(_der(_ecCertDerBase64), {
          _ecExpectedSpkiSha256,
          _rsaExpectedSpkiSha256,
        }),
        isTrue,
      );
    });

    test('rejects a cert whose SPKI is not pinned', () {
      expect(
        certMatchesSpkiPins(_der(_ecCertDerBase64), {_rsaExpectedSpkiSha256}),
        isFalse,
      );
    });

    test('rejects rather than throws on malformed certificates', () {
      expect(
        certMatchesSpkiPins(Uint8List(0), {_ecExpectedSpkiSha256}),
        isFalse,
      );
    });
  });

  group('normalizePins', () {
    test('strips separators, lowercases, and drops empties', () {
      expect(normalizePins(['AA:BB:CC', ' dd ee ff ', '', '  ']), {
        'aabbcc',
        'ddeeff',
      });
    });
  });
}
