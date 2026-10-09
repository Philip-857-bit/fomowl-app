@Tags(['ffi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/wallet_account.dart';
import 'package:fomowl_wallet/screens/profile/widgets/bitcoin_network_preference_tile.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_native_crypto.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_preference_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_rollout_service.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/runtime_config_service.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';
import 'package:fomowl_wallet/services/wallet_vault_service.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'package:fomowl_wallet/theme/theme_controller.dart';
import 'bitcoin_rollout_service_test.dart' show Availability;
import 'helpers/bitcoin_memory_store.dart';

const mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const admitted = RuntimePolicySnapshot(
  bitcoinEnabled: true,
  bitcoinRolloutStage: 'default',
);

class Fixture {
  final StorageService storage;
  final WalletService wallet;
  final BlockchainService blockchain;
  final String identity;
  Fixture(this.storage, this.wallet, this.blockchain, this.identity);
  BitcoinNetworkPreferenceService get preference =>
      BitcoinNetworkPreferenceService(blockchain: blockchain, wallet: wallet);
  BitcoinRolloutService get rollout => BitcoinRolloutService(
    blockchain: blockchain,
    network: Availability(),
    provision: (chain, current) => BitcoinRolloutService.provisionSeedWallet(
      chain,
      current,
      walletService: wallet,
    ),
  );
}

Future<Fixture> fixture({bool provision = true}) async {
  final prefs = await SharedPreferences.getInstance();
  final storage = StorageService(
    secureStore: MemoryStore(),
    sharedPreferences: prefs,
  );
  const crypto = NativeBitcoinCrypto();
  final seed = await crypto.mnemonicToSeed(mnemonic);
  late String identity;
  try {
    identity = await crypto.seedWalletIdentity(seed, 0);
  } finally {
    seed.fillRange(0, seed.length, 0);
  }
  await storage.saveWallet(
    address: identity,
    privateKey: 'public-fixture',
    mnemonic: mnemonic,
    origin: WalletOrigin.derived,
    derivationIndex: 0,
    seedGroupId: 'preference_fixture',
  );
  final wallet = WalletService(storageService: storage);
  final blockchain = BlockchainService();
  final account = (await wallet.getActiveWalletAccount())!;
  blockchain.setActiveWalletContext(
    address: identity,
    supportedFamilies: account.supportedFamilies,
  );
  await blockchain.setEnabledFamilies({ChainFamily.evm});
  blockchain.configureBitcoinAvailability(available: true);
  final value = Fixture(storage, wallet, blockchain, identity);
  if (provision) await value.rollout.refresh(admitted);
  return value;
}

class PublicWallet extends WalletService {
  final WalletAccount account;
  final BitcoinWalletAccountState state;
  PublicWallet(StorageService storage, this.account, this.state)
    : super(storageService: storage);
  @override
  Future<WalletAccount?> getActiveWalletAccount() async => account;
  @override
  Future<BitcoinWalletAccountState?> ensureBitcoinAccount(
    String identity, {
    BitcoinProductNetwork network = BitcoinProductNetwork.mainnet,
    bool restoreRemovedWallet = false,
  }) async => state;
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
    'eligible runtime provisions support without enabling Bitcoin or overwriting preferences',
    () async {
      final value = await fixture(provision: false);
      expect(
        (await value.wallet.getActiveWalletAccount())!.supportsBitcoin,
        isFalse,
      );
      await value.rollout.refresh(admitted);
      expect(
        (await value.wallet.getActiveWalletAccount())!.supportsBitcoin,
        isTrue,
      );
      expect(
        value.blockchain.activeWalletSupportedFamilies,
        contains(ChainFamily.bitcoin),
      );
      expect(value.blockchain.enabledFamilies, {ChainFamily.evm});
      expect(await value.storage.getEnabledChainFamilies(), {ChainFamily.evm});
      value.blockchain.dispose();
    },
  );
  test(
    'explicit enable/disable persists, keeps custody and survives a later rollout refresh',
    () async {
      final value = await fixture();
      final before = await value.storage.bitcoinAccounts.readWalletState(
        value.identity,
        BitcoinProductNetwork.mainnet,
        0,
      );
      await value.preference.setEnabled(true);
      expect(value.blockchain.enabledFamilies, contains(ChainFamily.bitcoin));
      expect(
        await value.storage.getEnabledChainFamilies(),
        contains(ChainFamily.bitcoin),
      );
      await value.preference.setEnabled(false);
      expect(value.blockchain.enabledFamilies, {ChainFamily.evm});
      expect(await value.storage.getEnabledChainFamilies(), {ChainFamily.evm});
      final after = await value.storage.bitcoinAccounts.readWalletState(
        value.identity,
        BitcoinProductNetwork.mainnet,
        0,
      );
      expect(
        after!.accounts[BitcoinPurpose.bip84]!.metadata,
        before!.accounts[BitcoinPurpose.bip84]!.metadata,
      );
      expect(
        after.accounts[BitcoinPurpose.bip86]!.metadata,
        before.accounts[BitcoinPurpose.bip86]!.metadata,
      );
      await value.rollout.refresh(admitted);
      expect(value.blockchain.enabledFamilies, {ChainFamily.evm});
      expect(await value.storage.getEnabledChainFamilies(), {ChainFamily.evm});
      value.blockchain.dispose();
    },
  );
  test(
    'disabling active Bitcoin selects an enabled supported fallback',
    () async {
      final value = await fixture();
      await value.preference.setEnabled(true);
      value.blockchain.setActiveNetworkKey('bitcoin:mainnet');
      expect(value.blockchain.activeFamily, ChainFamily.bitcoin);
      await value.preference.setEnabled(false);
      expect(value.blockchain.activeFamily, ChainFamily.evm);
      expect(value.blockchain.enabledFamilies, {ChainFamily.evm});
      value.blockchain.dispose();
    },
  );
  test(
    'Bitcoin can be disabled even when it was the only enabled family',
    () async {
      final value = await fixture();
      await value.blockchain.setEnabledFamilies({ChainFamily.bitcoin});
      await value.preference.setEnabled(false);
      expect(value.blockchain.enabledFamilies, {ChainFamily.evm});
      expect(value.blockchain.activeFamily, ChainFamily.evm);
      value.blockchain.dispose();
    },
  );
  test('unavailable backend prevents manual enablement', () async {
    final value = await fixture();
    value.blockchain.configureBitcoinAvailability(available: false);
    await expectLater(value.preference.setEnabled(true), throwsStateError);
    expect(await value.storage.getEnabledChainFamilies(), {ChainFamily.evm});
    value.blockchain.dispose();
  });
  test('private-key-only wallet cannot enable Bitcoin', () async {
    final value = await fixture();
    await value.storage.saveWallet(
      address: '0xprivate',
      privateKey: 'public-fixture',
      origin: WalletOrigin.imported,
    );
    value.blockchain.setActiveWalletContext(
      address: '0xprivate',
      supportedFamilies: {ChainFamily.evm},
    );
    await expectLater(value.preference.setEnabled(true), throwsStateError);
    expect(await value.storage.getEnabledChainFamilies(), {ChainFamily.evm});
    value.blockchain.dispose();
  });
  for (final enabled in [false, true]) {
    test(
      'restart preserves Bitcoin preference $enabled, including a stale saved active network',
      () async {
        final value = await fixture();
        await value.preference.setEnabled(enabled);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_network_key', 'bitcoin:mainnet');
        final restarted = BlockchainService();
        restarted.setActiveWalletContext(
          address: value.identity,
          supportedFamilies: value.blockchain.activeWalletSupportedFamilies,
        );
        restarted.configureBitcoinAvailability(available: true);
        await restarted.init();
        expect(
          restarted.enabledFamilies.contains(ChainFamily.bitcoin),
          enabled,
        );
        if (!enabled) expect(restarted.activeFamily, ChainFamily.evm);
        expect(
          (await value.storage.getEnabledChainFamilies())!.contains(
            ChainFamily.bitcoin,
          ),
          enabled,
        );
        restarted.dispose();
        value.blockchain.dispose();
      },
    );
  }
  testWidgets(
    'Manage Networks Bitcoin switch opts in/out and hides unavailable or imported wallets',
    (tester) async {
      final prepared = (await tester.runAsync(() async {
        final value = await fixture();
        final account = (await value.wallet.getActiveWalletAccount())!;
        final state = (await value.storage.bitcoinAccounts.readWalletState(
          value.identity,
          BitcoinProductNetwork.mainnet,
          0,
        ))!;
        return (value, PublicWallet(value.storage, account, state));
      }))!;
      final (value, publicWallet) = prepared;
      final theme = ThemeController(storage: value.storage);
      Widget host(WalletOrigin origin) => MultiProvider(
        providers: [
          ChangeNotifierProvider<BlockchainService>.value(
            value: value.blockchain,
          ),
          ChangeNotifierProvider<ThemeController>.value(value: theme),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BitcoinNetworkPreferenceTile(
              origin: origin,
              wallet: publicWallet,
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(WalletOrigin.derived));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('bitcoin-network-preference'));
      expect(find.text('Bitcoin'), findsOneWidget);
      expect(find.textContaining('BTC'), findsOneWidget);
      expect(tester.widget<Switch>(toggle).value, isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isFalse);
      value.blockchain.configureBitcoinAvailability(available: false);
      await tester.pumpAndSettle();
      expect(toggle, findsNothing);
      value.blockchain.configureBitcoinAvailability(available: true);
      await tester.pumpWidget(host(WalletOrigin.imported));
      await tester.pumpAndSettle();
      expect(toggle, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      value.blockchain.dispose();
      theme.dispose();
    },
  );
}
