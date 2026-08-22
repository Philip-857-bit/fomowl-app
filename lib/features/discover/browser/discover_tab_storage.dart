import 'dart:convert';

import '../discover_url_utils.dart';
import '../../../services/secure_store.dart';

class DiscoverTabSnapshot {
  const DiscoverTabSnapshot({
    required this.id,
    required this.url,
    required this.title,
  });

  final String id;
  final String? url;
  final String? title;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'url': url,
    'title': title,
  };

  static DiscoverTabSnapshot? fromJson(dynamic value) {
    if (value is! Map) return null;
    final map = value.cast<Object?, Object?>();
    final id = map['id']?.toString().trim() ?? '';
    if (id.isEmpty) return null;
    final rawUrl = map['url']?.toString().trim();
    String? url;
    if (rawUrl != null && rawUrl.isNotEmpty) {
      final uri = Uri.tryParse(rawUrl);
      if (uri == null || !isSupportedDiscoverWebUri(uri)) return null;
      url = uri.toString();
    }
    final rawTitle = map['title']?.toString().trim();
    return DiscoverTabSnapshot(
      id: id,
      url: url,
      title: rawTitle == null || rawTitle.isEmpty ? null : rawTitle,
    );
  }
}

class DiscoverTabsSnapshot {
  const DiscoverTabsSnapshot({required this.tabs, required this.activeTabId});

  static const int currentVersion = 1;

  final List<DiscoverTabSnapshot> tabs;
  final String? activeTabId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': currentVersion,
    'activeTabId': activeTabId,
    'tabs': tabs.map((tab) => tab.toJson()).toList(growable: false),
  };

  static DiscoverTabsSnapshot? fromJson(dynamic value, {required int maxTabs}) {
    if (value is! Map) return null;
    final map = value.cast<Object?, Object?>();
    if (map['version'] != currentVersion || map['tabs'] is! List) return null;
    final tabs = (map['tabs'] as List)
        .map(DiscoverTabSnapshot.fromJson)
        .whereType<DiscoverTabSnapshot>()
        .take(maxTabs)
        .toList(growable: false);
    if (tabs.isEmpty) return null;
    final requestedActiveId = map['activeTabId']?.toString();
    final activeTabId = tabs.any((tab) => tab.id == requestedActiveId)
        ? requestedActiveId
        : tabs.first.id;
    return DiscoverTabsSnapshot(tabs: tabs, activeTabId: activeTabId);
  }
}

class DiscoverTabStorage {
  DiscoverTabStorage({SecureStore? secureStore})
    : _secureStore = secureStore ?? const FlutterSecureStoreAdapter();

  static const String _storageKey = 'discover_tabs_v1';
  final SecureStore _secureStore;

  SecureStore get secureStore => _secureStore;

  Future<DiscoverTabsSnapshot?> load({
    required int maxTabs,
    required String? scopeKey,
  }) async {
    final key = _storageKeyFor(scopeKey);
    if (key == null) return null;
    final raw = await _secureStore.read(key: key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return DiscoverTabsSnapshot.fromJson(jsonDecode(raw), maxTabs: maxTabs);
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required DiscoverTabsSnapshot snapshot,
    required String? scopeKey,
  }) async {
    final key = _storageKeyFor(scopeKey);
    if (key == null) return;
    await _secureStore.write(key: key, value: jsonEncode(snapshot.toJson()));
  }

  String? _storageKeyFor(String? scopeKey) {
    final normalized = scopeKey?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    final encoded = base64UrlEncode(utf8.encode(normalized));
    return '${_storageKey}_$encoded';
  }
}
