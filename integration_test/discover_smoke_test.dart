import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_dapp_entry.dart';
import 'package:fomowl_wallet/features/discover/catalog/widgets/discover_landing_view.dart';
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscoverLandingView(
            featuredDapps: [entry],
            trendingDapps: [entry],
            filteredDapps: [entry],
            categories: const ['dex', 'defi'],
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
    expect(find.text('Uniswap'), findsWidgets);

    await tester.tap(find.text('Uniswap').first);
    await tester.pumpAndSettle();

    expect(opened?.id, 'uniswap');
  });
}
