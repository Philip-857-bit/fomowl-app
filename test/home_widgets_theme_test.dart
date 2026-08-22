import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/network_entry.dart';
import 'package:fomowl_wallet/screens/home/widgets/home_top_bar.dart';
import 'package:fomowl_wallet/screens/home/widgets/network_selector_sheet.dart';
import 'package:fomowl_wallet/screens/home/widgets/quick_actions_row.dart';
import 'package:fomowl_wallet/screens/home/widgets/social_banner_card.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';

class _FakeBlockchainService extends ChangeNotifier implements BlockchainService {
  String _activeNetworkKey = 'evm:56';

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
    String networkKey = 'evm:56',
    BlockchainService? mockBlockchain,
  }) {
    final service = mockBlockchain ?? (_FakeBlockchainService()..setActiveNetworkKey(networkKey));
    return ChangeNotifierProvider<BlockchainService>.value(
      value: service,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Home Widgets Theme Verification', () {
    testWidgets('QuickActionsRow renders action buttons with chain accent icons', (tester) async {
      bool receiveTapped = false;
      bool sendTapped = false;
      bool withdrawTapped = false;

      await tester.pumpWidget(
        wrapWithTheme(
          networkKey: 'evm:56', // BSC Gold #F3BA2F
          child: QuickActionsRow(
            onReceive: () => receiveTapped = true,
            onSend: () => sendTapped = true,
            onWithdraw: () => withdrawTapped = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_rounded), findsOneWidget);

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.arrow_downward_rounded));
      expect(iconWidget.color, const Color(0xFFF3BA2F));

      await tester.tap(find.byIcon(Icons.arrow_downward_rounded));
      expect(receiveTapped, isTrue);

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      expect(sendTapped, isTrue);

      await tester.tap(find.byIcon(Icons.account_balance_rounded));
      expect(withdrawTapped, isTrue);
    });

    testWidgets('HomeTopBar renders wallet selector and themed HELP badge', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          networkKey: 'evm:1', // Ethereum Blue #627EEA
          child: HomeTopBar(
            walletName: 'Main Wallet',
            onWalletTap: () {},
            chainSymbol: 'ETH',
            chainId: 1,
            onNetworkTap: () {},
            onHelpTap: () {},
            onNotificationsTap: () {},
            showNotificationDot: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Main Wallet'), findsOneWidget);
      expect(find.text('HELP'), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);

      final walletIcon = tester.widget<Icon>(find.byIcon(Icons.account_balance_wallet));
      expect(walletIcon.color, const Color(0xFF627EEA));
    });

    testWidgets('SocialBannerCard renders banner text and themed action', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        wrapWithTheme(
          networkKey: 'evm:8453', // Base Blue #0052FF
          child: SocialBannerCard(
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.campaign_rounded), findsOneWidget);
      final campaignIcon = tester.widget<Icon>(find.byIcon(Icons.campaign_rounded));
      expect(campaignIcon.color, const Color(0xFF0052FF));

      await tester.tap(find.byType(SocialBannerCard));
      expect(tapped, isTrue);
    });

    testWidgets('NetworkSelectorSheet renders network items and triggers selection', (tester) async {
      NetworkEntry? selectedEntry;
      final entries = [
        EvmNetworkEntry(const EvmChain(chainId: 1, name: 'Ethereum', symbol: 'ETH', rpcUrl: '')),
        EvmNetworkEntry(const EvmChain(chainId: 56, name: 'BNB Smart Chain', symbol: 'BNB', rpcUrl: '')),
      ];

      await tester.pumpWidget(
        wrapWithTheme(
          networkKey: 'evm:56',
          child: NetworkSelectorSheet(
            entries: entries,
            activeNetworkKey: 'evm:56',
            onSelect: (entry) => selectedEntry = entry,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Ethereum Chain'), findsOneWidget);
      expect(find.text('BNB Smart Chain'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);


      await tester.tap(find.text('Ethereum Chain'));
      expect(selectedEntry?.name, 'Ethereum');
    });
  });
}
