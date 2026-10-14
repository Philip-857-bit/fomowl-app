import 'dart:convert';
import 'dart:math';
import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_network_data.dart';
import '../../models/bitcoin_offramp_intent.dart';
import 'bitcoin_account_store.dart';
import 'bitcoin_network_service.dart';
import 'bitcoin_submission_journal.dart';

/// Public payment metadata; this object never grants signing authorization.
class BitcoinOfframpSubmission {
  final Object _store;
  final String walletIdentity;
  final BitcoinOfframpIntent intent;
  final String txid;
  final String _attemptId;
  final bool accepted;
  const BitcoinOfframpSubmission._(
    this._store,
    this.walletIdentity,
    this.intent,
    this.txid,
    this._attemptId,
    this.accepted,
  );
  Map<String, dynamic> _json() => {
    'reference': intent.reference,
    'destination': intent.destination,
    'amountSat': intent.amountSat.toString(),
    'networkKey': intent.network.networkKey,
    'txid': txid,
    'attemptId': _attemptId,
    'accepted': accepted,
    'fundingExpiresAt': intent.fundingExpiresAt.toIso8601String(),
  };
}

/// Nonpersistent rejection capability belonging to one live reserve call.
class BitcoinOfframpAttempt {
  final BitcoinOfframpJournal _owner;
  final BitcoinOfframpSubmission submission;
  bool _live = true;
  BitcoinOfframpAttempt._(this._owner, this.submission);
}

/// Blocks another payment for a reference across restart and wrapper instances.
/// Does not clear UTXO reservations or retry a transaction broadcast.
class BitcoinOfframpJournal {
  final BitcoinAccountStore store;
  BitcoinOfframpJournal(this.store);

  String _identity(String value) {
    final identity = value.trim().toLowerCase();
    if (identity.isEmpty || identity.length > 128) {
      throw const FormatException('Invalid Bitcoin cash-out identity');
    }
    return identity;
  }

  List<BitcoinOfframpSubmission> _decode(String identity, String? encoded) {
    if (encoded == null) return [];
    if (encoded.length > 131072) {
      throw const FormatException('Invalid Bitcoin cash-out journal');
    }
    Object? raw;
    try {
      raw = jsonDecode(encoded);
    } catch (_) {
      throw const FormatException('Invalid Bitcoin cash-out journal');
    }
    if (raw is! Map<String, dynamic> ||
        raw.length != 3 ||
        raw['version'] is! int ||
        raw['version'] != 1 ||
        raw['walletIdentity'] != identity ||
        raw['attempts'] is! List ||
        (raw['attempts'] as List).length > 256) {
      throw const FormatException('Invalid Bitcoin cash-out journal');
    }
    final references = <String>{};
    final result = <BitcoinOfframpSubmission>[];
    for (final entry in raw['attempts'] as List) {
      if (entry is! Map<String, dynamic> ||
          entry.length != 8 ||
          entry['reference'] is! String ||
          entry['attemptId'] is! String ||
          !RegExp(r'^[0-9a-f]{32}$').hasMatch(entry['attemptId'] as String) ||
          entry['accepted'] is! bool ||
          !references.add(entry['reference'] as String)) {
        throw const FormatException('Invalid Bitcoin cash-out journal');
      }
      final intent = BitcoinOfframpIntent.fromWithdrawalPlan(
        entry['reference'] as String,
        {
          'reference': entry['reference'],
          'toAddress': entry['destination'],
          'amountBaseUnits': entry['amountSat'],
          'networkKey': entry['networkKey'],
          'chainFamily': 'bitcoin',
          'assetSymbol': 'BTC',
          'nativeSymbol': 'BTC',
          'decimals': 8,
          'action': 'transfer',
          'fundingExpiresAt': entry['fundingExpiresAt'],
        },
      );
      result.add(
        BitcoinOfframpSubmission._(
          store.secureStore,
          identity,
          intent,
          bitcoinTxid(entry['txid']),
          entry['attemptId'] as String,
          entry['accepted'] as bool,
        ),
      );
    }
    return result;
  }

  String _encode(String identity, List<BitcoinOfframpSubmission> entries) =>
      jsonEncode({
        'version': 1,
        'walletIdentity': identity,
        'attempts': entries.map((entry) => entry._json()).toList(),
      });

  Future<BitcoinOfframpSubmission?> read(
    String walletIdentity,
    String reference,
  ) {
    final identity = _identity(walletIdentity);
    return store.updateOfframpState(identity, (encoded) {
      final entries = _decode(identity, encoded);
      final matches = entries.where(
        (entry) => entry.intent.reference == reference,
      );
      return (matches.isEmpty ? null : matches.single, null);
    });
  }

