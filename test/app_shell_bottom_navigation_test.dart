import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/shell/app_shell_bottom_navigation.dart';
import 'package:fomowl_wallet/features/shell/app_shell_controller.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';

void main() {
  testWidgets('shell navigation keeps Pay separate from tab selection', (
    tester,
  ) async {
    AppShellTab? tappedTab;
    var payTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          bottomNavigationBar: AppShellBottomNavigation(
            currentTab: AppShellTab.wallet,
            onTabTap: (tab) => tappedTab = tab,
            onPayTap: () => payTaps += 1,
          ),
        ),
      ),
    );

    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Swap'), findsOneWidget);
    expect(find.text('Pay'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);

    final walletX = tester.getCenter(find.text('Wallet')).dx;
    final swapX = tester.getCenter(find.text('Swap')).dx;
    final payX = tester.getCenter(find.text('Pay')).dx;
    final discoverX = tester.getCenter(find.text('Discover')).dx;
    expect(walletX, lessThan(swapX));
    expect(swapX, lessThan(payX));
    expect(payX, lessThan(discoverX));

    await tester.tap(find.text('Pay'));
    await tester.pump();
    expect(payTaps, 1);
    expect(tappedTab, isNull);

    await tester.tap(find.text('Discover'));
    await tester.pump();
    expect(tappedTab, AppShellTab.discover);
    expect(payTaps, 1);
  });
}
