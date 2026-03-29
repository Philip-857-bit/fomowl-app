import 'package:flutter/foundation.dart';

enum AppShellTab { wallet, swap, discover, settings }

class AppShellController extends ChangeNotifier {
  AppShellTab _currentTab = AppShellTab.wallet;

  AppShellTab get currentTab => _currentTab;

  int get currentIndex => AppShellTab.values.indexOf(_currentTab);

  void selectTab(AppShellTab tab) {
    if (_currentTab == tab) {
      return;
    }
    _currentTab = tab;
    notifyListeners();
  }

  void selectIndex(int index) {
    if (index < 0 || index >= AppShellTab.values.length) {
      return;
    }
    selectTab(AppShellTab.values[index]);
  }
}
