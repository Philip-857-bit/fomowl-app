import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/screens/profile/widgets/settings_item_tile.dart';
import 'package:fomowl_wallet/screens/profile/widgets/settings_wallet_header_card.dart';
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

  group('Profile & Settings Widgets Theme Verification', () {
    testWidgets('SettingsWalletHeaderCard renders wallet name, address, and copy icon', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        wrapWithTheme(
          networkKey: 'evm:56', // BSC Gold
          child: SettingsWalletHeaderCard(
            walletName: 'Main Alpha Wallet',
            walletAddress: '0x71C8451234567890123456789012345678903944',
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Main Alpha Wallet'), findsOneWidget);
      expect(find.text('0x71C8...3944'), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

      await tester.tap(find.byType(SettingsWalletHeaderCard));
      expect(tapped, isTrue);
    });

    testWidgets('SettingsItemTile renders icon, title, subtitle and responds to taps', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        wrapWithTheme(
          networkKey: 'evm:1',
          child: SettingsItemTile(
            icon: Icons.security,
            title: 'Security Settings',
            subtitle: 'Manage passcode and biometrics',
            attention: true,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Security Settings'), findsOneWidget);
      expect(find.text('Manage passcode and biometrics'), findsOneWidget);
      expect(find.byIcon(Icons.security), findsOneWidget);

      final icon = tester.widget<Icon>(find.byIcon(Icons.security));
      expect(icon.color, const Color(0xFF627EEA));

      await tester.tap(find.byType(SettingsItemTile));
      expect(tapped, isTrue);
    });
  });
}
