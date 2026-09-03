import '../models/token.dart';

/// Utility helpers for computing identifiers used to persist token visibility.
class TokenVisibilityUtils {
  TokenVisibilityUtils._();

  /// Creates a stable identifier for a token using its contract address when
  /// available or falling back to the native symbol.
  static String identifier(Token token) {
    final scope = token.networkKey?.trim().toLowerCase();
    final tokenId = legacyIdentifier(token);
    if (scope != null && scope.isNotEmpty) {
      return '$scope:$tokenId';
    }
    return tokenId;
  }

  /// Identifier format used before networkKey scoping was introduced.
  static String legacyIdentifier(Token token) {
    final address = token.contractAddress;
    return (address != null && address.isNotEmpty)
        ? address.toLowerCase()
        : 'native_${token.symbol.toLowerCase()}';
  }

  /// All accepted identifiers while migrating legacy unscoped visibility keys.
  static Set<String> identifiers(Token token) {
    final current = identifier(token);
    final legacy = legacyIdentifier(token);
    return {current, if (legacy != current) legacy};
  }

  static bool contains(Set<String> identifiers, Token token) {
    if (TokenVisibilityUtils.identifiers(
      token,
    ).any((id) => identifiers.contains(id))) {
      return true;
    }

    // Robustness: a token hidden under one networkKey scope (e.g. "evm:1:0x..")
    // must stay hidden even when it is later encountered with a different or
    // absent scope. This happens in the Send/Swap token pickers, which merge
    // tokens from several sources (wallet, cache, backend "suggested" list,
    // custom) — some of which carry no networkKey, so their identifiers never
    // match the scope-qualified stored id and the token leaks back into the
    // list. Visibility is already bucketed per chain, so matching the un-scoped
    // legacy id (contract address or native_<symbol>) as a scope suffix is
    // unambiguous within a chain and never collides with a different token.
    final suffix = ':${legacyIdentifier(token)}';
    return identifiers.any((id) => id.endsWith(suffix));
  }
}
