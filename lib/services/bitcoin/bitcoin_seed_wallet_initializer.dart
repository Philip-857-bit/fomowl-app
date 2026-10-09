import '../../models/chain.dart';
import '../../models/wallet_account.dart';
import '../storage_service.dart';
import 'bitcoin_native_crypto.dart';
import 'bitcoin_provisioning_service.dart';

/// Called only after explicit seed creation/import has saved the stable wallet identity.
class BitcoinSeedWalletInitializer {
  final StorageService storage;
  final BitcoinCryptoApi crypto;
  BitcoinSeedWalletInitializer({
    required this.storage,
    this.crypto = const NativeBitcoinCrypto(),
  });
  Future<void> initializeSavedSeedWallet(String identity) async {
    final wallet = (await storage.getWalletAccounts())
        .where(
          (wallet) => wallet.address.toLowerCase() == identity.toLowerCase(),
        )
        .firstOrNull;
    if (wallet == null || wallet.origin != WalletOrigin.derived) {
      throw StateError('Bitcoin initialization requires a saved seed wallet');
    }
    // Explicit creation/recovery may restore a deliberately deleted namespace.
    // Live records are preserved and remain authoritative.
    await storage.bitcoinAccounts.activateWallet(identity);
    final enabled = await storage.getEnabledChainFamilies();
    if (enabled?.contains(ChainFamily.bitcoin) != true) return;
    await BitcoinProvisioningService(
      storage: storage,
      crypto: crypto,
    ).ensureWallet(identity);
  }
}
