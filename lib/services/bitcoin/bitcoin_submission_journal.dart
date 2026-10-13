import 'dart:convert';
import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_network_data.dart';
import '../../src/rust/api/bitcoin_transaction.dart';
import 'bitcoin_account_store.dart';
import 'bitcoin_saved_transaction.dart';

/// Confirmed replacement receipt metadata for presentation only. It never
/// authorizes signing or releases an input reservation.
class BitcoinResolvedSubmission {
  final String txid;
  final BigInt feeSat;
  final BigInt recipientTotalSat;
  BitcoinResolvedSubmission._(this.txid, this.feeSat, this.recipientTotalSat);
  factory BitcoinResolvedSubmission._fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value.length != 3 ||
        !value.keys.toSet().containsAll([
          'txid',
          'feeSat',
          'recipientTotalSat',
        ])) {
      throw const FormatException('Invalid resolved Bitcoin submission');
    }
    BigInt number(Object? value) {
      if (value is! String ||
          !RegExp(r'^(0|[1-9][0-9]{0,19})$').hasMatch(value)) {
        throw const FormatException('Invalid resolved Bitcoin amount');
      }
      final amount = BigInt.parse(value);
      if (amount.bitLength > 64) {
        throw const FormatException('Invalid resolved Bitcoin amount');
      }
      return amount;
    }

    return BitcoinResolvedSubmission._(
      bitcoinTxid(value['txid']),
      number(value['feeSat']),
      number(value['recipientTotalSat']),
    );
  }
  Map<String, String> _toJson() => {
    'txid': txid,
    'feeSat': feeSat.toString(),
    'recipientTotalSat': recipientTotalSat.toString(),
  };
}

