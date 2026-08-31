import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/wallet_account.dart';
import 'package:fomowl_wallet/screens/profile/decentralized_profile_screen.dart';
import 'package:fomowl_wallet/services/app_patch_service.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/currency_controller.dart';
import 'package:fomowl_wallet/services/language_controller.dart';
import 'package:fomowl_wallet/services/secure_store.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings surfaces referrals entry and opens referrals route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Owllet',
      packageName: 'com.fomowl.wallet',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    final prefs = await SharedPreferences.getInstance();
    final secureStore = _InMemorySecureStore();
    final storage = StorageService(
      secureStore: secureStore,
      sharedPreferences: prefs,
    );
    await storage.saveWallet(
      address: '0xbF75A6D2F5824A42b0BF946c15580A5f504c8c5F',
      privateKey: 'test-private-key',
      walletName: 'Main Wallet',
    );
    await storage.setCurrency('USD');

    final walletService = WalletService(storageService: storage);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppPatchService>.value(
            value: AppPatchService.instance,
          ),
          ChangeNotifierProvider<BlockchainService>(
            create: (_) => BlockchainService(),
          ),
          ChangeNotifierProvider<CurrencyController>(
            create: (_) => CurrencyController(storage: storage),
          ),
          ChangeNotifierProvider<LanguageController>(
            create: (_) => LanguageController(
              storage: storage,
              walletService: walletService,
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routes: {
            '/referrals': (_) =>
                const Scaffold(body: Center(child: Text('Referral Route'))),
          },
          home: DecentralizedProfileScreen(
            showBottomNavigation: false,
            walletService: walletService,
            storageService: storage,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-back-button')), findsOneWidget);
    final referralsFinder = find.text('Referrals');
    expect(referralsFinder, findsOneWidget);

    await tester.ensureVisible(referralsFinder);
    await tester.tap(referralsFinder);
    await tester.pumpAndSettle();

    expect(find.text('Referral Route'), findsOneWidget);
  });

  testWidgets('settings header follows the active chain family address', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Owllet',
      packageName: 'com.fomowl.wallet',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(
      secureStore: _InMemorySecureStore(),
      sharedPreferences: prefs,
    );
    const evmAddress = '0x1234567890123456789012345678901234567890';
    const solanaAddress = '8h7meC5hcAWs3WNKMufRPVsbwEcK1rNExGvWWKniBXd2';
    await storage.saveWallet(
      address: evmAddress,
      privateKey: 'test-private-key',
      walletName: 'Main Wallet',
      origin: WalletOrigin.derived,
      derivationIndex: 0,
      seedGroupId: 'seed_test',
      addressesByFamily: const {
        ChainFamily.evm: evmAddress,
        ChainFamily.solana: solanaAddress,
        ChainFamily.tron: 'TCgnc2fPN89r1V3zMBhax9K3YDTFCRfH8j',
      },
    );
    final walletService = WalletService(storageService: storage);
    final blockchain = BlockchainService();
    blockchain.setActiveWalletContext(
      address: evmAddress,
      supportedFamilies: const {
        ChainFamily.evm,
        ChainFamily.solana,
        ChainFamily.tron,
      },
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppPatchService>.value(
            value: AppPatchService.instance,
          ),
          ChangeNotifierProvider<BlockchainService>.value(value: blockchain),
          ChangeNotifierProvider<CurrencyController>(
            create: (_) => CurrencyController(storage: storage),
          ),
          ChangeNotifierProvider<LanguageController>(
            create: (_) => LanguageController(
              storage: storage,
              walletService: walletService,
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DecentralizedProfileScreen(
            showBottomNavigation: false,
            walletService: walletService,
            storageService: storage,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0x1234...7890'), findsOneWidget);

    blockchain.setActiveNetworkKey(NetworkKey.solana('mainnet-beta'));
    await tester.pumpAndSettle();

    expect(find.text('8h7meC...BXd2'), findsOneWidget);
    expect(find.text('0x1234...7890'), findsNothing);
  });
}

class _InMemorySecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }

  @override
  Future<String?> read({required String key}) async {
    return _values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }
}
