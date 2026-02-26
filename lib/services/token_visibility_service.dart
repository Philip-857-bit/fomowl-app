import 'package:shared_preferences/shared_preferences.dart';

import '../models/token.dart';
import '../utils/token_visibility_utils.dart';

/// Persists which tokens should be hidden per chain and exposes helpers that
/// cache the results in-memory for fast lookups.
class TokenVisibilityService {
  TokenVisibilityService._internal();

  static final TokenVisibilityService _instance = TokenVisibilityService._internal();

  factory TokenVisibilityService() => _instance;

  final Map<int, Set<String>> _cache = {};

  /// Loads hidden tokens for [chainId] from storage.
  Future<Set<String>> loadHiddenTokens(int chainId) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key(chainId)) ?? const <String>[];
    final normalized = stored.map((e) => e.toLowerCase()).toSet();
    _cache[chainId] = normalized;
    return Set<String>.from(normalized);
  }

  /// Returns the cached hidden token identifiers for [chainId].
  Set<String> getHiddenTokens(int chainId) {
    final cached = _cache[chainId];
    if (cached == null) return <String>{};
    return Set<String>.from(cached);
  }

  /// Persists visibility changes for [token] on [chainId].
  Future<void> setTokenHidden(int chainId, Token token, bool hidden) async {
    final entry = _cache.putIfAbsent(chainId, () => <String>{});
    final identifier = TokenVisibilityUtils.identifier(token);
    if (hidden) {
      entry.add(identifier);
    } else {
      entry.remove(identifier);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key(chainId), entry.toList());
  }

  /// Returns whether [token] is hidden for [chainId].
  bool isHidden(int chainId, Token token) {
    final entry = _cache[chainId];
    if (entry == null) return false;
    return entry.contains(TokenVisibilityUtils.identifier(token));
  }

  String _key(int chainId) => 'hidden_tokens_$chainId';
}
