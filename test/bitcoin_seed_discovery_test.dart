@Tags(['ffi'])
library;

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_native_crypto.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_seed_account_discovery.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';
import 'package:fomowl_wallet/services/wallet_vault_service.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'helpers/bitcoin_memory_store.dart';

const mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

class PublicDiscoveryNetwork extends Fake implements BitcoinNetworkApi {
  final String usedAddress;
  PublicDiscoveryNetwork(this.usedAddress);
  @override
  Future<List<BitcoinAddressActivity>> fetchAccountState(
    String identity,
    BitcoinProductNetwork network,
    List<String> addresses,
  ) async {
    expect(identity, '0xauthentication');
    expect(addresses, hasLength(40));
    expect(addresses.every((value) => value.startsWith('bc1')), isTrue);
    expect(addresses.any((value) => value.contains('xpub')), isFalse);
    return addresses
        .map(
          (address) => BitcoinAddressActivity.fromJson({
            'address': address,
            'used': address == usedAddress,
            'confirmedBalanceSats': 0,
            'mempoolBalanceSats': 0,
            'txCount': address == usedAddress ? 1 : 0,
            'utxos': [],
          }),
        )
        .toList();
  }
}

class IndexDiscovery extends Fake implements BitcoinSeedDiscoveryApi {
  final calls = <int>[];
  final identities = <String>[];
  bool outage = false;
  @override
  Future<bool> hasActivity(Uint8List seed, String identity, int index) async {
    expect(seed, hasLength(64));
    calls.add(index);
    identities.add(identity);
    if (outage) throw const BitcoinNetworkException(500);
    return index == 3;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => RustLib.init());
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WalletVaultService.unlock();
  });
  tearDown(WalletVaultService.lockAll);
  test(
    'native BIP86-only past activity is discoverable even when its balance is zero',
    () async {
      const crypto = NativeBitcoinCrypto();
      final seed = await crypto.mnemonicToSeed(mnemonic);
      try {
        final account = await crypto.deriveAccount(
          seed,
          BitcoinProductNetwork.mainnet,
          3,
          BitcoinPurpose.bip86,
        );
        final used = await crypto.deriveAddress(
          account,
          BitcoinKeychain.receive,
          0,
        );
        final discovery = BitcoinSeedAccountDiscovery(
          network: PublicDiscoveryNetwork(used),
        );
        expect(
          await discovery.hasActivity(seed, '0xauthentication', 3),
          isTrue,
        );
        expect(
          await discovery.hasActivity(seed, '0xauthentication', 2),
          isFalse,
        );
        await expectLater(
          discovery.hasActivity(seed, '0xauthentication', 20),
          throwsArgumentError,
        );
      } finally {
        seed.fillRange(0, seed.length, 0);
      }
    },
  );
  test(
    'seed import restores higher Bitcoin-only account using the saved root wallet identity',
    () async {
      final storage = StorageService(
        secureStore: MemoryStore(),
        sharedPreferences: await SharedPreferences.getInstance(),
      );
      final discovery = IndexDiscovery();
      final service = WalletService(
        storageService: storage,
        bitcoinSeedDiscovery: discovery,
        bitcoinDiscoveryEnabled: () => true,
        seedAccountActivityChecker:
            ({
              required evmAddress,
              required solanaAddress,
              required tronAddress,
              required derivationIndex,
            }) async => false,
      );
      final imported = await service.importWalletsFromMnemonic(mnemonic);
      expect(imported, hasLength(2));
      final wallets = await storage.getWalletAccounts();
      expect(wallets.map((wallet) => wallet.derivationIndex), [0, 3]);
      expect(discovery.calls, [1, 2, 3, 4, 5, 6, 7, 8]);
      expect(discovery.identities.toSet(), {imported.first['address']!});
      expect(imported.first.containsKey('discoveryPartial'), isFalse);
    },
  );
  test(
    'provider outage preserves the root account and reports incomplete discovery',
    () async {
      final storage = StorageService(
        secureStore: MemoryStore(),
        sharedPreferences: await SharedPreferences.getInstance(),
      );
      final discovery = IndexDiscovery()..outage = true;
      final service = WalletService(
        storageService: storage,
        bitcoinSeedDiscovery: discovery,
        bitcoinDiscoveryEnabled: () => true,
        seedAccountActivityChecker:
            ({
              required evmAddress,
              required solanaAddress,
              required tronAddress,
              required derivationIndex,
            }) async => false,
      );
      final imported = await service.importWalletsFromMnemonic(mnemonic);
      expect(imported, hasLength(1));
      expect(imported.single['discoveryPartial'], 'true');
      expect((await storage.getWalletAccounts()).single.derivationIndex, 0);
    },
  );
}
