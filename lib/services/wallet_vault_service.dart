import 'dart:convert';
import 'dart:typed_data';

import 'package:hex/hex.dart';

import '../models/chain.dart';
import '../src/rust/api/wallet_vault.dart' as rust;
import 'native_crypto.dart';
import 'bitcoin/bitcoin_wallet_vault_service.dart';

/// A single protected-storage value contains both authenticated ciphertext and
/// wrapping material. Platform storage protects the whole value; atomic writes
/// avoid interrupted key/ciphertext pairs. This is not a hardware-isolation API.
abstract interface class WalletVaultStore {
  Future<String?> readVaultRecord(ChainFamily family, String address);
  Future<void> writeVaultRecord(
    ChainFamily family,
    String address,
    String value,
  );
}

class WalletVaultRecord {
  WalletVaultRecord(this.encryptedVault, this.wrappingKey);
  final String encryptedVault;
  final Uint8List wrappingKey;

  factory WalletVaultRecord.decode(String value) {
    if (value.length > 10000) {
      throw const FormatException('Invalid vault record');
    }
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 3 ||
        decoded['version'] != 1 ||
        decoded['encryptedVault'] is! String ||
        decoded['wrappingKeyHex'] is! String) {
      throw const FormatException('Invalid vault record');
    }
    final keyHex = decoded['wrappingKeyHex'] as String;
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(keyHex)) {
      throw const FormatException('Invalid vault wrapping key');
    }
    return WalletVaultRecord(
      decoded['encryptedVault'] as String,
      Uint8List.fromList(HEX.decode(keyHex)),
    );
  }

  String encode() => jsonEncode({
    'version': 1,
    'encryptedVault': encryptedVault,
    'wrappingKeyHex': HEX.encode(wrappingKey),
  });
  void dispose() => wrappingKey.fillRange(0, wrappingKey.length, 0);
  @override
  String toString() => 'WalletVaultRecord(REDACTED)';
}

/// Verified, restart-safe migration shared by all signing hosts in Flutter.
/// Storage I/O and cryptography remain separate from transaction orchestration.
class WalletVaultService {
  WalletVaultService(this.store);
  final WalletVaultStore store;
  static final Set<rust.RustWalletSigningAccount> _accounts = {};
  static final Expando<Future<void>> _closing = Expando();
  static int _generation = 0;
  // Custody starts locked; bootstrap or successful user authentication opens it.
  static bool _locked = true;

  static void unlock() {
    BitcoinWalletVaultService.unlock();
    _locked = false;
    _generation++;
  }

  static Future<void> lockAll() async {
    _locked = true;
    await Future.wait([
      _invalidateGenericAccounts(),
      BitcoinWalletVaultService.lockAll(),
    ]);
  }

  static bool isOpen(rust.RustWalletSigningAccount signer) =>
      !_locked && _accounts.contains(signer) && !signer.isDisposed;

  /// Context changes revoke in-flight custody without changing authentication.
  static Future<void> invalidateOpenAccounts() async {
    await Future.wait([
      _invalidateGenericAccounts(),
      BitcoinWalletVaultService.invalidateOpenAccounts(),
    ]);
  }

  static Future<void> _invalidateGenericAccounts() async {
    _generation++;
    await Future.wait(_accounts.toList().map(close));
  }

  static void _requireUnlocked(int generation) {
    if (_locked || generation != _generation) {
      throw StateError('Wallet signing session is locked');
    }
  }

  final Map<String, Future<void>> _migrations = {};

  Future<rust.RustWalletSigningAccount> _open(
    ChainFamily family,
    String address,
    String raw,
  ) async {
    final record = WalletVaultRecord.decode(raw);
    try {
      return await rust.openWalletVault(
        chainFamily: family.name,
        encryptedVault: record.encryptedVault,
        expectedAddress: address,
        wrappingKey: record.wrappingKey,
      );
    } finally {
      record.dispose();
    }
  }

  static Future<void> close(rust.RustWalletSigningAccount signer) =>
      _closing[signer] ??= _close(signer);

  static Future<void> _close(rust.RustWalletSigningAccount signer) async {
    _accounts.remove(signer);
    if (signer.isDisposed) return;
    try {
      await signer.close();
    } finally {
      signer.dispose();
    }
  }

  Future<rust.RustWalletSigningAccount> open({
    required ChainFamily family,
    required String address,
    required Future<String?> Function() loadLegacyKey,
    required Future<void> Function() removeVerifiedLegacyKey,
  }) async {
    final generation = _generation;
    _requireUnlocked(generation);
    final slot =
        '${family.name}:${family == ChainFamily.evm ? address.toLowerCase() : address}';
    var raw = await store.readVaultRecord(family, address);
    if (raw == null) {
      final pending = _migrations[slot];
      if (pending != null) {
        await pending;
      } else {
        final migration = _migrate(family, address, loadLegacyKey);
        _migrations[slot] = migration;
        try {
          await migration;
        } finally {
          _migrations.remove(slot);
        }
      }
      raw = await store.readVaultRecord(family, address);
      if (raw == null) throw StateError('Verified vault record is missing');
    }
    // An existing record is authoritative: corruption never triggers fallback.
    final signer = await _open(family, address, raw);
    try {
      _requireUnlocked(generation);
      await removeVerifiedLegacyKey();
      _requireUnlocked(generation);
      _accounts.add(signer);
      return signer;
    } catch (_) {
      await close(signer);
      rethrow;
    }
  }

  Future<void> _migrate(
    ChainFamily family,
    String address,
    Future<String?> Function() loadLegacyKey,
  ) async {
    final secret = await loadLegacyKey();
    if (secret == null || secret.isEmpty) {
      // Another instance may have completed the same migration and cleanup.
      final existing = await store.readVaultRecord(family, address);
      if (existing != null) {
        final signer = await _open(family, address, existing);
        await close(signer);
        return;
      }
      throw StateError('No wallet found');
    }
    final key = await NativeCrypto.generateVaultWrappingKey();
    WalletVaultRecord? record;
    try {
      final encrypted = await rust.sealWalletVault(
        chainFamily: family.name,
        privateKeyHex: secret,
        expectedAddress: address,
        wrappingKey: key,
      );
      record = WalletVaultRecord(encrypted, key);
      final serialized = record.encode();
      final candidate = await _open(family, address, serialized);
      await close(candidate);
      await store.writeVaultRecord(family, address, serialized);
      final persisted = await store.readVaultRecord(family, address);
      if (persisted != serialized) {
        throw StateError('Vault storage verification failed');
      }
      final verified = await _open(family, address, persisted!);
      await close(verified);
    } finally {
      if (record != null) {
        record.dispose();
      } else {
        key.fillRange(0, key.length, 0);
      }
    }
  }

  /// Call only from explicit authenticated backup/private-key export flows.
  Future<String> exportKey(ChainFamily family, String address) async {
    final generation = _generation;
    _requireUnlocked(generation);
    final raw = await store.readVaultRecord(family, address);
    if (raw == null) throw StateError('Vault record is missing');
    final record = WalletVaultRecord.decode(raw);
    try {
      final secret = await rust.exportWalletVaultKey(
        chainFamily: family.name,
        encryptedVault: record.encryptedVault,
        expectedAddress: address,
        wrappingKey: record.wrappingKey,
      );
      _requireUnlocked(generation);
      return secret;
    } finally {
      record.dispose();
    }
  }
}
