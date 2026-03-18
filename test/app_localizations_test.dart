import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:fomowl_wallet/l10n/app_localizations.dart';

void main() {
  group('AppLocalizations', () {
    testWidgets('loads English locale', (WidgetTester tester) async {
      late AppLocalizations l;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(l.appName, isNotEmpty);
      expect(l.home, isNotEmpty);
      expect(l.wallet, isNotEmpty);
    });
  });
}
