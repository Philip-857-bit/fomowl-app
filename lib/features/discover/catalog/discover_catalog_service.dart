import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/app_environment.dart';
import '../../../services/blockchain/blockchain_catalog.dart';
import '../../../services/http_client_service.dart';
import '../discover_url_utils.dart';
import 'discover_catalog_snapshot.dart';
import 'discover_dapp_entry.dart';

class DiscoverCatalogService {
  static const String _cacheKey = 'discover_catalog_snapshot_v1';

  DiscoverCatalogService({http.Client? client})
    : _client = client ?? HttpClientService().client;

  final http.Client _client;

  Future<DiscoverCatalogSnapshot?> loadCachedSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return DiscoverCatalogSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<DiscoverCatalogSnapshot> getSnapshot({
    bool forceRefresh = false,
  }) async {
    final cached = await loadCachedSnapshot();
    if (!forceRefresh && cached != null && cached.isFresh) {
      return cached;
    }

    try {
      final fresh = await _fetchFromBackend();
      await _saveSnapshot(fresh);
      return fresh;
    } catch (_) {
      if (cached != null && cached.isFresh) {
        return cached;
      }
      final fallback = _bundledSnapshot();
      await _saveSnapshot(fallback);
      return fallback;
    }
  }

  Future<DiscoverCatalogSnapshot> _fetchFromBackend() async {
    final response = await _client
        .get(AppEnvironment.discover('/catalog'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to load Discover catalog.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid Discover catalog response.');
    }

    final dapps = (decoded['dapps'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((entry) {
          try {
            return DiscoverDappEntry.fromJson(entry.cast<String, dynamic>());
          } on FormatException catch (error) {
            debugPrint('Skipping invalid Discover DApp entry: $error');
            return null;
          }
        })
        .whereType<DiscoverDappEntry>()
        .where(
          (entry) =>
              entry.isActive &&
              entry.launchUrl.isNotEmpty &&
              normalizeDiscoverOrigin(entry.origin) != null,
        )
        .toList(growable: false);

    return DiscoverCatalogSnapshot(
      dapps: dapps,
      fetchedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> _saveSnapshot(DiscoverCatalogSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(snapshot.toJson()));
  }

  /// Every EVM chain the wallet can switch to.
  ///
  /// Derived from [BlockchainCatalog] rather than hand-listed so the bundled
  /// fallback catalog can never drift behind the chain registry again. The
  /// hand-maintained copies previously stopped at Arbitrum, which left newer
  /// networks unusable in the fallback path and misreported per-DApp network
  /// support in the UI.
  static List<int> get _walletEvmChainIds => BlockchainCatalog.builtInChains
      .map((chain) => chain.chainId)
      .toList(growable: false);

  DiscoverCatalogSnapshot _bundledSnapshot() {
    // Keep the emergency catalog complementary to Owllet's native product.
    // Swap, bridge, NFT portfolio/marketplace, and fiat funding experiences
    // already have first-party surfaces and should not be duplicated here.
    final walletChainIds = _walletEvmChainIds;
    return DiscoverCatalogSnapshot(
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      dapps: <DiscoverDappEntry>[
        DiscoverDappEntry(
          id: 'discover-aave',
          slug: 'aave',
          origin: 'https://app.aave.com',
          launchUrl: 'https://app.aave.com',
          title: 'Aave',
          subtitle: 'Lend and borrow on major EVM networks',
          logoUrl: null,
          heroImageUrl: null,
          badgeText: 'LENDING',
          categories: <String>['defi', 'lending'],
          supportedChainIds: walletChainIds,
          featuredRank: 1,
          trendingRank: 1,
          isActive: true,
          createdAt: '2026-04-07T00:00:00Z',
          updatedAt: '2026-04-07T00:00:00Z',
        ),
        DiscoverDappEntry(
          id: 'discover-lido',
          slug: 'lido',
          origin: 'https://stake.lido.fi',
          launchUrl: 'https://stake.lido.fi',
          title: 'Lido',
          subtitle: 'Stake ETH and manage liquid staking positions',
          logoUrl: null,
          heroImageUrl: null,
          badgeText: 'STAKING',
          categories: <String>['staking'],
          supportedChainIds: walletChainIds,
          featuredRank: 2,
          trendingRank: 2,
          isActive: true,
          createdAt: '2026-08-27T00:00:00Z',
          updatedAt: '2026-08-27T00:00:00Z',
        ),
        DiscoverDappEntry(
          id: 'discover-snapshot',
          slug: 'snapshot',
          origin: 'https://snapshot.box',
          launchUrl: 'https://snapshot.box',
          title: 'Snapshot',
          subtitle: 'Join community governance and vote on proposals',
          logoUrl: null,
          heroImageUrl: null,
          badgeText: 'GOVERNANCE',
          categories: <String>['governance'],
          supportedChainIds: walletChainIds,
          featuredRank: 3,
          trendingRank: 3,
          isActive: true,
          createdAt: '2026-08-27T00:00:00Z',
          updatedAt: '2026-08-27T00:00:00Z',
        ),
        DiscoverDappEntry(
          id: 'discover-galxe',
          slug: 'galxe',
          origin: 'https://app.galxe.com',
          launchUrl: 'https://app.galxe.com/quest',
          title: 'Galxe',
          subtitle: 'Discover web3 communities, quests, and rewards',
          logoUrl: null,
          heroImageUrl: null,
          badgeText: 'QUESTS',
          categories: <String>['community'],
          supportedChainIds: walletChainIds,
          featuredRank: 4,
          trendingRank: 4,
          isActive: true,
          createdAt: '2026-08-27T00:00:00Z',
          updatedAt: '2026-08-27T00:00:00Z',
        ),
      ],
    );
  }
}
