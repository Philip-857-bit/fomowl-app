import 'package:decimal/decimal.dart';

import '../../models/chain.dart';
import '../../models/token.dart';
import '../../utils/token_visibility_utils.dart';
import 'home_portfolio_data.dart';

class HomePortfolioRepository {
  const HomePortfolioRepository();

  static final Decimal _minVisibleUncertifiedUsd = Decimal.parse('0.01');

  List<Token> prepareVisibleTokens(
    List<Token> tokens,
    Set<String> hiddenTokenKeys, {
    Set<String> userAddedAddresses = const {},
  }) => _prepareVisibleTokens(
    tokens,
    hiddenTokenKeys,
    userAddedAddresses: userAddedAddresses,
  );

  Future<HomePortfolioData> filterSections({
    required List<HomePortfolioSection> sections,
    required Future<Set<String>> Function(int chainId) loadHiddenTokens,
  }) async {
    final visibleSections = await Future.wait(
      sections.map(
        (section) => _filterSection(
          section: section,
          loadHiddenTokens: loadHiddenTokens,
        ),
      ),
    );

    final filtered = visibleSections.whereType<HomePortfolioSection>().toList()
      ..sort(
        (left, right) => right.totalBalanceUsd.compareTo(left.totalBalanceUsd),
      );

    return HomePortfolioData.fromSections(filtered);
  }

  Future<HomePortfolioData> loadPortfolio({
    required String walletAddress,
    required List<EvmChain> chains,
    required Future<List<Token>> Function(int chainId) fetchTokens,
    required Future<Set<String>> Function(int chainId) loadHiddenTokens,
  }) async {
    if (walletAddress.trim().isEmpty) {
      return HomePortfolioData.empty();
    }

    final sections = await Future.wait(
      chains.map(
        (chain) async => _loadSection(
          chain: chain,
          fetchTokens: fetchTokens,
          loadHiddenTokens: loadHiddenTokens,
        ),
      ),
    );

    return filterSections(
      sections: sections.whereType<HomePortfolioSection>().toList(),
      loadHiddenTokens: loadHiddenTokens,
    );
  }

  Future<HomePortfolioSection?> _loadSection({
    required EvmChain chain,
    required Future<List<Token>> Function(int chainId) fetchTokens,
    required Future<Set<String>> Function(int chainId) loadHiddenTokens,
  }) async {
    try {
      final tokens = await fetchTokens(chain.chainId);
      return _filterSection(
        section: HomePortfolioSection(chain: chain, tokens: tokens),
        loadHiddenTokens: loadHiddenTokens,
      );
    } catch (_) {
      return null;
    }
  }

  Future<HomePortfolioSection?> _filterSection({
    required HomePortfolioSection section,
    required Future<Set<String>> Function(int chainId) loadHiddenTokens,
  }) async {
    final hiddenTokenKeys = await loadHiddenTokens(section.chain.chainId);
    final visibleTokens = _prepareVisibleTokens(
      section.tokens,
      hiddenTokenKeys,
    );

    if (visibleTokens.isEmpty) {
      return null;
    }

    return HomePortfolioSection(chain: section.chain, tokens: visibleTokens);
  }

  List<Token> _prepareVisibleTokens(
    List<Token> tokens,
    Set<String> hiddenTokenKeys, {
    Set<String> userAddedAddresses = const {},
  }) {
    final deduped = <String, Token>{};
    for (final token in tokens) {
      if (hiddenTokenKeys.contains(TokenVisibilityUtils.identifier(token))) {
        continue;
      }
      final isNativeToken =
          token.contractAddress == null ||
          token.contractAddress!.trim().isEmpty;
      final addr = token.contractAddress?.trim().toLowerCase() ?? '';
      final isUserAdded = addr.isNotEmpty && userAddedAddresses.contains(addr);
      if (!isNativeToken &&
          !isUserAdded &&
          token.balance <= 0 &&
          token.totalValueUsd <= 0) {
        continue;
      }
      if (!isNativeToken && !isUserAdded && !token.isCertified) {
        final totalValueUsd = token.totalValueUsdDecimal;
        final unitPriceUsd = token.unitPriceUsdDecimal;
        if (unitPriceUsd <= Decimal.zero ||
            totalValueUsd < _minVisibleUncertifiedUsd) {
          continue;
        }
      }

      final key =
          (token.contractAddress?.trim().isNotEmpty == true
                  ? token.contractAddress
                  : token.symbol)
              ?.toLowerCase() ??
          token.name.toLowerCase();
      final existing = deduped[key];
      if (existing == null || _shouldReplaceToken(existing, token)) {
        deduped[key] = token;
      }
    }

    final visibleTokens = deduped.values.toList()
      ..sort(
        (left, right) =>
            right.totalValueUsdDecimal.compareTo(left.totalValueUsdDecimal),
      );
    return visibleTokens;
  }

  bool _shouldReplaceToken(Token current, Token next) {
    if (current.isCertified != next.isCertified) {
      return next.isCertified;
    }
    final valueComparison = next.totalValueUsdDecimal.compareTo(
      current.totalValueUsdDecimal,
    );
    if (valueComparison != 0) {
      return valueComparison > 0;
    }
    return next.balanceDecimal.compareTo(current.balanceDecimal) > 0;
  }
}
