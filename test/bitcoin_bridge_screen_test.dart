import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/screens/swap/swap_screen.dart';
import 'package:fomowl_wallet/screens/swap/bitcoin_bridge_screen.dart';
import 'package:fomowl_wallet/screens/swap/widgets/bridge_tab_content.dart';
import 'package:fomowl_wallet/screens/swap/widgets/swap_tab_content.dart';
import 'helpers/test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUp(installTestFonts);
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final network in ['mainnet', 'testnet4']) {
    testWidgets(
      'Bitcoin $network opens Bridge only and never initializes Swap or Limit',
      (tester) async {
        final chain = BlockchainService();
        chain.setActiveWalletContext(
          address: '0xwallet',
          supportedFamilies: {ChainFamily.bitcoin},
        );
        await chain.setEnabledFamilies({ChainFamily.bitcoin});
        chain.configureBitcoinAvailability(
          available: true,
          testnetEnabled: true,
        );
        chain.setActiveNetworkKey('bitcoin:$network');
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: chain,
            child: const MaterialApp(
              home: SwapScreen(showBottomNavigation: false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BitcoinBridgeScreen), findsOneWidget);
        expect(find.byType(SwapTabContent), findsNothing);
        expect(find.text('Limit'), findsNothing);
        // Runtime is off in this fixture: no native account/provider flow starts.
        expect(find.byType(BridgeTabContent), findsNothing);
        expect(
          find.text(
            network == 'mainnet'
                ? 'Bitcoin bridging is unavailable right now.'
                : 'Bitcoin bridges use Mainnet. Testnet4 is available for wallet transfer testing.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        chain.dispose();
      },
    );
  }
}
