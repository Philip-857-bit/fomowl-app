import 'dart:async';
import 'dart:convert';
import '../../models/bitcoin_account_state.dart';
import '../secure_store.dart';
import 'bitcoin_protected_record.dart';

class _WalletQueue {
  Future<void> tail = Future.value();
  int generation = 0;
  bool removed = false;
  Object submissionRevision = Object();
  Future<T> run<T>(
    Future<T> Function() operation, {
    bool allowRemoved = false,
  }) {
    final captured = generation;
    final result = tail.then((_) async {
      if (captured != generation || removed && !allowRemoved) {
        throw StateError('Bitcoin wallet context was removed');
      }
      return operation();
    });
    tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

class _Manifest {
  final bool removed;
  final List<BitcoinAccountSlot> slots;
  const _Manifest(this.removed, this.slots);
}

/// The protected store owns all mutation. Queues are shared by wrappers over one SecureStore.
/// Manifest registration precedes new records, so interrupted writes remain discoverable for cleanup.
class BitcoinAccountStore {
  final SecureStore secureStore;
  BitcoinAccountStore(this.secureStore);
  static final Expando<Map<String, _WalletQueue>> _queues = Expando();
  Map<String, _WalletQueue> get _walletQueues => _queues[secureStore] ??= {};
  String _identity(String identity) {
    final value = identity.trim().toLowerCase();
    if (value.isEmpty || value.length > 128) {
      throw const FormatException('Invalid Bitcoin wallet identity');
    }
    return value;
  }

  _WalletQueue _queue(String identity) =>
      _walletQueues.putIfAbsent(_identity(identity), _WalletQueue.new);
  String _manifestKey(String identity) =>
      'bitcoin_hd_manifest_v1_${Uri.encodeComponent(_identity(identity))}';
  String _submissionKey(String identity) =>
      'bitcoin_submission_v1_${Uri.encodeComponent(_identity(identity))}';
  String _offrampKey(String identity) =>
      'bitcoin_offramp_v1_${Uri.encodeComponent(_identity(identity))}';
  String _billKey(String identity) =>
      'bitcoin_bill_funding_v1_${Uri.encodeComponent(_identity(identity))}';
  String _bridgeKey(String identity) =>
      'bitcoin_bridge_funding_v1_${Uri.encodeComponent(_identity(identity))}';

  /// Bridge guards are isolated from bills, off-ramp and input reservations.
  /// The shared wallet queue also revokes these writes on deletion/reset.
  Future<T> updateBridgeState<T>(
    String identity,
    (T, String?) Function(String?) update,
  ) => _queue(identity).run(() async {
    if ((await _manifest(identity)).removed) {
      throw StateError('Bitcoin wallet context was removed');
    }
    final key = _bridgeKey(identity);
    final (result, encoded) = update(await _read(key));
    if (encoded != null) {
      if (encoded.length > 131072) {
        throw const FormatException('Invalid Bitcoin bridge funding state');
      }
      await _write(key, encoded);
    }
    return result;
  });

  /// Invoice payment guards use a separate namespace from Breet withdrawals.
  Future<T> updateBillState<T>(
    String identity,
    (T, String?) Function(String?) update,
  ) => _queue(identity).run(() async {
    if ((await _manifest(identity)).removed) {
      throw StateError('Bitcoin wallet context was removed');
    }
    final key = _billKey(identity);
    final (result, encoded) = update(await _read(key));
    if (encoded != null) {
      if (encoded.length > 131072) {
        throw const FormatException('Invalid Bitcoin bill funding state');
      }
      await _write(key, encoded);
    }
    return result;
  });

  /// Public operation-reference/txid bindings, isolated from the UTXO journal.
  /// Uses the same custody lifecycle queue so deletion/reset revoke old writes.
  Future<T> updateOfframpState<T>(
    String identity,
    (T, String?) Function(String?) update,
  ) => _queue(identity).run(() async {
    if ((await _manifest(identity)).removed) {
      throw StateError('Bitcoin wallet context was removed');
    }
    final key = _offrampKey(identity);
    final (result, encoded) = update(await _read(key));
    if (encoded != null) {
      if (encoded.length > 131072) {
        throw const FormatException('Invalid Bitcoin cash-out state');
      }
      await _write(key, encoded);
    }
    return result;
  });

  /// Opaque, process-local revision shared by wrappers over one protected store.
  /// Async observers cannot survive process restart; durable records remain
  /// authoritative and are never released merely because this token changes.
  Object submissionRevision(String identity) =>
      _queue(identity).submissionRevision;

  /// Serialized public submission metadata, sharing custody deletion/reset revocation.
  Future<T> updateSubmissionState<T>(
    String identity,
    (T, String?) Function(String?) update,
  ) => _queue(identity).run(() async {
    if ((await _manifest(identity)).removed) {
      throw StateError('Bitcoin wallet context was removed');
    }
    final key = _submissionKey(identity);
    final (result, encoded) = update(await _read(key));
    if (encoded != null) {
      // Invalidate observers even if the write's outcome becomes uncertain.
      _queue(identity).submissionRevision = Object();
      await _write(key, encoded);
    }
    return result;
  });
  Future<String?> _read(String key) async {
    try {
      return await secureStore.read(key: key);
    } catch (_) {
      throw StateError('Protected Bitcoin storage unavailable');
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await secureStore.write(key: key, value: value);
      if (await secureStore.read(key: key) != value) {
        throw StateError('Protected storage write was not retained');
      }
    } catch (_) {
      throw StateError('Protected Bitcoin storage unavailable');
    }
  }

  Future<void> _delete(String key) async {
    try {
      await secureStore.delete(key: key);
      if (await secureStore.read(key: key) != null) {
        throw StateError("Protected storage deletion was not retained");
      }
    } catch (_) {
      throw StateError('Protected Bitcoin storage unavailable');
    }
  }

  Future<_Manifest> _manifest(String identity) async {
    final encoded = await _read(_manifestKey(identity));
    if (encoded == null) return const _Manifest(false, []);
    Object? raw;
    if (encoded.length > 16384) {
      throw const FormatException('Invalid Bitcoin storage manifest');
    }
    try {
      raw = jsonDecode(encoded);
    } catch (_) {
      throw const FormatException('Invalid Bitcoin storage manifest');
    }
    if (raw is! Map<String, dynamic> ||
        raw.length != 3 ||
        raw['version'] is! int ||
        raw['version'] != 1 ||
        raw['removed'] is! bool ||
        raw['slots'] is! List) {
      throw const FormatException('Invalid Bitcoin storage manifest');
    }
    final entries = raw['slots'] as List;
    if (entries.length > 16) {
      throw const FormatException('Invalid Bitcoin storage manifest');
    }
    final slots = <BitcoinAccountSlot>[];
    final keys = <String>{};
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Invalid Bitcoin storage manifest');
      }
      final slot = BitcoinAccountSlot.fromJson(_identity(identity), entry);
      if (!keys.add(slot.storageKey)) {
        throw const FormatException('Duplicate Bitcoin storage slot');
      }
      slots.add(slot);
    }
    return _Manifest(raw['removed'] as bool, slots);
  }

