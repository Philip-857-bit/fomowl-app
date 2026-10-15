import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_bridge_quote.dart';
import '../../models/bitcoin_discovery.dart';
import '../../models/bitcoin_network_data.dart';
import '../bridge_service.dart' show BridgeService, BridgeStatus;
import 'bitcoin_bridge_journal.dart';
import 'bitcoin_broadcast_service.dart';
import 'bitcoin_network_service.dart';
import 'bitcoin_offramp_service.dart'
    show BitcoinOfframpExecutor, NativeBitcoinOfframpExecutor;
import 'bitcoin_protected_record.dart';
import 'bitcoin_send_service.dart';
import 'bitcoin_signing_service.dart';
import 'bitcoin_submission_journal.dart';

class BitcoinPreparedBridgeFunding {
  final BitcoinBridgeFundingService _owner;
  final String walletIdentity;
  final BitcoinBridgeQuote quote;
  final BitcoinDerivedAddress refundAddress;
  final BitcoinPreparedTransfer transfer;
  const BitcoinPreparedBridgeFunding._(
    this._owner,
    this.walletIdentity,
    this.quote,
    this.refundAddress,
    this.transfer,
  );
}

enum BitcoinBridgePhase {
  checkingSubmission,
  bitcoinSubmitted,
  bitcoinConfirmed,
  bridgeProcessing,
  delivered,
  refundReported,
  refunded,
  failed,
  reviewRequired,
}

class BitcoinBridgeFundingRecovery {
  final BitcoinBridgeSubmission submission;
  final String observedTxid;
  final BitcoinTransactionStatus chainStatus;
  final BridgeStatus? providerStatus;
  final bool delivered;
  final bool refunded;
  const BitcoinBridgeFundingRecovery(
    this.submission,
    this.observedTxid,
    this.chainStatus,
    this.providerStatus,
    this.delivered, {
    this.refunded = false,
  });

  BitcoinBridgePhase get phase {
    if (refunded) {
      return BitcoinBridgePhase.refunded;
    }
    if (submission.completed && !delivered) {
      return BitcoinBridgePhase.reviewRequired;
    }
    if (providerStatus?.isRefunded == true) {
      return BitcoinBridgePhase.refundReported;
    }
    if (providerStatus?.isFailure == true) {
      return BitcoinBridgePhase.failed;
    }
    if (delivered) {
      return BitcoinBridgePhase.delivered;
    }
    if (chainStatus.confirmed) {
      return providerStatus == null
          ? BitcoinBridgePhase.bitcoinConfirmed
          : BitcoinBridgePhase.bridgeProcessing;
    }
    if (chainStatus.found || submission.accepted) {
      return BitcoinBridgePhase.bitcoinSubmitted;
    }
    return BitcoinBridgePhase.checkingSubmission;
  }
}

/// Local, exact-plan funding. Reuses the mechanical opaque signer/broadcaster;
/// it does not reuse Breet business logic, provider PSBTs, or bill settlement.
class BitcoinBridgeFundingService {
  final BitcoinSendService planner;
  final BitcoinBridgeJournal journal;
  final BitcoinOfframpExecutor executor;
  final DateTime Function() _now;
  final Future<BitcoinTransactionStatus> Function(BitcoinProductNetwork, String)
  _chainStatus;
  final Future<BridgeStatus?> Function(String) _providerStatus;
  final Expando<Future<BitcoinBroadcastOutcome>> _executions = Expando();

  factory BitcoinBridgeFundingService({
    BitcoinSendService? planner,
    BitcoinOfframpExecutor? executor,
    DateTime Function()? now,
    Future<BitcoinTransactionStatus> Function(BitcoinProductNetwork, String)?
    chainStatus,
    Future<BridgeStatus?> Function(String)? providerStatus,
  }) {
    final selected = planner ?? BitcoinSendService();
    final clock = now ?? DateTime.now;
    return BitcoinBridgeFundingService._(
      selected,
      BitcoinBridgeJournal(selected.store, now: clock),
      executor ??
          NativeBitcoinOfframpExecutor(
            signing: BitcoinSigningService(
              store: selected.store,
              crypto: selected.crypto,
            ),
            broadcast: BitcoinBroadcastService(network: selected.network),
          ),
      clock,
      chainStatus ?? selected.network.fetchTransactionStatus,
      providerStatus ?? (id) => BridgeService().getStatus(requestId: id),
    );
  }
  BitcoinBridgeFundingService._(
    this.planner,
    this.journal,
    this.executor,
    this._now,
    this._chainStatus,
    this._providerStatus,
  );

