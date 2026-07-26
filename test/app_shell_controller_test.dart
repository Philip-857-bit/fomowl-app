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
}
