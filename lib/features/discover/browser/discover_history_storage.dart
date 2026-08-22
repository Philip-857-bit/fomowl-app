import 'dart:convert';

import '../../../services/secure_store.dart';
import 'browser_history_entry.dart';

class DiscoverHistoryStorage {
  DiscoverHistoryStorage({SecureStore? secureStore})
    : _secureStore = secureStore ?? const FlutterSecureStoreAdapter();

  static const String _storageKey = 'discover_browser_history_v1';
  static const int maxStoredEntries = 50;
  final SecureStore _secureStore;

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
    final payload = history
        .take(maxStoredEntries)
        .map((entry) => entry.toJson())
        .toList(growable: false);
    await _secureStore.write(key: key, value: jsonEncode(payload));
  }

  Future<void> clear({required String? scopeKey}) async {
    final key = _storageKeyFor(scopeKey);
    if (key == null) return;
    await _secureStore.delete(key: key);
  }

  String? _storageKeyFor(String? scopeKey) {
    final normalized = scopeKey?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    final encoded = base64UrlEncode(utf8.encode(normalized));
    return '${_storageKey}_$encoded';
  }
}
