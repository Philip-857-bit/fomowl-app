/// Helpers for SubjectPublicKeyInfo (SPKI) pinning.
///
/// Pins are the lowercase hex SHA-256 of the certificate's DER-encoded
/// SubjectPublicKeyInfo rather than of the whole certificate. The SPKI stays
/// stable across certificate renewals as long as the server reuses its key
/// pair, so routine renewals (e.g. Let's Encrypt every 90 days) do not
/// invalidate the pin.
///
/// Generate a pin with:
/// ```
/// openssl s_client -connect host:443 -servername host </dev/null \
///   | openssl x509 -pubkey -noout \
///   | openssl pkey -pubin -outform DER \
///   | openssl dgst -sha256
/// ```
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Normalizes raw pin strings (strips colons/whitespace, lowercases) and
/// drops empty entries.
Set<String> normalizePins(List<String> pins) {
  return pins
      .map(
        (value) => value.replaceAll(':', '').replaceAll(' ', '').toLowerCase(),
      )
      .where((value) => value.isNotEmpty)
      .toSet();
}

/// Whether the SPKI of [certDer] (a DER-encoded X.509 certificate) matches
/// one of [normalizedPins]. Returns false instead of throwing on malformed
/// certificates so a parse failure can never bypass pinning.
bool certMatchesSpkiPins(Uint8List certDer, Set<String> normalizedPins) {
  try {
    return normalizedPins.contains(spkiSha256Hex(certDer));
  } on FormatException {
    return false;
  }
}

/// Lowercase hex SHA-256 of the SubjectPublicKeyInfo extracted from
/// [certDer], a DER-encoded X.509 certificate.
String spkiSha256Hex(Uint8List certDer) {
  return sha256.convert(extractSpkiDer(certDer)).toString();
}

/// Extracts the DER-encoded SubjectPublicKeyInfo from a DER X.509
/// certificate. Throws [FormatException] on malformed input.
///
/// RFC 5280 structure walked here:
/// ```
/// Certificate ::= SEQUENCE {
///   tbsCertificate       TBSCertificate,
///   signatureAlgorithm   AlgorithmIdentifier,
///   signatureValue       BIT STRING }
/// TBSCertificate ::= SEQUENCE {
///   version         [0]  EXPLICIT Version DEFAULT v1,
///   serialNumber         CertificateSerialNumber,
///   signature            AlgorithmIdentifier,
///   issuer               Name,
///   validity             Validity,
///   subject              Name,
///   subjectPublicKeyInfo SubjectPublicKeyInfo,
///   ... }
/// ```
Uint8List extractSpkiDer(Uint8List certDer) {
  const sequenceTag = 0x30;
  const contextZeroTag = 0xa0;

  final certificate = _DerCursor(certDer);
  final tbsCertificate = certificate.enterElement(expectedTag: sequenceTag);
  final tbsFields = tbsCertificate.enterElement(expectedTag: sequenceTag);

  if (tbsFields.peekTag() == contextZeroTag) {
    tbsFields.skipElement(); // version
  }
  tbsFields.skipElement(); // serialNumber
  tbsFields.skipElement(); // signature AlgorithmIdentifier
  tbsFields.skipElement(); // issuer
  tbsFields.skipElement(); // validity
  tbsFields.skipElement(); // subject

  if (tbsFields.peekTag() != sequenceTag) {
    throw const FormatException(
      'Expected SubjectPublicKeyInfo SEQUENCE in TBSCertificate',
    );
  }
  return tbsFields.readElement(); // subjectPublicKeyInfo (full TLV)
}

/// Minimal DER (TLV) reader over a byte range. Only supports what X.509
/// certificate traversal needs: single-byte tags and definite lengths.
class _DerCursor {
  _DerCursor(this._bytes) : _offset = 0, _end = _bytes.length;

  _DerCursor._(this._bytes, this._offset, this._end);

  final Uint8List _bytes;
  int _offset;
  final int _end;

  int peekTag() {
    if (_offset >= _end) {
      throw const FormatException('Unexpected end of DER data');
    }
    return _bytes[_offset];
  }

  /// Reads the header at the cursor, returning the content range and the
  /// offset just past the element.
  ({int contentStart, int contentEnd}) _readHeader() {
    if (_offset + 2 > _end) {
      throw const FormatException('Truncated DER header');
    }
    var cursor = _offset + 1; // skip tag
    var length = _bytes[cursor++];
    if (length & 0x80 != 0) {
      final lengthBytes = length & 0x7f;
      if (lengthBytes == 0 || lengthBytes > 4) {
        throw const FormatException('Unsupported DER length encoding');
      }
      if (cursor + lengthBytes > _end) {
        throw const FormatException('Truncated DER length');
      }
      length = 0;
      for (var i = 0; i < lengthBytes; i++) {
        length = (length << 8) | _bytes[cursor++];
      }
    }
    final contentEnd = cursor + length;
    if (contentEnd > _end) {
      throw const FormatException('DER element exceeds enclosing element');
    }
    return (contentStart: cursor, contentEnd: contentEnd);
  }

  /// Returns a cursor over the content of the element at the cursor and
  /// advances past it. Verifies the tag when [expectedTag] is given.
  _DerCursor enterElement({int? expectedTag}) {
    if (expectedTag != null && peekTag() != expectedTag) {
      throw FormatException(
        'Expected DER tag 0x${expectedTag.toRadixString(16)}, '
        'found 0x${peekTag().toRadixString(16)}',
      );
    }
    final header = _readHeader();
    final content = _DerCursor._(
      _bytes,
      header.contentStart,
      header.contentEnd,
    );
    _offset = header.contentEnd;
    return content;
  }

  /// Advances past the element at the cursor.
  void skipElement() {
    _offset = _readHeader().contentEnd;
  }

  /// Returns the full TLV bytes of the element at the cursor and advances
  /// past it.
  Uint8List readElement() {
    final start = _offset;
    final end = _readHeader().contentEnd;
    _offset = end;
    return Uint8List.sublistView(_bytes, start, end);
  }
}
