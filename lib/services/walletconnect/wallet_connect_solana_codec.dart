import 'dart:convert';
import 'dart:typed_data';
import '../native_crypto.dart';
import 'wallet_connect_policy.dart';

/// WalletConnect result/error translation; chain wire rules live in Rust.
class WalletConnectSolanaCodec {
  const WalletConnectSolanaCodec._();

  static Map<String, String> signedTransactionResult({
    required String signatureBase58,
    required Uint8List signedTransaction,
  }) => {
    'signature': signatureBase58,
    'transaction': base64Encode(signedTransaction),
  };

  static Future<Uint8List> messageBytes(Uint8List transactionBytes) async {
    try {
      return await NativeCrypto.solanaTransactionMessageBytes(transactionBytes);
    } catch (_) {
      throw const WalletConnectPolicyException(
        -32602,
        'The Solana transaction is malformed.',
      );
    }
  }

  static Future<Uint8List> attachSignature({
    required Uint8List transactionBytes,
    required String signerAddress,
    required Uint8List signature,
  }) async {
    try {
      return await NativeCrypto.attachSolanaTransactionSignature(
        transaction: transactionBytes,
        signerAddress: signerAddress,
        signature: signature,
      );
    } catch (error) {
      final message = error.toString();
      if (message.contains('Invalid connected Solana account') ||
          message.contains('does not require the connected Solana account')) {
        throw const WalletConnectPolicyException(
          4100,
          'The transaction does not require a valid connected Solana account.',
        );
      }
      throw const WalletConnectPolicyException(
        -32602,
        'The Solana transaction or signature is malformed.',
      );
    }
  }
}
