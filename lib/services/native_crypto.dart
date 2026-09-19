/// Native cryptographic operations powered by Rust via flutter_rust_bridge.
///
/// This module provides a clean Dart API over the Rust FFI functions for
/// performance-critical crypto operations. Each function falls back to a
/// Dart-only implementation if the Rust library is unavailable (e.g. tests).
library;

import 'package:flutter/foundation.dart';
import 'package:bip39/bip39.dart' as dart_bip39;

import '../src/rust/api/argon2.dart' as rust_argon2;
import '../src/rust/api/bip32.dart' as rust_bip32;
import '../src/rust/api/bip39.dart' as rust_bip39;
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

  // ---------- BIP-39 -------------------------------------------------------

  /// Generate a new 12-word BIP-39 mnemonic (128-bit entropy).
  static Future<String> generateMnemonic() async {
    try {
      return await rust_bip39.generateMnemonic();
    } catch (e) {
      debugPrint('[NativeCrypto] generateMnemonic Rust error, using Dart: $e');
      return dart_bip39.generateMnemonic();
    }
  }

  /// Validate a BIP-39 mnemonic phrase.
  static Future<bool> validateMnemonic(String phrase) async {
    try {
      final isValid = await rust_bip39.validateMnemonic(phrase: phrase);
      return isValid;
    } catch (e) {
      debugPrint('[NativeCrypto] validateMnemonic Rust error, using Dart: $e');
      return dart_bip39.validateMnemonic(phrase);
    }
  }

  /// Convert a BIP-39 mnemonic phrase to a 64-byte seed.
  static Future<Uint8List> mnemonicToSeed(String phrase) async {
    try {
      final seed = await rust_bip39.mnemonicToSeed(phrase: phrase);
      return Uint8List.fromList(seed);
    } catch (e) {
      debugPrint('[NativeCrypto] mnemonicToSeed Rust error, using Dart: $e');
      return dart_bip39.mnemonicToSeed(phrase);
    }
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
      debugPrint('[NativeCrypto] signSerializedSolanaTransaction Rust error: $e');
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
}
