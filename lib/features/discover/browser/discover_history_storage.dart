import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../config/app_environment.dart';
import '../../../services/http_client_service.dart';
import '../../../services/secure_store.dart';
import 'browser_history_entry.dart';

class DiscoverHistoryStorage {
  DiscoverHistoryStorage({
    SecureStore? secureStore,
    HttpClientService? httpClientService,
  }) : _secureStore = secureStore ?? const FlutterSecureStoreAdapter(),
       _httpClientService = httpClientService ?? HttpClientService();

  static const String _storageKey = 'discover_browser_history_v1';
  static const int maxStoredEntries = 50;
  final SecureStore _secureStore;
  final HttpClientService _httpClientService;

  Future<void> recordRemoteVisit({
    required String url,
    required String origin,
    String? title,
    String? walletAddress,
  }) async {
    try {
      final payload = <String, dynamic>{
        'url': url,
        'origin': origin,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (walletAddress != null && walletAddress.trim().isNotEmpty)
          'walletAddress': walletAddress.trim(),
        'source': 'discover_browser',
        'platform': defaultTargetPlatform.name,
      };

      final response = await _httpClientService
          .sendWithRetry(
            () => _httpClientService.client.post(
              AppEnvironment.discover('/visit'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            ),
          )
          .timeout(const Duration(seconds: 6));

      if (kDebugMode && response.statusCode >= 500) {
        debugPrint(
          'Discover remote visit recording failed: ${response.statusCode}',
        );
      }
    } catch (_) {
      // Non-blocking telemetry
    }
  }

  Future<List<BrowserHistoryEntry>> load({required String? scopeKey}) async {
    final key = _storageKeyFor(scopeKey);
    if (key == null) return const <BrowserHistoryEntry>[];
    final raw = await _secureStore.read(key: key);
    if (raw == null || raw.isEmpty) return const <BrowserHistoryEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <BrowserHistoryEntry>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(BrowserHistoryEntry.fromJson)
          .take(maxStoredEntries)
          .toList(growable: false);
    } catch (_) {
      return const <BrowserHistoryEntry>[];
    }
  }

  Future<void> save({
    required List<BrowserHistoryEntry> history,
    required String? scopeKey,
  }) async {
    final key = _storageKeyFor(scopeKey);
    if (key == null) return;
    try {
      final payload = history
          .take(maxStoredEntries)
          .map((entry) => entry.toJson())
          .toList(growable: false);
      await _secureStore.write(key: key, value: jsonEncode(payload));
    } catch (_) {}
  }

  Future<void> clear({required String? scopeKey}) async {
    final key = _storageKeyFor(scopeKey);
    if (key == null) return;
    try {
      await _secureStore.delete(key: key);
    } catch (_) {}
  }

  String? _storageKeyFor(String? scopeKey) {
    final normalized = scopeKey?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    final encoded = base64UrlEncode(utf8.encode(normalized));
    return '${_storageKey}_$encoded';
  }
}
