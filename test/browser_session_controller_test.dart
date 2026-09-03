import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/discover/browser/browser_session_controller.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_catalog_service.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_catalog_snapshot.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_dapp_entry.dart';

class _FakeDiscoverCatalogService extends DiscoverCatalogService {
  _FakeDiscoverCatalogService({
    this.snapshot,
    this.cachedSnapshot,
    this.error,
    this.cacheError,
  });

  final DiscoverCatalogSnapshot? snapshot;
  final DiscoverCatalogSnapshot? cachedSnapshot;
  final Object? error;
  final Object? cacheError;

  @override
  Future<DiscoverCatalogSnapshot?> loadCachedSnapshot() async {
    if (cacheError != null) {
      throw cacheError!;
    }
    return cachedSnapshot;
  }

  @override
  Future<DiscoverCatalogSnapshot> getSnapshot({
    bool forceRefresh = false,
  }) async {
    if (error != null) {
      throw error!;
    }
    return snapshot!;
  }
}

DiscoverDappEntry _entry({
  required String id,
  required String origin,
  required String launchUrl,
  required List<String> categories,
  int? featuredRank,
  int? trendingRank,
}) {
  return DiscoverDappEntry(
    id: id,
    slug: id,
    origin: origin,
    launchUrl: launchUrl,
    title: id,
    subtitle: '$id subtitle',
    logoUrl: null,
    heroImageUrl: null,
    badgeText: null,
    categories: categories,
    supportedChainIds: const [1],
    featuredRank: featuredRank,
    trendingRank: trendingRank,
    isActive: true,
    createdAt: '2026-03-28T00:00:00Z',
    updatedAt: '2026-03-28T00:00:00Z',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BrowserSessionController', () {
    test(
      'loadCatalog populates derived featured/trending/categories',
      () async {
        final controller = BrowserSessionController(
          catalogService: _FakeDiscoverCatalogService(
            snapshot: DiscoverCatalogSnapshot(
              dapps: [
                _entry(
                  id: 'uniswap',
                  origin: 'https://app.uniswap.org',
                  launchUrl: 'https://app.uniswap.org',
                  categories: const ['dex', 'defi'],
                  featuredRank: 2,
                  trendingRank: 1,
                ),
                _entry(
                  id: 'aave',
                  origin: 'https://app.aave.com',
                  launchUrl: 'https://app.aave.com',
                  categories: const ['lending', 'defi'],
                  featuredRank: 1,
                  trendingRank: 2,
                ),
              ],
              fetchedAt: DateTime.now().toUtc(),
            ),
          ),
        );

        await controller.loadCatalog();

        expect(controller.snapshot, isNotNull);
        expect(controller.featuredDapps.map((dapp) => dapp.id), [
          'aave',
          'uniswap',
        ]);
        expect(controller.trendingDapps.map((dapp) => dapp.id), [
          'uniswap',
          'aave',
        ]);
        expect(controller.categories, ['defi', 'dex', 'lending']);
      },
    );

    test(
      'loadCatalog falls back to cached snapshot when refresh fails',
      () async {
        final cachedSnapshot = DiscoverCatalogSnapshot(
          dapps: [
            _entry(
              id: 'cached',
              origin: 'https://cached.example',
              launchUrl: 'https://cached.example',
              categories: const ['defi'],
            ),
          ],
          fetchedAt: DateTime.now().toUtc(),
        );
        final controller = BrowserSessionController(
          catalogService: _FakeDiscoverCatalogService(
            cachedSnapshot: cachedSnapshot,
            error: StateError('catalog fetch failed'),
          ),
        );

        await controller.loadCatalog();

        expect(controller.snapshot?.dapps.map((dapp) => dapp.id), ['cached']);
        expect(controller.catalogError, contains('catalog fetch failed'));
      },
    );

    test(
      'loadCatalog keeps both live and cached failure details when fallback fails',
      () async {
        final controller = BrowserSessionController(
          catalogService: _FakeDiscoverCatalogService(
            error: StateError('catalog fetch failed'),
            cacheError: StateError('cache fetch failed'),
          ),
        );

        await controller.loadCatalog();

        expect(controller.snapshot, isNull);
        expect(controller.catalogError, contains('catalog fetch failed'));
        expect(controller.catalogError, contains('cache fetch failed'));
      },
    );

    test(
      'openManualInput opens non-allowlisted URL in general web mode',
      () async {
        final controller = BrowserSessionController(
          catalogService: _FakeDiscoverCatalogService(
            snapshot: DiscoverCatalogSnapshot(
              dapps: [
                _entry(
                  id: 'uniswap',
                  origin: 'https://app.uniswap.org',
                  launchUrl: 'https://app.uniswap.org',
                  categories: const ['dex'],
                ),
              ],
              fetchedAt: DateTime.now().toUtc(),
            ),
          ),
        );
        await controller.loadCatalog();

        controller.openManualInput('https://example.com');

        expect(controller.viewState, DiscoverViewState.browser);
        expect(controller.currentUri?.toString(), 'https://example.com');
        expect(controller.activeDapp, isNull);
        expect(
          controller.browserAccessMode,
          DiscoverBrowserAccessMode.generalWeb,
        );
      },
    );

    test(
      'allowsNavigation allows general browsing even when snapshot is stale',
      () async {
        final controller = BrowserSessionController(
          catalogService: _FakeDiscoverCatalogService(
            snapshot: DiscoverCatalogSnapshot(
              dapps: [
                _entry(
                  id: 'uniswap',
                  origin: 'https://app.uniswap.org',
                  launchUrl: 'https://app.uniswap.org',
                  categories: const ['dex'],
                ),
              ],
              fetchedAt: DateTime.now().toUtc().subtract(
                const Duration(hours: 2),
              ),
            ),
          ),
        );
        await controller.loadCatalog();

        final allowed = controller.allowsNavigation(
          Uri.parse('https://app.uniswap.org'),
        );
        expect(allowed, isTrue);
        expect(controller.viewState, DiscoverViewState.landing);
      },
    );

    test(
      'canInjectProviderFor requires a fresh approved injectable origin',
      () async {
        final controller = BrowserSessionController(
          catalogService: _FakeDiscoverCatalogService(
            snapshot: DiscoverCatalogSnapshot(
              dapps: [
                _entry(
                  id: 'uniswap',
                  origin: 'https://app.uniswap.org',
                  launchUrl: 'https://app.uniswap.org',
                  categories: const ['dex'],
                ),
                _entry(
                  id: 'local',
                  origin: 'http://localhost:3000',
                  launchUrl: 'http://localhost:3000',
                  categories: const ['dev'],
                ),
              ],
              fetchedAt: DateTime.now().toUtc(),
            ),
          ),
        );
        await controller.loadCatalog();

        expect(
          controller.canInjectProviderFor(Uri.parse('https://app.uniswap.org')),
          isTrue,
        );
        expect(
          controller.canInjectProviderFor(Uri.parse('http://localhost:3000')),
          isTrue,
        );
        expect(
          controller.canInjectProviderFor(Uri.parse('https://example.com')),
          isTrue,
        );
        expect(
          controller.shouldInjectDappDetectorFor(
            Uri.parse('https://example.com'),
          ),
          isFalse,
        );
      },
    );

    test('allowsNavigation blocks phishing and scam websites', () async {
      final controller = BrowserSessionController(
        catalogService: _FakeDiscoverCatalogService(
          snapshot: DiscoverCatalogSnapshot(
            dapps: const [],
            fetchedAt: DateTime.now().toUtc(),
          ),
        ),
      );
      await controller.loadCatalog();

      final allowedSafe = controller.allowsNavigation(
        Uri.parse('https://app.uniswap.org'),
      );
      expect(allowedSafe, isTrue);
      expect(controller.viewState, DiscoverViewState.landing);

      final allowedPhishing = controller.allowsNavigation(
        Uri.parse('https://uniswap-v4-airdrop.com'),
      );
      expect(allowedPhishing, isFalse);
      expect(controller.viewState, DiscoverViewState.blocked);
      expect(controller.blockedState?.reason, contains('phishing'));
    });

    test('openManualInput submits DuckDuckGo search for plain text', () async {
      final controller = BrowserSessionController(
        catalogService: _FakeDiscoverCatalogService(
          snapshot: DiscoverCatalogSnapshot(
            dapps: const [],
            fetchedAt: DateTime.now().toUtc(),
          ),
        ),
      );
      await controller.loadCatalog();

      controller.openManualInput('best bridge for base');

      expect(controller.viewState, DiscoverViewState.browser);
      expect(
        controller.currentUri?.toString(),
        'https://duckduckgo.com/?q=best+bridge+for+base',
      );
      expect(
        controller.browserAccessMode,
        DiscoverBrowserAccessMode.generalWeb,
      );
    });

    test(
      'updateLoadedPage clears active dapp after leaving allowlisted origin',
      () async {
        final controller = BrowserSessionController(
          catalogService: _FakeDiscoverCatalogService(
            snapshot: DiscoverCatalogSnapshot(
              dapps: [
                _entry(
                  id: 'uniswap',
                  origin: 'https://app.uniswap.org',
                  launchUrl: 'https://app.uniswap.org',
                  categories: const ['dex'],
                ),
              ],
              fetchedAt: DateTime.now().toUtc(),
            ),
          ),
        );
        await controller.loadCatalog();
        controller.openDapp(
          _entry(
            id: 'uniswap',
            origin: 'https://app.uniswap.org',
            launchUrl: 'https://app.uniswap.org',
            categories: const ['dex'],
          ),
        );

        controller.updateLoadedPage(
          Uri.parse('https://example.com'),
          title: 'Example',
        );

        expect(controller.activeDapp, isNull);
        expect(
          controller.browserAccessMode,
          DiscoverBrowserAccessMode.generalWeb,
        );
      },
    );

    test(
      'updateLoadedPage records history and caps it at 20 entries',
      () async {
        final controller = BrowserSessionController(
          catalogService: _FakeDiscoverCatalogService(
            snapshot: DiscoverCatalogSnapshot(
              dapps: [
                _entry(
                  id: 'local',
                  origin: 'http://localhost:3000',
                  launchUrl: 'http://localhost:3000',
                  categories: const ['dev'],
                ),
              ],
              fetchedAt: DateTime.now().toUtc(),
            ),
          ),
        );
        await controller.loadCatalog();

        for (var index = 0; index < 25; index++) {
          controller.updateLoadedPage(
            Uri.parse('http://localhost:3000/page-$index'),
            title: 'Page $index',
          );
        }

        expect(controller.history.length, 20);
        expect(controller.history.first.title, 'Page 24');
        expect(controller.history.last.title, 'Page 5');
      },
    );

    test('returnToLanding clears active browser state', () async {
      final controller = BrowserSessionController(
        catalogService: _FakeDiscoverCatalogService(
          snapshot: DiscoverCatalogSnapshot(
            dapps: [
              _entry(
                id: 'uniswap',
                origin: 'https://app.uniswap.org',
                launchUrl: 'https://app.uniswap.org',
                categories: const ['dex'],
              ),
            ],
            fetchedAt: DateTime.now().toUtc(),
          ),
        ),
      );
      await controller.loadCatalog();
      controller.openManualInput('https://app.uniswap.org');

      controller.returnToLanding();

      expect(controller.viewState, DiscoverViewState.landing);
      expect(controller.activeDapp, isNull);
      expect(controller.currentUri, isNull);
      expect(controller.pageTitle, isNull);
      expect(controller.blockedState, isNull);
    });
  });
}
