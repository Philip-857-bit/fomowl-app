import 'package:flutter/foundation.dart';

import '../../models/token.dart';

enum AppShellTab { wallet, swap, discover, settings }

class AppShellController extends ChangeNotifier {
  AppShellTab _currentTab = AppShellTab.wallet;
  String? _pendingDiscoverUrl;
  Token? _pendingSwapFromToken;
  bool _isBottomNavVisible = true;

  AppShellTab get currentTab => _currentTab;
  String? get pendingDiscoverUrl => _pendingDiscoverUrl;
  Token? get pendingSwapFromToken => _pendingSwapFromToken;
  bool get isBottomNavVisible => _isBottomNavVisible;

  int get currentIndex => AppShellTab.values.indexOf(_currentTab);

  void setBottomNavVisible(bool visible) {
    if (_isBottomNavVisible == visible) {
      return;
    }
    _isBottomNavVisible = visible;
    notifyListeners();
  }

  void selectTab(AppShellTab tab) {
    if (_currentTab == tab) {
      return;
    }
    _currentTab = tab;
    _isBottomNavVisible = true;
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
  /// action) so the next Swap screen can pre-select it.
  ///
  /// This must not switch the shell tab: token details opens a standalone Swap
  /// route so Android back returns to token details without duplicating the
  /// app shell or mutating the route underneath it.
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
