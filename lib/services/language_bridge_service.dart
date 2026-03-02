import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/language_utils.dart';

class LanguageBridgeService {
  static const String _baseUrl =
      'https://fomowl-backend.onrender.com/api/language';

  Future<Map<String, String>> getSupportedLanguages() async {
    try {
      final uri = Uri.parse('$_baseUrl/supported');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return const {};
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['languages'] as List<dynamic>? ?? const [];
      final result = <String, String>{};
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final code = item['code']?.toString();
        final name = item['name']?.toString();
        if (code == null || name == null || code.isEmpty || name.isEmpty) {
          continue;
        }
        final normalized = LanguageUtils.normalizeLanguageCode(code);
        if (LanguageUtils.supportedLanguageCodes.contains(normalized)) {
          result[name] = normalized;
        }
      }
      return result;
    } on TimeoutException catch (e) {
      debugPrint('Language getSupportedLanguages timeout: $e');
      return const {};
    } on FormatException catch (e) {
      debugPrint('Language getSupportedLanguages parse failed: $e');
      return const {};
    } catch (e) {
      debugPrint('Language getSupportedLanguages failed: $e');
      return const {};
    }
  }

  Future<String?> getLanguagePreference({required String walletAddress}) async {
    try {
      final encodedWallet = Uri.encodeComponent(walletAddress);
      final uri = Uri.parse('$_baseUrl/preference/$encodedWallet');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final code = data['languageCode']?.toString();
      if (code == null || code.isEmpty) return null;
      return LanguageUtils.normalizeLanguageCode(code);
    } catch (e) {
      debugPrint('Language getLanguagePreference failed: $e');
      return null;
    }
  }

  Future<String?> reconcileLanguage({
    required String? walletAddress,
    required String? localLanguageCode,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (walletAddress == null || walletAddress.isEmpty) return null;
    try {
      final backendLanguageCode = await getLanguagePreference(
        walletAddress: walletAddress,
      ).timeout(timeout);
      if (backendLanguageCode == null || backendLanguageCode.isEmpty) {
        return null;
      }
      final normalizedBackend = LanguageUtils.normalizeLanguageCode(
        backendLanguageCode,
      );
      final normalizedLocal = LanguageUtils.normalizeLanguageCode(
        localLanguageCode,
      );
      if (normalizedBackend == normalizedLocal) return null;
      return normalizedBackend;
    } catch (_) {
      return null;
    }
  }

  Future<void> syncLanguagePreference({
    required String walletAddress,
    required String languageCode,
  }) async {
    final uri = Uri.parse('$_baseUrl/preference');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'walletAddress': walletAddress,
            'languageCode': languageCode,
            'provider': 'deepl',
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to sync language preference');
    }
  }

  Future<String> translateText({
    required String text,
    required String sourceCode,
    required String targetCode,
  }) async {
    final uri = Uri.parse('$_baseUrl/translate');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': text,
            'source': sourceCode,
            'target': targetCode,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Translation request failed (HTTP ${response.statusCode})',
      );
    }
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['translatedText']?.toString() ?? text;
    } catch (e) {
      debugPrint(
        'Failed to parse translation response: $e. Body: ${response.body}',
      );
      return text;
    }
  }
}