  Future<BitcoinOfframpAttempt> reserve(
    String walletIdentity,
    BitcoinOfframpIntent intent,
    String txid,
  ) {
    final identity = _identity(walletIdentity);
    final hash = bitcoinTxid(txid);
    return store.updateOfframpState(identity, (encoded) {
      final entries = _decode(identity, encoded);
      if (entries.any((entry) => entry.intent.reference == intent.reference)) {
        throw StateError(
          'This Bitcoin cash-out has an unresolved or submitted payment',
        );
      }
      if (entries.length >= 256) {
        throw StateError('Bitcoin cash-out history needs reconciliation');
      }
      final random = Random.secure();
      final nonce = List.generate(
        16,
        (_) => random.nextInt(256),
      ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      final submission = BitcoinOfframpSubmission._(
        store.secureStore,
        identity,
        intent,
        hash,
        nonce,
        false,
      );
      entries.add(submission);
      return (
        BitcoinOfframpAttempt._(this, submission),
        _encode(identity, entries),
      );
    });
  }

  void retainPending(BitcoinOfframpAttempt attempt) {
    if (identical(attempt._owner, this)) attempt._live = false;
  }

  Future<void> markAccepted(BitcoinOfframpAttempt attempt) {
    if (!identical(attempt._owner, this) || !attempt._live) {
      throw StateError('Bitcoin cash-out attempt is no longer live');
    }
    attempt._live = false;
    final saved = attempt.submission;
    return store.updateOfframpState(saved.walletIdentity, (encoded) {
      final entries = _decode(saved.walletIdentity, encoded);
      final index = entries.indexWhere((entry) => _same(entry, saved));
      if (index < 0) throw StateError('Bitcoin cash-out state changed');
      entries[index] = BitcoinOfframpSubmission._(
        saved._store,
        saved.walletIdentity,
        saved.intent,
        saved.txid,
        saved._attemptId,
        true,
      );
      return (null, _encode(saved.walletIdentity, entries));
    });
  }

  /// Only the broadcaster's recognized, definitive pre-provider rejection.
  Future<bool> releaseRejected(
    BitcoinOfframpAttempt attempt,
    BitcoinPreProviderRejection evidence,
  ) {
    if (!identical(attempt._owner, this) || !attempt._live) {
      return Future.value(false);
    }
    attempt._live = false;
    final saved = attempt.submission;
    return store.updateOfframpState(saved.walletIdentity, (encoded) {
      final entries = _decode(saved.walletIdentity, encoded);
      final index = entries.indexWhere((entry) => _same(entry, saved));
      if (index < 0 || entries[index].accepted) return (false, null);
      entries.removeAt(index);
      return (true, _encode(saved.walletIdentity, entries));
    });
  }

  /// Backend acknowledgement and exact positive chain confirmation are both
  /// supplied by the host observer, never by mini-app request fields.
  Future<bool> reconcileConfirmed(
    BitcoinOfframpSubmission saved, {
    required BitcoinProductNetwork network,
    required String observedTxid,
    required BitcoinTransactionStatus status,
    required bool backendAcknowledged,
    BitcoinVerifiedResolvedPayment? replacementProof,
  }) {
    final observed = bitcoinTxid(observedTxid);
    final replacement = replacementProof?.transaction;
    final verifiedReplacement =
        replacementProof != null &&
        replacementProof.belongsTo(
          store.secureStore,
          saved.walletIdentity,
          saved.intent.network,
          saved.txid,
        ) &&
        replacement!.signed.txid == observed &&
        replacement.plan.recipients.length == 1 &&
        replacement.plan.recipients.single.address ==
            saved.intent.destination &&
        replacement.plan.recipients.single.amountSat ==
            saved.intent.amountSat &&
        replacement.plan.recipientTotalSat == saved.intent.amountSat;
    if (!identical(saved._store, store.secureStore) ||
        network != saved.intent.network ||
        observed != saved.txid && !verifiedReplacement ||
        !backendAcknowledged ||
        !status.found ||
        !status.confirmed ||
        status.confirmations < 1) {
      return Future.value(false);
    }
    return store.updateOfframpState(saved.walletIdentity, (encoded) {
      final entries = _decode(saved.walletIdentity, encoded);
      final index = entries.indexWhere((entry) => _same(entry, saved));
      if (index < 0) return (false, null);
      entries.removeAt(index);
      return (true, _encode(saved.walletIdentity, entries));
    });
  }

  bool _same(BitcoinOfframpSubmission left, BitcoinOfframpSubmission right) =>
      left.walletIdentity == right.walletIdentity &&
      left.intent.matches(right.intent) &&
      left.txid == right.txid &&
      left._attemptId == right._attemptId;
}
