/// Native cryptographic operations powered by Rust via flutter_rust_bridge.
///
/// This module provides a clean Dart API over the Rust FFI functions for
/// crypto operations. Rust failures propagate; production never silently
/// selects a different mnemonic, derivation, or signing implementation.
library;

import 'package:flutter/foundation.dart';

import '../src/rust/api/argon2.dart' as rust_argon2;
import '../src/rust/api/bip32.dart' as rust_bip32;
import '../src/rust/api/bip39.dart' as rust_bip39;
import '../src/rust/api/evm_tx.dart' as rust_evm_tx;
import '../src/rust/api/evm_signing_account.dart' as rust_account;
import '../src/rust/api/secp256k1_api.dart' as rust_secp;
import '../src/rust/api/solana_tx.dart' as rust_solana_tx;

/// Singleton entry point for all native (Rust) crypto operations.
///
/// Usage:
///   final mnemonic = await NativeCrypto.generateMnemonic();
///   final isValid  = await NativeCrypto.validateMnemonic(mnemonic);
///   final seed     = await NativeCrypto.mnemonicToSeed(mnemonic);
///   final privKey  = await NativeCrypto.deriveEvmPrivateKeyFromSeed(seed, 0);
class NativeCrypto {
  NativeCrypto._();

  static Future<rust_account.RustEvmSigningAccount> createEvmSigningAccount({
    required String privateKeyHex,
    required String expectedAddress,
  }) => rust_account.createEvmSigningAccount(
    privateKeyHex: privateKeyHex,
    expectedAddress: expectedAddress,
  );

  // ---------- BIP-39 -------------------------------------------------------

  /// Generate a new 12-word BIP-39 mnemonic (128-bit entropy).
  static Future<String> generateMnemonic() async {
    return await rust_bip39.generateMnemonic();
  }

  /// Validate a BIP-39 mnemonic phrase using the shared Rust engine.
  static Future<bool> validateMnemonic(String phrase) async {
    return await rust_bip39.validateMnemonic(phrase: phrase);
  }

  /// Derive a seed only after Rust validates the mnemonic and its checksum.
  static Future<Uint8List> mnemonicToSeed(String phrase) async {
    final seed = await rust_bip39.mnemonicToSeed(phrase: phrase);
    return Uint8List.fromList(seed);
  }

  // ---------- HD Key Derivation -------------------------------------------

  /// Compatibility alias for deriving an Ethereum private key.
  ///
  /// Prefer [deriveEvmPrivateKeyFromSeed] in new code because Solana/TRON use
  /// different curves and derivation paths.
  static Future<String> deriveWalletFromSeed(
    Uint8List seed,
    int derivationIndex,
  ) {
    return deriveEvmPrivateKeyFromSeed(seed, derivationIndex);
  }

  /// Derive an Ethereum private key from a 64-byte seed at the given index.
  /// Returns a 64-character hex string (no 0x prefix).
  ///
  /// Path: m/44'/60'/0'/0/{derivationIndex}
  static Future<String> deriveEvmPrivateKeyFromSeed(
    Uint8List seed,
    int derivationIndex,
  ) async {
    try {
      return await rust_bip32.deriveEvmPrivateKeyFromSeed(
        seed: seed.toList(),
        derivationIndex: derivationIndex,
      );
    } catch (e) {
      debugPrint('[NativeCrypto] deriveEvmPrivateKeyFromSeed Rust error: $e');
      rethrow;
    }
  }

  /// Derive an EIP-55 Ethereum address from the wallet seed.
  static Future<String> deriveEvmAddressFromSeed(
    Uint8List seed,
    int derivationIndex,
  ) async {
    try {
      return await rust_bip32.deriveEvmAddressFromSeed(
        seed: seed.toList(),
        derivationIndex: derivationIndex,
      );
    } catch (e) {
      debugPrint('[NativeCrypto] deriveEvmAddressFromSeed Rust error: $e');
      rethrow;
    }
  }

