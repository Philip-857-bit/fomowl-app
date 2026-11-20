import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/screens/swap/swap_screen.dart';
import 'package:fomowl_wallet/screens/swap/widgets/bridge_tab_content.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';

class _Wallet extends WalletService {
  @override
  Future<String?> getWalletAddressForFamily(ChainFamily family) async =>
      family == ChainFamily.evm
      ? '0x1111111111111111111111111111111111111111'
      : null;
}

void main() {
  test('supportsSwapBridgeTab enables Bridge tab for Asset Chain', () {
    SharedPreferences.setMockInitialValues({});
    final blockchain = BlockchainService();
    blockchain.setActiveChainByChainId(42420);
    expect(supportsSwapBridgeTab(blockchain), isTrue);
    blockchain.setActiveChainByChainId(42421);
    expect(supportsSwapBridgeTab(blockchain), isTrue);
    blockchain.dispose();
  });

  testWidgets('Asset Chain exposes the native Asset Chain bridge flow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    final blockchain = BlockchainService();
    blockchain.setActiveChainByChainId(42420);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BridgeTabContent(
              blockchain: blockchain,
              walletService: _Wallet(),
              walletAddress: '0x1111111111111111111111111111111111111111',
              tokens: const [],
              onSelectFromChain: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('BRIDGE FROM'), findsOneWidget);
    expect(find.text('Asset Chain native bridge'), findsOneWidget);
    expect(find.textContaining("Bridging isn't available"), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    blockchain.dispose();
  });

  testWidgets('EVM bridge tab exposes the native Asset Chain bridge entry', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    final blockchain = BlockchainService();
    blockchain.setActiveChainByChainId(1);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BridgeTabContent(
              blockchain: blockchain,
              walletService: _Wallet(),
              walletAddress: '0x1111111111111111111111111111111111111111',
              tokens: const [],
              onSelectFromChain: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Asset Chain native bridge'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    blockchain.dispose();
  });
}
