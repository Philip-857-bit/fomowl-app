import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_dapp_entry.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_product_entry.dart';
import 'package:fomowl_wallet/features/mini_apps/mini_app_definition.dart';

DiscoverDappEntry _dapp({
  required String id,
  required String origin,
  int? rank,
  bool isFomowlProduct = true,
  List<String> categories = const ['defi'],
}) {
  return DiscoverDappEntry(
    id: id,
    slug: id,
    origin: origin,
    launchUrl: '$origin/app',
    title: id,
    subtitle: null,
    logoUrl: null,
    heroImageUrl: null,
    badgeText: null,
    categories: categories,
    supportedChainIds: const [1],
    featuredRank: rank,
    trendingRank: null,
    isActive: true,
    isFomowlProduct: isFomowlProduct,
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-01T00:00:00Z',
  );
}

void main() {
  const pay = MiniAppDefinition(
    id: 'owllet_pay',
    title: 'OwlletPay',
    description: 'Pay',
    launchUrl: 'https://pay.owllet.example/home',
    allowedOrigins: ['https://checkout.owllet.example'],
  );
  const affiliate = MiniAppDefinition(
    id: 'affiliate',
    title: 'Affiliate',
    description: 'Affiliate',
    launchUrl: 'https://affiliate.owllet.example',
  );

  test('merges configured mini apps before ranked catalog entries', () {
    final products = DiscoverProductEntry.merge(
      miniApps: const [pay, affiliate],
      catalogDapps: [
        _dapp(id: 'third', origin: 'https://third.example', rank: 3),
        _dapp(id: 'first', origin: 'https://first.example', rank: 1),
        _dapp(
          id: 'not-fomowl',
          origin: 'https://hidden.example',
          isFomowlProduct: false,
        ),
      ],
    );

    expect(products.map((entry) => entry.id), [
      'owllet_pay',
      'affiliate',
      'first',
      'third',
    ]);
  });

  test(
    'filters unconfigured mini apps and deduplicates normalized origins',
    () {
      const unavailable = MiniAppDefinition(
        id: 'future',
        title: 'Future',
        description: 'Future',
        launchUrl: null,
      );
      final products = DiscoverProductEntry.merge(
        miniApps: const [pay, unavailable],
        catalogDapps: [
          _dapp(
            id: 'duplicate',
            origin: 'HTTPS://PAY.OWLLET.EXAMPLE:443',
            rank: 1,
          ),
          _dapp(id: 'unique', origin: 'https://unique.example', rank: 2),
        ],
      );

      expect(products.map((entry) => entry.id), ['owllet_pay', 'unique']);
    },
  );

  test('orders preferred categories then appends backend categories', () {
    final categories = DiscoverProductEntry.orderedCategories([
      _dapp(
        id: 'one',
        origin: 'https://one.example',
        rank: 1,
        categories: const ['gaming', 'defi', 'nft'],
      ),
      _dapp(
        id: 'two',
        origin: 'https://two.example',
        rank: 2,
        categories: const ['analytics', 'dex'],
      ),
    ]);

    expect(categories.take(7), [
      'Featured',
      'Shop',
      'DEX',
      'NFTs',
      'AI&Bot',
      'Staking',
      'DeFi',
    ]);
    expect(categories.skip(7), ['Analytics', 'Gaming']);
  });

  test('resolves trusted catalog origins to mini-app host routing', () {
    final matched = DiscoverProductEntry.trustedMiniAppForDapp(
      _dapp(
        id: 'pay-catalog',
        origin: 'https://checkout.owllet.example',
        rank: 1,
      ),
      const [pay, affiliate],
    );
    final ordinary = DiscoverProductEntry.trustedMiniAppForDapp(
      _dapp(id: 'ordinary', origin: 'https://ordinary.example', rank: 2),
      const [pay, affiliate],
    );

    expect(matched?.id, 'owllet_pay');
    expect(ordinary, isNull);
  });
}
