import 'dart:async';
import 'dart:collection';
import '../../models/bitcoin_account_state.dart';
import 'bitcoin_account_store.dart';
import 'bitcoin_native_crypto.dart';
import 'bitcoin_protected_record.dart';

/// Authentication/lifecycle policy around the separate Rust HD vault/session model.
class BitcoinWalletVaultService {
  final BitcoinAccountStore store;
  final BitcoinCryptoApi crypto;
  BitcoinWalletVaultService({
    required this.store,
    this.crypto = const NativeBitcoinCrypto(),
  });
  static bool _locked = true;
  static int _generation = 0;
  static final Map<BitcoinSigningAccount, int> _opened = HashMap.identity();
  static final Expando<Future<void>> _closing = Expando();
  static bool get isUnlocked => !_locked;
  static void unlock() {
    _locked = false;
    _generation++;
    // Reauthentication never keeps custody from an earlier generation alive.
    for (final signer in _opened.keys.toList()) {
      unawaited(close(signer).catchError((Object _) {}));
    }
  }

  static int beginOperation() {
    final value = _generation;
    checkOperation(value);
    return value;
  }

  static void checkOperation(int generation) {
    if (_locked || generation != _generation) {
      throw StateError('Bitcoin signing context is locked or expired');
    }
  }

  static bool isOpen(BitcoinSigningAccount signer) =>
      !_locked && _opened[signer] == _generation;
  static Future<void> lockAll() async {
    _locked = true;
    await invalidateOpenAccounts();
  }

  static Future<void> invalidateOpenAccounts() async {
    _generation++;
    await Future.wait(_opened.keys.toList().map(close));
  }

  static Future<void> close(BitcoinSigningAccount signer) =>
      _closing[signer] ??= _close(signer);
  static Future<void> _close(BitcoinSigningAccount signer) async {
    _opened.remove(signer);
    await signer.close();
  }

  Future<BitcoinSigningAccount> open(
    BitcoinAccountSlot slot,
    BitcoinHdAccountMetadata expected,
  ) async {
    final generation = beginOperation();
    if (!slot.matches(expected)) {
      throw StateError('Bitcoin account identity mismatch');
    }
    final signer = await store.withRecord(slot, (record) async {
      checkOperation(generation);
      if (record.state.metadata != expected) {
        throw StateError('Bitcoin account identity mismatch');
      }
      return crypto.openAccount(
        expected,
        record.encryptedVault,
        record.wrappingKey,
      );
    });
    try {
      checkOperation(generation);
      if (await signer.accountInfo() != expected) {
        throw StateError('Bitcoin account identity mismatch');
      }
      checkOperation(generation);
      _opened[signer] = generation;
      return signer;
    } catch (_) {
      await close(signer);
      rethrow;
    }
  }

  /// The account always closes, including cancellation and failures. Context is
  /// checked after close so a lock during shutdown cannot release a stale result.
  Future<T> withAccount<T>(
    BitcoinAccountSlot slot,
    BitcoinHdAccountMetadata expected,
    Future<T> Function(BitcoinSigningAccount) operation,
  ) async {
    final generation = beginOperation();
    final signer = await open(slot, expected);
    late T result;
    try {
      checkOperation(generation);
      result = await operation(signer);
    } finally {
      await close(signer);
    }
    checkOperation(generation);
    return result;
  }
}
