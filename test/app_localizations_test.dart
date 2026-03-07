import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/l10n/app_localizations.dart';

void main() {
  group('AppLocalizations', () {
    test('resolves every english key for all supported languages', () {
      final englishValues = AppLocalizations.resolvedStringsForLanguage('en');

      for (final languageCode in AppLocalizations.supportedLanguageCodes) {
        final localized = AppLocalizations.resolvedStringsForLanguage(
          languageCode,
        );

        expect(
          localized.keys.toSet(),
          containsAll(englishValues.keys),
          reason: 'Missing keys for $languageCode',
        );

        for (final entry in englishValues.entries) {
          expect(
            localized[entry.key],
            isNotNull,
            reason: 'Missing translation for ${entry.key} in $languageCode',
          );
        }
      }
    });
  });
}
