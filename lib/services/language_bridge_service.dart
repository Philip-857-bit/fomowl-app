import 'dart:convert';

import 'package:http/http.dart' as http;

class LanguageBridgeService {
  static const String _baseUrl = 'https://fomowl-backend.onrender.com/api/language';

  Future<Map<String, String>> getSupportedLanguages() async {
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
      result[name] = code;
    }
    return result;
  }

  Future<String?> getLanguagePreference({
    required String walletAddress,
  }) async {
    final uri = Uri.parse('$_baseUrl/preference/$walletAddress');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      return null;
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final code = data['languageCode']?.toString();
    if (code == null || code.isEmpty) return null;
    return code;
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
      throw Exception('Translation request failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['translatedText']?.toString() ?? text;
  }
}
