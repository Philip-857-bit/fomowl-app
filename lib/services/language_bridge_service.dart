import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_environment.dart';
import '../utils/language_utils.dart';
import 'wallet_backend_auth_service.dart';
import 'http_client_service.dart';

class LanguageBridgeService {
  LanguageBridgeService({
    WalletBackendAuthService? walletBackendAuthService,
    HttpClientService? httpClientService,
  }) : _walletBackendAuthService =
           walletBackendAuthService ?? WalletBackendAuthService(),
       _httpClientService = httpClientService ?? HttpClientService();

  final WalletBackendAuthService _walletBackendAuthService;
  final HttpClientService _httpClientService;

  Future<Map<String, String>> getSupportedLanguages() async {
    try {
      final uri = AppEnvironment.language('/supported');
      final response = await _httpClientService
          .sendWithRetry(() => _httpClientService.client.get(uri))
          .timeout(const Duration(seconds: 10));
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
          result[normalized] = name;
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
      final uri = AppEnvironment.language('/preference/$encodedWallet');
      final response = await _walletBackendAuthService
          .sendAuthorized(
            walletAddress,
            (headers) => _httpClientService.sendWithRetry(
              () => _httpClientService.client.get(uri, headers: headers),
            ),
            const {},
          )
          .timeout(const Duration(seconds: 10));
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

  Future<void> syncLanguagePreference({
    required String walletAddress,
    required String languageCode,
  }) async {
    final uri = AppEnvironment.language('/preference');
    final response = await _walletBackendAuthService
        .sendAuthorized(
          walletAddress,
          (headers) => _httpClientService.sendWithRetry(
            () => _httpClientService.client.post(
              uri,
              headers: headers,
              body: jsonEncode({
                'walletAddress': walletAddress,
                'languageCode': LanguageUtils.normalizeLanguageCode(
                  languageCode,
                ),
                'provider': 'deepl',
              }),
            ),
          ),
          {'Content-Type': 'application/json'},
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
    final uri = AppEnvironment.language('/translate');
    final response = await _httpClientService
        .sendWithRetry(
          () => _httpClientService.client.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'source': sourceCode,
              'target': targetCode,
            }),
          ),
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
        'Failed to parse translation response: $e. Status: ${response.statusCode}',
      );
      return text;
    }
  }
}
