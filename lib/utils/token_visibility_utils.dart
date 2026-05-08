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
    return TokenVisibilityUtils.identifiers(
      token,
    ).any((id) => identifiers.contains(id));
  }
}
