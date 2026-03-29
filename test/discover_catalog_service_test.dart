import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_catalog_service.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_catalog_snapshot.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_dapp_entry.dart';
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
  });
}
