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
  }) => broadcastTransaction(
    client: client,
    account: account,
    chainId: chainId,
    to: to,
    valueWei: valueWei,
    gasPriceWei: gasPriceWei,
    gasLimit: gasLimit,
    data: data,
    nonce: nonce,
  );

  static Future<String> broadcastTransaction({
    required Web3Client client,
    required EvmSigningAccount account,
    required int chainId,
    EthereumAddress? to,
    required BigInt valueWei,
    required int gasLimit,
    Uint8List? data,
    int? nonce,
    BigInt? gasPriceWei,
    BigInt? maxFeePerGasWei,
    BigInt? maxPriorityFeePerGasWei,
  }) async {
    final typed = maxFeePerGasWei != null || maxPriorityFeePerGasWei != null;
    final fees = [gasPriceWei, maxFeePerGasWei, maxPriorityFeePerGasWei];
    if (chainId <= 0 ||
        (nonce != null && nonce < 0) ||
        gasLimit <= 0 ||
        valueWei < BigInt.zero ||
        valueWei.bitLength > 256 ||
        fees.any(
          (fee) => fee != null && (fee < BigInt.zero || fee.bitLength > 128),
        ) ||
        (typed
            ? gasPriceWei != null ||
                  maxFeePerGasWei == null ||
                  maxPriorityFeePerGasWei == null
            : gasPriceWei == null)) {
      throw ArgumentError('Invalid EVM transaction fields or fee policy');
    }
    if (typed && maxPriorityFeePerGasWei! > maxFeePerGasWei!) {
      throw ArgumentError('Priority fee exceeds maximum fee per gas');
    }
    final resolvedNonce =
        nonce ??
        await client.getTransactionCount(
          account.address,
          atBlock: const BlockNum.pending(),
        );
    final rawHex = await NativeCrypto.signEvmTransaction(
      privateKeyHex: account._privateKeyHex,
      chainId: chainId,
      nonce: resolvedNonce,
      gasLimit: gasLimit,
      toAddress: to?.hex,
      valueWei: valueWei,
      dataHex: data == null ? '' : '0x${HEX.encode(data)}',
      gasPriceWei: gasPriceWei,
      maxFeePerGasWei: maxFeePerGasWei,
      maxPriorityFeePerGasWei: maxPriorityFeePerGasWei,
    );
    return client.sendRawTransaction(web3_crypto.hexToBytes(rawHex));
  }
}
