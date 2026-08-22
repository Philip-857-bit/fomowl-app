import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/screens/profile/widgets/settings_item_tile.dart';
import 'package:fomowl_wallet/screens/profile/widgets/settings_wallet_header_card.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';

import 'package:fomowl_wallet/screens/profile/widgets/wallet_theme_selector_sheet.dart';
import 'package:fomowl_wallet/theme/app_chain_theme.dart';
import 'package:fomowl_wallet/theme/theme_controller.dart';

class _FakeBlockchainService extends ChangeNotifier
    implements BlockchainService {
  String _activeNetworkKey = 'evm:1';

  @override
  String get activeNetworkKey => _activeNetworkKey;

  @override
  Future<void> setActiveNetworkKey(String key) async {
    _activeNetworkKey = key;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithTheme({
    required Widget child,
    String networkKey = 'evm:1',
    ThemeController? themeController,
  }) {
    final service = _FakeBlockchainService()..setActiveNetworkKey(networkKey);
    final controller = themeController ?? ThemeController();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BlockchainService>.value(value: service),
        ChangeNotifierProvider<ThemeController>.value(value: controller),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  group('Profile & Settings Widgets Theme Verification', () {
    testWidgets(
      'SettingsWalletHeaderCard renders wallet name, address, and copy icon',
      (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          wrapWithTheme(
            networkKey: 'evm:56', // BSC Gold
            child: SettingsWalletHeaderCard(
              walletName: 'Main Alpha Wallet',
              walletAddress: '0x71C8451234567890123456789012345678903944',
              onTap: () => tapped = true,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Main Alpha Wallet'), findsOneWidget);
        expect(find.text('0x71C8...3944'), findsOneWidget);
        expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

        await tester.tap(find.byType(SettingsWalletHeaderCard));
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'SettingsItemTile renders icon, title, subtitle and responds to taps',
      (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          wrapWithTheme(
            networkKey: 'evm:1',
            child: SettingsItemTile(
              icon: Icons.security,
              title: 'Security Settings',
              subtitle: 'Manage passcode and biometrics',
              attention: true,
              onTap: () => tapped = true,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Security Settings'), findsOneWidget);
        expect(find.text('Manage passcode and biometrics'), findsOneWidget);
        expect(find.byIcon(Icons.security), findsOneWidget);

        final icon = tester.widget<Icon>(find.byIcon(Icons.security));
        expect(icon.color, const Color(0xFF627EEA));

        await tester.tap(find.byType(SettingsItemTile));
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'WalletThemeSelectorSheet renders Classic and Adaptive options and toggles state',
      (tester) async {
        final themeController = ThemeController();
        await themeController.setThemeMode(AppThemeMode.adaptive);

        await tester.pumpWidget(
          wrapWithTheme(
            themeController: themeController,
            child: const WalletThemeSelectorSheet(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Wallet Theme'), findsOneWidget);
        expect(find.text('Classic'), findsOneWidget);
        expect(find.text('(Owllet Default Mode)'), findsOneWidget);
        expect(find.text('Adaptive Theme'), findsOneWidget);

        // Tap Classic
        await tester.tap(find.text('Classic'));
        await tester.pumpAndSettle();

        expect(themeController.isClassic, isTrue);

        // Tap Adaptive Theme
        await tester.tap(find.text('Adaptive Theme'));
        await tester.pumpAndSettle();

        expect(themeController.isAdaptive, isTrue);
      },
    );

    testWidgets(
      'AppChainTheme respects ThemeController classic vs adaptive modes',
      (tester) async {
        final themeController = ThemeController();
        await themeController.setThemeMode(AppThemeMode.classic);

        late AppChainTheme resolvedTheme;

        await tester.pumpWidget(
          wrapWithTheme(
            networkKey: 'evm:56', // BSC Gold
            themeController: themeController,
            child: Builder(
              builder: (ctx) {
                resolvedTheme = ctx.chainTheme;
                return Container();
              },
            ),
          ),
        );
        await tester.pump();

        // In Classic mode, even with BSC active, theme is FOMOwl Signature Red
        expect(
          resolvedTheme.accentColor,
          AppChainTheme.fomowlSignature.accentColor,
        );

        // Switch to Adaptive mode
        await themeController.setThemeMode(AppThemeMode.adaptive);
        await tester.pump();

        // In Adaptive mode, theme is BSC Gold
        expect(resolvedTheme.accentColor, AppChainTheme.bsc.accentColor);
      },
    );
  });
}
