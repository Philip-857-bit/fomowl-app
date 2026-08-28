import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_dapp_entry.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_product_entry.dart';
import 'package:fomowl_wallet/features/discover/catalog/widgets/discover_landing_view.dart';
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
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DiscoverLandingView(
            query: '',
            products: [DiscoverProductEntry.dapp(entry)],
            dapps: [entry],
            filteredDapps: [entry],
            categories: const ['Featured', 'DEX', 'DeFi'],
            loading: false,
            error: null,
            onRefresh: () async {},
            onOpenProduct: (_) {},
            onOpenDapp: (value) => opened = value,
            onOpenOwlletPay: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('FOMOWL Products'), findsOneWidget);
    expect(find.text('OwlletPay'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Uniswap'),
      find.byType(ListView).first,
      const Offset(0, -250),
    );
    expect(find.text('Uniswap'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('discover-dapp-uniswap')));
    await tester.pumpAndSettle();

    expect(opened?.id, 'uniswap');
  });
}
