import '../../../models/token.dart';

class TokenManagementQueryHelper {
  static bool isContractAddress(String value) {
    return RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(value.trim());
  }

  static List<Token> filterLocalTokens(List<Token> tokens, String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return List<Token>.from(tokens);
    return tokens
        .where(
          (t) =>
              t.name.toLowerCase().contains(trimmed) ||
              t.symbol.toLowerCase().contains(trimmed) ||
              (t.contractAddress ?? '').toLowerCase().contains(trimmed),
        )
        .toList();
  }
}
