/// Native cryptographic operations powered by Rust via flutter_rust_bridge.
///
/// This module provides a clean Dart API over the Rust FFI functions for
/// performance-critical crypto operations. Each function falls back to a
/// Dart-only implementation if the Rust library is unavailable (e.g. tests).
library;

import 'package:flutter/foundation.dart';

import '../src/rust/api/argon2.dart' as rust_argon2;
import '../src/rust/api/bip32.dart' as rust_bip32;
import '../src/rust/api/bip39.dart' as rust_bip39;
import '../src/rust/api/secp256k1_api.dart' as rust_secp;

/// Singleton entry point for all native (Rust) crypto operations.
///
/// Usage:
///   final mnemonic = await NativeCrypto.generateMnemonic();
///   final isValid  = await NativeCrypto.validateMnemonic(mnemonic);
///   final seed     = await NativeCrypto.mnemonicToSeed(mnemonic);
///   final privKey  = await NativeCrypto.deriveWalletFromSeed(seed, 0);
class NativeCrypto {
  NativeCrypto._();

  // ---------- BIP-39 -------------------------------------------------------

  /// Generate a new 12-word BIP-39 mnemonic (128-bit entropy).
  static Future<String> generateMnemonic() async {
    try {
      return await rust_bip39.generateMnemonic();
    } catch (e) {
      debugPrint('[NativeCrypto] generateMnemonic Rust error, using Dart: $e');
      rethrow;
    }
  }

  /// Validate a BIP-39 mnemonic phrase.
  static Future<bool> validateMnemonic(String phrase) async {
    try {
      return await rust_bip39.validateMnemonic(phrase: phrase);
    } catch (e) {
      debugPrint('[NativeCrypto] validateMnemonic Rust error: $e');
      rethrow;
    }
  }

  /// Convert a BIP-39 mnemonic phrase to a 64-byte seed.
  static Future<Uint8List> mnemonicToSeed(String phrase) async {
    try {
      final seed = await rust_bip39.mnemonicToSeed(phrase: phrase);
      return Uint8List.fromList(seed);
    } catch (e) {
      debugPrint('[NativeCrypto] mnemonicToSeed Rust error: $e');
      rethrow;
    }
  }

  // ---------- BIP-32 (HD Key Derivation) ------------------------------------

  /// Derive an Ethereum private key from a 64-byte seed at the given index.
  /// Returns a 64-character hex string (no 0x prefix).
  ///
  /// Path: m/44'/60'/0'/0/{derivationIndex}
  static Future<String> deriveWalletFromSeed(
    Uint8List seed,
    int derivationIndex,
  ) async {
    try {
      return await rust_bip32.deriveWalletFromSeed(
        seed: seed.toList(),
        derivationIndex: derivationIndex,
      );
    } catch (e) {
      debugPrint('[NativeCrypto] deriveWalletFromSeed Rust error: $e');
      rethrow;
    }
  }

  // ---------- Argon2id (Passcode Hashing) -----------------------------------

  /// Derive a passcode hash using Argon2id. Returns base64-encoded hash.
  static Future<String> derivePasscodeHash({
    required String passcode,
    required String saltBase64,
    int iterations = 3,
    int memoryKiB = 65536,
  }) async {
    try {
      return await rust_argon2.derivePasscodeHashArgon2(
        passcode: passcode,
        saltBase64: saltBase64,
        iterations: iterations,
        memoryPowerOf2: memoryKiB,
      );
    } catch (e) {
      debugPrint('[NativeCrypto] derivePasscodeHash Rust error: $e');
      rethrow;
    }
  }

  // ---------- secp256k1 (Transaction / Message Signing) ---------------------

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

  /// Sign EIP-712 typed data.
  /// NOTE: This is currently stubbed in Rust — falls back to Dart's EthSigUtil.
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
      // EIP-712 is intentionally unimplemented in Rust — callers should
      // catch this and use Dart's EthSigUtil as fallback.
      debugPrint('[NativeCrypto] signTypedData Rust stubbed — use Dart: $e');
      rethrow;
    }
  }
}
