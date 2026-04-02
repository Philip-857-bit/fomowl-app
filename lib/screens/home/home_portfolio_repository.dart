import '../../models/chain.dart';
import '../../models/token.dart';
import '../../utils/token_visibility_utils.dart';
import 'home_portfolio_data.dart';

class HomePortfolioRepository {
  const HomePortfolioRepository();

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

    final visibleSections = sections.whereType<HomePortfolioSection>().toList()
      ..sort(
        (left, right) => right.totalBalanceUsd.compareTo(left.totalBalanceUsd),
      );

    return HomePortfolioData.fromSections(visibleSections);
  }

  Future<HomePortfolioSection?> _loadSection({
    required EvmChain chain,
    required Future<List<Token>> Function(int chainId) fetchTokens,
    required Future<Set<String>> Function(int chainId) loadHiddenTokens,
  }) async {
    try {
      final hiddenTokenKeys = await loadHiddenTokens(chain.chainId);
      final tokens = await fetchTokens(chain.chainId);
      final visibleTokens =
          tokens
              .where(
                (token) => !hiddenTokenKeys.contains(
                  TokenVisibilityUtils.identifier(token),
                ),
              )
              .toList()
            ..sort(
              (left, right) => right.totalValueUsdDecimal.compareTo(
                left.totalValueUsdDecimal,
              ),
            );

      if (visibleTokens.isEmpty) {
        return null;
      }

      return HomePortfolioSection(chain: chain, tokens: visibleTokens);
    } catch (_) {
      return null;
    }
  }
}
