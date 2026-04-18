import 'package:flutter/foundation.dart';

enum AppShellTab { wallet, swap, discover, settings }

class AppShellController extends ChangeNotifier {
  AppShellTab _currentTab = AppShellTab.wallet;
  String? _pendingDiscoverUrl;

  AppShellTab get currentTab => _currentTab;
  String? get pendingDiscoverUrl => _pendingDiscoverUrl;

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

  void selectIndex(int index) {
    if (index < 0 || index >= AppShellTab.values.length) {
      return;
    }
    selectTab(AppShellTab.values[index]);
  }
}
