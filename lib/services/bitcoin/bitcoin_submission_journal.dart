import 'dart:convert';
import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_network_data.dart';
import '../../src/rust/api/bitcoin_transaction.dart';
import 'bitcoin_account_store.dart';

/// Public metadata for one persisted entry; its storage scope is opaque.
class BitcoinPendingSubmission {
  final Object _store;
  final String walletIdentity;
  final BitcoinProductNetwork network;
  final String txid;
  final List<String> inputs;
  final bool legacy;
  final Object _revision;
  BitcoinPendingSubmission._(
    this._store,
    this.walletIdentity,
    this.network,
    this.txid,
    List<String> inputs,
    this.legacy,
    this._revision,
  ) : inputs = List.unmodifiable(inputs);
  @override
  String toString() => 'BitcoinPendingSubmission';
}

/// A non-serializable capability for one live submission attempt. No secrets.
class BitcoinSubmissionReservation {
  final Object _store;
  final Object _owner = Object();
  final String _identity;
  final BitcoinProductNetwork _network;
  final String _txid;
  final Set<String> _inputs;
  bool _released = false;
  BitcoinSubmissionReservation._(
    this._store,
    this._identity,
    this._network,
    this._txid,
    List<String> inputs,
  ) : _inputs = Set.unmodifiable(inputs);
  @override
  String toString() => 'BitcoinSubmissionReservation';
}

/// Public outpoints only. Uncertain broadcasts remain reserved across restarts.
/// No elapsed-time release: a timeout is not evidence that a transaction failed.
class BitcoinSubmissionJournal {
  final BitcoinAccountStore store;
  final bool internalTestnetRecovery;
  static const internalBuild =
      String.fromEnvironment(
        'BITCOIN_BUILD_AUDIENCE',
        defaultValue: 'production',
      ) ==
      'internal';
  const BitcoinSubmissionJournal(
    this.store, {
    this.internalTestnetRecovery = internalBuild,
  });
  static final Expando<Map<String, Object>> _owners = Expando();
  Map<String, Object> get _liveOwners => _owners[store.secureStore] ??= {};
  String _ownerKey(
    String identity,
    BitcoinProductNetwork network,
    String txid,
  ) => jsonEncode([identity.toLowerCase(), network.id, txid]);
  static final _hash = RegExp(r'^[0-9a-f]{64}$');
  static final _outpoint = RegExp(r'^[0-9a-f]{64}:[0-9]{1,10}$');
  Map<String, dynamic> _decode(String? raw, String identity) {
    if (raw == null) {
      return {
        'version': 2,
        'identity': identity.toLowerCase(),
        'entries': <String, dynamic>{},
        'legacyEntries': <String>[],
      };
    }
    if (raw.length > 524288) {
      throw const FormatException('Invalid Bitcoin submission journal');
    }
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        ![1, 2].contains(value['version']) ||
        value.length != (value['version'] == 1 ? 3 : 4) ||
        value['identity'] != identity.toLowerCase() ||
        value['entries'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid Bitcoin submission journal');
    }
    final entries = value['entries'] as Map<String, dynamic>;
    if (entries.length > 1024) {
      throw const FormatException('Invalid Bitcoin submission journal');
    }
    final seen = <String>{};
    for (final entry in entries.entries) {
      final parts = entry.key.split('|');
      if (parts.length != 2 ||
          !['mainnet', 'testnet4'].contains(parts[0]) ||
          !_hash.hasMatch(parts[1]) ||
          entry.value is! List ||
          (entry.value as List).isEmpty ||
          (entry.value as List).length > 1000) {
        throw const FormatException('Invalid Bitcoin submission journal');
      }
      for (final point in entry.value as List) {
        if (point is! String ||
            !_outpoint.hasMatch(point) ||
            int.parse(point.split(':').last) > 0xffffffff ||
            !seen.add('${parts[0]}|$point')) {
          throw const FormatException('Invalid Bitcoin submission journal');
        }
      }
    }
    if (value['version'] == 1) {
      // Existing uncertain entries remain reserved. All newly created entries
      // use v2 and are never eligible for this legacy-only manual override.
      value['version'] = 2;
      value['legacyEntries'] = entries.keys.toList();
    }
    final legacy = value['legacyEntries'];
    if (legacy is! List ||
        legacy.length > 1024 ||
        legacy.toSet().length != legacy.length ||
        legacy.any((key) => key is! String || !entries.containsKey(key))) {
      throw const FormatException('Invalid Bitcoin submission journal');
    }
    return value;
  }

