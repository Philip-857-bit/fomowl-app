import '../../models/chain.dart';
import '../../models/wallet_account.dart';
import '../blockchain_service.dart';
import '../wallet_service.dart';

/// User preference only. Runtime admission and wallet custody are separate.
class BitcoinNetworkPreferenceService {
  final BlockchainService blockchain;
  final WalletService wallet;
  BitcoinNetworkPreferenceService({
    required this.blockchain,
    WalletService? wallet,
  }) : wallet = wallet ?? WalletService();

  Future<void> setEnabled(bool enabled) async {
    final identity = blockchain.activeWalletAddress.toLowerCase();
    if (enabled) {
      void check() {
        if (identity.isEmpty ||
            blockchain.activeWalletAddress.toLowerCase() != identity ||
            !blockchain.isBitcoinNetworkAvailable('bitcoin:mainnet')) {
          throw StateError('Bitcoin is unavailable for this wallet');
        }
      }

      check();
      final account = await wallet.getActiveWalletAccount();
      check();
      if (account == null ||
          account.address.toLowerCase() != identity ||
          account.origin != WalletOrigin.derived) {
        throw StateError('Bitcoin requires a seed-backed wallet');
      }
      final state = await wallet.ensureBitcoinAccount(account.address);
      check();
      final provisioned = await wallet.getActiveWalletAccount();
      check();
      if (state == null ||
          provisioned == null ||
          provisioned.address.toLowerCase() != identity ||
          provisioned.origin != WalletOrigin.derived ||
          !provisioned.supportsFamily(ChainFamily.bitcoin)) {
        throw StateError('Bitcoin account provisioning is incomplete');
      }
      blockchain.setActiveWalletContext(
        address: provisioned.address,
        supportedFamilies: provisioned.supportedFamilies,
      );
      await blockchain.setEnabledFamilies({
        ...blockchain.enabledFamilies,
        ChainFamily.bitcoin,
      });
      return;
    }
    final next = {...blockchain.enabledFamilies}..remove(ChainFamily.bitcoin);
    if (next.isEmpty) {
      for (final family in [
        ChainFamily.evm,
        ChainFamily.solana,
        ChainFamily.tron,
      ]) {
        if (blockchain.activeWalletSupportedFamilies.contains(family)) {
          next.add(family);
          break;
        }
      }
    }
    if (next.isEmpty) {
      throw StateError('At least one supported network must remain enabled');
    }
    await blockchain.setEnabledFamilies(next);
  }
}
