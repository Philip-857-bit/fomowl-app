import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:fomowl_wallet/l10n/app_localizations.dart';

class _TestWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const _TestWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) async {
    return const DefaultWidgetsLocalizations();
  }

  @override
  bool shouldReload(_TestWidgetsLocalizationsDelegate old) => false;
}

void main() {
  group('AppLocalizations', () {
    testWidgets('loads English locale', (WidgetTester tester) async {
      late AppLocalizations l;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Localizations(
            locale: const Locale('en'),
            delegates: const [
              _TestWidgetsLocalizationsDelegate(),
              AppLocalizations.delegate,
            ],
            child: Builder(
              builder: (context) {
                l = AppLocalizations.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(l.appName, isNotEmpty);
      expect(l.home, isNotEmpty);
      expect(l.wallet, isNotEmpty);
    });

    testWidgets('loads all supported locales', (WidgetTester tester) async {
      for (final locale in AppLocalizations.supportedLocales) {
        late AppLocalizations l;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Localizations(
              locale: locale,
              delegates: const [
                _TestWidgetsLocalizationsDelegate(),
                AppLocalizations.delegate,
              ],
              child: Builder(
                builder: (context) {
                  l = AppLocalizations.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(l.appName, isNotEmpty, reason: 'appName empty for $locale');
        expect(l.home, isNotEmpty, reason: 'home empty for $locale');
        expect(l.wallet, isNotEmpty, reason: 'wallet empty for $locale');
      }
    });
  });
}