  /// Derive an EIP-55 Ethereum address from a raw 32-byte private key.
  static Future<String> deriveEvmAddressFromPrivateKey(
    String privateKeyHex,
  ) async {
    try {
      return await rust_bip32.deriveEvmAddressFromPrivateKey(
        privateKeyHex: privateKeyHex,
      );
    } catch (e) {
      debugPrint(
        '[NativeCrypto] deriveEvmAddressFromPrivateKey Rust error: $e',
      );
      rethrow;
    }
  }

  /// Derive the existing unprefixed 64-byte EVM public-key metadata as hex.
  static Future<String> deriveEvmPublicKeyFromPrivateKey(
    String privateKeyHex,
  ) =>
      rust_bip32.deriveEvmPublicKeyFromPrivateKey(privateKeyHex: privateKeyHex);

  /// Derive a Solana Ed25519 private key seed at m/44'/501'/{index}'/0'.
  static Future<Uint8List> deriveSolanaPrivateKeyFromSeed(
    Uint8List seed,
    int derivationIndex,
  ) async {
    try {
      return await rust_bip32.deriveSolanaPrivateKeyFromSeed(
        seed: seed.toList(),
        derivationIndex: derivationIndex,
      );
    } catch (e) {
      debugPrint(
        '[NativeCrypto] deriveSolanaPrivateKeyFromSeed Rust error: $e',
      );
      rethrow;
    }
  }

  /// Derive a Solana base58 public address from the wallet seed.
  static Future<String> deriveSolanaAddressFromSeed(
    Uint8List seed,
    int derivationIndex,
  ) async {
    try {
      return await rust_bip32.deriveSolanaAddressFromSeed(
        seed: seed.toList(),
        derivationIndex: derivationIndex,
      );
    } catch (e) {
      debugPrint('[NativeCrypto] deriveSolanaAddressFromSeed Rust error: $e');
      rethrow;
    }
  }

  /// Derive a TRON secp256k1 private key at m/44'/195'/0'/0/{index}.
  static Future<String> deriveTronPrivateKeyFromSeed(
    Uint8List seed,
    int derivationIndex,
  ) async {
    try {
      return await rust_bip32.deriveTronPrivateKeyFromSeed(
        seed: seed.toList(),
        derivationIndex: derivationIndex,
      );
    } catch (e) {
      debugPrint('[NativeCrypto] deriveTronPrivateKeyFromSeed Rust error: $e');
      rethrow;
    }
  }

  /// Derive a TRON base58check address from the wallet seed.
  static Future<String> deriveTronAddressFromSeed(
    Uint8List seed,
    int derivationIndex,
  ) async {
    try {
      return await rust_bip32.deriveTronAddressFromSeed(
        seed: seed.toList(),
        derivationIndex: derivationIndex,
      );
    } catch (e) {
      debugPrint('[NativeCrypto] deriveTronAddressFromSeed Rust error: $e');
      rethrow;
    }
  }

  /// Derive a Solana base58 public address from a 32-byte Ed25519 private key.
  static Future<String> deriveSolanaAddressFromPrivateKey(
    Uint8List privateKeyBytes,
  ) async {
    try {
      return await rust_bip32.deriveSolanaAddressFromPrivateKey(
        privateKeyBytes: privateKeyBytes.toList(),
      );
    } catch (e) {
      debugPrint(
        '[NativeCrypto] deriveSolanaAddressFromPrivateKey Rust error: $e',
      );
      rethrow;
    }
  }

  /// Normalize a Solana private key export using Rust/Solana keypair handling.
  ///
  /// Accepts 32-byte seed or 64-byte keypair material encoded as hex, JSON byte
  /// array, base58, or base64. Returns normalized 32-byte private key hex and
  /// the derived Solana address.
  static Future<rust_bip32.SolanaPrivateKeyImport> normalizeSolanaPrivateKey(
    String privateKey,
  ) async {
    try {
      return await rust_bip32.normalizeSolanaPrivateKey(privateKey: privateKey);
    } catch (e) {
      debugPrint('[NativeCrypto] normalizeSolanaPrivateKey Rust error: $e');
      rethrow;
    }
  }

