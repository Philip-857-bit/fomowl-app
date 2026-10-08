import '../../models/chain.dart';
import '../../models/token.dart';
import '../../models/token_standard.dart';
import '../../utils/token_visibility_utils.dart';
import '../../utils/token_trust_utils.dart';
import 'home_portfolio_data.dart';

class HomePortfolioRepository {
  const HomePortfolioRepository();

  List<Token> prepareVisibleTokens(
    List<Token> tokens,
    Set<String> hiddenTokenKeys, {
    Set<String> userAddedAddresses = const {},
    int chainId = 0,
    bool explicitSearch = false,
  }) => _prepareVisibleTokens(
    tokens,
    hiddenTokenKeys,
    userAddedAddresses: userAddedAddresses,
    chainId: chainId,
    explicitSearch: explicitSearch,
  );

  Future<HomePortfolioData> filterSections({
    required List<HomePortfolioSection> sections,
    required Future<Set<String>> Function(int chainId) loadHiddenTokens,
    Set<String> Function(int chainId)? loadUserAddedAddresses,
  }) async {
    final visibleSections = await Future.wait(
      sections.map(
        (section) => _filterSection(
          section: section,
          loadHiddenTokens: loadHiddenTokens,
          userAddedAddresses:
              loadUserAddedAddresses?.call(section.chain.chainId) ?? const {},
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
    Set<String> Function(int chainId)? loadUserAddedAddresses,
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
          userAddedAddresses:
              loadUserAddedAddresses?.call(chain.chainId) ?? const {},
        ),
      ),
    );

    return filterSections(
      sections: sections.whereType<HomePortfolioSection>().toList(),
      loadHiddenTokens: loadHiddenTokens,
      loadUserAddedAddresses: loadUserAddedAddresses,
    );
  }

  Future<HomePortfolioSection?> _loadSection({
    required EvmChain chain,
    required Future<List<Token>> Function(int chainId) fetchTokens,
    required Future<Set<String>> Function(int chainId) loadHiddenTokens,
    required Set<String> userAddedAddresses,
  }) async {
    try {
      final tokens = await fetchTokens(chain.chainId);
      return await _filterSection(
        section: HomePortfolioSection(chain: chain, tokens: tokens),
        loadHiddenTokens: loadHiddenTokens,
        userAddedAddresses: userAddedAddresses,
      );
    } catch (_) {
      return null;
    }
  }

  Future<HomePortfolioSection?> _filterSection({
    required HomePortfolioSection section,
    required Future<Set<String>> Function(int chainId) loadHiddenTokens,
    Set<String> userAddedAddresses = const {},
  }) async {
    final hiddenTokenKeys = await loadHiddenTokens(section.chain.chainId);
    final scopedTokens = section.tokens
        .where((token) => _tokenBelongsToSection(token, section.chain))
        .toList();
    final visibleTokens = _prepareVisibleTokens(
      scopedTokens,
      hiddenTokenKeys,
      userAddedAddresses: userAddedAddresses,
      chainId: section.chain.chainId,
    );

    if (visibleTokens.isEmpty) {
      return null;
    }

    return HomePortfolioSection(chain: section.chain, tokens: visibleTokens);
  }

  bool _tokenBelongsToSection(Token token, EvmChain chain) {
    final expectedNetworkKey = _sectionNetworkKey(chain).toLowerCase();
    final tokenNetworkKey = token.networkKey?.trim().toLowerCase();
    if (tokenNetworkKey != null && tokenNetworkKey.isNotEmpty) {
      return tokenNetworkKey == expectedNetworkKey;
    }

    final contract = token.contractAddress?.trim() ?? '';
    final isNative =
        contract.isEmpty ||
        token.effectiveTokenStandard == TokenStandard.native;
    final symbol = token.symbol.trim().toUpperCase();
    switch (chain.family) {
      case ChainFamily.bitcoin:
        return isNative && symbol == 'BTC';
      case ChainFamily.evm:
        if (token.effectiveTokenStandard == TokenStandard.spl ||
            token.effectiveTokenStandard == TokenStandard.trc20) {
          return false;
        }
        if (isNative) {
          return symbol == chain.symbol.trim().toUpperCase();
        }
        return contract.startsWith(RegExp(r'0x', caseSensitive: false));
      case ChainFamily.solana:
        if (token.effectiveTokenStandard == TokenStandard.erc20 ||
            token.effectiveTokenStandard == TokenStandard.trc20) {
          return false;
        }
        if (isNative) {
          return symbol == 'SOL' || symbol == chain.symbol.trim().toUpperCase();
        }
        return !contract.startsWith(RegExp(r'0x', caseSensitive: false));
      case ChainFamily.tron:
        if (token.effectiveTokenStandard == TokenStandard.erc20 ||
            token.effectiveTokenStandard == TokenStandard.spl) {
          return false;
        }
        if (isNative) {
          return symbol == 'TRX' || symbol == chain.symbol.trim().toUpperCase();
        }
        return contract.startsWith('T');
    }
  }

  String _sectionNetworkKey(EvmChain chain) {
    return switch (chain.family) {
      ChainFamily.bitcoin => throw UnsupportedError(
        'Bitcoin is unavailable for this operation.',
      ),
      ChainFamily.solana => NetworkKey.solana('mainnet'),
      ChainFamily.tron => NetworkKey.tron('mainnet'),
      ChainFamily.evm => NetworkKey.evm(chain.chainId),
    };
  }

  List<Token> _prepareVisibleTokens(
    List<Token> tokens,
    Set<String> hiddenTokenKeys, {
    Set<String> userAddedAddresses = const {},
    int chainId = 0,
    bool explicitSearch = false,
  }) {
    final deduped = <String, Token>{};
    for (final token in tokens) {
      if (TokenVisibilityUtils.contains(hiddenTokenKeys, token)) {
        continue;
      }
      final isNativeToken =
          token.contractAddress == null ||
          token.contractAddress!.trim().isEmpty;
      final addr = token.contractAddress?.trim().toLowerCase() ?? '';
      final isUserAdded = addr.isNotEmpty && userAddedAddresses.contains(addr);
      if (!explicitSearch &&
          !TokenTrustUtils.showsByDefault(
            token,
            chainId: chainId,
            isUserAdded: isUserAdded,
          )) {
        continue;
      }
      if (!isNativeToken &&
          !isUserAdded &&
          token.balance <= 0 &&
          token.totalValueUsd <= 0) {
        continue;
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
