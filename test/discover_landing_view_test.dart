import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_dapp_entry.dart';
import 'package:fomowl_wallet/features/discover/catalog/widgets/discover_landing_view.dart';
import 'package:fomowl_wallet/features/discover/market/discover_trending_token.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';

DiscoverDappEntry _entry(String id) {
  return DiscoverDappEntry(
    id: id,
    slug: id,
    origin: 'https://$id.example',
    launchUrl: 'https://$id.example',
    title: id.toUpperCase(),
    subtitle: '$id subtitle',
    logoUrl: null,
    heroImageUrl: null,
    badgeText: 'DEX',
    categories: const ['dex', 'defi'],
    supportedChainIds: const [1],
    featuredRank: 1,
    trendingRank: 1,
    isActive: true,
    createdAt: '2026-03-28T00:00:00Z',
    updatedAt: '2026-03-28T00:00:00Z',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const trendingToken = DiscoverTrendingToken(
    id: 'ethereum',
    symbol: 'ETH',
    name: 'Ethereum',
    imageUrl: 'https://example.com/eth.png',
    priceUsd: 3452.12,
    changePercent24h: -1.12,
  );

  testWidgets(
    'DiscoverLandingView shows loading indicator when empty and loading',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          Scaffold(
            body: DiscoverLandingView(
              query: '',
              featuredDapps: const [],
              trendingDapps: const [],
              filteredDapps: const [],
              categories: const [],
              trendingTokens: const [],
              loadingTrendingTokens: true,
              trendingTokensError: null,
              loading: true,
              error: null,
              onRefresh: () async {},
              onOpenDapp: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets('DiscoverLandingView renders key sections and dapp content', (
    WidgetTester tester,
  ) async {
    final uniswap = _entry('uniswap');
    final aave = _entry('aave');

    await tester.pumpWidget(
      _wrapWithApp(
        Scaffold(
          body: DiscoverLandingView(
            query: '',
            featuredDapps: [uniswap],
            trendingDapps: [aave],
            filteredDapps: [uniswap, aave],
            categories: const ['dex', 'defi'],
            trendingTokens: const [trendingToken],
            loadingTrendingTokens: false,
            trendingTokensError: null,
            loading: false,
            error: 'Catalog refresh failed.',
            onRefresh: () async {},
            onOpenDapp: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Featured DApps'), findsOneWidget);
    expect(find.text('Cash In'), findsOneWidget);
    expect(find.text('Bulk Pay'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Trending Tokens'),
      find.byType(ListView).first,
      const Offset(0, -250),
    );
    expect(find.text('Trending Tokens'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('UNISWAP'),
      find.byType(ListView).first,
      const Offset(0, -250),
    );

    expect(find.text('UNISWAP'), findsOneWidget);
  });
}

Widget _wrapWithApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}
