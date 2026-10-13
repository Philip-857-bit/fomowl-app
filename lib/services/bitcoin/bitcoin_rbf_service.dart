import 'dart:convert';
import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_network_data.dart';
import '../../models/bitcoin_replacement_observation.dart';
import '../../src/rust/api/bitcoin_transaction.dart';
import '../storage_service.dart';
import 'bitcoin_account_store.dart';
import 'bitcoin_broadcast_service.dart';
import 'bitcoin_network_service.dart';
import 'bitcoin_protected_record.dart';
import 'bitcoin_saved_transaction.dart';
import 'bitcoin_send_service.dart';
import 'bitcoin_signing_service.dart';
import 'bitcoin_submission_journal.dart';

/// A single-use, process-local approval. Stored transaction data grants no
/// signing authority; the coordinator rechecks it before and after unlock.
class BitcoinPreparedReplacement {
  final BitcoinRbfService _owner;
  final BitcoinPendingSubmission _original;
  final DateTime _createdAt;
  final BitcoinPreparedTransfer transfer;
  bool _used = false;
  BitcoinPreparedReplacement._(
    this._owner,
    this._original,
    this._createdAt,
    this.transfer,
  );
  String get originalTxid => _original.txid;
  BigInt get originalFeeSat => _original.transaction!.signed.feeSat;
  BigInt get replacementFeeSat => transfer.plan.feeSat;
  BigInt get additionalFeeSat => replacementFeeSat - originalFeeSat;
}

/// Host orchestration only. Rust owns replacement construction and validation.
class BitcoinRbfService {
  final BitcoinSubmissionJournal journal;
  final BitcoinNetworkApi network;
  final BitcoinReplacementNetworkApi _observations;
  final BitcoinSigningService _signing;
  final DateTime Function() _now;
  factory BitcoinRbfService({
    BitcoinAccountStore? store,
    BitcoinNetworkApi? network,
    BitcoinSigningService? signing,
    DateTime Function()? now,
  }) {
    final protectedStore = store ?? StorageService().bitcoinAccounts;
    final host = network ?? BitcoinNetworkService();
    if (host is! BitcoinReplacementNetworkApi) {
      throw ArgumentError('Bitcoin replacement observations are required');
    }
    final custody = signing ?? BitcoinSigningService(store: protectedStore);
    if (!identical(custody.store.secureStore, protectedStore.secureStore)) {
      throw ArgumentError('Bitcoin replacement custody scope mismatch');
    }
    return BitcoinRbfService._(
      BitcoinSubmissionJournal(protectedStore),
      host,
      host as BitcoinReplacementNetworkApi,
      custody,
      now ?? DateTime.now,
    );
  }
  BitcoinRbfService._(
    this.journal,
    this.network,
    this._observations,
    this._signing,
    this._now,
  );

  void _current(bool Function() isCurrent) {
    if (!isCurrent()) throw StateError('Bitcoin wallet context changed');
  }

  Future<BitcoinPendingSubmission?> _candidate(
    String identity,
    BitcoinProductNetwork network,
    String txid,
    bool Function() isCurrent,
  ) async {
    _current(isCurrent);
    final hash = bitcoinTxid(txid);
    if (!await _observations.replacementAvailable(network)) return null;
    _current(isCurrent);
    final entries = await journal.pending(
      identity.trim().toLowerCase(),
      network,
    );
    _current(isCurrent);
    final matches = entries.where((entry) => entry.txid == hash);
    if (matches.length != 1) return null;
    final snapshot = matches.single;
    final original = snapshot.transaction;
    if (!snapshot.active ||
        snapshot.legacy ||
        original == null ||
        !original.plan.rbf) {
      return null;
    }
    await journal.validateReplacement(snapshot);
    await validateBitcoinTransferPlan(plan: original.plan);
    final verified = await verifyBitcoinTransfer(
      plan: original.plan,
      rawTransactionHex: original.signed.rawTransactionHex,
    );
    _current(isCurrent);
    if (verified.txid != snapshot.txid ||
        verified.txid != original.signed.txid ||
        verified.wtxid != original.signed.wtxid ||
        verified.feeSat != original.signed.feeSat ||
        verified.vbytes != original.signed.vbytes ||
        original.account.network != network) {
      throw StateError('Saved Bitcoin transaction verification failed');
    }
    final state = await journal.store.readState(
      BitcoinAccountSlot(
        walletIdentity: snapshot.walletIdentity,
        network: network,
        accountIndex: original.account.accountIndex,
        purpose: original.account.purpose,
      ),
    );
    _current(isCurrent);
    if (state?.metadata != original.account) {
      throw StateError('Bitcoin replacement account identity mismatch');
    }
    await journal.validateReplacement(snapshot);
    return snapshot;
  }

