import '../../src/rust/api/bitcoin_transaction.dart';
import '../storage_service.dart';
import 'bitcoin_account_store.dart';
import 'bitcoin_native_crypto.dart';
import 'bitcoin_protected_record.dart';
import 'bitcoin_send_service.dart';
import 'bitcoin_wallet_vault_service.dart';
import 'bitcoin_submission_journal.dart';

/// A public signed transaction plus non-serializable, live authentication scope.
/// Only the signing coordinator can create this authorization.
class BitcoinSignedTransfer {
  final BitcoinPreparedTransfer transfer;
  final SignedBitcoinTransactionDto transaction;
  final int _authenticationGeneration;
  final BitcoinSubmissionJournal submissionJournal;
  BitcoinSignedTransfer._(
    this.transfer,
    this.transaction,
    this._authenticationGeneration,
    this.submissionJournal,
  );
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
      final reserved = await journal.reserved(identity, transfer.network);
      if (transfer.plan.selectedUtxos.any(
        (input) => reserved.contains('${input.txid}:${input.vout}'),
      )) {
        throw StateError('Bitcoin inputs already have a pending submission');
      }
      check();
      if (!await authenticate()) {
        throw StateError('Bitcoin authentication was cancelled');
      }
      check();
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
      return BitcoinSignedTransfer._(transfer, verified, generation, journal);
    } finally {
      identities.remove(identity);
    }
  }
}
