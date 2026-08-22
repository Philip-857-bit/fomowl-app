import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../services/security/phishing_protection_service.dart';
import '../catalog/discover_catalog_service.dart';
import '../catalog/discover_catalog_snapshot.dart';
import '../catalog/discover_dapp_entry.dart';
import '../discover_url_utils.dart';
import 'blocked_navigation_state.dart';
import 'browser_history_entry.dart';
import 'discover_history_storage.dart';

enum DiscoverViewState { landing, browser, blocked }

enum DiscoverBrowserAccessMode { generalWeb, allowlistedDapp }

class BrowserSessionController extends ChangeNotifier {
  BrowserSessionController({
    required DiscoverCatalogService catalogService,
    DiscoverHistoryStorage? historyStorage,
  }) : _catalogService = catalogService,
       _historyStorage = historyStorage ?? DiscoverHistoryStorage();

  final DiscoverCatalogService _catalogService;
  final DiscoverHistoryStorage _historyStorage;

  DiscoverCatalogSnapshot? _snapshot;
  DiscoverViewState _viewState = DiscoverViewState.landing;
  BlockedNavigationState? _blockedState;
  DiscoverDappEntry? _activeDapp;
  Uri? _currentUri;
  String? _pageTitle;
  String _query = '';
  bool _loadingCatalog = false;
  String? _catalogError;
  String? _scopeKey;
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
  DiscoverBrowserAccessMode get browserAccessMode {
    final currentUri = _currentUri;
    if (currentUri != null &&
        findDappByOrigin(normalizeOriginFromUri(currentUri)) != null) {
      return DiscoverBrowserAccessMode.allowlistedDapp;
    }
    return DiscoverBrowserAccessMode.generalWeb;
  }

