import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/utils/language_utils.dart';

void main() {
  group('LanguageUtils', () {
    test('fallbackLanguageCode should be en', () {
      expect(LanguageUtils.fallbackLanguageCode, 'en');
    });

    test('defaultLocale should use fallbackLanguageCode', () {
      expect(LanguageUtils.defaultLocale.languageCode, 'en');
      expect(LanguageUtils.defaultLocale.countryCode, '');
    });

    test('supportedLanguageCodes should contain expected languages', () {
      expect(LanguageUtils.supportedLanguageCodes.length, 8);
      expect(LanguageUtils.supportedLanguageCodes.contains('en'), isTrue);
      expect(LanguageUtils.supportedLanguageCodes.contains('es'), isTrue);
      expect(LanguageUtils.supportedLanguageCodes.contains('fr'), isTrue);
      expect(LanguageUtils.supportedLanguageCodes.contains('zh'), isTrue);
      expect(LanguageUtils.supportedLanguageCodes.contains('ar'), isTrue);
      expect(LanguageUtils.supportedLanguageCodes.contains('yo'), isTrue);
      expect(LanguageUtils.supportedLanguageCodes.contains('ig'), isTrue);
      expect(LanguageUtils.supportedLanguageCodes.contains('ha'), isTrue);
    });

    test('languageNamesByCode should map correctly', () {
      expect(LanguageUtils.languageNamesByCode['en'], 'English');
      expect(LanguageUtils.languageNamesByCode['es'], 'Español');
      expect(LanguageUtils.languageNamesByCode['zh'], '中文');
    });

    test('normalizeLanguageCode handles null and empty', () {
      expect(LanguageUtils.normalizeLanguageCode(null), 'en');
      expect(LanguageUtils.normalizeLanguageCode(''), 'en');
      expect(LanguageUtils.normalizeLanguageCode('   '), 'en');
    });

    test('normalizeLanguageCode normalizes supported codes', () {
      expect(LanguageUtils.normalizeLanguageCode('en'), 'en');
      expect(LanguageUtils.normalizeLanguageCode('EN'), 'en');
      expect(LanguageUtils.normalizeLanguageCode(' eN '), 'en');
      expect(LanguageUtils.normalizeLanguageCode('zh'), 'zh');
    });

    test(
      'normalizeLanguageCode normalizes display names to supported codes',
      () {
        expect(LanguageUtils.normalizeLanguageCode('English'), 'en');
        expect(LanguageUtils.normalizeLanguageCode('english'), 'en');
        expect(LanguageUtils.normalizeLanguageCode('Spanish'), 'es');
        expect(LanguageUtils.normalizeLanguageCode('French'), 'fr');
        expect(LanguageUtils.normalizeLanguageCode('Chinese'), 'zh');
        expect(
          LanguageUtils.normalizeLanguageCode('Zhongwen'),
          'zh',
        ); // zho prefix
        expect(LanguageUtils.normalizeLanguageCode('Arabic'), 'ar');
        expect(LanguageUtils.normalizeLanguageCode('Yoruba'), 'yo');
        expect(LanguageUtils.normalizeLanguageCode('Igbo'), 'ig');
        expect(LanguageUtils.normalizeLanguageCode('Hausa'), 'ha');
      },
    );

    test(
      'normalizeLanguageCode normalizes region codes to supported codes',
      () {
        expect(LanguageUtils.normalizeLanguageCode('en-US'), 'en');
        expect(LanguageUtils.normalizeLanguageCode('fr-FR'), 'fr');
        expect(LanguageUtils.normalizeLanguageCode('zh-CN'), 'zh');
        expect(LanguageUtils.normalizeLanguageCode('es_ES'), 'es');
        expect(LanguageUtils.normalizeLanguageCode('zh_CN'), 'zh');
      },
    );

    test(
      'normalizeLanguageCode falls back to english for unsupported values',
      () {
        expect(LanguageUtils.normalizeLanguageCode('pt'), 'en');
        expect(LanguageUtils.normalizeLanguageCode('pt-BR'), 'en');
        expect(LanguageUtils.normalizeLanguageCode('German'), 'en');
        expect(LanguageUtils.normalizeLanguageCode('unknown'), 'en');
      },
    );

    test('toLocale returns correct Locale', () {
      expect(LanguageUtils.toLocale('en').languageCode, 'en');
      expect(LanguageUtils.toLocale('fr-FR').languageCode, 'fr');
      expect(LanguageUtils.toLocale('unknown').languageCode, 'en');
      expect(LanguageUtils.toLocale(null).languageCode, 'en');
    });
  });
}
