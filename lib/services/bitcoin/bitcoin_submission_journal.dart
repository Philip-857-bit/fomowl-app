import 'dart:convert';
import '../../models/bitcoin_account_state.dart';
import '../../src/rust/api/bitcoin_transaction.dart';
import 'bitcoin_account_store.dart';

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
  const BitcoinSubmissionJournal(this.store);
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
        'version': 1,
        'identity': identity.toLowerCase(),
        'entries': <String, dynamic>{},
      };
    }
    if (raw.length > 524288) {
      throw const FormatException('Invalid Bitcoin submission journal');
    }
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value.length != 3 ||
        value['version'] != 1 ||
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
    return value;
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
