import 'dart:convert';
import 'dart:io';

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
    test('all locale ARBs include every English key', () {
      final l10nDir = Directory('lib/l10n');
      final enFile = File('lib/l10n/app_en.arb');
      expect(enFile.existsSync(), isTrue, reason: 'Missing app_en.arb');

      final enMap =
          jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      final enKeys = enMap.keys
          .where((key) => !key.startsWith('@'))
          .where((key) => key != '@@locale')
          .toSet();

      final localeFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .where((file) => !file.path.endsWith('app_en.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      for (final file in localeFiles) {
        final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final localeKeys = map.keys
            .where((key) => !key.startsWith('@'))
            .where((key) => key != '@@locale')
            .toSet();
        final missing = enKeys.difference(localeKeys);

        expect(
          missing,
          isEmpty,
          reason: '${file.path} missing keys: ${missing.join(', ')}',
        );
      }
    });

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
      expect(l.pay, 'Pay');
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
        expect(l.pay, isNotEmpty, reason: 'pay empty for $locale');
        expect(
          l.referralsSubtitle,
          isNotEmpty,
          reason: 'referralsSubtitle empty for $locale',
        );
      }
    });

    test('referrals subtitle no longer references 0.1 in any ARB', () {
      final l10nDir = Directory('lib/l10n');
      final localeFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      for (final file in localeFiles) {
        final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final subtitle = map['referralsSubtitle']?.toString() ?? '';
        expect(
          subtitle.contains('0.1'),
          isFalse,
          reason: '${file.path} still contains the old referral reward text',
        );
      }
    });
  });
}