  Future<BitcoinReplacementObservation> _observe(
    BitcoinPendingSubmission original,
    bool Function() isCurrent,
  ) async {
    _current(isCurrent);
    final context = await _observations.fetchReplacementContext(
      original.network,
      original.txid,
    );
    _current(isCurrent);
    context.requireOriginal(
      original.network,
      original.txid,
      original.transaction!.outputCount,
    );
    return context;
  }

  Future<bool> available(
    String identity,
    BitcoinProductNetwork network,
    String txid, {
    required bool Function() isCurrent,
  }) async {
    try {
      final original = await _candidate(identity, network, txid, isCurrent);
      if (original == null) return false;
      await _observe(original, isCurrent);
      await journal.validateReplacement(original);
      return isCurrent();
    } catch (_) {
      return false;
    }
  }

  Future<BitcoinPreparedReplacement> prepare(
    String identity,
    BitcoinProductNetwork network,
    String txid,
    BigInt feeRateSatVb, {
    required bool Function() isCurrent,
  }) async {
    final original = await _candidate(identity, network, txid, isCurrent);
    if (original == null) throw StateError('Bitcoin speed up is unavailable');
    final saved = original.transaction!;
    if (feeRateSatVb <= saved.plan.feeRateSatVb ||
        feeRateSatVb.isNegative ||
        feeRateSatVb.bitLength > 64) {
      throw const FormatException(
        'A higher valid Bitcoin fee rate is required',
      );
    }
    final context = await _observe(original, isCurrent);
    final plan = await planBitcoinTransferReplacement(
      originalPlan: saved.plan,
      originalSignedTxHex: saved.signed.rawTransactionHex,
      originalTxid: original.txid,
      originalUnconfirmed: context.originalUnconfirmed,
      hasDescendants: context.hasDescendants,
      incrementalRelayFeeSatVb: context.incrementalRelayFeeSatVb,
      feeRateSatVb: feeRateSatVb,
    );
    _current(isCurrent);
    await journal.validateReplacement(original);
    return BitcoinPreparedReplacement._(
      this,
      original,
      _now(),
      BitcoinPreparedTransfer(
        walletIdentity: original.walletIdentity,
        network: network,
        purpose: saved.account.purpose,
        plan: plan,
      ),
    );
  }

  void _fresh(BitcoinPreparedReplacement approval, bool Function() isCurrent) {
    _current(isCurrent);
    final age = _now().difference(approval._createdAt);
    if (!identical(approval._owner, this) ||
        age.isNegative ||
        age > const Duration(seconds: 30)) {
      throw StateError('Bitcoin replacement approval expired');
    }
  }

  Future<BitcoinBroadcastOutcome> submit(
    BitcoinPreparedReplacement approval, {
    required Future<bool> Function() authenticate,
    required bool Function() isCurrent,
  }) async {
    _fresh(approval, isCurrent);
    if (approval._used) {
      throw StateError('Bitcoin replacement approval was already used');
    }
    approval._used = true;
    final signed = await _signing.sign(
      approval.transfer,
      authenticate: () async {
        _fresh(approval, isCurrent);
        final accepted = await authenticate();
        _fresh(approval, isCurrent);
        return accepted;
      },
      isCurrent: () =>
          isCurrent() &&
          _now().difference(approval._createdAt) >= Duration.zero &&
          _now().difference(approval._createdAt) <= const Duration(seconds: 30),
      replacing: approval._original,
      observeReplacement: () => _observe(approval._original, isCurrent),
    );
    _fresh(approval, isCurrent);
    await journal.validateReplacement(approval._original);
    final context = await _observe(approval._original, isCurrent);
    final original = approval._original.transaction!;
    final rebuilt = await planBitcoinTransferReplacement(
      originalPlan: original.plan,
      originalSignedTxHex: original.signed.rawTransactionHex,
      originalTxid: approval.originalTxid,
      originalUnconfirmed: context.originalUnconfirmed,
      hasDescendants: context.hasDescendants,
      incrementalRelayFeeSatVb: context.incrementalRelayFeeSatVb,
      feeRateSatVb: approval.transfer.plan.feeRateSatVb,
    );
    _fresh(approval, isCurrent);
    if (jsonEncode(BitcoinSavedTransaction.planToJson(rebuilt)) !=
        jsonEncode(
          BitcoinSavedTransaction.planToJson(approval.transfer.plan),
        )) {
      throw StateError('Bitcoin replacement does not match approval');
    }
    return BitcoinBroadcastService(network: network).broadcast(
      signed,
      isCurrent: () =>
          isCurrent() &&
          _now().difference(approval._createdAt) >= Duration.zero &&
          _now().difference(approval._createdAt) <= const Duration(seconds: 30),
    );
  }
}
