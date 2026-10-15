// Reuse the existing opaque signing/broadcast port, without cash-out transport.
import 'bitcoin_offramp_service.dart'
    show BitcoinOfframpExecutor, NativeBitcoinOfframpExecutor;
import '../../models/bitcoin_bill_funding_plan.dart';
import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_network_data.dart';
import 'bitcoin_broadcast_service.dart';
import 'bitcoin_network_service.dart';
import 'bitcoin_bill_funding_journal.dart';
import 'bitcoin_send_service.dart';
import 'bitcoin_signing_service.dart';
import 'bitcoin_submission_journal.dart';

class BitcoinPreparedBillFunding {
  final BitcoinBillFundingService _owner;
  final String walletIdentity;
  final BitcoinBillFundingPlan intent;
  final BitcoinPreparedTransfer transfer;
  final DateTime _expiresAt;
  BitcoinPreparedBillFunding._(
    this._owner,
    this.walletIdentity,
    this.intent,
    this.transfer,
    this._expiresAt,
  );
}

class BitcoinBillFundingPaymentResult {
  final BitcoinBroadcastOutcome outcome;
  final bool backendAcknowledged;
  const BitcoinBillFundingPaymentResult(this.outcome, this.backendAcknowledged);
}

class BitcoinBillFundingRecoveryResult {
  final String observedTxid;
  final BitcoinBillFundingSubmission submission;
  final BitcoinTransactionStatus status;
  final bool backendAcknowledged;
  const BitcoinBillFundingRecoveryResult(
    this.submission,
    this.status,
    this.backendAcknowledged,
    this.observedTxid,
  );
}

class BitcoinBillFundingAlreadySubmitted implements Exception {
  final BitcoinBillFundingSubmission submission;
  const BitcoinBillFundingAlreadySubmitted(this.submission);
  @override
  String toString() => 'This Bitcoin bill payment already has a saved payment';
}

class BitcoinBillFundingService {
  final BitcoinSendService planner;
  final BitcoinBillFundingJournal journal;
  final BitcoinOfframpExecutor executor;
  final Future<BitcoinBillFundingPlan> Function(
    String identity,
    String reference,
  )
  fetchIntent;
  final Future<void> Function(String identity, String reference, String txid)
  acknowledge;
  final Future<void> Function(String identity, String reference, String txid)
  acknowledgeReadOnly;
  final DateTime Function() _now;
  final Future<BitcoinTransactionStatus> Function(BitcoinProductNetwork, String)
  _fetchStatus;
  final Expando<Future<BitcoinBillFundingPaymentResult>> _executions =
      Expando();

