import 'dart:typed_data';

import 'package:hex/hex.dart';
import 'package:web3dart/crypto.dart' as web3_crypto;
import 'package:web3dart/web3dart.dart';

import 'native_crypto.dart';

/// A sender whose address has been checked against its key by the Rust core.
///
/// This is a temporary Dart signing context, not a Rust vault handle. Its key
/// stays private to this adapter library and must never be logged or persisted.
class EvmSigningAccount {
  EvmSigningAccount._(this.address, this._privateKeyHex);

  final EthereumAddress address;
  final String _privateKeyHex;

  @override
  String toString() =>
      'EvmSigningAccount(address: ${address.hex}, key: REDACTED)';
}

/// Flutter-side coordination for the shared Rust EVM signing engine.
///
/// Callers own ABI encoding, approved transaction fields, gas estimation,
/// client lifecycle, and UI permission checks. This adapter verifies the signer,
/// resolves the pending nonce when omitted, and broadcasts canonical Rust bytes.
class EvmTransactionService {
  static Future<EvmSigningAccount> verifyAccount({
    required EthereumAddress sender,
    required String privateKeyHex,
    String mismatchMessage = 'Active EVM address does not match private key',
  }) async {
    final derivedAddress = await NativeCrypto.deriveEvmAddressFromPrivateKey(
      privateKeyHex,
    );
    if (derivedAddress.toLowerCase() != sender.hex.toLowerCase()) {
      throw Exception(mismatchMessage);
    }
    return EvmSigningAccount._(sender, privateKeyHex);
  }

  static Future<String> broadcastLegacy({
    required Web3Client client,
    required EvmSigningAccount account,
    required int chainId,
    required EthereumAddress to,
    required BigInt valueWei,
    required BigInt gasPriceWei,
    required int gasLimit,
    Uint8List? data,
    int? nonce,
  }) async {
    if (chainId <= 0 ||
        (nonce != null && nonce < 0) ||
        gasLimit <= 0 ||
        gasPriceWei < BigInt.zero ||
        gasPriceWei.bitLength > 128 ||
        valueWei < BigInt.zero ||
        valueWei.bitLength > 256) {
      throw ArgumentError('Invalid legacy EVM transaction fields');
    }
    final resolvedNonce =
        nonce ??
        await client.getTransactionCount(
          account.address,
          atBlock: const BlockNum.pending(),
        );
    final rawHex = await NativeCrypto.signLegacyEvmTransaction(
      privateKeyHex: account._privateKeyHex,
      chainId: chainId,
      nonce: resolvedNonce,
      gasPriceWei: gasPriceWei,
      gasLimit: gasLimit,
      toAddress: to.hex,
      valueWei: valueWei,
      dataHex: data == null ? '' : '0x${HEX.encode(data)}',
    );
    return client.sendRawTransaction(web3_crypto.hexToBytes(rawHex));
  }
}
