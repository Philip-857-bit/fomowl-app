import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/app_environment.dart';
import '../discover_url_utils.dart';
import 'discover_catalog_snapshot.dart';
import 'discover_dapp_entry.dart';

class DiscoverCatalogService {
  static const String _cacheKey = 'discover_catalog_snapshot_v1';

  DiscoverCatalogService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<DiscoverCatalogSnapshot?> loadCachedSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return DiscoverCatalogSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<DiscoverCatalogSnapshot> getSnapshot({
    bool forceRefresh = false,
  }) async {
    final cached = await loadCachedSnapshot();
    if (!forceRefresh && cached != null && cached.isFresh) {
      return cached;
    }

    try {
      final fresh = await _fetchFromBackend();
      await _saveSnapshot(fresh);
      return fresh;
    } catch (_) {
      if (cached != null && cached.isFresh) {
        return cached;
      }
      rethrow;
    }
  }

  Future<DiscoverCatalogSnapshot> _fetchFromBackend() async {
    final response = await _client
        .get(AppEnvironment.discover('/catalog'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to load Discover catalog.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid Discover catalog response.');
    }

    final dapps = (decoded['dapps'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (entry) => DiscoverDappEntry.fromJson(entry.cast<String, dynamic>()),
        )
        .where(
          (entry) =>
              entry.isActive &&
              entry.launchUrl.isNotEmpty &&
              normalizeDiscoverOrigin(entry.origin) != null,
        )
        .toList(growable: false);

    return DiscoverCatalogSnapshot(
      dapps: dapps,
      fetchedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> _saveSnapshot(DiscoverCatalogSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(snapshot.toJson()));
  }
}