/// Public metadata for one persisted entry; its storage scope is opaque.
class BitcoinPendingSubmission {
  final Object _store;
  final String walletIdentity;
  final BitcoinProductNetwork network;
  final String txid;
  final List<String> inputs;
  final bool legacy;
  final String rootTxid;
  final bool active;
  final BitcoinSavedTransaction? transaction;
  final Object _revision;
  BitcoinPendingSubmission._(
    this._store,
    this.walletIdentity,
    this.network,
    this.txid,
    List<String> inputs,
    this.legacy,
    this._revision, {
    String? rootTxid,
    this.active = true,
    this.transaction,
  }) : rootTxid = rootTxid ?? txid,
       inputs = List.unmodifiable(inputs);
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
  final String _rootTxid;
  final String? _previousTxid;
  bool _released = false;
  BitcoinSubmissionReservation._(
    this._store,
    this._identity,
    this._network,
    this._txid,
    List<String> inputs, {
    String? rootTxid,
    String? previousTxid,
  }) : _rootTxid = rootTxid ?? _txid,
       _previousTxid = previousTxid,
       _inputs = Set.unmodifiable(inputs);
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
        'version': 3,
        'identity': identity.toLowerCase(),
        'entries': <String, dynamic>{},
        'legacyEntries': <String>[],
        'outbound': <String, dynamic>{},
        'resolved': <String, dynamic>{},
      };
    }
    if (raw.length > 8 * 1024 * 1024) {
      throw const FormatException('Invalid Bitcoin submission journal');
    }
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value['version'] is! int ||
        ![1, 2, 3].contains(value['version']) ||
        value.length !=
            (value['version'] == 1
                ? 3
                : value['version'] == 2
                ? 4
                : 6) ||
        value['version'] != 3 && raw.length > 524288 ||
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
      // use the current format and are never eligible for this legacy override.
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
    if (value['version'] == 2) {
      value['version'] = 3;
      value['outbound'] = <String, dynamic>{};
      value['resolved'] = <String, dynamic>{};
    }
    final resolved = value['resolved'];
    if (resolved is! Map<String, dynamic> || resolved.length > 4096) {
      throw const FormatException('Invalid Bitcoin replacement receipts');
    }
    for (final receipt in resolved.entries) {
      final parts = receipt.key.split('|');
      final winner = BitcoinResolvedSubmission._fromJson(receipt.value);
      if (parts.length != 2 ||
          !['mainnet', 'testnet4'].contains(parts[0]) ||
          !_hash.hasMatch(parts[1]) ||
          parts[1] == winner.txid) {
        throw const FormatException(
          'Invalid Bitcoin replacement receipt identity',
        );
      }
    }
    final outbound = value['outbound'];
    if (outbound is! Map<String, dynamic> || outbound.length > entries.length) {
      throw const FormatException('Invalid Bitcoin outbound journal');
    }
    final identities = entries.keys.toSet();
    for (final item in outbound.entries) {
      if (!entries.containsKey(item.key) ||
          legacy.contains(item.key) ||
          item.value is! Map<String, dynamic>) {
        throw const FormatException('Invalid Bitcoin outbound journal');
      }
      final record = item.value as Map<String, dynamic>;
      final chain = record['chain'];
      final records = record['records'];
      if (record.length != 2 ||
          chain is! List ||
          chain.isEmpty ||
          chain.length > 32 ||
          records is! Map<String, dynamic> ||
          records.length != chain.length ||
          chain.toSet().length != chain.length ||
          chain.first != item.key.split('|').last) {
        throw const FormatException('Invalid Bitcoin replacement lineage');
      }
      BitcoinSavedTransaction? original;
      BitcoinSavedTransaction? previous;
      for (final id in chain) {
        if (id is! String || !_hash.hasMatch(id) || !records.containsKey(id)) {
          throw const FormatException('Invalid Bitcoin replacement identity');
        }
        if (id != chain.first &&
            !identities.add('${item.key.split('|').first}|$id')) {
          throw const FormatException('Duplicate Bitcoin replacement identity');
        }
        final saved = BitcoinSavedTransaction.fromJson(records[id]);
        final points = _points(id, saved.plan.selectedUtxos);
        final expected = List<String>.from(entries[item.key] as List);
        if (saved.signed.txid != id ||
            saved.account.network.id != item.key.split('|').first ||
            points.length != expected.length ||
            !points.toSet().containsAll(expected)) {
          throw const FormatException(
            'Bitcoin saved transaction identity mismatch',
          );
        }
        original ??= saved;
        if (saved.account != original.account ||
            jsonEncode(saved.planJson['selectedUtxos']) !=
                jsonEncode(original.planJson['selectedUtxos']) ||
            saved.plan.changeIndex != original.plan.changeIndex ||
            jsonEncode(saved.planJson['recipients']) !=
                jsonEncode(original.planJson['recipients'])) {
          throw const FormatException('Bitcoin replacement intent mismatch');
        }
        if (previous != null &&
            (!saved.plan.rbf ||
                saved.signed.feeSat <= previous.signed.feeSat ||
                saved.plan.feeRateSatVb <= previous.plan.feeRateSatVb)) {
          throw const FormatException('Bitcoin replacement fee mismatch');
        }
        previous = saved;
      }
    }
    return value;
  }

  Future<Map<String, BitcoinResolvedSubmission>> resolvedAliases(
    String identity,
    BitcoinProductNetwork network,
  ) => store.updateSubmissionState(identity, (raw) {
    final receipts = _decode(raw, identity)['resolved'] as Map<String, dynamic>;
    return (
      Map<String, BitcoinResolvedSubmission>.unmodifiable({
        for (final receipt in receipts.entries)
          if (receipt.key.startsWith('${network.id}|'))
            receipt.key.split('|').last: BitcoinResolvedSubmission._fromJson(
              receipt.value,
            ),
      }),
      null,
    );
  });

  Future<List<BitcoinPendingSubmission>> pending(
    String identity,
    BitcoinProductNetwork network,
  ) => store.updateSubmissionState(identity, (raw) {
    final value = _decode(raw, identity);
    final entries = value['entries'] as Map<String, dynamic>;
    final legacy = value['legacyEntries'] as List;
    final outbound = value['outbound'] as Map<String, dynamic>;
    return (
      List.unmodifiable([
        for (final entry in entries.entries)
          if (entry.key.startsWith('${network.id}|'))
            for (final id
                in outbound[entry.key] == null
                    ? [entry.key.split('|').last]
                    : (outbound[entry.key]['chain'] as List))
              BitcoinPendingSubmission._(
                store.secureStore,
                identity.toLowerCase(),
                network,
                id as String,
                List<String>.from(entry.value),
                legacy.contains(entry.key),
                store.submissionRevision(identity),
                rootTxid: entry.key.split('|').last,
                active:
                    outbound[entry.key] == null ||
                    id == (outbound[entry.key]['chain'] as List).last,
                transaction: outbound[entry.key] == null
                    ? null
                    : BitcoinSavedTransaction.fromJson(
                        outbound[entry.key]['records'][id],
                      ),
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
      final key = '${snapshot.network.id}|${snapshot.rootTxid}';
      final outbound = value['outbound'] as Map<String, dynamic>;
      final chain = outbound[key]?['chain'] as List?;
      final actual = entries[key];
      if (actual is! List ||
          actual.length != snapshot.inputs.length ||
          !actual.toSet().containsAll(snapshot.inputs) ||
          legacy.contains(key) != snapshot.legacy ||
          (chain == null
              ? snapshot.txid != snapshot.rootTxid
              : !chain.contains(snapshot.txid)) ||
          _liveOwners.containsKey(
            _ownerKey(
              snapshot.walletIdentity,
              snapshot.network,
              snapshot.rootTxid,
            ),
          )) {
        return (false, null);
      }
      if (chain != null && chain.length > 1 && snapshot.transaction != null) {
        final receipts = value['resolved'] as Map<String, dynamic>;
        final winner = BitcoinResolvedSubmission._(
          snapshot.txid,
          snapshot.transaction!.signed.feeSat,
          snapshot.transaction!.plan.recipientTotalSat,
        );
        for (final candidate in chain) {
          if (candidate != snapshot.txid) {
            receipts['${snapshot.network.id}|$candidate'] = winner._toJson();
          }
        }
        // Bound display-only history; pending input reservations are never evicted.
        while (receipts.length > 4096) {
          receipts.remove(receipts.keys.first);
        }
      }
      entries.remove(key);
      legacy.remove(key);
      outbound.remove(key);
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
    List<BitcoinUtxoDto> inputs, {
    BitcoinSavedTransaction? transaction,
  }) async {
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
          (value['resolved'] as Map<String, dynamic>).remove(key);
          if (transaction != null) {
            (value['outbound'] as Map<String, dynamic>)[key] = {
              'chain': [txid],
              'records': {txid: transaction.toJson()},
            };
          }
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

  void _replacementSnapshot(
    Map<String, dynamic> value,
    BitcoinPendingSubmission snapshot,
  ) {
    if (!identical(snapshot._store, store.secureStore) ||
        snapshot.transaction == null ||
        snapshot.legacy ||
        !snapshot.active ||
        !identical(
          snapshot._revision,
          store.submissionRevision(snapshot.walletIdentity),
        )) {
      throw StateError('Bitcoin replacement snapshot changed');
    }
    final key = '${snapshot.network.id}|${snapshot.rootTxid}';
    final actual = (value['entries'] as Map<String, dynamic>)[key];
    final outbound = (value['outbound'] as Map<String, dynamic>)[key];
    if (actual is! List ||
        actual.length != snapshot.inputs.length ||
        !actual.toSet().containsAll(snapshot.inputs) ||
        outbound == null ||
        (outbound['chain'] as List).last != snapshot.txid ||
        jsonEncode(outbound['records'][snapshot.txid]) !=
            jsonEncode(snapshot.transaction!.toJson()) ||
        _liveOwners.containsKey(
          _ownerKey(
            snapshot.walletIdentity,
            snapshot.network,
            snapshot.rootTxid,
          ),
        )) {
      throw StateError('Bitcoin replacement snapshot changed');
    }
  }

  Future<void> validateReplacement(BitcoinPendingSubmission snapshot) =>
      store.updateSubmissionState(snapshot.walletIdentity, (raw) {
        _replacementSnapshot(_decode(raw, snapshot.walletIdentity), snapshot);
        return (null, null);
      });

  /// One exact input reservation covers all replacement candidates. A rejection
  /// restores its parent; confirmation of either candidate reconciles the root.
  Future<BitcoinSubmissionReservation> reserveReplacementAttempt(
    BitcoinPendingSubmission snapshot,
    BitcoinSavedTransaction replacement,
  ) async {
    final ownerKey = _ownerKey(
      snapshot.walletIdentity,
      snapshot.network,
      snapshot.rootTxid,
    );
    BitcoinSubmissionReservation? created;
    try {
      return await store.updateSubmissionState(snapshot.walletIdentity, (raw) {
        final value = _decode(raw, snapshot.walletIdentity);
        _replacementSnapshot(value, snapshot);
        final key = '${snapshot.network.id}|${snapshot.rootTxid}';
        final outbound = (value['outbound'] as Map<String, dynamic>)[key];
        final chain = outbound['chain'] as List;
        if (chain.length >= 32 || chain.contains(replacement.signed.txid)) {
          throw StateError('Bitcoin replacement requires reconciliation');
        }
        chain.add(replacement.signed.txid);
        (value['resolved'] as Map<String, dynamic>).remove(
          '${snapshot.network.id}|${replacement.signed.txid}',
        );
        (outbound['records'] as Map<String, dynamic>)[replacement.signed.txid] =
            replacement.toJson();
        final encoded = jsonEncode(value);
        _decode(encoded, snapshot.walletIdentity);
        created = BitcoinSubmissionReservation._(
          store.secureStore,
          snapshot.walletIdentity,
          snapshot.network,
          replacement.signed.txid,
          snapshot.inputs,
          rootTxid: snapshot.rootTxid,
          previousTxid: snapshot.txid,
        );
        _liveOwners[ownerKey] = created!._owner;
        return (created!, encoded);
      });
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
    final ownerKey = _ownerKey(identity, network, reservation._rootTxid);
    final released = await store.updateSubmissionState<bool>(identity, (raw) {
      if (reservation._released) return (false, null);
      if (!identical(_liveOwners[ownerKey], reservation._owner)) {
        throw StateError('Bitcoin reservation is not owned by this attempt');
      }
      final value = _decode(raw, identity);
      final entries = value['entries'] as Map<String, dynamic>;
      final key = '${network.id}|${reservation._rootTxid}';
      final stored = entries[key];
      if (stored == null) return (false, null);
      final actual = List<String>.from(stored).toSet();
      if (actual.length != expected.length || !actual.containsAll(expected)) {
        throw StateError('Bitcoin reservation input mismatch');
      }
      final outbound = value['outbound'] as Map<String, dynamic>;
      if (reservation._previousTxid == null) {
        entries.remove(key);
        (value['legacyEntries'] as List).remove(key);
        outbound.remove(key);
      } else {
        final data = outbound[key];
        if (data == null) {
          throw StateError('Bitcoin replacement lineage changed');
        }
        final chain = data['chain'] as List;
        if (chain.length < 2 ||
            chain.last != txid ||
            chain[chain.length - 2] != reservation._previousTxid) {
          throw StateError('Bitcoin replacement lineage changed');
        }
        chain.removeLast();
        (data['records'] as Map<String, dynamic>).remove(txid);
      }
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
      reservation._rootTxid,
    );
    if (identical(_liveOwners[key], reservation._owner)) {
      _liveOwners.remove(key);
    }
  }
}
