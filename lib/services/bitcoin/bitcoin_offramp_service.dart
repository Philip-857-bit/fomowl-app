import '../../models/bitcoin_offramp_intent.dart';
import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_network_data.dart';
import 'bitcoin_broadcast_service.dart';
import 'bitcoin_network_service.dart';
import 'bitcoin_offramp_journal.dart';
import 'bitcoin_send_service.dart';
import 'bitcoin_signing_service.dart';
import 'bitcoin_submission_journal.dart';

abstract interface class BitcoinOfframpExecutor {
  Future<BitcoinBroadcastOutcome> execute(
    BitcoinPreparedTransfer transfer, {
    required Future<bool> Function() authenticate,
    required bool Function() isCurrent,
    required Future<void> Function(String txid) beforeBroadcast,
  });
}

/// Production execution always uses existing opaque Rust signing and verified
/// broadcast. The port permits deterministic host tests without fixture keys.
class NativeBitcoinOfframpExecutor implements BitcoinOfframpExecutor {
  final BitcoinSigningService signing;
  final BitcoinBroadcastService broadcast;
  NativeBitcoinOfframpExecutor({
    required this.signing,
    required this.broadcast,
  });
  @override
  Future<BitcoinBroadcastOutcome> execute(
    BitcoinPreparedTransfer transfer, {
    required Future<bool> Function() authenticate,
    required bool Function() isCurrent,
    required Future<void> Function(String txid) beforeBroadcast,
  }) async {
    final signed = await signing.sign(
      transfer,
      authenticate: authenticate,
      isCurrent: isCurrent,
    );
    signed.checkAuthorization();
    await beforeBroadcast(signed.transaction.txid);
    return broadcast.broadcast(signed, isCurrent: isCurrent);
  }
}

class BitcoinPreparedOfframp {
  final BitcoinOfframpService _owner;
  final String walletIdentity;
  final BitcoinOfframpIntent intent;
  final BitcoinPreparedTransfer transfer;
  final DateTime _expiresAt;
  BitcoinPreparedOfframp._(
    this._owner,
    this.walletIdentity,
    this.intent,
    this.transfer,
    this._expiresAt,
  );
}

class BitcoinOfframpPaymentResult {
  final BitcoinBroadcastOutcome outcome;
  final bool backendAcknowledged;
  const BitcoinOfframpPaymentResult(this.outcome, this.backendAcknowledged);
}

class BitcoinOfframpRecoveryResult {
  final String observedTxid;
  final BitcoinOfframpSubmission submission;
  final BitcoinTransactionStatus status;
  final bool backendAcknowledged;
  const BitcoinOfframpRecoveryResult(
    this.submission,
    this.status,
    this.backendAcknowledged,
    this.observedTxid,
  );
}

class BitcoinOfframpAlreadySubmitted implements Exception {
  final BitcoinOfframpSubmission submission;
  const BitcoinOfframpAlreadySubmitted(this.submission);
  @override
  String toString() => 'This Bitcoin cash-out already has a saved payment';
}

class BitcoinOfframpService {
  final BitcoinSendService planner;
  final BitcoinOfframpJournal journal;
  final BitcoinOfframpExecutor executor;
  final Future<BitcoinOfframpIntent> Function(String identity, String reference)
  fetchIntent;
  final Future<void> Function(String identity, String reference, String txid)
  acknowledge;
  final DateTime Function() _now;
  final Future<BitcoinTransactionStatus> Function(BitcoinProductNetwork, String)
  _fetchStatus;
  final Expando<Future<BitcoinOfframpPaymentResult>> _executions = Expando();

  factory BitcoinOfframpService({
    required Future<BitcoinOfframpIntent> Function(
      String identity,
      String reference,
    )
    fetchIntent,
    required Future<void> Function(
      String identity,
      String reference,
      String txid,
    )
    acknowledge,
    BitcoinSendService? planner,
    BitcoinOfframpExecutor? executor,
    DateTime Function()? now,
    Future<BitcoinTransactionStatus> Function(BitcoinProductNetwork, String)?
    fetchStatus,
  }) {
    final selected = planner ?? BitcoinSendService();
    return BitcoinOfframpService._(
      selected,
      fetchIntent,
      acknowledge,
      executor ??
          NativeBitcoinOfframpExecutor(
            signing: BitcoinSigningService(
              store: selected.store,
              crypto: selected.crypto,
            ),
            broadcast: BitcoinBroadcastService(network: selected.network),
          ),
      now ?? DateTime.now,
      fetchStatus ?? selected.network.fetchTransactionStatus,
    );
  }

  BitcoinOfframpService._(
    BitcoinSendService selected,
    this.fetchIntent,
    this.acknowledge,
    this.executor,
    this._now,
    this._fetchStatus,
  ) : planner = selected,
      journal = BitcoinOfframpJournal(selected.store);

