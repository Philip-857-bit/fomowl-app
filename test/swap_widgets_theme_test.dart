import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/screens/swap/widgets/swap_direction_button.dart';
import 'package:fomowl_wallet/screens/swap/widgets/swap_figma_icons.dart';
import 'package:fomowl_wallet/screens/swap/widgets/swap_from_card.dart';
import 'package:fomowl_wallet/screens/swap/widgets/swap_primary_button.dart';
import 'package:fomowl_wallet/screens/swap/widgets/swap_tab_pill_bar.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';

class _FakeBlockchainService extends ChangeNotifier implements BlockchainService {
  String _activeNetworkKey = 'evm:1';

  @override
  String get activeNetworkKey => _activeNetworkKey;

  @override
  Future<void> setActiveNetworkKey(String key) async {
    _activeNetworkKey = key;
    notifyListeners();
  }


  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithTheme({
    required Widget child,
    String networkKey = 'evm:1',
  }) {
    final service = _FakeBlockchainService()..setActiveNetworkKey(networkKey);
    return ChangeNotifierProvider<BlockchainService>.value(
      value: service,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  group('Swap Suite Widgets Theme Verification', () {
    testWidgets('SwapTabPillBar switches tabs and applies active pill styling', (tester) async {
      SwapTab activeTab = SwapTab.swap;

      await tester.pumpWidget(
        wrapWithTheme(
          networkKey: 'evm:1',
          child: StatefulBuilder(
            builder: (context, setState) {
              return SwapTabPillBar(
                activeTab: activeTab,
                onTabSelected: (tab) => setState(() => activeTab = tab),
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('SWAP'), findsOneWidget);
      expect(find.text('LIMIT'), findsOneWidget);
      expect(find.text('BRIDGE'), findsOneWidget);

      await tester.tap(find.text('LIMIT'));
      await tester.pumpAndSettle();
      expect(activeTab, SwapTab.limit);

      await tester.tap(find.text('BRIDGE'));
      await tester.pumpAndSettle();
      expect(activeTab, SwapTab.bridge);
    });

    testWidgets('SwapPrimaryButton renders enabled state with theme gradient', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        wrapWithTheme(
          networkKey: 'evm:56', // BSC
          child: SwapPrimaryButton(
            enabled: true,
            isBusy: false,
            onPressed: () => pressed = true,
            label: 'Swap Tokens',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Swap Tokens'), findsOneWidget);

      await tester.tap(find.text('Swap Tokens'));
      expect(pressed, isTrue);
    });

    testWidgets('SwapDirectionButton renders with chain accent color', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        wrapWithTheme(
          networkKey: 'evm:8453',
          child: SwapDirectionButton(
            onPressed: () => pressed = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FigmaSwapDirectionIcon), findsOneWidget);

      final icon = tester.widget<FigmaSwapDirectionIcon>(find.byType(FigmaSwapDirectionIcon));
      expect(icon.color, const Color(0xFF0052FF));

      await tester.tap(find.byType(SwapDirectionButton));
      expect(pressed, isTrue);
    });

    testWidgets('SwapFromCard renders percentage pills and selects values', (tester) async {
      int selectedPercent = 0;
      final controller = TextEditingController(text: '100');
      final token = Token(
        name: 'Ethereum',
        symbol: 'ETH',
        decimals: 18,
        balance: 2.5,
        priceUsd: 3000.0,
        valueUsd: 7500.0,
        changePercent24h: 1.5,
      );



      await tester.pumpWidget(
        wrapWithTheme(
          networkKey: 'evm:1',
          child: SwapFromCard(
            controller: controller,
            token: token,
            usdValue: 300000.0,
            balance: 2.5,
            selectedPercentage: selectedPercent,
            onAmountChanged: (_) {},
            onSelectToken: () {},
            onPercentSelected: (pct) => selectedPercent = pct,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('25%'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('MAX'), findsOneWidget);

      await tester.tap(find.text('50%'));
      expect(selectedPercent, 50);

      await tester.tap(find.text('MAX'));
      expect(selectedPercent, 100);
    });
  });
}
