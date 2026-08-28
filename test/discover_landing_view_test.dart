import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_dapp_entry.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_product_entry.dart';
import 'package:fomowl_wallet/features/discover/catalog/widgets/discover_landing_view.dart';
import 'package:fomowl_wallet/features/mini_apps/mini_app_definition.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';

DiscoverDappEntry _entry(
  String id, {
  int? featuredRank = 1,
  List<String> categories = const ['dex', 'defi'],
}) {
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
    categories: categories,
    supportedChainIds: const [1],
    featuredRank: featuredRank,
    trendingRank: 1,
    isActive: true,
    createdAt: '2026-03-28T00:00:00Z',
    updatedAt: '2026-03-28T00:00:00Z',
  );
}

const _owlletPay = MiniAppDefinition(
  id: 'owllet_pay',
  title: 'OwlletPay',
  description: 'Fund and shop with crypto.',
  launchUrl: 'https://pay.owllet.example',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows loading indicator when catalog and products are empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithApp(
        DiscoverLandingView(
          query: '',
          products: const [],
          dapps: const [],
          filteredDapps: const [],
          categories: const ['Featured'],
          loading: true,
          error: null,
          onRefresh: () async {},
          onOpenProduct: (_) {},
          onOpenDapp: (_) {},
          onOpenOwlletPay: () {},
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders the Figma hierarchy and opens product and dapp cards', (
    tester,
  ) async {
    final uniswap = _entry('uniswap');
    final aave = _entry('aave');
    DiscoverProductEntry? openedProduct;
    DiscoverDappEntry? openedDapp;
    var openedBanner = false;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrapWithApp(
        DiscoverLandingView(
          query: '',
          products: [DiscoverProductEntry.miniApp(_owlletPay)],
          dapps: [uniswap, aave],
          filteredDapps: [uniswap, aave],
          categories: const ['Featured', 'DEX', 'DeFi'],
          loading: false,
          error: null,
          onRefresh: () async {},
          onOpenProduct: (product) => openedProduct = product,
          onOpenDapp: (dapp) => openedDapp = dapp,
          onOpenOwlletPay: () => openedBanner = true,
        ),
      ),
    );

    expect(find.text('OwlletPay'), findsWidgets);
    expect(find.text('FOMOWL Products'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Featured'), findsOneWidget);
    expect(find.text('Trending Tokens'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('discover-owllet-pay-banner')));
    expect(openedBanner, isTrue);

    await tester.tap(find.byKey(const ValueKey('discover-product-owllet_pay')));
    expect(openedProduct?.miniApp?.id, 'owllet_pay');

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('discover-dapp-uniswap')),
      find.byKey(const ValueKey('discover-landing-list')),
      const Offset(0, -220),
    );
    await tester.tap(find.byKey(const ValueKey('discover-dapp-uniswap')));
    expect(openedDapp?.id, 'uniswap');
  });

  testWidgets('search mode hides promotions and lists full catalog matches', (
    tester,
  ) async {
    final uniswap = _entry('uniswap');

    await tester.pumpWidget(
      _wrapWithApp(
        DiscoverLandingView(
          query: 'uni',
          products: [DiscoverProductEntry.miniApp(_owlletPay)],
          dapps: [uniswap, _entry('aave')],
          filteredDapps: [uniswap],
          categories: const ['Featured', 'DEX', 'DeFi'],
          loading: false,
          error: null,
          onRefresh: () async {},
          onOpenProduct: (_) {},
          onOpenDapp: (_) {},
          onOpenOwlletPay: () {},
        ),
      ),
    );

    expect(find.text('Search results'), findsOneWidget);
    expect(find.text('UNISWAP'), findsOneWidget);
    expect(find.text('FOMOWL Products'), findsNothing);
    expect(
      find.byKey(const ValueKey('discover-owllet-pay-banner')),
      findsNothing,
    );
  });

  testWidgets('category filtering and Explore View all expand inline', (
    tester,
  ) async {
    final entries = <DiscoverDappEntry>[
      _entry('one', featuredRank: 1),
      _entry('two', featuredRank: 2),
      _entry('three', featuredRank: 3),
      _entry('four', featuredRank: 4),
      _entry('five', featuredRank: 5),
      _entry('gallery', featuredRank: null, categories: const ['nft']),
    ];

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrapWithApp(
        DiscoverLandingView(
          query: '',
          products: [DiscoverProductEntry.miniApp(_owlletPay)],
          dapps: entries,
          filteredDapps: entries,
          categories: const ['Featured', 'DEX', 'NFTs', 'DeFi'],
          loading: false,
          error: null,
          onRefresh: () async {},
          onOpenProduct: (_) {},
          onOpenDapp: (_) {},
          onOpenOwlletPay: () {},
        ),
      ),
    );

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('view-all-explore')),
      find.byKey(const ValueKey('discover-landing-list')),
      const Offset(0, -220),
    );
    expect(find.byKey(const ValueKey('discover-dapp-five')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('view-all-explore')));
    await tester.pump();
    expect(find.byKey(const ValueKey('discover-dapp-five')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('discover-category-NFTs')));
    await tester.pump();
    expect(find.text('GALLERY'), findsOneWidget);
    expect(find.text('ONE'), findsNothing);
  });

  testWidgets('narrow layout and large text do not overflow', (tester) async {
    final dapp = _entry('a-very-long-decentralized-application-name');
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 700),
          textScaler: TextScaler.linear(1.35),
        ),
        child: _wrapWithApp(
          DiscoverLandingView(
            query: '',
            products: [DiscoverProductEntry.miniApp(_owlletPay)],
            dapps: [dapp],
            filteredDapps: [dapp],
            categories: const [
              'Featured',
              'Shop',
              'DEX',
              'NFTs',
              'AI&Bot',
              'Staking',
              'DeFi',
            ],
            loading: false,
            error: null,
            onRefresh: () async {},
            onOpenProduct: (_) {},
            onOpenDapp: (_) {},
            onOpenOwlletPay: () {},
          ),
        ),
      ),
    );

    final layoutError = tester.takeException();
    expect(layoutError, isNull);
  });
}

Widget _wrapWithApp(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}
