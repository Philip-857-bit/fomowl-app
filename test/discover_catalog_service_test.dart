import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_catalog_service.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_catalog_snapshot.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_dapp_entry.dart';
import 'package:fomowl_wallet/features/discover/discover_url_utils.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DiscoverDappEntry entry({
    required String id,
    required String origin,
    required String launchUrl,
    required bool isActive,
  }) {
    return DiscoverDappEntry(
      id: id,
      slug: id,
      origin: origin,
      launchUrl: launchUrl,
      title: id,
      subtitle: null,
      logoUrl: null,
      heroImageUrl: null,
      badgeText: null,
      categories: const ['dex'],
      supportedChainIds: const [1],
      featuredRank: 1,
      trendingRank: 1,
      isActive: isActive,
      createdAt: '2026-03-28T00:00:00Z',
      updatedAt: '2026-03-28T00:00:00Z',
    );
  }

  group('DiscoverCatalogService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('filters invalid and inactive DApps from backend response', () async {
      final service = DiscoverCatalogService(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'dapps': [
                entry(
                  id: 'uniswap',
                  origin: 'https://app.uniswap.org',
                  launchUrl: 'https://app.uniswap.org',
                  isActive: true,
                ).toJson(),
                entry(
                  id: 'inactive',
                  origin: 'https://inactive.example',
                  launchUrl: 'https://inactive.example',
                  isActive: false,
                ).toJson(),
                entry(
                  id: 'bad-origin',
                  origin: '',
                  launchUrl: 'https://good.example',
                  isActive: true,
                ).toJson(),
                {
                  'id': '',
                  'slug': 'missing-id',
                  'origin': 'https://missing-id.example',
                  'launchUrl': 'https://missing-id.example',
                  'title': 'Missing ID',
                  'categories': ['dex'],
                  'supportedChainIds': [1],
                  'featuredRank': 1,
                  'trendingRank': 1,
                  'isActive': true,
                  'createdAt': '2026-03-28T00:00:00Z',
                  'updatedAt': '2026-03-28T00:00:00Z',
                },
              ],
            }),
            200,
          );
        }),
      );

      final snapshot = await service.getSnapshot(forceRefresh: true);
      expect(snapshot.dapps.map((dapp) => dapp.id), ['uniswap']);

      final cached = await service.loadCachedSnapshot();
      expect(cached?.dapps.map((dapp) => dapp.id), ['uniswap']);
    });

    test('returns fresh cached snapshot without hitting backend', () async {
      final cachedSnapshot = DiscoverCatalogSnapshot(
        dapps: [
          entry(
            id: 'cached',
            origin: 'https://app.aave.com',
            launchUrl: 'https://app.aave.com',
            isActive: true,
          ),
        ],
        fetchedAt: DateTime.now().toUtc(),
      );
      SharedPreferences.setMockInitialValues({
        'discover_catalog_snapshot_v1': jsonEncode(cachedSnapshot.toJson()),
      });

      var callCount = 0;
      final service = DiscoverCatalogService(
        client: MockClient((request) async {
          callCount += 1;
          return http.Response('{}', 500);
        }),
      );

      final snapshot = await service.getSnapshot();
      expect(snapshot.dapps.map((dapp) => dapp.id), ['cached']);
      expect(callCount, 0);
    });

    test(
      'bundled fallback is stale and complements native Owllet features',
      () async {
        final service = DiscoverCatalogService(
          client: MockClient((request) async {
            return http.Response('{}', 500);
          }),
        );

        final snapshot = await service.getSnapshot();
        expect(snapshot.dapps.map((dapp) => dapp.slug), <String>[
          'aave',
          'lido',
          'snapshot',
          'galxe',
        ]);
        expect(snapshot.isFresh, isFalse);

        const nativeFeatureCategories = <String>{
          'swap',
          'dex',
          'exchange',
          'bridge',
          'nft',
          'nfts',
          'collectibles',
          'marketplace',
          'onramp',
          'offramp',
          'payments',
        };
        final fallbackCategories = snapshot.dapps
            .expand((dapp) => dapp.categories)
            .map((category) => category.toLowerCase())
            .toSet();
        expect(
          fallbackCategories.intersection(nativeFeatureCategories),
          isEmpty,
        );

        expect(
          {for (final dapp in snapshot.dapps) dapp.slug: dapp.origin},
          <String, String>{
            'aave': 'https://app.aave.com',
            'lido': 'https://stake.lido.fi',
            'snapshot': 'https://snapshot.box',
            'galxe': 'https://app.galxe.com',
          },
        );
        for (final dapp in snapshot.dapps) {
          expect(
            normalizeOriginFromUri(Uri.parse(dapp.launchUrl)),
            dapp.origin,
            reason: '${dapp.slug} must launch from its allowlisted origin',
          );
        }

        final cached = await service.loadCachedSnapshot();
        expect(cached?.dapps.map((dapp) => dapp.slug), <String>[
          'aave',
          'lido',
          'snapshot',
          'galxe',
        ]);
        expect(cached?.isFresh, isFalse);
      },
    );
  });
}
