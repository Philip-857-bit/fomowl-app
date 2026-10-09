import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/features/shell/app_shell_controller.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/widgets/bitcoin_capability_gate.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final brightness in Brightness.values) {
    testWidgets('Bitcoin guard is localized in the $brightness theme', (
      tester,
    ) async {
      final service = BlockchainService();
      service.setActiveWalletContext(
        address: '0xwallet',
        supportedFamilies: {ChainFamily.bitcoin},
      );
      await service.setEnabledFamilies({ChainFamily.bitcoin});
      service.configureBitcoinAvailability(available: true);
      service.setActiveNetworkKey('bitcoin:mainnet');
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(brightness: brightness),
            home: BitcoinCapabilityGate(
              feature: 'Swaps',
              builder: (_) =>
                  throw StateError('Unsupported screen initialized'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Esta función todavía no está disponible para Bitcoin.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      service.dispose();
    });
  }
  testWidgets(
    'unsupported screen construction is deferred for Bitcoin and resumes on EVM',
    (tester) async {
      final service = BlockchainService();
      service.setActiveWalletContext(
        address: '0xwallet',
        supportedFamilies: {ChainFamily.evm, ChainFamily.bitcoin},
      );
      await service.setEnabledFamilies({ChainFamily.evm, ChainFamily.bitcoin});
      service.configureBitcoinAvailability(available: true);
      service.setActiveNetworkKey('bitcoin:mainnet');
      var builds = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: MaterialApp(
            home: BitcoinCapabilityGate(
              feature: 'Swaps',
              builder: (_) {
                builds++;
                return const Scaffold(body: Text('Supported screen'));
              },
            ),
          ),
        ),
      );
      expect(builds, 0);
      expect(
        find.text('This feature is not available for Bitcoin yet.'),
        findsOneWidget,
      );
      service.setActiveNetworkKey('evm:1');
      await tester.pumpAndSettle();
      expect(builds, greaterThan(0));
      expect(find.text('Supported screen'), findsOneWidget);
      service.dispose();
    },
  );
  test('Bitcoin native token is never queued as an EVM swap asset', () {
    final controller = AppShellController();
    controller.openSwapWithToken(
      Token(
        symbol: 'BTC',
        name: 'Bitcoin',
        balance: 1,
        valueUsd: 0,
        changePercent24h: 0,
        networkKey: 'bitcoin:mainnet',
      ),
    );
    expect(controller.pendingSwapFromToken, isNull);
    controller.dispose();
  });
}
