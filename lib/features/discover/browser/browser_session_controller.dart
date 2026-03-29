import 'package:flutter/foundation.dart';

import '../catalog/discover_catalog_service.dart';
import '../catalog/discover_catalog_snapshot.dart';
import '../catalog/discover_dapp_entry.dart';
import '../discover_url_utils.dart';
import 'blocked_navigation_state.dart';
import 'browser_history_entry.dart';

enum DiscoverViewState { landing, browser, blocked }

class BrowserSessionController extends ChangeNotifier {
  BrowserSessionController({required DiscoverCatalogService catalogService})
    : _catalogService = catalogService;

  final DiscoverCatalogService _catalogService;

  DiscoverCatalogSnapshot? _snapshot;
  DiscoverViewState _viewState = DiscoverViewState.landing;
  BlockedNavigationState? _blockedState;
  DiscoverDappEntry? _activeDapp;
  Uri? _currentUri;
  String? _pageTitle;
  String _query = '';
  bool _loadingCatalog = false;
  String? _catalogError;
  final List<BrowserHistoryEntry> _history = <BrowserHistoryEntry>[];

  DiscoverCatalogSnapshot? get snapshot => _snapshot;
  DiscoverViewState get viewState => _viewState;
  BlockedNavigationState? get blockedState => _blockedState;
  DiscoverDappEntry? get activeDapp => _activeDapp;
  Uri? get currentUri => _currentUri;
  String? get pageTitle => _pageTitle;
  String get query => _query;
  bool get loadingCatalog => _loadingCatalog;
  String? get catalogError => _catalogError;
  List<BrowserHistoryEntry> get history => List.unmodifiable(_history);

  List<DiscoverDappEntry> get filteredDapps {
    final dapps = _snapshot?.dapps ?? const <DiscoverDappEntry>[];
    if (_query.trim().isEmpty) {
      return dapps;
    }
    return dapps
        .where((entry) => entry.matchesQuery(_query))
        .toList(growable: false);
  }

  List<DiscoverDappEntry> get featuredDapps {
    final dapps = filteredDapps
        .where((entry) => entry.featuredRank != null)
        .toList();
    dapps.sort(
      (left, right) =>
          (left.featuredRank ?? 9999).compareTo(right.featuredRank ?? 9999),
    );
    return dapps;
  }

  List<DiscoverDappEntry> get trendingDapps {
    final dapps = filteredDapps
        .where((entry) => entry.trendingRank != null)
        .toList();
    dapps.sort(
      (left, right) =>
          (left.trendingRank ?? 9999).compareTo(right.trendingRank ?? 9999),
    );
    return dapps;
  }

  List<String> get categories {
    final values = <String>{};
    for (final dapp in filteredDapps) {
      values.addAll(dapp.categories);
    }
    final sorted = values.toList()..sort();
    return sorted;
  }

  Future<void> loadCatalog({bool forceRefresh = false}) async {
    if (_loadingCatalog) {
      return;
    }
    _loadingCatalog = true;
    _catalogError = null;
    notifyListeners();
    try {
      _snapshot = await _catalogService.getSnapshot(forceRefresh: forceRefresh);
    } catch (error) {
      _catalogError = error.toString();
      _snapshot ??= await _catalogService.loadCachedSnapshot();
    } finally {
      _loadingCatalog = false;
      notifyListeners();
    }
  }

  void updateQuery(String value) {
    if (_query == value) {
      return;
    }
    _query = value;
    notifyListeners();
  }

  void returnToLanding() {
    _viewState = DiscoverViewState.landing;
    _blockedState = null;
    _activeDapp = null;
    _currentUri = null;
    _pageTitle = null;
    notifyListeners();
  }

  void openDapp(DiscoverDappEntry dapp) {
    final uri = Uri.tryParse(dapp.launchUrl);
    if (uri == null) {
      showBlocked(
        BlockedNavigationState(
          url: dapp.launchUrl,
          origin: dapp.origin,
          reason: 'The DApp launch URL is invalid.',
        ),
      );
      return;
    }
    _activeDapp = dapp;
    _currentUri = uri;
    _blockedState = null;
    _pageTitle = dapp.title;
    _viewState = DiscoverViewState.browser;
    _recordHistory(uri, title: dapp.title);
    notifyListeners();
  }

  void openManualInput(String value) {
    final uri = normalizeDiscoverUri(value);
    if (uri == null) {
      showBlocked(
        const BlockedNavigationState(
          url: '',
          origin: '',
          reason: 'Enter a valid allowlisted URL.',
        ),
      );
      return;
    }

    final matchingDapp = findDappByOrigin(normalizeOriginFromUri(uri));
    if (matchingDapp == null) {
      showBlocked(
        BlockedNavigationState(
          url: uri.toString(),
          origin: normalizeOriginFromUri(uri),
          reason: 'This DApp is not approved for the in-app browser.',
        ),
      );
      return;
    }

    _activeDapp = matchingDapp;
    _currentUri = uri;
    _blockedState = null;
    _pageTitle = matchingDapp.title;
    _viewState = DiscoverViewState.browser;
    _recordHistory(uri, title: matchingDapp.title);
    notifyListeners();
  }

  bool allowsNavigation(Uri uri) {
    if (_snapshot == null || !(_snapshot?.isFresh ?? false)) {
      showBlocked(
        BlockedNavigationState(
          url: uri.toString(),
          origin: normalizeOriginFromUri(uri),
          reason:
              'The Discover allowlist snapshot is unavailable or expired. Refresh Discover before opening DApps.',
        ),
      );
      return false;
    }

    final origin = normalizeOriginFromUri(uri);
    if (findDappByOrigin(origin) == null) {
      showBlocked(
        BlockedNavigationState(
          url: uri.toString(),
          origin: origin,
          reason: 'This DApp origin is not on the Owllet allowlist.',
        ),
      );
      return false;
    }

    return true;
  }

  bool canInjectProviderFor(Uri uri) {
    if (!(_snapshot?.isFresh ?? false)) {
      return false;
    }
    if (!isDiscoverInjectableUri(uri)) {
      return false;
    }
    return findDappByOrigin(normalizeOriginFromUri(uri)) != null;
  }

  DiscoverDappEntry? findDappByOrigin(String origin) {
    for (final dapp in _snapshot?.dapps ?? const <DiscoverDappEntry>[]) {
      if (dapp.origin == origin) {
        return dapp;
      }
    }
    return null;
  }

  void updateLoadedPage(Uri uri, {String? title}) {
    _currentUri = uri;
    _activeDapp ??= findDappByOrigin(normalizeOriginFromUri(uri));
    _pageTitle = title?.trim().isNotEmpty == true ? title!.trim() : _pageTitle;
    _recordHistory(uri, title: title);
    if (_viewState != DiscoverViewState.browser) {
      _viewState = DiscoverViewState.browser;
    }
    notifyListeners();
  }

  void showBlocked(BlockedNavigationState state) {
    _blockedState = state;
    _viewState = DiscoverViewState.blocked;
    notifyListeners();
  }

  void _recordHistory(Uri uri, {String? title}) {
    _history.insert(
      0,
      BrowserHistoryEntry(
        url: uri.toString(),
        origin: normalizeOriginFromUri(uri),
        title: title,
        visitedAt: DateTime.now().toUtc(),
      ),
    );
    if (_history.length > 20) {
      _history.removeRange(20, _history.length);
    }
  }
}