  List<DiscoverDappEntry> get filteredDapps {
    final dapps = _snapshot?.dapps ?? const <DiscoverDappEntry>[];
    final query = _query.trim();
    if (query.isEmpty) {
      return dapps;
    }
    return dapps
        .where((entry) => entry.matchesQuery(query))
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
      try {
        _snapshot ??= await _catalogService.loadCachedSnapshot();
      } catch (cacheError) {
        _catalogError =
            '$_catalogError | cached snapshot load failed: $cacheError';
      }
    } finally {
      _loadingCatalog = false;
      notifyListeners();
    }
  }

  Future<void> loadPersistedHistory({String? scopeKey}) async {
    _scopeKey = scopeKey;
    try {
      final loaded = await _historyStorage.load(scopeKey: scopeKey);
      if (loaded.isNotEmpty) {
        _history.clear();
        _history.addAll(loaded);
        notifyListeners();
      }
    } catch (_) {}
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

  /// Optional hook that lets the embedded web view consume a back press by
  /// navigating back in its own page history. Returns true if it handled it.
  Future<bool> Function()? _webViewBackHandler;

  void setWebViewBackHandler(Future<bool> Function()? handler) {
    _webViewBackHandler = handler;
  }

  /// Handle a system back press while a page/dapp is open in Discover: first
  /// let the web view go back in its history, otherwise close the page back to
  /// the catalog. Returns true if the back press was consumed (so the shell
  /// should not leave the Discover tab).
  Future<bool> handleBackRequest() async {
    final handler = _webViewBackHandler;
    if (handler != null && await handler()) {
      return true;
    }
    if (_currentUri != null || _viewState != DiscoverViewState.landing) {
      returnToLanding();
      return true;
    }
    return false;
  }

  void openDapp(
    DiscoverDappEntry dapp, {
    String invalidLaunchUrlReason = 'The DApp launch URL is invalid.',
  }) {
    final uri = Uri.tryParse(dapp.launchUrl);
    if (uri == null) {
      showBlocked(
        BlockedNavigationState(
          url: dapp.launchUrl,
          origin: dapp.origin,
          reason: invalidLaunchUrlReason,
        ),
      );
      return;
    }
    _beginBrowsing(uri, activeDapp: dapp, title: dapp.title);
  }

  void openManualInput(
    String value, {
    String invalidInputReason = 'Enter a valid website or search term.',
    String webSearchTitle = 'DuckDuckGo search',
  }) {
    final target = resolveDiscoverInput(value);
    if (target == null) {
      showBlocked(
        BlockedNavigationState(url: '', origin: '', reason: invalidInputReason),
      );
      return;
    }

    final matchingDapp = findDappByOrigin(normalizeOriginFromUri(target.uri));
    final title = switch (target.type) {
      DiscoverInputType.url => matchingDapp?.title ?? target.uri.host,
      DiscoverInputType.webSearch => webSearchTitle,
    };
    _beginBrowsing(target.uri, activeDapp: matchingDapp, title: title);
  }

  void restoreBrowsing(String rawUrl, {String? title}) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !isSupportedDiscoverWebUri(uri)) return;
    final matchingDapp = findDappByOrigin(normalizeOriginFromUri(uri));
    _beginBrowsing(
      uri,
      activeDapp: matchingDapp,
      title: title?.trim().isNotEmpty == true
          ? title!.trim()
          : matchingDapp?.title ?? uri.host,
    );
  }

  bool allowsNavigation(
    Uri uri, {
    String unsupportedSchemeReason =
        'This website scheme is not supported in the in-app browser.',
  }) {
    if (!isSupportedDiscoverWebUri(uri)) {
      showBlocked(
        BlockedNavigationState(
          url: uri.toString(),
          origin: uri.host.isEmpty ? '' : normalizeOriginFromUri(uri),
          reason: unsupportedSchemeReason,
        ),
      );
      return false;
    }

    // Phishing and Malicious Domain Protection
    final phishingCheck = PhishingProtectionService.instance.checkUri(uri);
    if (phishingCheck.isBlocked) {
      showBlocked(
        BlockedNavigationState(
          url: uri.toString(),
          origin: uri.host.isEmpty ? '' : normalizeOriginFromUri(uri),
          reason:
              phishingCheck.reason ??
              'Security Alert: Access to this website is blocked to protect your funds.',
        ),
      );
      return false;
    }

    return true;
  }

  /// Allows provider injection for all secure HTTPS and local web addresses.
  /// Signing and account exposure are strictly gated by explicit user approval and biometrics.
  bool canInjectProviderFor(Uri uri) {
    return isDiscoverInjectableUri(uri);
  }

  bool shouldInjectDappDetectorFor(Uri uri) {
    return false;
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
    _activeDapp = findDappByOrigin(normalizeOriginFromUri(uri));
    _pageTitle = title?.trim().isNotEmpty == true ? title!.trim() : _pageTitle;
    _recordHistory(uri, title: title);
    if (_viewState != DiscoverViewState.browser) {
      _viewState = DiscoverViewState.browser;
    }
    notifyListeners();
  }

  void blockDetectedDapp(
    Uri uri, {
    required String trigger,
    required String reason,
  }) {
    showBlocked(
      BlockedNavigationState(
        url: uri.toString(),
        origin: normalizeOriginFromUri(uri),
        reason: reason.replaceFirst('{trigger}', trigger),
      ),
    );
  }

  void showBlocked(BlockedNavigationState state) {
    _blockedState = state;
    _viewState = DiscoverViewState.blocked;
    notifyListeners();
  }

  void _recordHistory(Uri uri, {String? title}) {
    if (uri.toString() == 'about:blank' || uri.scheme.isEmpty) return;
    _history.removeWhere((item) => item.url == uri.toString());
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
    unawaited(_historyStorage.save(history: _history, scopeKey: _scopeKey));
  }

  void _beginBrowsing(
    Uri uri, {
    required DiscoverDappEntry? activeDapp,
    required String title,
  }) {
    _activeDapp = activeDapp;
    _currentUri = uri;
    _blockedState = null;
    _pageTitle = title;
    _viewState = DiscoverViewState.browser;
    _recordHistory(uri, title: title);
    notifyListeners();
  }
}
