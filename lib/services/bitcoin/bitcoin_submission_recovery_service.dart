import '../../models/bitcoin_account_state.dart';
import 'bitcoin_native_crypto.dart';
import 'bitcoin_network_service.dart';
import 'bitcoin_submission_journal.dart';
import 'bitcoin_wallet_service.dart';
import 'bitcoin_wallet_vault_service.dart';

/// Manual legacy recovery is a testing escape hatch, never absence-based
/// automatic reconciliation. Production and mainnet cannot use it.
class BitcoinSubmissionRecoveryService {
  final BitcoinSubmissionJournal journal;
  final BitcoinNetworkApi network;
  final BitcoinWalletApi wallet;
  final BitcoinCryptoApi crypto;
  const BitcoinSubmissionRecoveryService({
    required this.journal,
    required this.network,
    required this.wallet,
    this.crypto = const NativeBitcoinCrypto(),
  });

  Future<bool> recover(
    BitcoinPendingSubmission entry, {
    required bool acknowledgedPreBroadcastRejection,
    required Future<bool> Function() authenticate,
    required bool Function() isCurrent,
  }) async {
    if (!journal.internalTestnetRecovery ||
        entry.network != BitcoinProductNetwork.testnet4 ||
        !entry.legacy ||
        !acknowledgedPreBroadcastRejection) {
      throw StateError('Legacy recovery is unavailable for this submission');
    }
    if (!isCurrent()) throw StateError('Bitcoin wallet context changed');
    if (!await authenticate()) {
      throw StateError('Bitcoin recovery authentication cancelled');
    }
    final generation = BitcoinWalletVaultService.beginOperation();
    void check() {
      BitcoinWalletVaultService.checkOperation(generation);
      if (!isCurrent()) throw StateError('Bitcoin wallet context changed');
    }

    check();
    Future<void> absent() async {
      final status = await network
          .fetchTransactionStatus(entry.network, entry.txid)
          .timeout(const Duration(seconds: 8));
      check();
      if (status.found || status.confirmed) {
        throw StateError(
          'This Bitcoin transaction is already known to the network',
        );
      }
    }

    await absent();
    final snapshot = await wallet
        .refresh(
          entry.walletIdentity,
          entry.network,
          force: true,
          isCurrent: isCurrent,
        )
        .timeout(const Duration(seconds: 60));
    check();
    if (snapshot.discovery.state.walletIdentity.toLowerCase() !=
            entry.walletIdentity ||
        snapshot.discovery.state.network != entry.network) {
      throw StateError('Bitcoin recovery account mismatch');
    }
    for (final point in entry.inputs) {
      final candidates = snapshot.discovery.utxos
          .where((utxo) => utxo.outpoint == point)
          .toList();
      if (candidates.length != 1 || !candidates.single.confirmed) {
        throw StateError('Reserved Bitcoin input is not confirmed and unspent');
      }
      final utxo = candidates.single;
      final owner = snapshot.discovery.ownership[utxo.address];
      if (owner == null ||
          owner.account.network != entry.network ||
          snapshot.discovery.state.accounts[owner.account.purpose]?.metadata !=
              owner.account) {
        throw StateError('Bitcoin recovery input ownership mismatch');
      }
      final script = await crypto.deriveScript(
        owner.account,
        owner.keychain,
        owner.addressIndex,
      );
      check();
      if (script.toLowerCase() != utxo.scriptPubkeyHex.toLowerCase()) {
        throw StateError('Bitcoin recovery input ownership mismatch');
      }
    }
    await absent();
    check();
    return journal.recoverLegacyTestnet4(entry, checkAuthorization: check);
  }
}
