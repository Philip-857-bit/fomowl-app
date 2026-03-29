import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_dapp_entry.dart';
import 'package:fomowl_wallet/features/discover/catalog/widgets/discover_landing_view.dart';

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

  testWidgets(
    'DiscoverLandingView shows loading indicator when empty and loading',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscoverLandingView(
              featuredDapps: const [],
              trendingDapps: const [],
              filteredDapps: const [],
              categories: const [],
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

  testWidgets('DiscoverLandingView renders error and opens tapped dapp', (
    WidgetTester tester,
  ) async {
    DiscoverDappEntry? opened;
    final uniswap = _entry('uniswap');
    final aave = _entry('aave');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscoverLandingView(
            featuredDapps: [uniswap],
            trendingDapps: [aave],
            filteredDapps: [uniswap, aave],
            categories: const ['dex', 'defi'],
            loading: false,
            error: 'Catalog refresh failed.',
            onRefresh: () async {},
            onOpenDapp: (entry) => opened = entry,
          ),
        ),
      ),
    );

    expect(find.text('Catalog refresh failed.'), findsOneWidget);
    expect(find.text('Featured DApps'), findsOneWidget);

    await tester.tap(find.text('UNISWAP').first);
    await tester.pump();

    expect(opened?.id, 'uniswap');
  });
}
