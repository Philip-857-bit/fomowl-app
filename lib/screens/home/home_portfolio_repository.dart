import '../../models/chain.dart';
import '../../models/token.dart';
import '../../utils/token_visibility_utils.dart';
import 'home_portfolio_data.dart';

class HomePortfolioRepository {
  const HomePortfolioRepository();

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
    final visibleTokens =
        section.tokens
            .where(
              (token) => !hiddenTokenKeys.contains(
                TokenVisibilityUtils.identifier(token),
              ),
            )
            .where((token) => token.balance > 0 || token.totalValueUsd > 0)
            .toList()
          ..sort(
            (left, right) =>
                right.totalValueUsdDecimal.compareTo(left.totalValueUsdDecimal),
          );

    if (visibleTokens.isEmpty) {
      return null;
    }

    return HomePortfolioSection(chain: section.chain, tokens: visibleTokens);
  }
}
