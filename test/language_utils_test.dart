import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/utils/language_utils.dart';

void main() {
  group('LanguageUtils', () {
    test('normalizes display names and region codes to supported codes', () {
      expect(LanguageUtils.normalizeLanguageCode('English'), 'en');
      expect(LanguageUtils.normalizeLanguageCode('fr-FR'), 'fr');
      expect(LanguageUtils.normalizeLanguageCode('zh_CN'), 'zh');
    });

    test('falls back to english for unsupported values', () {
      expect(LanguageUtils.normalizeLanguageCode('pt-BR'), 'en');
      expect(LanguageUtils.toLocale('unknown').languageCode, 'en');
    });
  });
}
