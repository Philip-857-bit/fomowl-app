import '../../../models/chain.dart';
import '../../../models/token.dart';

class TokenManagementQueryHelper {
  static final _evmRe = RegExp(r'^0x[a-fA-F0-9]{40}$');
  static final _solanaRe = RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$');
  static final _tronRe = RegExp(r'^T[1-9A-HJ-NP-Za-km-z]{33}$');

  /// Returns true when [value] looks like a contract / mint address.
  /// Pass [family] to restrict to a single chain format; omit (null) to
  /// accept any known format (EVM 0x…, Solana base58, Tron T…).
  static bool isContractAddress(String value, {ChainFamily? family}) {
    final v = value.trim();
    if (family == null) {
      return _evmRe.hasMatch(v) || _tronRe.hasMatch(v) || _solanaRe.hasMatch(v);
    }
    return switch (family) {
      ChainFamily.evm => _evmRe.hasMatch(v),
      ChainFamily.tron => _tronRe.hasMatch(v),
      ChainFamily.solana => _solanaRe.hasMatch(v),
    };
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
