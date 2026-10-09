import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_discovery.dart';
import '../../models/chain.dart';
import '../storage_service.dart';
import 'bitcoin_address_allocator.dart';
import 'bitcoin_native_crypto.dart';
import 'bitcoin_protected_record.dart';

abstract interface class BitcoinReceiveApi {
  Future<BitcoinDerivedAddress> currentAddress(
    String identity,
    BitcoinProductNetwork network, {
    BitcoinPurpose purpose = BitcoinPurpose.bip84,
  });
}

/// Uses public protected account state; receiving never opens a signing vault.
class BitcoinReceiveService implements BitcoinReceiveApi {
  final StorageService storage;
  final BitcoinCryptoApi crypto;
  BitcoinReceiveService({StorageService? storage, BitcoinCryptoApi? crypto})
    : storage = storage ?? StorageService(),
      crypto = crypto ?? const NativeBitcoinCrypto();

  @override
  Future<BitcoinDerivedAddress> currentAddress(
    String identity,
    BitcoinProductNetwork network, {
    BitcoinPurpose purpose = BitcoinPurpose.bip84,
  }) async {
    final wallet = (await storage.getWalletAccounts())
        .where(
          (wallet) => wallet.address.toLowerCase() == identity.toLowerCase(),
        )
        .firstOrNull;
    if (wallet == null || !wallet.supportsFamily(ChainFamily.bitcoin)) {
      throw StateError('Bitcoin receiving requires a provisioned seed wallet');
    }
    return BitcoinAddressAllocator(
      store: storage.bitcoinAccounts,
      crypto: crypto,
    ).currentReceive(
      BitcoinAccountSlot(
        walletIdentity: identity,
        network: network,
        accountIndex: wallet.derivationIndex ?? 0,
        purpose: purpose,
      ),
    );
  }
}
