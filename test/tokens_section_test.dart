import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/screens/home/home_portfolio_data.dart';
import 'package:fomowl_wallet/screens/home/widgets/tokens_section.dart';
import 'package:fomowl_wallet/services/nft_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ethereumChain = EvmChain(
    name: 'Ethereum',
    symbol: 'ETH',
    chainId: 1,
    rpcUrl: 'https://rpc.example/1',
  );

  const ethToken = Token(
    symbol: 'ETH',
    name: 'Ethereum',
    contractAddress: '0xeth',
    balance: 1,
    valueUsd: 120,
    changePercent24h: 4.2,
  );

  Future<void> pumpSection(
    WidgetTester tester, {
    VoidCallback? onScan,
    VoidCallback? onOpenSettings,
    VoidCallback? onManageTokens,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TokensSection(
              tokens: const [ethToken],
              portfolioSections: const [
                HomePortfolioSection(chain: ethereumChain, tokens: [ethToken]),
              ],
              isLoading: false,
              isLoadingPortfolio: false,
              isLoadingNfts: false,
              nftPreview: const <NftAsset>[],
              hasMoreNfts: false,
              localization: AppLocalizations.of(context),
              onScan: onScan ?? () {},
              onOpenSettings: onOpenSettings ?? () {},
              onManageTokens: onManageTokens ?? () {},
              onOpenNfts: () {},
              isTokenHidden: (_) => false,
              onSelectToken: (_) {},
              onSelectNftCollection: (_) {},
              chainId: 1,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders tabs in order and opens on tokens by default', (
    tester,
  ) async {
    await pumpSection(tester);

    expect(find.text('Tokens'), findsOneWidget);
    expect(find.text('Portfolio'), findsOneWidget);
    expect(find.text('NFTs'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    expect(find.text('Ethereum'), findsOneWidget);
  });

  testWidgets('shows manage icon on tokens tab and keeps nft tab intact', (
    tester,
  ) async {
    await pumpSection(tester);

    await tester.tap(find.text('Tokens'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    expect(find.text('Ethereum'), findsOneWidget);

    await tester.tap(find.text('NFTs'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.collections_outlined), findsOneWidget);
  });

  testWidgets('maps scan, settings, and token manager toolbar controls', (
    tester,
  ) async {
    var scanTapped = false;
    var settingsTapped = false;
    var manageTapped = false;
    await pumpSection(
      tester,
      onScan: () => scanTapped = true,
      onOpenSettings: () => settingsTapped = true,
      onManageTokens: () => manageTapped = true,
    );

    await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.tap(find.byIcon(Icons.tune_rounded));

    expect(scanTapped, isTrue);
    expect(settingsTapped, isTrue);
    expect(manageTapped, isTrue);
  });
}
