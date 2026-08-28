import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/widgets/bottom_navigation.dart';
import 'package:fomowl_wallet/widgets/floating_navigation_pill.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

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
    expect(
      find.byKey(const ValueKey('floating-bottom-navigation')),
      findsOneWidget,
    );
  });

  testWidgets('floating navigation stays above the bottom safe area', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
          child: Material(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FloatingNavigationPill(destinations: []),
            ),
          ),
        ),
      ),
    );

    final screenHeight = tester.getSize(find.byType(MediaQuery).first).height;
    final pillBottom = tester
        .getBottomRight(
          find.byKey(const ValueKey('floating-bottom-navigation')),
        )
        .dy;
    expect(screenHeight - pillBottom, 46);
  });
}
