import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_native_screen.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/widgets/bottom_navigation.dart';
import 'package:provider/provider.dart';

class _UnavailableChain extends ChangeNotifier implements BlockchainService {
  EvmChain? selected;
  @override
  String get activeNetworkKey => 'evm:1';
  @override
  String get activeNetworkName => 'Ethereum';
  @override
  List<EvmChain> get allChains => BlockchainService.builtInChains;
  @override
  void setActiveChain(EvmChain chain) {
    selected = chain;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestPopObserver extends NavigatorObserver {
  bool didPopRoute = false;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    didPopRoute = true;
    super.didPop(route, previousRoute);
  }
}

void main() {
  testWidgets(
    'BurstNativeScreen renders transparent AppBar with title Burst, leading back button, no actions, and no BottomNavBar',
    (tester) async {
      final chain = _UnavailableChain();
      final observer = _TestPopObserver();

      await tester.pumpWidget(
        ChangeNotifierProvider<BlockchainService>.value(
          value: chain,
          child: MaterialApp(
            navigatorObservers: [observer],
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BurstNativeScreen(
                        networksLoader: () async => {
                          'supportedChains': [
                            {
                              'chainId': 56,
                              'name': 'BNB Smart Chain',
                              'networkKey': 'evm:56',
                            },
                          ],
                        },
                      ),
                    ),
                  ),
                  child: const Text('Open Burst'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Burst'));
      await tester.pumpAndSettle();

      // Verify AppBar is present
      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);

      final appBar = tester.widget<AppBar>(appBarFinder);
      expect(appBar.backgroundColor, Colors.transparent);
      expect(appBar.foregroundColor, Colors.white);
      expect(appBar.elevation, 0);
      expect(appBar.centerTitle, isTrue);

      // Verify title is "Burst"
      expect(
        find.descendant(of: appBarFinder, matching: find.text('Burst')),
        findsOneWidget,
      );

      // Verify clean header: no actions, no switcher chip, no wallet icon
      expect(appBar.actions, anyOf(isNull, isEmpty));
      expect(find.byIcon(Icons.account_balance_wallet_outlined), findsNothing);
      expect(find.text('Switch'), findsNothing);

      // Verify BottomNavBar is completely removed
      expect(find.byType(BottomNavBar), findsNothing);

      // Verify leading back button
      final backButton = find.descendant(
        of: appBarFinder,
        matching: find.byType(IconButton),
      );
      expect(backButton, findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Tap leading back button and verify pop
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(observer.didPopRoute, isTrue);
      expect(find.text('Open Burst'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      chain.dispose();
    },
  );
}
