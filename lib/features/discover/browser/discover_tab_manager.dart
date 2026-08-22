import 'dart:async';

import 'package:flutter/foundation.dart';

import '../catalog/discover_catalog_service.dart';
import '../permissions/dapp_permission_service.dart';
import '../provider/dapp_provider_bridge.dart';
import 'browser_session_controller.dart';
import 'discover_history_storage.dart';
import 'discover_tab_storage.dart';

class DiscoverBrowserTab {
  const DiscoverBrowserTab({
    required this.id,
    required this.sessionController,
    required this.providerBridge,
  });

  final String id;
  final BrowserSessionController sessionController;
  final DappProviderBridge providerBridge;

  DiscoverTabSnapshot toSnapshot() => DiscoverTabSnapshot(
    id: id,
    url: sessionController.currentUri?.toString(),
    title: sessionController.pageTitle,
  );
}

class DiscoverTabManager extends ChangeNotifier {
  DiscoverTabManager({
    required DiscoverCatalogService catalogService,
    required DappPermissionService permissionService,
    DiscoverTabStorage? storage,
    DiscoverHistoryStorage? historyStorage,
    this.maxTabs = 5,
  }) : _catalogService = catalogService,
       _permissionService = permissionService,
       _storage = storage ?? DiscoverTabStorage(),
       _historyStorage =
           historyStorage ??
           DiscoverHistoryStorage(secureStore: storage?.secureStore) {
    final initial = _createTab();
    _tabs.add(initial);
    _activeTabId = initial.id;
  }

  final DiscoverCatalogService _catalogService;
  final DappPermissionService _permissionService;
  final DiscoverTabStorage _storage;
  final DiscoverHistoryStorage _historyStorage;

  final int maxTabs;
  final List<DiscoverBrowserTab> _tabs = <DiscoverBrowserTab>[];
  final Map<String, VoidCallback> _sessionListeners = <String, VoidCallback>{};
  String? _activeTabId;
  Timer? _saveDebounce;
  int _nextId = 0;
  bool _initialized = false;
  String? _scopeKey;

  List<DiscoverBrowserTab> get tabs => List.unmodifiable(_tabs);
  int get tabCount => _tabs.length;
  bool get canAddTab => _tabs.length < maxTabs;
  bool get initialized => _initialized;
  String get activeTabId => _activeTabId ?? _tabs.first.id;
  int get activeIndex => _tabs.indexWhere((tab) => tab.id == activeTabId);
  DiscoverBrowserTab get activeTab =>
      _tabs.firstWhere((tab) => tab.id == activeTabId);

  Future<void> initialize({String? scopeKey}) async {
    if (_initialized) return;
    _scopeKey = scopeKey;
    final restored = await _storage.load(maxTabs: maxTabs, scopeKey: _scopeKey);
    if (restored != null) {
      _replaceTabs(
        restored.tabs.map(
          (snapshot) => _createTab(
            id: snapshot.id,
            initialUrl: snapshot.url,
            initialTitle: snapshot.title,
          ),
        ),
        activeTabId: restored.activeTabId,
      );
    }
    _initialized = true;
    await activeTab.sessionController.loadCatalog(forceRefresh: true);
    await activeTab.sessionController.loadPersistedHistory(scopeKey: _scopeKey);
    for (final tab in _tabs) {
      if (tab.id != activeTabId) {
        await tab.sessionController.loadCatalog();
        await tab.sessionController.loadPersistedHistory(scopeKey: _scopeKey);
      }
    }

    notifyListeners();
    _scheduleSave();
  }

  Future<DiscoverBrowserTab?> addTab() async {
    if (!canAddTab) return null;
    final tab = _createTab();
    _tabs.add(tab);
    _activeTabId = tab.id;
    notifyListeners();
    _scheduleSave();
    await tab.sessionController.loadCatalog();
    return tab;
  }

  void selectTab(String id) {
    if (id == _activeTabId || !_tabs.any((tab) => tab.id == id)) return;
    _activeTabId = id;
    notifyListeners();
    _scheduleSave();
  }

  void closeTab(String id) {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;
    if (_tabs.length == 1) {
      _tabs.single.sessionController.returnToLanding();
      _scheduleSave();
      return;
    }

    final wasActive = id == _activeTabId;
    final removed = _tabs.removeAt(index);
    _disposeTab(removed);
    if (wasActive) {
      final nextIndex = index.clamp(0, _tabs.length - 1);
      _activeTabId = _tabs[nextIndex].id;
    }
    notifyListeners();
    _scheduleSave();
  }

  Future<bool> handleBackRequest() =>
      activeTab.sessionController.handleBackRequest();

  DiscoverBrowserTab _createTab({
    String? id,
    String? initialUrl,
    String? initialTitle,
  }) {
    final session = BrowserSessionController(
      catalogService: _catalogService,
      historyStorage: _historyStorage,
    );
    if (initialUrl != null) {
      session.restoreBrowsing(initialUrl, title: initialTitle);
    }

    final tab = DiscoverBrowserTab(
      id: id ?? _newId(),
      sessionController: session,
      providerBridge: DappProviderBridge(
        sessionController: session,
        permissionService: _permissionService,
      ),
    );
    void listener() {
      notifyListeners();
      _scheduleSave();
    }

    _sessionListeners[tab.id] = listener;
    session.addListener(listener);
    return tab;
  }

  String _newId() {
    _nextId += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_nextId';
  }

  void _replaceTabs(
    Iterable<DiscoverBrowserTab> replacements, {
    required String? activeTabId,
  }) {
    for (final tab in _tabs) {
      _disposeTab(tab);
    }
    _tabs
      ..clear()
      ..addAll(replacements.take(maxTabs));
    if (_tabs.isEmpty) {
      _tabs.add(_createTab());
    }
    _activeTabId = _tabs.any((tab) => tab.id == activeTabId)
        ? activeTabId
        : _tabs.first.id;
  }

  void _disposeTab(DiscoverBrowserTab tab) {
    final listener = _sessionListeners.remove(tab.id);
    if (listener != null) tab.sessionController.removeListener(listener);
    tab.sessionController.dispose();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(
        _storage.save(
          snapshot: DiscoverTabsSnapshot(
            tabs: _tabs.map((tab) => tab.toSnapshot()).toList(growable: false),
            activeTabId: activeTabId,
          ),
          scopeKey: _scopeKey,
        ),
      );
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    for (final tab in _tabs) {
      _disposeTab(tab);
    }
    super.dispose();
  }
}