  Future<List<BitcoinPendingSubmission>> pending(
    String identity,
    BitcoinProductNetwork network,
  ) => store.updateSubmissionState(identity, (raw) {
    final value = _decode(raw, identity);
    final entries = value['entries'] as Map<String, dynamic>;
    final legacy = value['legacyEntries'] as List;
    return (
      List.unmodifiable([
        for (final entry in entries.entries)
          if (entry.key.startsWith('${network.id}|'))
            BitcoinPendingSubmission._(
              store.secureStore,
              identity.toLowerCase(),
              network,
              entry.key.split('|').last,
              List<String>.from(entry.value),
              legacy.contains(entry.key),
              store.submissionRevision(identity),
            ),
      ]),
      null,
    );
  });

  /// Remove only the exact persisted entry observed before a verified status
  /// lookup. Any intervening protected mutation invalidates that observation,
  /// including deleting and recreating the same txid/input set.
  Future<bool> reconcileConfirmed(
    BitcoinPendingSubmission snapshot,
    BitcoinTransactionStatus status, {
    required bool Function() isCurrent,
  }) async {
    if (!identical(snapshot._store, store.secureStore)) {
      throw StateError('Bitcoin submission storage scope mismatch');
    }
    if (!status.found || !status.confirmed || status.confirmations < 1) {
      return false;
    }
    return store.updateSubmissionState(snapshot.walletIdentity, (raw) {
      if (!isCurrent() ||
          !identical(
            snapshot._revision,
            store.submissionRevision(snapshot.walletIdentity),
          )) {
        return (false, null);
      }
      final value = _decode(raw, snapshot.walletIdentity);
      final entries = value['entries'] as Map<String, dynamic>;
      final legacy = value['legacyEntries'] as List;
      final key = '${snapshot.network.id}|${snapshot.txid}';
      final actual = entries[key];
      if (actual is! List ||
          actual.length != snapshot.inputs.length ||
          !actual.toSet().containsAll(snapshot.inputs) ||
          legacy.contains(key) != snapshot.legacy ||
          _liveOwners.containsKey(
            _ownerKey(snapshot.walletIdentity, snapshot.network, snapshot.txid),
          )) {
        return (false, null);
      }
      entries.remove(key);
      legacy.remove(key);
      final encoded = jsonEncode(value);
      _decode(encoded, snapshot.walletIdentity);
      return (true, encoded);
    });
  }

  /// Explicit authenticated manual override, confined to old internal Testnet4
  /// entries. The recovery coordinator must check chain facts first.
  Future<bool> recoverLegacyTestnet4(
    BitcoinPendingSubmission snapshot, {
    required void Function() checkAuthorization,
  }) async {
    if (!internalTestnetRecovery ||
        snapshot.network != BitcoinProductNetwork.testnet4 ||
        !snapshot.legacy ||
        !identical(snapshot._store, store.secureStore)) {
      throw StateError('Legacy recovery is unavailable for this submission');
    }
    return store.updateSubmissionState(snapshot.walletIdentity, (raw) {
      checkAuthorization();
      final value = _decode(raw, snapshot.walletIdentity);
      final entries = value['entries'] as Map<String, dynamic>;
      final legacy = value['legacyEntries'] as List;
      final key = '${snapshot.network.id}|${snapshot.txid}';
      final actual = entries[key];
      if (actual == null) return (false, null);
      if (!legacy.contains(key) ||
          actual is! List ||
          actual.length != snapshot.inputs.length ||
          !actual.toSet().containsAll(snapshot.inputs) ||
          _liveOwners.containsKey(
            _ownerKey(snapshot.walletIdentity, snapshot.network, snapshot.txid),
          )) {
        throw StateError('Bitcoin recovery snapshot changed');
      }
      entries.remove(key);
      legacy.remove(key);
      final encoded = jsonEncode(value);
      _decode(encoded, snapshot.walletIdentity);
      return (true, encoded);
    });
  }

  Future<Set<String>> reserved(
    String identity,
    BitcoinProductNetwork network,
  ) => store.updateSubmissionState(identity, (raw) {
    final entries = _decode(raw, identity)['entries'] as Map<String, dynamic>;
    return (
      {
        for (final entry in entries.entries)
          if (entry.key.startsWith('${network.id}|'))
            ...List<String>.from(entry.value as List),
      },
      null,
    );
  });

  List<String> _points(String txid, List<BitcoinUtxoDto> inputs) {
    if (!_hash.hasMatch(txid) || inputs.isEmpty || inputs.length > 1000) {
      throw const FormatException('Invalid Bitcoin submission');
    }
    final points = inputs
        .map((input) => '${input.txid}:${input.vout}')
        .toList();
    if (points.toSet().length != points.length) {
      throw const FormatException('Duplicate Bitcoin submission input');
    }
    if (points.any(
      (point) =>
          !_outpoint.hasMatch(point) ||
          int.parse(point.split(':').last) > 0xffffffff,
    )) {
      throw const FormatException('Invalid Bitcoin submission input');
    }
    return points;
  }

