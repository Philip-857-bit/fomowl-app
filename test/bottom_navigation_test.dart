import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/widgets/bottom_navigation.dart';

void main() {
  testWidgets('legacy bottom navigation exposes every app shell destination', (
    tester,
  ) async {
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
          bottomNavigationBar: BottomNavBar(currentIndex: 1, onTap: (_) {}),
        ),
      ),
    );

    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Swap'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
