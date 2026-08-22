import 'dart:convert';
import 'dart:typed_data';

import '../wallet_service.dart';
import 'wallet_connect_policy.dart';

class WalletConnectSolanaCodec {
  const WalletConnectSolanaCodec._();

  static Map<String, String> signedTransactionResult({
    required String signatureBase58,
    required Uint8List signedTransaction,
  }) => <String, String>{
    'signature': signatureBase58,
    'transaction': base64Encode(signedTransaction),
  };

  static Uint8List messageBytes(Uint8List transactionBytes) {
    final signatureHeader = _readShortVec(transactionBytes, 0);
    final messageOffset =
        signatureHeader.nextOffset + signatureHeader.value * 64;
    if (signatureHeader.value < 1 || messageOffset >= transactionBytes.length) {
      throw const WalletConnectPolicyException(
        -32602,
        'The Solana transaction is malformed.',
      );
    }
    return Uint8List.fromList(transactionBytes.sublist(messageOffset));
  }

  static Uint8List attachSignature({
    required Uint8List transactionBytes,
    required String signerAddress,
    required Uint8List signature,
  }) {
    if (signature.length != 64) {
      throw const WalletConnectPolicyException(
        -32602,
        'The Solana signature is malformed.',
      );
    }

    final signatureHeader = _readShortVec(transactionBytes, 0);
    final messageOffset =
        signatureHeader.nextOffset + signatureHeader.value * 64;
    if (signatureHeader.value < 1 || messageOffset >= transactionBytes.length) {
      throw const WalletConnectPolicyException(
        -32602,
        'The Solana transaction is malformed.',
      );
    }

    final message = Uint8List.sublistView(transactionBytes, messageOffset);
    final versioned = message.first & 0x80 != 0;
    final headerOffset = versioned ? 1 : 0;
    if (message.length < headerOffset + 4) {
      throw const WalletConnectPolicyException(
        -32602,
        'The Solana transaction message is malformed.',
      );
    }
    final requiredSignatures = message[headerOffset];
    final keyCountHeader = _readShortVec(message, headerOffset + 3);
    final keysOffset = keyCountHeader.nextOffset;
    final keysEnd = keysOffset + keyCountHeader.value * 32;
    if (requiredSignatures < 1 ||
        requiredSignatures > signatureHeader.value ||
        requiredSignatures > keyCountHeader.value ||
        keysEnd > message.length) {
      throw const WalletConnectPolicyException(
        -32602,
        'The Solana transaction signer metadata is invalid.',
      );
    }

    final signerKey = WalletService.decodeBase58Bytes(signerAddress);
    if (signerKey.length != 32) {
      throw const WalletConnectPolicyException(
        4100,
        'The connected Solana account is invalid.',
      );
    }

    var signerIndex = -1;
    for (var index = 0; index < requiredSignatures; index++) {
      final start = keysOffset + index * 32;
      if (_bytesEqual(message, start, signerKey)) {
        signerIndex = index;
        break;
      }
    }
    if (signerIndex < 0) {
      throw const WalletConnectPolicyException(
        4100,
        'The transaction does not require the connected Solana account.',
      );
    }

    final result = Uint8List.fromList(transactionBytes);
    final signatureOffset = signatureHeader.nextOffset + signerIndex * 64;
    result.setRange(signatureOffset, signatureOffset + 64, signature);
    return result;
  }

  static _ShortVec _readShortVec(Uint8List bytes, int offset) {
    var value = 0;
    var shift = 0;
    var cursor = offset;
    while (cursor < bytes.length && shift <= 21) {
      final byte = bytes[cursor++];
      value |= (byte & 0x7f) << shift;
      if (byte & 0x80 == 0) return _ShortVec(value, cursor);
      shift += 7;
    }
    throw const WalletConnectPolicyException(
      -32602,
      'The Solana transaction length is malformed.',
    );
  }

  static bool _bytesEqual(Uint8List source, int offset, Uint8List expected) {
    if (offset + expected.length > source.length) return false;
    for (var index = 0; index < expected.length; index++) {
      if (source[offset + index] != expected[index]) return false;
    }
    return true;
  }
}

class _ShortVec {
  const _ShortVec(this.value, this.nextOffset);

  final int value;
  final int nextOffset;
}
