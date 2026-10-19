import 'dart:async';
import 'dart:convert';
import '../models/evm_outbound_transaction.dart';
import 'secure_store.dart';

class _Queue {
  Future<void> tail = Future.value();
  Object revision = Object();
  int generation = 0;
  bool removed = false;
  Future<T> run<T>(Future<T> Function() action, {bool removal = false}) {
    final epoch = generation;
    final result = tail.then((_) {
      if (epoch != generation || removed && !removal) {
        throw const EvmReplacementException('Wallet context changed');
      }
      return action();
    });
    tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

class EvmOutboundSnapshot {
  final EvmOutboundTransaction transaction;
  final EvmOutboundStore _owner;
  final Object _revision;
  EvmOutboundSnapshot._(this.transaction, this._owner, this._revision);
}

class EvmOutboundReservation {
  final EvmOutboundTransaction transaction;
  final EvmOutboundStore _owner;
  final _Queue _queue;
  final int _generation;
  bool _providerStarted = false;
  bool _finished = false;
  EvmOutboundReservation._(this.transaction, this._owner, this._queue)
    : _generation = _queue.generation;
}

/// One protected value per sender, shared serialized mutation across wrappers.
/// Unknown outcomes are retained; time or a missing transaction never clears them.
class EvmOutboundStore {
  final SecureStore secureStore;
  EvmOutboundStore(this.secureStore);
  static final Expando<Map<String, _Queue>> _queues = Expando();
  Map<String, _Queue> get _all => _queues[secureStore] ??= {};
  String _sender(String value) {
    final sender = value.trim().toLowerCase();
    if (!RegExp(r'^0x[0-9a-f]{40}$').hasMatch(sender)) {
      throw const EvmReplacementException('Invalid wallet identity');
    }
    return sender;
  }

  _Queue _queue(String sender) => _all.putIfAbsent(_sender(sender), _Queue.new);
  String _key(String sender) => 'evm_outbound_v1_${_sender(sender)}';
  Future<List<EvmOutboundTransaction>> _read(String sender) async {
    final String? raw;
    try {
      raw = await secureStore.read(key: _key(sender));
    } catch (_) {
      throw const EvmReplacementException(
        'Protected outbound storage unavailable',
      );
    }
    if (raw == null) return [];
    if (raw.length > 4 * 1024 * 1024) {
      throw const EvmReplacementException(
        'Outbound history exceeds storage limit',
      );
    }
    Object? data;
    try {
      data = jsonDecode(raw);
    } catch (_) {
      throw const EvmReplacementException('Invalid protected outbound history');
    }
    if (data is! Map<String, dynamic> ||
        data.length != 2 ||
        data['version'] is! int ||
        data['version'] != 1 ||
        data['transactions'] is! List ||
        (data['transactions'] as List).length > 1024) {
      throw const EvmReplacementException('Invalid protected outbound history');
    }
    final entries = (data['transactions'] as List)
        .map(EvmOutboundTransaction.fromJson)
        .toList();
    if (entries.any((entry) => entry.fields.sender != _sender(sender)) ||
        entries.map((e) => e.hash).toSet().length != entries.length) {
      throw const EvmReplacementException('Invalid protected outbound history');
    }
    for (final entry in entries.where((entry) => entry.unresolved)) {
      if (entries.any(
        (other) =>
            other.unresolved &&
            other.fields.chainId == entry.fields.chainId &&
            other.fields.nonce == entry.fields.nonce &&
            other.rootHash != entry.rootHash,
      )) {
        throw const EvmReplacementException(
          'Conflicting outbound nonce records',
        );
      }
      if (entry.replacesHash != null &&
          !entries.any(
            (parent) =>
                parent.hash == entry.replacesHash &&
                parent.rootHash == entry.rootHash &&
                parent.fields.chainId == entry.fields.chainId &&
                parent.fields.nonce == entry.fields.nonce &&
                parent.unresolved,
          )) {
        throw const EvmReplacementException('Invalid replacement lineage');
      }
    }
    return entries;
  }

  Future<void> _write(
    String sender,
    List<EvmOutboundTransaction> entries,
  ) async {
    if (entries.length > 1024) {
      throw const EvmReplacementException('Too many unresolved transactions');
    }
    final encoded = jsonEncode({
      'version': 1,
      'transactions': entries.map((e) => e.toJson()).toList(),
    });
    if (encoded.length > 4 * 1024 * 1024) {
      throw const EvmReplacementException(
        'Outbound history exceeds storage limit',
      );
    }
    _queue(sender).revision = Object();
    final String? persisted;
    try {
      await secureStore.write(key: _key(sender), value: encoded);
      persisted = await secureStore.read(key: _key(sender));
    } catch (_) {
      throw const EvmReplacementException(
        'Protected outbound storage unavailable',
      );
    }
    // A silent/dropped write cannot authorize broadcast.
    if (persisted != encoded) {
      throw const EvmReplacementException(
        'Unable to persist outbound transaction',
      );
    }
    if (_queue(sender).removed) {
      throw const EvmReplacementException('Wallet context changed');
    }
  }

  Future<List<EvmOutboundTransaction>> list(String sender) =>
      _queue(sender).run(() async => List.unmodifiable(await _read(sender)));
  Future<EvmOutboundSnapshot?> snapshot(
    String sender,
    int chainId,
    String hash,
  ) => _queue(sender).run(() async {
    final entries = await _read(sender);
    final matches = entries.where(
      (e) => e.fields.chainId == chainId && e.hash == hash.toLowerCase(),
    );
    return matches.isEmpty
        ? null
        : EvmOutboundSnapshot._(matches.single, this, _queue(sender).revision);
  });
  void _check(
    EvmOutboundSnapshot snapshot,
    List<EvmOutboundTransaction> entries,
  ) {
    final original = snapshot.transaction;
    final sender = original.fields.sender;
    final same = entries.where((entry) => entry.hash == original.hash);
    if (!identical(snapshot._owner.secureStore, secureStore) ||
        !identical(snapshot._revision, _queue(sender).revision) ||
        same.length != 1 ||
        jsonEncode(same.single.toJson()) != jsonEncode(original.toJson()) ||
        !original.unresolved ||
        entries.any(
          (entry) =>
              entry.rootHash == original.rootHash &&
              entry.replacesHash == original.hash &&
              entry.unresolved,
        )) {
      throw const EvmReplacementException(
        'The saved transaction changed. Review it again.',
      );
    }
  }

  Future<void> validate(EvmOutboundSnapshot snapshot) =>
      _queue(snapshot.transaction.fields.sender).run(
        () async =>
            _check(snapshot, await _read(snapshot.transaction.fields.sender)),
      );
  Future<EvmOutboundReservation> reserve(
    EvmOutboundTransaction entry, {
    EvmOutboundSnapshot? replacing,
    int? confirmedNonce,
  }) => _queue(entry.fields.sender).run(() async {
    var entries = await _read(entry.fields.sender);
    if (entry.state != EvmOutboundState.unknown ||
        entries.any((e) => e.hash == entry.hash)) {
      throw const EvmReplacementException('Transaction already recorded');
    }
    if (replacing != null) {
      _check(replacing, entries);
      final original = replacing.transaction;
      if (entry.replacesHash != original.hash ||
          entry.rootHash != original.rootHash ||
          entry.fields.sender != original.fields.sender ||
          entry.fields.chainId != original.fields.chainId ||
          entry.fields.nonce != original.fields.nonce) {
        throw const EvmReplacementException(
          'Replacement identity does not match',
        );
      }
    } else {
      if (entry.replacesHash != null || entry.rootHash != entry.hash) {
        throw const EvmReplacementException('Invalid original transaction');
      }
      if (confirmedNonce != null) {
        if (confirmedNonce < 0 || confirmedNonce > entry.fields.nonce) {
          throw const EvmReplacementException('Invalid confirmed nonce');
        }
        entries = entries
            .map(
              (old) =>
                  old.fields.chainId == entry.fields.chainId &&
                      old.fields.nonce < confirmedNonce &&
                      old.unresolved
                  ? old.withState(EvmOutboundState.settled)
                  : old,
            )
            .toList();
      }
      if (entries.any(
        (old) =>
            old.fields.chainId == entry.fields.chainId &&
            old.fields.nonce == entry.fields.nonce &&
            old.unresolved,
      )) {
        throw const EvmReplacementException(
          'An earlier submission already reserves this nonce. Check its outcome.',
        );
      }
    }
    final terminal = entries.where((old) => !old.unresolved).toList();
    final discard = terminal.length > 128
        ? terminal.take(terminal.length - 128).map((e) => e.hash).toSet()
        : <String>{};
    entries.removeWhere((old) => discard.contains(old.hash));
    await _write(entry.fields.sender, [...entries, entry]);
    return EvmOutboundReservation._(entry, this, _queue(entry.fields.sender));
  });

  /// Seals the no-provider abort capability immediately before the RPC send.
  void beginProviderSend(EvmOutboundReservation reservation) {
    final queue = _queue(reservation.transaction.fields.sender);
    if (!identical(reservation._owner.secureStore, secureStore) ||
        !identical(reservation._queue, queue) ||
        reservation._generation != queue.generation ||
        queue.removed ||
        reservation._finished ||
        reservation._providerStarted) {
      throw const EvmReplacementException('Invalid broadcast reservation');
    }
    reservation._providerStarted = true;
  }

  Future<void> submitted(
    EvmOutboundReservation reservation,
    String providerHash,
  ) async {
    if (providerHash.toLowerCase() != reservation.transaction.hash) {
      throw const EvmReplacementException(
        'Broadcast returned an unexpected transaction ID',
      );
    }
    await _mark(reservation, EvmOutboundState.submitted);
  }

  /// Only the live broadcasting adapter uses this after proving no RPC send began.
  Future<void> rejectedBeforeProvider(EvmOutboundReservation reservation) =>
      _mark(reservation, EvmOutboundState.rejected);
  Future<void> _mark(
    EvmOutboundReservation reservation,
    EvmOutboundState state,
  ) => _queue(reservation.transaction.fields.sender).run(() async {
    final entry = reservation.transaction;
    if (reservation._finished ||
        (state == EvmOutboundState.rejected
            ? reservation._providerStarted
            : !reservation._providerStarted)) {
      throw const EvmReplacementException(
        'Broadcast reservation cannot authorize this transition',
      );
    }
    final queue = _queue(entry.fields.sender);
    if (!identical(reservation._owner.secureStore, secureStore) ||
        !identical(reservation._queue, queue) ||
        reservation._generation != queue.generation) {
      throw const EvmReplacementException('Wallet context changed');
    }
    final entries = await _read(entry.fields.sender);
    final index = entries.indexWhere(
      (old) =>
          old.hash == entry.hash &&
          old.fields.sameAs(entry.fields) &&
          old.rootHash == entry.rootHash &&
          old.replacesHash == entry.replacesHash,
    );
    if (index < 0 || !entries[index].unresolved) {
      throw const EvmReplacementException('Saved transaction changed');
    }
    if (state == EvmOutboundState.rejected &&
        entries.any(
          (child) => child.replacesHash == entry.hash && child.unresolved,
        )) {
      throw const EvmReplacementException(
        'Replacement still reserves this nonce',
      );
    }
    entries[index] = entries[index].withState(state);
    await _write(entry.fields.sender, entries);
    reservation._finished = true;
  });
  // Called only after opening verified custody for this sender.
  Future<void> activate(String sender) async {
    final queue = _queue(sender);
    if (!queue.removed) return;
    await queue.tail;
    queue.generation++;
    queue.revision = Object();
    queue.removed = false;
  }

  Future<void> invalidateAllAndDrain() async {
    invalidateAll();
    await Future.wait(_all.values.map((queue) => queue.tail));
  }

  Future<void> deleteWallet(String sender) async {
    final queue = _queue(sender);
    queue.generation++;
    queue.revision = Object();
    queue.removed = true;
    await queue.run(() => secureStore.delete(key: _key(sender)), removal: true);
  }

  void invalidateAll() {
    for (final queue in _all.values) {
      queue.generation++;
      queue.revision = Object();
      queue.removed = true;
    }
  }
}
