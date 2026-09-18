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
    VoidCallback? onManageTokens,
    bool portfolioEnabled = true,
    List<Token> tokens = const [ethToken],
    bool balancesUnavailable = false,
    bool confirmedZero = false,
    String? freshnessCaption,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TokensSection(
              tokens: tokens,
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
              onManageTokens: onManageTokens ?? () {},
              onOpenNfts: () {},
              isTokenHidden: (_) => false,
              onSelectToken: (_) {},
              onSelectNftCollection: (_) {},
              chainId: 1,
              portfolioEnabled: portfolioEnabled,
              balancesUnavailable: balancesUnavailable,
              confirmedZero: confirmedZero,
              freshnessCaption: freshnessCaption,
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
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    expect(find.text('ETHEREUM'), findsOneWidget);
  });

  testWidgets('shows manage icon on tokens tab and keeps nft tab intact', (
    tester,
  ) async {
    await pumpSection(tester);

    await tester.tap(find.text('Tokens'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    expect(find.text('ETHEREUM'), findsOneWidget);

    await tester.tap(find.text('NFTs'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.collections_outlined), findsOneWidget);
  });

  testWidgets('maps scan and token manager toolbar controls', (tester) async {
    var scanTapped = false;
    var manageTapped = false;
    await pumpSection(
      tester,
      onScan: () => scanTapped = true,
      onManageTokens: () => manageTapped = true,
    );

    await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));
    await tester.tap(find.byIcon(Icons.tune_rounded));

    expect(scanTapped, isTrue);
    expect(manageTapped, isTrue);
  });

  testWidgets('hides the portfolio tab when runtime policy disables it', (
    tester,
  ) async {
    await pumpSection(tester, portfolioEnabled: false);

    expect(find.text('Tokens'), findsOneWidget);
    expect(find.text('Portfolio'), findsNothing);
    expect(find.text('NFTs'), findsOneWidget);
  });

  testWidgets('distinguishes unavailable balances from a confirmed empty wallet', (
    tester,
  ) async {
    await pumpSection(
      tester,
      tokens: const [],
      balancesUnavailable: true,
    );
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);

    await pumpSection(
      tester,
      tokens: const [],
      confirmedZero: true,
    );
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);
  });
}
