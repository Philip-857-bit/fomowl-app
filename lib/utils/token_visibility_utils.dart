import '../models/token.dart';

/// Utility helpers for computing identifiers used to persist token visibility.
class TokenVisibilityUtils {
  TokenVisibilityUtils._();

  /// Creates a stable identifier for a token using its contract address when
  /// available or falling back to the native symbol.
  static String identifier(Token token) {
    final address = token.contractAddress;
    if (address != null && address.isNotEmpty) {
      return address.toLowerCase();
    }
    return 'native_${token.symbol.toLowerCase()}';
  }
}
