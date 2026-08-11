import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/screens/swap/widgets/swap_from_card.dart';
import 'package:fomowl_wallet/screens/swap/widgets/swap_limit_widgets.dart';

void main() {
  testWidgets('unsupported networks do not render a disabled Limit tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwapTabSelector(
            activeTab: SwapTab.swap,
            showLimitTab: false,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('SWAP'), findsOneWidget);
    expect(find.text('BRIDGE'), findsOneWidget);
    expect(find.text('LIMIT'), findsNothing);
  });

  testWidgets('swap percentage controls remain on their own row on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwapFromCard(
            controller: TextEditingController(),
            token: const Token(
              symbol: 'TRX',
              name: 'TRON',
              balance: 100,
              valueUsd: 33,
              priceUsd: 0.33,
              changePercent24h: 0,
              networkKey: 'tron:mainnet',
            ),
            usdValue: 0,
            balance: 100,
            selectedPercentage: 0,
            onAmountChanged: (_) {},
            onSelectToken: () {},
            onPercentSelected: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('SWAP FROM'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('MAX'), findsOneWidget);
    final headerTop = tester.getTopLeft(find.text('SWAP FROM')).dy;
    final chipTop = tester.getTopLeft(find.text('25%')).dy;
    expect(chipTop, greaterThan(headerTop));
  });
}
