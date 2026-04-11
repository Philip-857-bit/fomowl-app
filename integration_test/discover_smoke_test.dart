import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_dapp_entry.dart';
import 'package:fomowl_wallet/features/discover/catalog/widgets/discover_landing_view.dart';
import 'package:fomowl_wallet/features/discover/market/discover_trending_token.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('discover landing renders and opens a curated dapp card', (
    WidgetTester tester,
  ) async {
    DiscoverDappEntry? opened;

    final entry = DiscoverDappEntry(
      id: 'uniswap',
      slug: 'uniswap',
      origin: 'https://app.uniswap.org',
      launchUrl: 'https://app.uniswap.org',
      title: 'Uniswap',
      subtitle: 'Swap tokens',
      logoUrl: null,
      heroImageUrl: null,
      badgeText: 'DEX',
      categories: const ['dex', 'defi'],
      supportedChainIds: const [1, 8453],
      featuredRank: 1,
      trendingRank: 1,
      isActive: true,
      createdAt: '2026-03-28T00:00:00Z',
      updatedAt: '2026-03-28T00:00:00Z',
    );
    const trendingToken = DiscoverTrendingToken(
      id: 'ethereum',
      symbol: 'ETH',
      name: 'Ethereum',
      imageUrl: 'https://example.com/eth.png',
      priceUsd: 3452.12,
      changePercent24h: -1.12,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DiscoverLandingView(
            query: '',
            featuredDapps: [entry],
            trendingDapps: [entry],
            filteredDapps: [entry],
            categories: const ['dex', 'defi'],
            trendingTokens: const [trendingToken],
            loadingTrendingTokens: false,
            trendingTokensError: null,
            loading: false,
            error: null,
            onRefresh: () async {},
            onOpenDapp: (value) => opened = value,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Featured DApps'), findsOneWidget);
    expect(find.text('Bulk Pay'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Uniswap'),
      find.byType(ListView).first,
      const Offset(0, -250),
    );
    expect(find.text('Uniswap'), findsWidgets);

    await tester.tap(find.text('Uniswap').first);
    await tester.pumpAndSettle();

    expect(opened?.id, 'uniswap');
  });
}
