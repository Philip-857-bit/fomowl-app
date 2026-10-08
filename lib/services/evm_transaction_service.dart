import 'dart:typed_data';

import 'package:hex/hex.dart';
import 'package:web3dart/crypto.dart' as web3_crypto;
import 'package:web3dart/web3dart.dart';

import 'native_crypto.dart';
import '../src/rust/api/evm_signing_account.dart' as rust_account;

/// A sender whose address has been checked against its key by the Rust core.
///
/// Dart holds only a Rust opaque reference and public address. Legacy key
/// loading still passes through Dart at import; encrypted vault migration is later.
class EvmSigningAccount {
  EvmSigningAccount._(this.address, this._rustSigner);

  final EthereumAddress address;
  final rust_account.RustEvmSigningAccount _rustSigner;
  Future<void>? _closing;

  bool get isClosed => _closing != null || _rustSigner.isDisposed;

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    if (_rustSigner.isDisposed) return;
    try {
      await _rustSigner.close();
    } finally {
      _rustSigner.dispose();
    }
  }

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
    try {
      final signer = await NativeCrypto.createEvmSigningAccount(
        privateKeyHex: privateKeyHex,
        expectedAddress: sender.hex,
      );
      return EvmSigningAccount._(sender, signer);
    } catch (error) {
      if (error.toString().contains(
        'Active EVM address does not match private key',
      )) {
        throw Exception(mismatchMessage);
      }
      rethrow;
    }
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
    if (account.isClosed) {
      throw StateError('EVM signing account is closed');
    }
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
    if (account.isClosed) {
      throw StateError('EVM signing account is closed');
    }
    final rawHex = await account._rustSigner.signTransaction(
      chainId: BigInt.from(chainId),
      nonce: BigInt.from(resolvedNonce),
      gasLimit: BigInt.from(gasLimit),
      toAddress: to?.hex,
      valueWei: valueWei.toString(),
      dataHex: data == null ? '' : '0x${HEX.encode(data)}',
      gasPriceWei: gasPriceWei?.toString(),
      maxFeePerGasWei: maxFeePerGasWei?.toString(),
      maxPriorityFeePerGasWei: maxPriorityFeePerGasWei?.toString(),
    );
    return client.sendRawTransaction(web3_crypto.hexToBytes(rawHex));
  }
}