  Future<void> _saveManifest(String identity, _Manifest manifest) => _write(
    _manifestKey(identity),
    jsonEncode({
      'version': 1,
      'removed': manifest.removed,
      'slots': manifest.slots.map((slot) => slot.toJson()).toList(),
    }),
  );
  Future<ProtectedBitcoinRecord?> _record(BitcoinAccountSlot slot) async {
    final value = await _read(slot.storageKey);
    if (value == null) return null;
    final record = ProtectedBitcoinRecord.decode(value);
    if (!record.matches(slot)) {
      record.dispose();
      throw const FormatException('Bitcoin protected record identity mismatch');
    }
    return record;
  }

  /// Explicitly called when a managed seed wallet is added/restored, never as a corrupt-record fallback.
  Future<void> activateWallet(String walletIdentity) {
    final queue = _queue(walletIdentity);
    return queue.run(() async {
      final manifest = await _manifest(walletIdentity);
      if (manifest.removed) {
        await _delete(_submissionKey(walletIdentity));
        await _delete(_offrampKey(walletIdentity));
        await _delete(_billKey(walletIdentity));
        await _delete(_bridgeKey(walletIdentity));
        for (final slot in manifest.slots) {
          await _delete(slot.storageKey);
        }
        await _saveManifest(walletIdentity, const _Manifest(false, []));
      }
      if (manifest.removed || queue.removed) {
        queue.generation++;
      }
      queue.removed = false;
    }, allowRemoved: true);
  }

  Future<BitcoinPurposeAccountState?> readState(BitcoinAccountSlot slot) =>
      _queue(slot.walletIdentity).run(() async {
        final manifest = await _manifest(slot.walletIdentity);
        if (manifest.removed) return null;
        final record = await _record(slot);
        try {
          return record?.state;
        } finally {
          record?.dispose();
        }
      }, allowRemoved: true);
  Future<T> withRecord<T>(
    BitcoinAccountSlot slot,
    FutureOr<T> Function(ProtectedBitcoinRecord) operation,
  ) async {
    final record = await _queue(slot.walletIdentity).run(() async {
      if ((await _manifest(slot.walletIdentity)).removed) {
        throw StateError('Bitcoin wallet context was removed');
      }
      final value = await _record(slot);
      if (value == null) throw StateError('Bitcoin custody is not provisioned');
      return value;
    });
    // Crypto callbacks run outside the I/O queue; lifecycle generation guards
    // in the vault service reject a signer opened during a wallet change/lock.
    try {
      return await operation(record);
    } finally {
      record.dispose();
    }
  }

