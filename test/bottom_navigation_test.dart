import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/mini_apps/mini_app_host_screen.dart';
import 'package:fomowl_wallet/features/shell/app_shell_controller.dart';
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
          bottomNavigationBar: const BottomNavBar(currentTab: AppShellTab.swap),
        ),
      ),
    );

    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Swap'), findsOneWidget);
    expect(find.text('Pay'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
    expect(
      find.byKey(const ValueKey('floating-bottom-navigation')),
      findsOneWidget,
    );
  });

  testWidgets('Pay opens the full-screen OwlletPay route with launch source', (
    tester,
  ) async {
    Object? routeArguments;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {
          '/owllet-pay': (context) {
            routeArguments = ModalRoute.of(context)?.settings.arguments;
            return const Scaffold(body: Text('OwlletPay Host'));
          },
        },
        home: const Scaffold(
          bottomNavigationBar: BottomNavBar(currentTab: AppShellTab.wallet),
        ),
      ),
    );

    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle();

    expect(find.text('OwlletPay Host'), findsOneWidget);
    final args = routeArguments! as MiniAppHostArguments;
    expect(args.miniAppId, 'owllet_pay');
    expect(args.launchSource, 'bottom_nav_pay');
  });

  testWidgets('Pay uses the normal unselected navigation appearance', (
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
        home: const Scaffold(
          bottomNavigationBar: BottomNavBar(currentTab: AppShellTab.wallet),
        ),
      ),
    );

    final payContainer = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text('Pay'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final decoration = payContainer.decoration! as BoxDecoration;
    final payIcon = tester.widget<Icon>(find.byIcon(Icons.payments_rounded));
    final discoverIcon = tester.widget<Icon>(
      find.byIcon(Icons.explore_outlined),
    );
    final payLabel = tester.widget<Text>(find.text('Pay'));
    final discoverLabel = tester.widget<Text>(find.text('Discover'));

    expect(decoration.color, Colors.transparent);
    expect(payIcon.color, discoverIcon.color);
    expect(payLabel.style?.color, discoverLabel.style?.color);
    expect(payLabel.style?.fontWeight, discoverLabel.style?.fontWeight);
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
    expect(screenHeight - pillBottom, 42);
  });
}