  void _current(bool Function() isCurrent) {
    if (!isCurrent()) {
      throw StateError('Bitcoin bridge wallet context changed');
    }
  }

  Future<void> _ownedRefund(
    String identity,
    BitcoinBridgeQuote quote,
    BitcoinDerivedAddress refund,
    bool Function() isCurrent,
  ) async {
    _current(isCurrent);
    if (refund.account.network != BitcoinProductNetwork.mainnet ||
        refund.keychain != BitcoinKeychain.receive ||
        refund.addressIndex < 0 ||
        refund.addressIndex >= 0x80000000 ||
        refund.address != quote.request.sender) {
      throw StateError('Bitcoin bridge refund address is not owned');
    }
    final slot = BitcoinAccountSlot(
      walletIdentity: identity,
      network: BitcoinProductNetwork.mainnet,
      accountIndex: refund.account.accountIndex,
      purpose: refund.account.purpose,
    );
    final state = await planner.store.readState(slot);
    _current(isCurrent);
    if (state == null ||
        state.metadata != refund.account ||
        refund.addressIndex > state.nextExternal) {
      throw StateError('Bitcoin bridge refund account changed');
    }
    final address = await planner.crypto.deriveAddress(
      state.metadata,
      refund.keychain,
      refund.addressIndex,
    );
    _current(isCurrent);
    final latest = await planner.store.readState(slot);
    _current(isCurrent);
    if (address != refund.address ||
        latest == null ||
        latest.metadata != state.metadata) {
      throw StateError('Bitcoin bridge refund ownership changed');
    }
  }

  Future<BitcoinPreparedBridgeFunding> prepare(
    String walletIdentity,
    BitcoinBridgeQuote quote, {
    required BitcoinDerivedAddress refundAddress,
    required bool Function() isCurrent,
  }) async {
    final identity = walletIdentity.trim().toLowerCase();
    _current(isCurrent);
    if (identity.isEmpty ||
        !quote.committed ||
        !quote.request.bitcoinOrigin ||
        quote.depositAddress == null ||
        !_now().isBefore(quote.approvalExpiresAt)) {
      throw StateError('Bitcoin bridge approval changed or expired');
    }
    if (!await journal.canPrepare(identity, quote.requestId)) {
      throw StateError('Review the saved Bitcoin bridge before paying again');
    }
    await _ownedRefund(identity, quote, refundAddress, isCurrent);
    final transfer = await planner.prepareTransfer(
      identity,
      BitcoinProductNetwork.mainnet,
      quote.depositAddress!,
      quote.request.amount,
      isCurrent: isCurrent,
    );
    final prepared = BitcoinPreparedBridgeFunding._(
      this,
      identity,
      quote,
      refundAddress,
      transfer,
    );
    _check(prepared, isCurrent);
    return prepared;
  }

  void _check(
    BitcoinPreparedBridgeFunding prepared,
    bool Function() isCurrent,
  ) {
    _current(isCurrent);
    final transfer = prepared.transfer;
    if (!identical(prepared._owner, this) ||
        !_now().isBefore(prepared.quote.approvalExpiresAt) ||
        transfer.walletIdentity.trim().toLowerCase() !=
            prepared.walletIdentity ||
        transfer.network != BitcoinProductNetwork.mainnet ||
        transfer.plan.recipients.length != 1 ||
        transfer.plan.recipients.single.address !=
            prepared.quote.depositAddress ||
        transfer.plan.recipients.single.amountSat !=
            prepared.quote.request.amount ||
        transfer.plan.recipientTotalSat != prepared.quote.request.amount) {
      throw StateError('Bitcoin bridge approved plan changed or expired');
    }
  }

