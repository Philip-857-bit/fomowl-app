import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomowl_wallet/l10n/app_localizations.dart';
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

    final referralsFinder = find.text('Referrals');
    expect(referralsFinder, findsOneWidget);

    await tester.ensureVisible(referralsFinder);
    await tester.tap(referralsFinder);
    await tester.pumpAndSettle();

    expect(find.text('Referral Route'), findsOneWidget);
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
