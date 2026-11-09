import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/shell/app_shell_controller.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/screens/swap/swap_screen.dart';
import 'package:fomowl_wallet/screens/swap/widgets/swap_limit_widgets.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/currency_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

void main() {
  testWidgets('Asset Chain to Solana restores the limit order tab', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'swap_limit_showcase_seen_v1': true,
    });
    ShowcaseView.register();
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final blockchain = BlockchainService();
    blockchain.setActiveChainByChainId(42420);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BlockchainService>.value(value: blockchain),
          ChangeNotifierProvider(create: (_) => AppShellController()),
          ChangeNotifierProvider(create: (_) => CurrencyController()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SwapScreen(showBottomNavigation: false),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('LIMIT'), findsNothing);
    expect(find.text('BRIDGE'), findsNothing);
    expect(find.byType(SwapTabSelector), findsNothing);

    blockchain.setActiveNetworkKey('solana:mainnet');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(blockchain.activeFamily, ChainFamily.solana);
    // The EVM selection is intentionally retained while another family is active.
    expect(blockchain.activeChain.chainId, 42420);
    expect(find.byType(SwapTabSelector), findsOneWidget);
    expect(find.text('LIMIT'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    blockchain.dispose();
  });
}