  /// Derive a TRON base58check address from a 32-byte secp256k1 private key
  /// (provided as 64 hex characters, no 0x prefix).
  static Future<String> deriveTronAddressFromPrivateKey(
    String privateKeyHex,
  ) async {
    try {
      return await rust_bip32.deriveTronAddressFromPrivateKey(
        privateKeyHex: privateKeyHex,
      );
    } catch (e) {
      debugPrint(
        '[NativeCrypto] deriveTronAddressFromPrivateKey Rust error: $e',
      );
      rethrow;
    }
  }

  // ---------- Argon2id (Passcode Hashing) ---------------------------------

  /// Derive a passcode hash using Argon2id. Returns base64-encoded hash.
  static Future<String> derivePasscodeHash({
    required String passcode,
    required String saltBase64,
    int iterations = 3,
    int memoryPowerOf2 = 16,
  }) async {
    try {
      return await rust_argon2.derivePasscodeHashArgon2(
        passcode: passcode,
        saltBase64: saltBase64,
        iterations: iterations,
        memoryPowerOf2: memoryPowerOf2,
      );
    } catch (e) {
      debugPrint('[NativeCrypto] derivePasscodeHash Rust error: $e');
      rethrow;
    }
  }

  // ---------- Signing ------------------------------------------------------

  /// Sign an Ethereum personal message (EIP-191).
  /// Returns a 0x-prefixed hex signature string.
  static Future<String> signPersonalMessage({
    required String privateKeyHex,
    required String message,
  }) async {
    try {
      return await rust_secp.signPersonalMessage(
        privateKeyHex: privateKeyHex,
        message: message,
      );
    } catch (e) {
      debugPrint('[NativeCrypto] signPersonalMessage Rust error: $e');
      rethrow;
    }
  }

  /// Sign a Solana transaction/message payload with a 32-byte Ed25519 private
  /// key seed. Returns a base58-encoded 64-byte signature.
  static Future<String> signSolanaMessage({
    required Uint8List privateKeyBytes,
    required Uint8List message,
  }) async {
    try {
      return await rust_bip32.signSolanaMessage(
        privateKeyBytes: privateKeyBytes.toList(),
        message: message.toList(),
      );
    } catch (e) {
      debugPrint('[NativeCrypto] signSolanaMessage Rust error: $e');
      rethrow;
    }
  }

  /// Compile Relay-style Solana instructions into a signed v0 transaction.
  /// Returns the base64-encoded signed transaction ready to broadcast.
  static Future<String> buildAndSignSolanaTransaction({
    required String payer,
    required String recentBlockhash,
    required String instructionsJson,
    required String lookupTablesJson,
    required Uint8List privateKeyBytes,
  }) async {
    try {
      return await rust_solana_tx.buildAndSignSolanaTransaction(
        payer: payer,
        recentBlockhash: recentBlockhash,
        instructionsJson: instructionsJson,
        lookupTablesJson: lookupTablesJson,
        privateKeyBytes: privateKeyBytes.toList(),
      );
    } catch (e) {
      debugPrint('[NativeCrypto] buildAndSignSolanaTransaction Rust error: $e');
      rethrow;
    }
  }

  /// Sign a Jupiter/Relay-style unsigned Solana transaction (base64 in, base64 out).
  static Future<String> signSerializedSolanaTransaction({
    required String serializedTxBase64,
    required String expectedSigner,
    required Uint8List privateKeyBytes,
  }) async {
    try {
      return await rust_solana_tx.signSerializedSolanaTransaction(
        serializedTxBase64: serializedTxBase64,
        expectedSigner: expectedSigner,
        privateKeyBytes: privateKeyBytes.toList(),
      );
    } catch (e) {
      debugPrint(
        '[NativeCrypto] signSerializedSolanaTransaction Rust error: $e',
      );
      rethrow;
    }
  }

