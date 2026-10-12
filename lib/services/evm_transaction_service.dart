import 'dart:typed_data';

import 'package:hex/hex.dart';
import 'package:web3dart/crypto.dart' as web3_crypto;
import 'package:web3dart/web3dart.dart';

import '../src/rust/api/wallet_vault.dart' as rust_account;
import 'wallet_vault_service.dart';

/// A sender whose address has been checked against its key by the Rust core.
///
/// Dart holds only a Rust opaque reference and public address. Vault opening
/// authenticates the protected record before signing.
class EvmSigningAccount {
  EvmSigningAccount._(this.address, this._rustSigner);

  final EthereumAddress address;
  final rust_account.RustWalletSigningAccount _rustSigner;
  Future<void>? _closing;

  bool get isClosed =>
      _closing != null || !WalletVaultService.isOpen(_rustSigner);

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    if (_rustSigner.isDisposed) return;
    await WalletVaultService.close(_rustSigner);
  }

  Future<String> signPersonalMessage(String message) {
    if (isClosed) throw StateError('EVM signing account is closed');
    return _rustSigner.signPersonalMessage(message: message);
  }

  Future<String> signTypedData(String jsonData) {
    if (isClosed) throw StateError('EVM signing account is closed');
    return _rustSigner.signTypedData(jsonData: jsonData);
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
  static Future<EvmSigningAccount> fromVault({
    required EthereumAddress sender,
    required rust_account.RustWalletSigningAccount signer,
  }) async {
    try {
      if (EthereumAddress.fromHex(await signer.address()) != sender) {
        throw StateError('Vault account address mismatch');
      }
      return EvmSigningAccount._(sender, signer);
    } catch (_) {
      await WalletVaultService.close(signer);
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
    void Function()? validateBeforeSigning,
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
    validateBeforeSigning?.call();
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
    if (account.isClosed) {
      throw StateError('EVM signing account is closed');
    }
    return client.sendRawTransaction(web3_crypto.hexToBytes(rawHex));
  }
}
