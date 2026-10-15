import 'dart:convert';
import 'dart:math';
import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_network_data.dart';
import '../../models/bitcoin_bill_funding_plan.dart';
import 'bitcoin_account_store.dart';
import 'bitcoin_network_service.dart';
import 'bitcoin_submission_journal.dart';

/// Public payment metadata; this object never grants signing authorization.
class BitcoinBillFundingSubmission {
  final Object _store;
  final String walletIdentity;
  final BitcoinBillFundingPlan intent;
  final String txid;
  final String _attemptId;
  final bool accepted;
  const BitcoinBillFundingSubmission._(
    this._store,
    this.walletIdentity,
    this.intent,
    this.txid,
    this._attemptId,
    this.accepted,
  );
  Map<String, dynamic> _json() => {
    'reference': intent.reference,
    'invoice': intent.toServerJson(),
    'txid': txid,
    'attemptId': _attemptId,
    'accepted': accepted,
  };
}

/// Nonpersistent rejection capability belonging to one live reserve call.
class BitcoinBillFundingAttempt {
  final BitcoinBillFundingJournal _owner;
  final BitcoinBillFundingSubmission submission;
  bool _live = true;
  BitcoinBillFundingAttempt._(this._owner, this.submission);
}

/// Blocks another payment for a reference across restart and wrapper instances.
/// Does not clear UTXO reservations or retry a transaction broadcast.
class BitcoinBillFundingJournal {
  final BitcoinAccountStore store;
  BitcoinBillFundingJournal(this.store);

  String _identity(String value) {
    final identity = value.trim().toLowerCase();
    if (identity.isEmpty || identity.length > 128) {
      throw const FormatException('Invalid Bitcoin bill payment identity');
    }
    return identity;
  }

  List<BitcoinBillFundingSubmission> _decode(String identity, String? encoded) {
    if (encoded == null) return [];
    if (encoded.length > 131072) {
      throw const FormatException('Invalid Bitcoin bill payment journal');
    }
    Object? raw;
    try {
      raw = jsonDecode(encoded);
    } catch (_) {
      throw const FormatException('Invalid Bitcoin bill payment journal');
    }
    if (raw is! Map<String, dynamic> ||
        raw.length != 3 ||
        raw['version'] is! int ||
        raw['version'] != 1 ||
        raw['walletIdentity'] != identity ||
        raw['attempts'] is! List ||
        (raw['attempts'] as List).length > 256) {
      throw const FormatException('Invalid Bitcoin bill payment journal');
    }
    final references = <String>{};
    final result = <BitcoinBillFundingSubmission>[];
    for (final entry in raw['attempts'] as List) {
      if (entry is! Map<String, dynamic> ||
          entry.length != 5 ||
          entry['reference'] is! String ||
          entry['invoice'] is! Map<String, dynamic> ||
          entry['attemptId'] is! String ||
          !RegExp(r'^[0-9a-f]{32}$').hasMatch(entry['attemptId'] as String) ||
          entry['accepted'] is! bool ||
          !references.add(entry['reference'] as String)) {
        throw const FormatException('Invalid Bitcoin bill payment journal');
      }
      final intent = BitcoinBillFundingPlan.fromServer(
        entry['reference'] as String,
        identity,
        entry['invoice'] as Map<String, dynamic>,
      );
      result.add(
        BitcoinBillFundingSubmission._(
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

  String _encode(String identity, List<BitcoinBillFundingSubmission> entries) =>
      jsonEncode({
        'version': 1,
        'walletIdentity': identity,
        'attempts': entries.map((entry) => entry._json()).toList(),
      });

  Future<BitcoinBillFundingSubmission?> read(
    String walletIdentity,
    String reference,
  ) {
    final identity = _identity(walletIdentity);
    return store.updateBillState(identity, (encoded) {
      final entries = _decode(identity, encoded);
      final matches = entries.where(
        (entry) => entry.intent.reference == reference,
      );
      return (matches.isEmpty ? null : matches.single, null);
    });
  }

  Future<BitcoinBillFundingAttempt> reserve(
    String walletIdentity,
    BitcoinBillFundingPlan intent,
    String txid,
  ) {
    final identity = _identity(walletIdentity);
    if (intent.walletIdentity != identity) {
      throw StateError('Bitcoin bill wallet identity changed');
    }
    final hash = bitcoinTxid(txid);
    return store.updateBillState(identity, (encoded) {
      final entries = _decode(identity, encoded);
      if (entries.any((entry) => entry.intent.reference == intent.reference)) {
        throw StateError(
          'This Bitcoin bill payment has an unresolved or submitted payment',
        );
      }
      if (entries.length >= 256) {
        throw StateError('Bitcoin bill payment history needs reconciliation');
      }
      final random = Random.secure();
      final nonce = List.generate(
        16,
        (_) => random.nextInt(256),
      ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      final submission = BitcoinBillFundingSubmission._(
        store.secureStore,
        identity,
        intent,
        hash,
        nonce,
        false,
      );
      entries.add(submission);
      return (
        BitcoinBillFundingAttempt._(this, submission),
        _encode(identity, entries),
      );
    });
  }

  void retainPending(BitcoinBillFundingAttempt attempt) {
    if (identical(attempt._owner, this)) attempt._live = false;
  }

  Future<void> markAccepted(BitcoinBillFundingAttempt attempt) {
    if (!identical(attempt._owner, this) || !attempt._live) {
      throw StateError('Bitcoin bill payment attempt is no longer live');
    }
    attempt._live = false;
    final saved = attempt.submission;
    return store.updateBillState(saved.walletIdentity, (encoded) {
      final entries = _decode(saved.walletIdentity, encoded);
      final index = entries.indexWhere((entry) => _same(entry, saved));
      if (index < 0) throw StateError('Bitcoin bill payment state changed');
      entries[index] = BitcoinBillFundingSubmission._(
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
    BitcoinBillFundingAttempt attempt,
    BitcoinPreProviderRejection evidence,
  ) {
    if (!identical(attempt._owner, this) || !attempt._live) {
      return Future.value(false);
    }
    attempt._live = false;
    final saved = attempt.submission;
    return store.updateBillState(saved.walletIdentity, (encoded) {
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
    BitcoinBillFundingSubmission saved, {
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
    return store.updateBillState(saved.walletIdentity, (encoded) {
      final entries = _decode(saved.walletIdentity, encoded);
      final index = entries.indexWhere((entry) => _same(entry, saved));
      if (index < 0) return (false, null);
      entries.removeAt(index);
      return (true, _encode(saved.walletIdentity, entries));
    });
  }

  bool _same(
    BitcoinBillFundingSubmission left,
    BitcoinBillFundingSubmission right,
  ) =>
      left.walletIdentity == right.walletIdentity &&
      left.intent.matches(right.intent) &&
      left.txid == right.txid &&
      left._attemptId == right._attemptId;
}
