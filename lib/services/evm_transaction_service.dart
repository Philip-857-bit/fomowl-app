import 'dart:typed_data';

import 'package:hex/hex.dart';
import 'package:web3dart/crypto.dart' as web3_crypto;
import 'package:web3dart/web3dart.dart';

import '../src/rust/api/wallet_vault.dart' as rust_account;
import 'wallet_vault_service.dart';
import '../models/evm_outbound_transaction.dart';

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
class EvmSignedTransaction {
  final EvmTransactionFields fields;
  final String hash;
  EvmSignedTransaction._(this.fields, this.hash);
}

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
    Future<void> Function(EvmSignedTransaction transaction)? beforeBroadcast,
    Future<void> Function()? abortedBeforeBroadcast,
    Duration? broadcastTimeout,
    void Function()? beforeProviderSend,
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
    Future<int> pendingNonce() {
      final request = client.getTransactionCount(
        account.address,
        atBlock: const BlockNum.pending(),
      );
      return beforeBroadcast == null
          ? request
          : request.timeout(const Duration(seconds: 12));
    }

    final resolvedNonce = nonce ?? await pendingNonce();
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
    final bytes = web3_crypto.hexToBytes(rawHex);
    if (beforeBroadcast != null) {
      final fields = EvmTransactionFields(
        chainId: chainId,
        sender: account.address.hex,
        nonce: resolvedNonce,
        destination: to?.hex ?? '',
        valueWei: valueWei,
        dataHex: data == null || data.isEmpty ? '0x' : '0x${HEX.encode(data)}',
        gasLimit: gasLimit,
        gasPriceWei: gasPriceWei,
        maxFeePerGasWei: maxFeePerGasWei,
        maxPriorityFeePerGasWei: maxPriorityFeePerGasWei,
      );
      final hash = '0x${HEX.encode(web3_crypto.keccak256(bytes))}';
      try {
        await beforeBroadcast(EvmSignedTransaction._(fields, hash));
      } catch (_) {
        try {
          await abortedBeforeBroadcast?.call();
        } catch (_) {
          /* Preserve uncertain storage. */
        }
        rethrow;
      }
      if (account.isClosed) {
        try {
          await abortedBeforeBroadcast?.call();
        } catch (_) {
          /* Keep the reservation when storage is uncertain. */
        }
        throw StateError('EVM signing account is closed');
      }
    }
    beforeProviderSend?.call();
    final result = client.sendRawTransaction(bytes);
    return broadcastTimeout == null ? result : result.timeout(broadcastTimeout);
  }
}
