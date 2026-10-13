import '../../src/rust/api/bitcoin_transaction.dart';
import 'dart:convert';
import '../../models/bitcoin_replacement_observation.dart';
import '../storage_service.dart';
import 'bitcoin_account_store.dart';
import 'bitcoin_native_crypto.dart';
import 'bitcoin_protected_record.dart';
import 'bitcoin_send_service.dart';
import 'bitcoin_wallet_vault_service.dart';
import 'bitcoin_submission_journal.dart';
import 'bitcoin_saved_transaction.dart';

/// A public signed transaction plus non-serializable, live authentication scope.
/// Only the signing coordinator can create this authorization.
class BitcoinSignedTransfer {
  final BitcoinPreparedTransfer transfer;
  final SignedBitcoinTransactionDto transaction;
  final int _authenticationGeneration;
  final BitcoinSubmissionJournal submissionJournal;
  final BitcoinPendingSubmission? replacing;
  BitcoinSignedTransfer._(
    this.transfer,
    this.transaction,
    this._authenticationGeneration,
    this.submissionJournal, {
    this.replacing,
  });
  void checkAuthorization() =>
      BitcoinWalletVaultService.checkOperation(_authenticationGeneration);
}

/// Authenticated approval orchestration. Account XPRVs and child keys stay in Rust.
class BitcoinSigningService {
  final BitcoinAccountStore store;
  final BitcoinCryptoApi crypto;
  BitcoinSigningService({BitcoinAccountStore? store, BitcoinCryptoApi? crypto})
    : store = store ?? StorageService().bitcoinAccounts,
      crypto = crypto ?? const NativeBitcoinCrypto();
  static final Expando<Set<String>> _busy = Expando();

  Future<BitcoinSignedTransfer> sign(
    BitcoinPreparedTransfer transfer, {
    required Future<bool> Function() authenticate,
    required bool Function() isCurrent,
    BitcoinPendingSubmission? replacing,
    Future<BitcoinReplacementObservation> Function()? observeReplacement,
  }) async {
    final identities = _busy[store.secureStore] ??= <String>{};
    final identity = transfer.walletIdentity.toLowerCase();
    if (!identities.add(identity)) {
      throw StateError('Bitcoin signing is already in progress');
    }
    void check() {
      if (!isCurrent()) throw StateError('Bitcoin wallet context changed');
    }

    try {
      check();
      final expected = NativeBitcoinCrypto.metadata(transfer.plan.account);
      if (expected.network != transfer.network ||
          expected.purpose != transfer.purpose) {
        throw StateError('Bitcoin signing account identity mismatch');
      }
      await validateBitcoinTransferPlan(plan: transfer.plan);
      final journal = BitcoinSubmissionJournal(store);
      Future<void> checkReplacement() async {
        if (replacing == null ||
            observeReplacement == null ||
            replacing.walletIdentity != identity ||
            replacing.network != transfer.network) {
          throw StateError('Bitcoin replacement scope mismatch');
        }
        await journal.validateReplacement(replacing);
        final original = replacing.transaction!;
        final context = await observeReplacement();
        check();
        context.requireOriginal(
          transfer.network,
          replacing.txid,
          original.outputCount,
        );
        final rebuilt = await planBitcoinTransferReplacement(
          originalPlan: original.plan,
          originalSignedTxHex: original.signed.rawTransactionHex,
          originalTxid: replacing.txid,
          originalUnconfirmed: context.originalUnconfirmed,
          hasDescendants: context.hasDescendants,
          incrementalRelayFeeSatVb: context.incrementalRelayFeeSatVb,
          feeRateSatVb: transfer.plan.feeRateSatVb,
        );
        if (jsonEncode(BitcoinSavedTransaction.planToJson(rebuilt)) !=
            jsonEncode(BitcoinSavedTransaction.planToJson(transfer.plan))) {
          throw StateError('Bitcoin replacement does not match approval');
        }
        await journal.validateReplacement(replacing);
      }

      if ((replacing == null) != (observeReplacement == null)) {
        throw StateError('Bitcoin replacement context is required');
      }
      if (replacing != null) {
        await checkReplacement();
      }
      final reserved = await journal.reserved(identity, transfer.network);
      if (replacing == null &&
          transfer.plan.selectedUtxos.any(
            (input) => reserved.contains('${input.txid}:${input.vout}'),
          )) {
        throw StateError('Bitcoin inputs already have a pending submission');
      }
      check();
      if (!await authenticate()) {
        throw StateError('Bitcoin authentication was cancelled');
      }
      check();
      if (replacing != null) {
        await checkReplacement();
      }
      final generation = BitcoinWalletVaultService.beginOperation();
      final slot = BitcoinAccountSlot(
        walletIdentity: identity,
        network: transfer.network,
        accountIndex: expected.accountIndex,
        purpose: transfer.purpose,
      );
      final signed =
          await BitcoinWalletVaultService(
            store: store,
            crypto: crypto,
          ).withAccount(slot, expected, (signer) async {
            check();
            final result = await signer.signTransaction(transfer.plan);
            check();
            return result;
          });
      check();
      BitcoinWalletVaultService.checkOperation(generation);
      final verified = await verifyBitcoinTransfer(
        plan: transfer.plan,
        rawTransactionHex: signed.rawTransactionHex,
      );
      if (signed.txid != verified.txid ||
          signed.wtxid != verified.wtxid ||
          signed.feeSat != verified.feeSat ||
          signed.vbytes != verified.vbytes) {
        throw StateError('Bitcoin signed transaction verification failed');
      }
      check();
      BitcoinWalletVaultService.checkOperation(generation);
      return BitcoinSignedTransfer._(
        transfer,
        verified,
        generation,
        journal,
        replacing: replacing,
      );
    } finally {
      identities.remove(identity);
    }
  }
}