  /// Compatibility API: untracked callers cannot release a pending reservation.
  Future<bool> reserve(
    String identity,
    BitcoinProductNetwork network,
    String txid,
    List<BitcoinUtxoDto> inputs,
  ) async {
    final reservation = await reserveAttempt(identity, network, txid, inputs);
    if (reservation == null) return false;
    retainPending(reservation);
    return true;
  }

  /// Null means an existing attempt; never acquires ownership of persisted data.
  Future<BitcoinSubmissionReservation?> reserveAttempt(
    String identity,
    BitcoinProductNetwork network,
    String txid,
    List<BitcoinUtxoDto> inputs,
  ) async {
    final points = _points(txid, inputs);
    final ownerKey = _ownerKey(identity, network, txid);
    BitcoinSubmissionReservation? created;
    try {
      return await store.updateSubmissionState<BitcoinSubmissionReservation?>(
        identity,
        (raw) {
          final value = _decode(raw, identity);
          final entries = value['entries'] as Map<String, dynamic>;
          final key = '${network.id}|$txid';
          if (entries.containsKey(key)) {
            if (jsonEncode(entries[key]) != jsonEncode(points)) {
              throw StateError('Bitcoin submission identity mismatch');
            }
            return (null, null);
          }
          final existing = {
            for (final entry in entries.entries)
              if (entry.key.startsWith('${network.id}|'))
                ...List<String>.from(entry.value as List),
          };
          if (points.any(existing.contains)) {
            throw StateError(
              'Bitcoin inputs already have a pending submission',
            );
          }
          if (entries.length >= 1024) {
            throw StateError(
              'Bitcoin submission journal requires reconciliation',
            );
          }
          entries[key] = points;
          final encoded = jsonEncode(value);
          _decode(encoded, identity);
          created = BitcoinSubmissionReservation._(
            store.secureStore,
            identity.toLowerCase(),
            network,
            txid,
            points,
          );
          _liveOwners[ownerKey] = created!._owner;
          return (created, encoded);
        },
      );
    } catch (_) {
      if (created != null &&
          identical(_liveOwners[ownerKey], created!._owner)) {
        _liveOwners.remove(ownerKey);
      }
      rethrow;
    }
  }

  /// Atomic compare-and-release of one proven-rejected live attempt only.
  /// A txid/input match cannot acquire release rights over old or later attempts.
  Future<bool> releaseRejected({
    required BitcoinSubmissionReservation reservation,
    required String identity,
    required BitcoinProductNetwork network,
    required String txid,
    required List<BitcoinUtxoDto> expectedInputs,
  }) async {
    final expected = _points(txid, expectedInputs).toSet();
    if (!identical(reservation._store, store.secureStore) ||
        reservation._identity != identity.toLowerCase() ||
        reservation._network != network ||
        reservation._txid != txid) {
      throw StateError('Bitcoin reservation identity mismatch');
    }
    if (expected.length != reservation._inputs.length ||
        !expected.containsAll(reservation._inputs)) {
      throw StateError('Bitcoin reservation input mismatch');
    }
    final ownerKey = _ownerKey(identity, network, txid);
    final released = await store.updateSubmissionState<bool>(identity, (raw) {
      if (reservation._released) return (false, null);
      if (!identical(_liveOwners[ownerKey], reservation._owner)) {
        throw StateError('Bitcoin reservation is not owned by this attempt');
      }
      final value = _decode(raw, identity);
      final entries = value['entries'] as Map<String, dynamic>;
      final key = '${network.id}|$txid';
      final stored = entries[key];
      if (stored == null) return (false, null);
      final actual = List<String>.from(stored).toSet();
      if (actual.length != expected.length || !actual.containsAll(expected)) {
        throw StateError('Bitcoin reservation input mismatch');
      }
      entries.remove(key);
      (value['legacyEntries'] as List).remove(key);
      final encoded = jsonEncode(value);
      _decode(encoded, identity);
      return (true, encoded);
    });
    if (released) {
      reservation._released = true;
      retainPending(reservation);
    }
    return released;
  }

  /// Revoke live release rights while retaining the durable pending entry.
  void retainPending(BitcoinSubmissionReservation reservation) {
    if (!identical(reservation._store, store.secureStore)) {
      throw StateError('Bitcoin reservation identity mismatch');
    }
    final key = _ownerKey(
      reservation._identity,
      reservation._network,
      reservation._txid,
    );
    if (identical(_liveOwners[key], reservation._owner)) {
      _liveOwners.remove(key);
    }
  }
}