  /// Sign a 32-byte TRON raw transaction hash. Returns a 0x-prefixed 65-byte
  /// hex signature with a 0/1 recovery ID.
  static Future<String> signTronRawHash({
    required String privateKeyHex,
    required String rawHashHex,
  }) async {
    try {
      return await rust_bip32.signTronRawHash(
        privateKeyHex: privateKeyHex,
        rawHashHex: rawHashHex,
      );
    } catch (e) {
      debugPrint('[NativeCrypto] signTronRawHash Rust error: $e');
      rethrow;
    }
  }

  /// Sign EIP-712 typed data. Returns a 0x-prefixed hex signature string.
  static Future<String> signTypedData({
    required String privateKeyHex,
    required String jsonData,
  }) async {
    try {
      return await rust_secp.signTypedData(
        privateKeyHex: privateKeyHex,
        jsonData: jsonData,
      );
    } catch (e) {
      debugPrint('[NativeCrypto] signTypedData Rust error: $e');
      rethrow;
    }
  }

  /// Sign a legacy EVM transaction (EIP-155) via Rust and Alloy.
  /// Returns a canonical 0x-prefixed raw transaction hex string.
  /// Fail-closed: does not fall back to Dart signing.
  static Future<String> signLegacyEvmTransaction({
    required String privateKeyHex,
    required int chainId,
    required int nonce,
    required BigInt gasPriceWei,
    required int gasLimit,
    required String toAddress,
    required BigInt valueWei,
    String dataHex = '',
  }) async {
    try {
      return await rust_evm_tx.signLegacyEvmTransaction(
        privateKeyHex: privateKeyHex,
        chainId: BigInt.from(chainId),
        nonce: BigInt.from(nonce),
        gasPriceWei: gasPriceWei.toString(),
        gasLimit: BigInt.from(gasLimit),
        toAddress: toAddress,
        valueWei: valueWei.toString(),
        dataHex: dataHex,
      );
    } catch (e) {
      debugPrint('[NativeCrypto] signLegacyEvmTransaction Rust error: $e');
      rethrow;
    }
  }

  /// Signs a call or contract creation using one explicit Rust fee policy.
  /// Returns canonical EIP-2718 bytes, including the type byte for EIP-1559.
  static Future<String> signEvmTransaction({
    required String privateKeyHex,
    required int chainId,
    required int nonce,
    required int gasLimit,
    String? toAddress,
    required BigInt valueWei,
    String dataHex = '',
    BigInt? gasPriceWei,
    BigInt? maxFeePerGasWei,
    BigInt? maxPriorityFeePerGasWei,
  }) {
    final fees = [gasPriceWei, maxFeePerGasWei, maxPriorityFeePerGasWei];
    if (chainId <= 0 ||
        nonce < 0 ||
        gasLimit <= 0 ||
        valueWei < BigInt.zero ||
        valueWei.bitLength > 256 ||
        fees.any(
          (fee) => fee != null && (fee < BigInt.zero || fee.bitLength > 128),
        )) {
      throw ArgumentError('Invalid EVM transaction fields');
    }
    return rust_evm_tx.signEvmTransaction(
      privateKeyHex: privateKeyHex,
      chainId: BigInt.from(chainId),
      nonce: BigInt.from(nonce),
      gasLimit: BigInt.from(gasLimit),
      toAddress: toAddress,
      valueWei: valueWei.toString(),
      dataHex: dataHex,
      gasPriceWei: gasPriceWei?.toString(),
      maxFeePerGasWei: maxFeePerGasWei?.toString(),
      maxPriorityFeePerGasWei: maxPriorityFeePerGasWei?.toString(),
    );
  }
}
