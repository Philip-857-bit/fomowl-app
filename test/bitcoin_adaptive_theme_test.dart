@Tags(['ffi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/network_entry.dart';
import 'package:fomowl_wallet/models/wallet_account.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/wallet_vault_service.dart';
import 'package:fomowl_wallet/theme/app_chain_theme.dart';
import 'package:fomowl_wallet/theme/theme_controller.dart';
import 'package:fomowl_wallet/screens/home/widgets/network_selector_sheet.dart';
import 'package:fomowl_wallet/screens/wallet/bitcoin_transfer_confirmation_screen.dart';
import 'package:fomowl_wallet/screens/profile/widgets/bitcoin_network_preference_tile.dart';
import 'package:fomowl_wallet/src/rust/api/bitcoin_transaction.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'bitcoin_confirmation_test.dart' show transfer;
import 'bitcoin_network_preference_test.dart' show fixture;
import 'helpers/bitcoin_memory_store.dart';
import 'helpers/test_fonts.dart';

class BitcoinThemeChain extends BlockchainService {
  @override
  String get activeNetworkKey => 'bitcoin:mainnet';
}

BitcoinNetworkEntry entry() => BitcoinNetworkEntry(
  const BitcoinChain(
    name: 'Bitcoin',
    networkId: 'mainnet',
    explorerUrl: 'https://mempool.space',
    logoUrl: '',
  ),
);
Widget host(
  Widget child,
  BlockchainService blockchain,
  ThemeController theme,
) => MultiProvider(
  providers: [
    ChangeNotifierProvider<BlockchainService>.value(value: blockchain),
    ChangeNotifierProvider<ThemeController>.value(value: theme),
  ],
  child: MaterialApp(
    theme: ThemeData.dark(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => RustLib.init());
  setUp(() async {
    await installTestFonts();
    SharedPreferences.setMockInitialValues({});
    WalletVaultService.unlock();
  });
  tearDown(WalletVaultService.lockAll);
  for (final key in ['bitcoin:mainnet', 'bitcoin:testnet4']) {
    test(
      '$key resolves Bitcoin adaptive theme',
      () =>
          expect(AppChainTheme.forNetworkKey(key), same(AppChainTheme.bitcoin)),
    );
  }
  test(
    'typed Bitcoin entry resolves Bitcoin theme and palette stays dark/orange',
    () {
      expect(AppChainTheme.forNetwork(entry()), same(AppChainTheme.bitcoin));
      expect(AppChainTheme.bitcoin.accentColor, const Color(0xFFF7931A));
      expect(AppChainTheme.bitcoin.primaryColor, const Color(0xFFF7931A));
      expect(AppChainTheme.bitcoin.balanceCardGradient.colors, [
        const Color(0xFF321B05),
        const Color(0xFF1C1005),
        const Color(0xFF0A0A0A),
      ]);
    },
  );
  for (final mode in AppThemeMode.values) {
    testWidgets(
      '$mode respects context theme and preserves Bitcoin confirmation approval',
      (tester) async {
        final blockchain = BitcoinThemeChain();
        final theme = ThemeController(
          storage: StorageService(secureStore: MemoryStore()),
        );
        await theme.setThemeMode(mode);
        final prepared = (await tester.runAsync(transfer))!;
        Object? approved;
        final expected = mode == AppThemeMode.classic
            ? AppChainTheme.fomowlSignature
            : AppChainTheme.bitcoin;
        await tester.pumpWidget(
          host(
            Builder(
              builder: (context) {
                expect(context.chainTheme, same(expected));
                return BitcoinTransferConfirmationScreen(
                  transfer: prepared,
                  onConfirm: (value) async => approved = value,
                );
              },
            ),
            blockchain,
            theme,
          ),
        );
        await tester.runAsync(
          () => validateBitcoinTransferPlan(plan: prepared.plan),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('bitcoin-confirm-transfer')),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        final button = tester.widget<FilledButton>(
          find.byKey(const Key('bitcoin-confirm-transfer')),
        );
        expect(
          button.style!.backgroundColor!.resolve({}),
          expected.accentColor,
        );
        await tester.tap(find.byKey(const Key('bitcoin-confirm-transfer')));
        await tester.pumpAndSettle();
        expect(approved, same(prepared));
        await tester.pumpWidget(const SizedBox.shrink());
        blockchain.dispose();
        theme.dispose();
      },
    );
  }
  testWidgets(
    'network selector styles selected Bitcoin with orange and retains selection',
    (tester) async {
      final blockchain = BitcoinThemeChain();
      final theme = ThemeController(
        storage: StorageService(secureStore: MemoryStore()),
      );
      NetworkEntry? selected;
      await tester.pumpWidget(
        host(
          NetworkSelectorSheet(
            entries: [entry()],
            activeNetworkKey: 'bitcoin:mainnet',
            onSelect: (value) => selected = value,
          ),
          blockchain,
          theme,
        ),
      );
      await tester.pumpAndSettle();
      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle_rounded));
      expect(icon.color, AppChainTheme.bitcoin.accentColor);
      await tester.tap(find.text('Bitcoin Chain'));
      expect(selected?.networkKey, 'bitcoin:mainnet');
      await tester.pumpWidget(const SizedBox.shrink());
      blockchain.dispose();
      theme.dispose();
    },
  );
  testWidgets('Bitcoin preference switch uses Bitcoin adaptive accent', (
    tester,
  ) async {
    final value = (await tester.runAsync(() async {
      final value = await fixture();
      await value.preference.setEnabled(true);
      value.blockchain.setActiveNetworkKey('bitcoin:mainnet');
      return value;
    }))!;
    final theme = ThemeController(storage: value.storage);
    await tester.pumpWidget(
      host(
        BitcoinNetworkPreferenceTile(
          origin: WalletOrigin.derived,
          wallet: value.wallet,
        ),
        value.blockchain,
        theme,
      ),
    );
    await tester.pumpAndSettle();
    final toggle = tester.widget<Switch>(
      find.byKey(const Key('bitcoin-network-preference')),
    );
    expect(toggle.activeThumbColor, AppChainTheme.bitcoin.accentColor);
    expect(
      toggle.activeTrackColor,
      AppChainTheme.bitcoin.accentColor.withValues(alpha: 0.3),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    value.blockchain.dispose();
    theme.dispose();
  });
}
