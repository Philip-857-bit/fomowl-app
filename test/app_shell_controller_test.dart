import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/features/shell/app_shell_controller.dart';
import 'package:fomowl_wallet/models/token.dart';

void main() {
  test(
    'opening swap for a token preserves the shell route and stashes token',
    () {
      final controller = AppShellController();
      const token = Token(
        symbol: 'ETH',
        name: 'Ethereum',
        balance: 1,
        valueUsd: 3000,
        changePercent24h: 0,
      );

      controller.openSwapWithToken(token);

      expect(controller.currentTab, AppShellTab.wallet);
      expect(controller.pendingSwapFromToken, same(token));
      expect(controller.consumePendingSwapFromToken(), same(token));
      expect(controller.pendingSwapFromToken, isNull);
    },
  );

  test('bottom nav visibility controls and resets on tab change', () {
    final controller = AppShellController();
    expect(controller.isBottomNavVisible, isTrue);

    var notified = false;
    controller.addListener(() => notified = true);

    controller.setBottomNavVisible(false);
    expect(controller.isBottomNavVisible, isFalse);
    expect(notified, isTrue);

    // Switching tabs should restore bottom nav visibility
    notified = false;
    controller.selectTab(AppShellTab.discover);
    expect(controller.isBottomNavVisible, isTrue);
    expect(notified, isTrue);
  });
}