  /// Read-only chain observation and idempotent bookkeeping. Never obtains a
  /// funding plan, authenticates a signer, releases uncertain inputs or sends BTC.
  Future<BitcoinOfframpRecoveryResult> recover(
    String walletIdentity,
    String reference, {
    required bool Function() isCurrent,
  }) async {
    final identity = walletIdentity.trim().toLowerCase();
    if (!BitcoinOfframpIntent.validReference(reference) || !isCurrent()) {
      throw StateError('Bitcoin cash-out context changed');
    }
    final saved = await journal.read(identity, reference);
    if (saved == null || !isCurrent()) {
      throw StateError('No saved Bitcoin cash-out payment');
    }
    final replacement = await BitcoinSubmissionJournal(
      planner.store,
    ).resolvedPayment(identity, saved.intent.network, saved.txid);
    if (!isCurrent()) throw StateError('Bitcoin cash-out context changed');
    if (replacement != null &&
        (replacement.transaction.plan.recipients.length != 1 ||
            replacement.transaction.plan.recipients.single.address !=
                saved.intent.destination ||
            replacement.transaction.plan.recipients.single.amountSat !=
                saved.intent.amountSat)) {
      throw StateError('Bitcoin cash-out replacement intent mismatch');
    }
    final observedTxid = replacement?.transaction.signed.txid ?? saved.txid;
    final status = await _fetchStatus(saved.intent.network, observedTxid);
    if (!isCurrent()) throw StateError('Bitcoin cash-out context changed');
    var acknowledged = false;
    if (saved.accepted || status.found) {
      try {
        await acknowledge(identity, reference, saved.txid);
        acknowledged = true;
      } catch (_) {
        // A failed callback leaves the exact durable guard in place.
      }
    }
    if (!isCurrent()) throw StateError('Bitcoin cash-out context changed');
    await journal.reconcileConfirmed(
      saved,
      network: saved.intent.network,
      observedTxid: observedTxid,
      status: status,
      backendAcknowledged: acknowledged,
      replacementProof: replacement,
    );
    return BitcoinOfframpRecoveryResult(
      saved,
      status,
      acknowledged,
      observedTxid,
    );
  }

  Future<BitcoinPreparedOfframp> prepare(
    String walletIdentity,
    String reference, {
    required bool Function() isCurrent,
  }) async {
    final identity = walletIdentity.trim().toLowerCase();
    if (!BitcoinOfframpIntent.validReference(reference)) {
      throw const FormatException('Invalid Bitcoin cash-out reference');
    }
    if (!isCurrent()) throw StateError('Bitcoin wallet context changed');
    final existing = await journal.read(identity, reference);
    if (existing != null) throw BitcoinOfframpAlreadySubmitted(existing);
    final intent = await fetchIntent(identity, reference);
    if (!isCurrent() ||
        intent.reference != reference ||
        !_now().isBefore(intent.fundingExpiresAt)) {
      throw StateError('Bitcoin cash-out intent changed');
    }
    final transfer = await planner.prepareTransfer(
      identity,
      intent.network,
      intent.destination,
      intent.amountSat,
      isCurrent: isCurrent,
    );
    final prepared = BitcoinPreparedOfframp._(
      this,
      identity,
      intent,
      transfer,
      _now().add(const Duration(minutes: 2)),
    );
    _check(prepared, isCurrent);
    return prepared;
  }

  void _check(BitcoinPreparedOfframp prepared, bool Function() isCurrent) {
    final transfer = prepared.transfer;
    if (!identical(prepared._owner, this) ||
        !isCurrent() ||
        !_now().isBefore(prepared._expiresAt) ||
        !_now().isBefore(prepared.intent.fundingExpiresAt) ||
        transfer.walletIdentity.trim().toLowerCase() !=
            prepared.walletIdentity ||
        transfer.network != prepared.intent.network ||
        transfer.plan.recipients.length != 1 ||
        transfer.plan.recipients.single.address !=
            prepared.intent.destination ||
        transfer.plan.recipients.single.amountSat !=
            prepared.intent.amountSat ||
        transfer.plan.recipientTotalSat != prepared.intent.amountSat) {
      throw StateError('Bitcoin cash-out approval changed or expired');
    }
  }

  Future<BitcoinOfframpPaymentResult> execute(
    BitcoinPreparedOfframp prepared, {
    required Future<bool> Function() authenticate,
    required bool Function() isCurrent,
  }) {
    _check(prepared, isCurrent);
    return _executions[prepared] ??= _execute(
      prepared,
      authenticate,
      isCurrent,
    );
  }

  Future<BitcoinOfframpPaymentResult> _execute(
    BitcoinPreparedOfframp prepared,
    Future<bool> Function() authenticate,
    bool Function() isCurrent,
  ) async {
    final identity = prepared.transfer.walletIdentity;
    BitcoinOfframpAttempt? attempt;
    try {
      final outcome = await executor.execute(
        prepared.transfer,
        authenticate: () async {
          if (!await authenticate()) return false;
          _check(prepared, isCurrent);
          final fresh = await fetchIntent(identity, prepared.intent.reference);
          _check(prepared, isCurrent);
          if (!prepared.intent.matches(fresh)) {
            throw StateError('Bitcoin cash-out intent changed');
          }
          return true;
        },
        isCurrent: isCurrent,
        beforeBroadcast: (txid) async {
          _check(prepared, isCurrent);
          attempt = await journal.reserve(identity, prepared.intent, txid);
          _check(prepared, isCurrent);
        },
      );
      if (attempt == null || attempt!.submission.txid != outcome.txid) {
        throw StateError('Bitcoin cash-out submission mismatch');
      }
      if (outcome.status == BitcoinSubmissionStatus.accepted) {
        try {
          await journal.markAccepted(attempt!);
        } catch (_) {
          // The durable pre-broadcast record still prevents another payment.
        }
      }
      var acknowledged = false;
      if (isCurrent() && outcome.status == BitcoinSubmissionStatus.accepted) {
        try {
          await acknowledge(identity, prepared.intent.reference, outcome.txid);
          acknowledged = true;
        } catch (_) {
          // A bookkeeping failure never retries the payment or clears its record.
        }
      }
      return BitcoinOfframpPaymentResult(outcome, acknowledged);
    } on BitcoinPreProviderRejection catch (proof) {
      if (attempt != null) await journal.releaseRejected(attempt!, proof);
      rethrow;
    } finally {
      if (attempt != null) journal.retainPending(attempt!);
    }
  }
}
