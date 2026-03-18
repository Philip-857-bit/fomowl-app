import 'package:flutter/material.dart';

class LanguageUtils {
  LanguageUtils._();

  static const String fallbackLanguageCode = 'en';
  static const Locale defaultLocale = Locale(fallbackLanguageCode, '');
  static const Set<String> supportedLanguageCodes = {
    'en',
    'es',
    'fr',
    'zh',
    'ar',
    'yo',
    'ig',
    'ha',
  };
  static const Map<String, String> languageNamesByCode = {
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'zh': '中文',
    'ar': 'العربية',
    'yo': 'Yorùbá',
    'ig': 'Igbo',
    'ha': 'Hausa',
  };

  static String normalizeLanguageCode(String? raw) {
    if (raw == null) return fallbackLanguageCode;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return fallbackLanguageCode;

    final lower = trimmed.toLowerCase();
    if (supportedLanguageCodes.contains(lower)) return lower;

    final splitDash = lower.split('-').first;
    if (supportedLanguageCodes.contains(splitDash)) return splitDash;

    final splitUnderscore = lower.split('_').first;
    if (supportedLanguageCodes.contains(splitUnderscore)) {
      return splitUnderscore;
    }

    if (lower.startsWith('arab')) return 'ar';
    if (lower.startsWith('eng')) return 'en';
    if (lower.startsWith('span')) return 'es';
    if (lower.startsWith('fren')) return 'fr';
    if (lower.startsWith('chin') || lower.startsWith('zho')) return 'zh';
    if (lower.startsWith('yor')) return 'yo';
    if (lower.startsWith('igb')) return 'ig';
    if (lower.startsWith('hau')) return 'ha';

    return fallbackLanguageCode;
  }

  static Locale toLocale(String? rawLanguageCode) {
    final code = normalizeLanguageCode(rawLanguageCode);
    return Locale(code, '');
  }
}
