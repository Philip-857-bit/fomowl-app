import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/discover/browser/blocked_navigation_state.dart';
import 'package:fomowl_wallet/features/discover/browser/widgets/discover_blocked_view.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DiscoverBlockedView renders state and fires callbacks', (
    WidgetTester tester,
  ) async {
    var requestedSupport = false;
    var openedExternal = false;
    var cancelled = false;
    late AppLocalizations l;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l = AppLocalizations.of(context);
            return Scaffold(
              body: DiscoverBlockedView(
                state: const BlockedNavigationState(
                  url: 'https://blocked.example/app',
                  origin: 'https://blocked.example',
                  reason: 'This origin is not allowlisted.',
                ),
                onRequestSupport: () => requestedSupport = true,
                onOpenExternal: () => openedExternal = true,
                onCancel: () => cancelled = true,
              ),
            );
          },
        ),
      ),
    );

    expect(find.text(l.discoverBlockedTitle), findsOneWidget);
    expect(find.text('This origin is not allowlisted.'), findsOneWidget);
    expect(find.text('https://blocked.example'), findsOneWidget);

    await tester.tap(find.text(l.discoverRequestSupport));
    await tester.pump();
    expect(requestedSupport, isTrue);

    await tester.tap(find.text(l.discoverOpenExternalBrowser));
    await tester.pump();
    expect(openedExternal, isTrue);

    await tester.tap(find.text(l.discoverCancel));
    await tester.pump();
    expect(cancelled, isTrue);
  });
}