  /// Returns false for an existing authoritative record. It is never overwritten with new plaintext-derived custody.
  Future<bool> createIfAbsent(
    BitcoinAccountSlot slot,
    ProtectedBitcoinRecord candidate,
  ) => _queue(slot.walletIdentity).run(() async {
    if (!candidate.matches(slot)) {
      throw const FormatException('Bitcoin protected record identity mismatch');
    }
    final manifest = await _manifest(slot.walletIdentity);
    if (manifest.removed) {
      throw StateError('Bitcoin wallet context was removed');
    }
    final existing = await _record(slot);
    if (existing != null) {
      try {
        if (existing.state.metadata != candidate.state.metadata) {
          throw StateError('Bitcoin account identity mismatch');
        }
        return false;
      } finally {
        existing.dispose();
      }
    }
    if (!manifest.slots.any((entry) => entry.storageKey == slot.storageKey)) {
      if (manifest.slots.length >= 16) {
        throw StateError('Too many Bitcoin custody records');
      }
      await _saveManifest(
        slot.walletIdentity,
        _Manifest(false, [...manifest.slots, slot]),
      );
    }
    await _write(slot.storageKey, candidate.encode());
    return true;
  });
  Future<BitcoinPurposeAccountState> updateState(
    BitcoinAccountSlot slot,
    BitcoinPurposeAccountState Function(BitcoinPurposeAccountState) update,
  ) => _queue(slot.walletIdentity).run(() async {
    if ((await _manifest(slot.walletIdentity)).removed) {
      throw StateError('Bitcoin wallet context was removed');
    }
    final record = await _record(slot);
    if (record == null) throw StateError('Bitcoin custody is not provisioned');
    try {
      final next = update(record.state);
      final old = record.state;
      if (next.metadata != old.metadata ||
          next.nextExternal < old.nextExternal ||
          next.nextInternal < old.nextInternal ||
          old.lastUsedExternal != null &&
              (next.lastUsedExternal == null ||
                  next.lastUsedExternal! < old.lastUsedExternal!) ||
          old.lastUsedInternal != null &&
              (next.lastUsedInternal == null ||
                  next.lastUsedInternal! < old.lastUsedInternal!) ||
          old.lastScan != null &&
              (next.lastScan == null ||
                  next.lastScan!.isBefore(old.lastScan!))) {
        throw StateError('Bitcoin account state cannot move backwards');
      }
      await _write(slot.storageKey, record.withState(next).encode());
      return next;
    } finally {
      record.dispose();
    }
  });
  Future<BitcoinWalletAccountState?> readWalletState(
    String walletIdentity,
    BitcoinProductNetwork network,
    int accountIndex,
  ) async {
    final states = <BitcoinPurpose, BitcoinPurposeAccountState>{};
    for (final purpose in BitcoinPurpose.values) {
      final state = await readState(
        BitcoinAccountSlot(
          walletIdentity: walletIdentity,
          network: network,
          accountIndex: accountIndex,
          purpose: purpose,
        ),
      );
      if (state != null) states[purpose] = state;
    }
    if (states.isEmpty) return null;
    return BitcoinWalletAccountState(
      walletIdentity: _identity(walletIdentity),
      network: network,
      accountIndex: accountIndex,
      accounts: states,
    );
  }

  Future<void> deleteWallet(String walletIdentity) {
    final queue = _queue(walletIdentity);
    queue.submissionRevision = Object();
    queue.generation++;
    queue.removed = true;
    return queue.run(() async {
      final manifest = await _manifest(walletIdentity);
      await _delete(_submissionKey(walletIdentity));
      await _delete(_offrampKey(walletIdentity));
      await _delete(_billKey(walletIdentity));
      await _delete(_bridgeKey(walletIdentity));
      // An account that never provisioned Bitcoin has no custody to journal.
      if (manifest.slots.isEmpty && !manifest.removed) {
        return;
      }
      // Tombstone first: interrupted deletion cannot reactivate partially deleted custody.
      await _saveManifest(walletIdentity, _Manifest(true, manifest.slots));
      for (final slot in manifest.slots) {
        await _delete(slot.storageKey);
      }
      await _saveManifest(walletIdentity, const _Manifest(true, []));
    }, allowRemoved: true);
  }

  /// StorageService reset subsequently clears platform storage; old queued writes stay revoked.
  void invalidateAll() {
    for (final queue in _walletQueues.values) {
      queue.submissionRevision = Object();
      queue.generation++;
      queue.removed = true;
    }
  }
}