  Future<BitcoinBroadcastOutcome> execute(
    BitcoinPreparedBridgeFunding prepared, {
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

  Future<BitcoinBroadcastOutcome> _execute(
    BitcoinPreparedBridgeFunding prepared,
    Future<bool> Function() authenticate,
    bool Function() isCurrent,
  ) async {
    BitcoinBridgeAttempt? attempt;
    try {
      final result = await executor.execute(
        prepared.transfer,
        authenticate: () async {
          if (!await authenticate()) {
            return false;
          }
          _check(prepared, isCurrent);
          await _ownedRefund(
            prepared.walletIdentity,
            prepared.quote,
            prepared.refundAddress,
            isCurrent,
          );
          _check(prepared, isCurrent);
          return true;
        },
        isCurrent: isCurrent,
        beforeBroadcast: (txid) async {
          _check(prepared, isCurrent);
          attempt = await journal.reserve(
            prepared.walletIdentity,
            prepared.quote,
            txid,
          );
          _check(prepared, isCurrent);
        },
      );
      if (attempt == null || attempt!.submission.txid != result.txid) {
        throw StateError('Bitcoin bridge submission changed');
      }
      if (result.status == BitcoinSubmissionStatus.accepted) {
        try {
          await journal.markAccepted(attempt!);
        } catch (_) {
          /* Durable guard still prevents another payment. */
        }
      }
      return result;
    } on BitcoinPreProviderRejection catch (proof) {
      if (attempt != null) {
        await journal.releaseRejected(attempt!, proof);
      }
      rethrow;
    } finally {
      if (attempt != null) {
        journal.retainPending(attempt!);
      }
    }
  }

  /// Observation only. Never replans, prompts for authentication, or broadcasts.
  Future<BitcoinBridgeFundingRecovery> recover(
    String walletIdentity, {
    required bool Function() isCurrent,
  }) async {
    final identity = walletIdentity.trim().toLowerCase();
    _current(isCurrent);
    final saved = await journal.latest(identity);
    _current(isCurrent);
    if (saved == null) {
      throw StateError('No saved Bitcoin bridge');
    }
    final replacement = await BitcoinSubmissionJournal(
      planner.store,
    ).resolvedPayment(identity, BitcoinProductNetwork.mainnet, saved.txid);
    _current(isCurrent);
    if (replacement != null &&
        (replacement.transaction.plan.recipients.length != 1 ||
            replacement.transaction.plan.recipients.single.address !=
                saved.quote.depositAddress ||
            replacement.transaction.plan.recipients.single.amountSat !=
                saved.quote.request.amount ||
            replacement.transaction.plan.recipientTotalSat !=
                saved.quote.request.amount)) {
      throw StateError('Bitcoin bridge replacement intent changed');
    }
    final txid = replacement?.transaction.signed.txid ?? saved.txid;
    final chain = await _chainStatus(BitcoinProductNetwork.mainnet, txid);
    _current(isCurrent);
    final provider = await _providerStatus(saved.quote.requestId);
    _current(isCurrent);
    var delivered =
        saved.resolution == 'delivered' &&
        chain.confirmed &&
        (provider == null || provider.isSuccess);
    var refunded =
        saved.resolution == 'refunded' &&
        chain.confirmed &&
        (provider == null || provider.isRefunded);
    if (!saved.completed) {
      delivered = await journal.completeDelivered(
        saved,
        observedTxid: txid,
        chainStatus: chain,
        providerRequestId: saved.quote.requestId,
        providerStatus: provider?.status.toLowerCase() ?? 'unknown',
        replacementProof: replacement,
      );
      if (!delivered) {
        refunded = await journal.completeRefunded(
          saved,
          observedTxid: txid,
          chainStatus: chain,
          providerRequestId: saved.quote.requestId,
          providerStatus: provider?.status.toLowerCase() ?? 'unknown',
          replacementProof: replacement,
        );
      }
    }
    _current(isCurrent);
    return BitcoinBridgeFundingRecovery(
      saved,
      txid,
      chain,
      provider,
      delivered,
      refunded: refunded,
    );
  }
}
