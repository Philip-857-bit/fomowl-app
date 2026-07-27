import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fomowl_wallet/screens/swap/widgets/swap_network_card.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shows selected network and invokes change action', (
    tester,
  ) async {
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwapNetworkCard(
            networkName: 'Solana',
            accentColor: Colors.purple,
            canSwitch: true,
            onChangeNetwork: () => changes++,
          ),
        ),
      ),
    );

    expect(find.text('Solana'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    expect(changes, 1);
  });

  testWidgets('hides change affordance for single-family wallets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SwapNetworkCard(
            networkName: 'Tron',
            accentColor: Colors.red,
            canSwitch: false,
          ),
        ),
      ),
    );

    expect(find.text('Tron'), findsOneWidget);
    expect(find.text('Change'), findsNothing);
  });
}
