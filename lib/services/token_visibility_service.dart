import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/token.dart';
import '../utils/token_visibility_utils.dart';

class TokenVisibilityChange {
  const TokenVisibilityChange({
    required this.chainId,
    required this.hiddenTokens,
  });

  final int chainId;
  final Set<String> hiddenTokens;
}

/// Persists which tokens should be hidden per chain and exposes helpers that
/// cache the results in-memory for fast lookups.
class TokenVisibilityService {
  TokenVisibilityService._internal();

  static final TokenVisibilityService _instance =
      TokenVisibilityService._internal();

  factory TokenVisibilityService() => _instance;

  final Map<int, Set<String>> _cache = {};
  final StreamController<TokenVisibilityChange> _changes =
      StreamController<TokenVisibilityChange>.broadcast();

  Stream<TokenVisibilityChange> get changes => _changes.stream;

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
      entry.removeAll(TokenVisibilityUtils.identifiers(token));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key(chainId), entry.toList());
    _emitChange(chainId, entry);
  }

  /// Returns whether [token] is hidden for [chainId].
  bool isHidden(int chainId, Token token) {
    final entry = _cache[chainId];
    if (entry == null) return false;
    return TokenVisibilityUtils.contains(entry, token);
  }

  void _emitChange(int chainId, Set<String> hiddenTokens) {
    if (_changes.isClosed) {
      return;
    }
    _changes.add(
      TokenVisibilityChange(
        chainId: chainId,
        hiddenTokens: Set<String>.from(hiddenTokens),
      ),
    );
  }

  String _key(int chainId) => 'hidden_tokens_$chainId';
}
