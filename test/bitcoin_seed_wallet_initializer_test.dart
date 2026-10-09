@Tags(['ffi'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/wallet_account.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_native_crypto.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_seed_wallet_initializer.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/wallet_vault_service.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'helpers/bitcoin_memory_store.dart';

const mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => RustLib.init());
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WalletVaultService.unlock();
  });
  tearDown(WalletVaultService.lockAll);
  Future<
    (StorageService, String, Map<BitcoinPurpose, BitcoinHdAccountMetadata>)
  >
  saved(int index) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(
      secureStore: MemoryStore(),
      sharedPreferences: await SharedPreferences.getInstance(),
    );
    const crypto = NativeBitcoinCrypto();
    final seed = await crypto.mnemonicToSeed(mnemonic);
    late String identity;
    final expected = <BitcoinPurpose, BitcoinHdAccountMetadata>{};
    try {
      identity = await crypto.seedWalletIdentity(seed, index);
      for (final purpose in BitcoinPurpose.values) {
        expected[purpose] = await crypto.deriveAccount(
          seed,
          BitcoinProductNetwork.mainnet,
          index,
          purpose,
        );
      }
    } finally {
      seed.fillRange(0, seed.length, 0);
    }
    await storage.saveWallet(
      address: identity,
      privateKey: 'public-fixture',
      mnemonic: mnemonic,
      origin: WalletOrigin.derived,
      derivationIndex: index,
      seedGroupId: 'seed_fixture',
    );
    return (storage, identity, expected);
  }

  test(
    'saved seed account index maps identically to BIP84 and BIP86 custody',
    () async {
      for (final index in [0, 1]) {
        final (storage, identity, expected) = await saved(index);
        await storage.setEnabledChainFamilies({ChainFamily.bitcoin});
        await BitcoinSeedWalletInitializer(
          storage: storage,
        ).initializeSavedSeedWallet(identity);
        final state = (await storage.bitcoinAccounts.readWalletState(
          identity,
          BitcoinProductNetwork.mainnet,
          index,
        ))!;
        for (final purpose in BitcoinPurpose.values) {
          expect(state.accounts[purpose]!.metadata, expected[purpose]);
        }
        expect(
          (await storage.getWalletAccounts()).single.supportsBitcoin,
          isTrue,
        );
      }
    },
  );
  test(
    'disabled Bitcoin defers vault provisioning until the family is enabled',
    () async {
      final (storage, identity, _) = await saved(0);
      final initializer = BitcoinSeedWalletInitializer(storage: storage);
      await initializer.initializeSavedSeedWallet(identity);
      expect(
        await storage.bitcoinAccounts.readWalletState(
          identity,
          BitcoinProductNetwork.mainnet,
          0,
        ),
        isNull,
      );
      expect(
        (await storage.getWalletAccounts()).single.supportsBitcoin,
        isFalse,
      );
      await storage.setEnabledChainFamilies({ChainFamily.bitcoin});
      await initializer.initializeSavedSeedWallet(identity);
      expect(
        (await storage.getWalletAccounts()).single.supportsBitcoin,
        isTrue,
      );
    },
  );
  test(
    'explicit seed recovery reactivates deleted HD storage without retaining old records',
    () async {
      final (storage, identity, expected) = await saved(0);
      await storage.setEnabledChainFamilies({ChainFamily.bitcoin});
      final initializer = BitcoinSeedWalletInitializer(storage: storage);
      await initializer.initializeSavedSeedWallet(identity);
      await storage.bitcoinAccounts.deleteWallet(identity);
      await initializer.initializeSavedSeedWallet(identity);
      final state = (await storage.bitcoinAccounts.readWalletState(
        identity,
        BitcoinProductNetwork.mainnet,
        0,
      ))!;
      expect(
        state.accounts[BitcoinPurpose.bip84]!.metadata,
        expected[BitcoinPurpose.bip84],
      );
    },
  );
}
