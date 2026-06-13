import 'package:flutter/foundation.dart';

import '../../models/token.dart';

enum AppShellTab { wallet, swap, discover, settings }

class AppShellController extends ChangeNotifier {
  AppShellTab _currentTab = AppShellTab.wallet;
  String? _pendingDiscoverUrl;
  Token? _pendingSwapFromToken;

  AppShellTab get currentTab => _currentTab;
  String? get pendingDiscoverUrl => _pendingDiscoverUrl;
  Token? get pendingSwapFromToken => _pendingSwapFromToken;

  int get currentIndex => AppShellTab.values.indexOf(_currentTab);

  void selectTab(AppShellTab tab) {
    if (_currentTab == tab) {
      return;
    }
    _currentTab = tab;
    notifyListeners();
  }

  void openDiscoverUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _pendingDiscoverUrl = trimmed;
    if (_currentTab != AppShellTab.discover) {
      _currentTab = AppShellTab.discover;
    }
    notifyListeners();
  }

  String? consumePendingDiscoverUrl() {
    final next = _pendingDiscoverUrl;
    _pendingDiscoverUrl = null;
    return next;
  }

  /// Stash a token chosen elsewhere (e.g. the token-detail screen's "Swap"
  /// action) so the Swap tab can pre-select it as the "from" token when it next
  /// initializes. Intentionally does NOT notify listeners or switch tabs: the
  /// navigation to the Swap tab handles visibility, and avoiding a notify keeps
  /// any already-mounted Swap screen from consuming the token prematurely.
  void openSwapWithToken(Token token) {
    _pendingSwapFromToken = token;
  }

  Token? consumePendingSwapFromToken() {
    final next = _pendingSwapFromToken;
    _pendingSwapFromToken = null;
    return next;
  }

  void selectIndex(int index) {
    if (index < 0 || index >= AppShellTab.values.length) {
      return;
    }
    selectTab(AppShellTab.values[index]);
  }

  /// Back-press handler registered by the Discover tab so the shell can let the
  /// in-app browser go back (page history / close page) before leaving the tab.
  Future<bool> Function()? _discoverBackHandler;

  void setDiscoverBackHandler(Future<bool> Function()? handler) {
    _discoverBackHandler = handler;
  }

  /// Returns true if the Discover tab consumed the back press.
  Future<bool> handleDiscoverBack() async {
    final handler = _discoverBackHandler;
    if (handler == null) {
      return false;
    }
    return handler();
  }
}