  factory BitcoinBillFundingService({
    required Future<BitcoinBillFundingPlan> Function(
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
    Future<void> Function(String identity, String reference, String txid)?
    acknowledgeReadOnly,
    BitcoinSendService? planner,
    BitcoinOfframpExecutor? executor,
    DateTime Function()? now,
    Future<BitcoinTransactionStatus> Function(BitcoinProductNetwork, String)?
    fetchStatus,
  }) {
    final selected = planner ?? BitcoinSendService();
    return BitcoinBillFundingService._(
      selected,
      fetchIntent,
      acknowledge,
      acknowledgeReadOnly ??
          (_, _, _) async {
            throw StateError('Read-only bill acknowledgement unavailable');
          },
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

  BitcoinBillFundingService._(
    BitcoinSendService selected,
    this.fetchIntent,
    this.acknowledge,
    this.acknowledgeReadOnly,
    this.executor,
    this._now,
    this._fetchStatus,
  ) : planner = selected,
      journal = BitcoinBillFundingJournal(selected.store);

  /// Read-only chain observation and idempotent bookkeeping. Never obtains a
  /// funding plan, authenticates a signer, releases uncertain inputs or sends BTC.
  Future<BitcoinBillFundingRecoveryResult> recover(
    String walletIdentity,
    String reference, {
    required bool Function() isCurrent,
  }) async {
    final identity = walletIdentity.trim().toLowerCase();
    if (!BitcoinBillFundingPlan.validReference(reference) || !isCurrent()) {
      throw StateError('Bitcoin bill payment context changed');
    }
    final saved = await journal.read(identity, reference);
    if (saved == null || !isCurrent()) {
      throw StateError('No saved Bitcoin bill payment');
    }
    final replacement = await BitcoinSubmissionJournal(
      planner.store,
    ).resolvedPayment(identity, saved.intent.network, saved.txid);
    if (!isCurrent()) throw StateError('Bitcoin bill payment context changed');
    if (replacement != null &&
        (replacement.transaction.plan.recipients.length != 1 ||
            replacement.transaction.plan.recipients.single.address !=
                saved.intent.destination ||
            replacement.transaction.plan.recipients.single.amountSat !=
                saved.intent.amountSat)) {
      throw StateError('Bitcoin bill payment replacement intent mismatch');
    }
    final observedTxid = replacement?.transaction.signed.txid ?? saved.txid;
    final status = await _fetchStatus(saved.intent.network, observedTxid);
    if (!isCurrent()) throw StateError('Bitcoin bill payment context changed');
    var acknowledged = false;
    if (saved.accepted || status.found) {
      try {
        await acknowledgeReadOnly(identity, reference, observedTxid);
        acknowledged = true;
      } catch (_) {
        // A failed callback leaves the exact durable guard in place.
      }
    }
    if (!isCurrent()) throw StateError('Bitcoin bill payment context changed');
    await journal.reconcileConfirmed(
      saved,
      network: saved.intent.network,
      observedTxid: observedTxid,
      status: status,
      backendAcknowledged: acknowledged,
      replacementProof: replacement,
    );
    return BitcoinBillFundingRecoveryResult(
      saved,
      status,
      acknowledged,
      observedTxid,
    );
  }

  Future<BitcoinPreparedBillFunding> prepare(
    String walletIdentity,
    String reference, {
    required bool Function() isCurrent,
  }) async {
    final identity = walletIdentity.trim().toLowerCase();
    if (!BitcoinBillFundingPlan.validReference(reference)) {
      throw const FormatException('Invalid Bitcoin bill payment reference');
    }
    if (!isCurrent()) throw StateError('Bitcoin wallet context changed');
    final existing = await journal.read(identity, reference);
    if (existing != null) throw BitcoinBillFundingAlreadySubmitted(existing);
    final intent = await fetchIntent(identity, reference);
    if (!isCurrent() ||
        intent.reference != reference ||
        intent.walletIdentity != identity ||
        !_now().isBefore(intent.expiresAt)) {
      throw StateError('Bitcoin bill payment intent changed');
    }
    final transfer = await planner.prepareTransfer(
      identity,
      intent.network,
      intent.destination,
      intent.amountSat,
      isCurrent: isCurrent,
    );
    final prepared = BitcoinPreparedBillFunding._(
      this,
      identity,
      intent,
      transfer,
      _now().add(const Duration(minutes: 2)),
    );
    _check(prepared, isCurrent);
    return prepared;
  }

  void _check(BitcoinPreparedBillFunding prepared, bool Function() isCurrent) {
    final transfer = prepared.transfer;
    if (!identical(prepared._owner, this) ||
        prepared.intent.walletIdentity != prepared.walletIdentity ||
        !isCurrent() ||
        !_now().isBefore(prepared._expiresAt) ||
        !_now().isBefore(prepared.intent.expiresAt) ||
        transfer.walletIdentity.trim().toLowerCase() !=
            prepared.walletIdentity ||
        transfer.network != prepared.intent.network ||
        transfer.plan.recipients.length != 1 ||
        transfer.plan.recipients.single.address !=
            prepared.intent.destination ||
        transfer.plan.recipients.single.amountSat !=
            prepared.intent.amountSat ||
        transfer.plan.recipientTotalSat != prepared.intent.amountSat) {
      throw StateError('Bitcoin bill payment approval changed or expired');
    }
  }

  Future<BitcoinBillFundingPaymentResult> execute(
    BitcoinPreparedBillFunding prepared, {
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

  Future<BitcoinBillFundingPaymentResult> _execute(
    BitcoinPreparedBillFunding prepared,
    Future<bool> Function() authenticate,
    bool Function() isCurrent,
  ) async {
    final identity = prepared.transfer.walletIdentity;
    BitcoinBillFundingAttempt? attempt;
    try {
      final outcome = await executor.execute(
        prepared.transfer,
        authenticate: () async {
          if (!await authenticate()) return false;
          _check(prepared, isCurrent);
          final fresh = await fetchIntent(identity, prepared.intent.reference);
          _check(prepared, isCurrent);
          if (!prepared.intent.matches(fresh)) {
            throw StateError('Bitcoin bill payment intent changed');
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
        throw StateError('Bitcoin bill payment submission mismatch');
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
      return BitcoinBillFundingPaymentResult(outcome, acknowledged);
    } on BitcoinPreProviderRejection catch (proof) {
      if (attempt != null) await journal.releaseRejected(attempt!, proof);
      rethrow;
    } finally {
      if (attempt != null) journal.retainPending(attempt!);
    }
  }
}
