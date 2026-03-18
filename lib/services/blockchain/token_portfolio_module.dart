import '../../models/chain.dart';
import '../../models/token.dart';

typedef PriceFetcher = Future<Map<String, double>> Function(List<String> ids);
typedef BalanceFetcher =
    Future<double> Function(
      String walletAddress,
      String tokenAddress,
      int decimals,
    );
typedef IconResolver = String? Function(String symbol);

class TokenPortfolioModule {
  TokenPortfolioModule({
    required this.getTokenPrices,
    required this.getTokenBalance,
    required this.resolveIconUrl,
  });

  final PriceFetcher getTokenPrices;
  final BalanceFetcher getTokenBalance;
  final IconResolver resolveIconUrl;

  Future<List<Token>> enrichTokensWithPrices(
    List<Token> tokens, {
    required String? nativeCoinGeckoId,
  }) async {
    final priceIds = <String>{};
    if (nativeCoinGeckoId != null && nativeCoinGeckoId.isNotEmpty) {
      priceIds.add(nativeCoinGeckoId);
    }
    for (final t in tokens) {
      final cgId = t.coinGeckoId;
      if (cgId != null && cgId.isNotEmpty) {
        priceIds.add(cgId);
      }
    }
    if (priceIds.isEmpty) return tokens;

    final prices = await getTokenPrices(priceIds.toList());

    return tokens.map((t) {
      final cgId = (t.coinGeckoId != null && t.coinGeckoId!.isNotEmpty)
          ? t.coinGeckoId!
          : (t.contractAddress == null && nativeCoinGeckoId != null
                ? nativeCoinGeckoId
                : null);
      if (cgId == null) return t;

      final price = prices[cgId] ?? 0.0;
      final change = prices['${cgId}_change'] ?? t.changePercent24h;

      if (t.priceUsd > 0 && t.valueUsd > 0 && price == 0) return t;
      if (price == 0) return t;

      return Token(
        symbol: t.symbol,
        name: t.name,
        contractAddress: t.contractAddress,
        balance: t.balance,
        valueUsd: t.balance * price,
        priceUsd: price,
        changePercent24h: change,
        decimals: t.decimals,
        imageUrl: t.imageUrl,
        coinGeckoId: t.coinGeckoId,
        isCertified: t.isCertified,
      );
    }).toList();
  }

  Future<List<Token>> mergeMissingCustomTokens({
    required String walletAddress,
    required List<Token> existing,
    required List<CustomTokenDefinition> customTokens,
  }) async {
    final merged = List<Token>.from(existing);
    final customPriceIds = customTokens
        .where((c) => c.coinGeckoId != null && c.coinGeckoId!.isNotEmpty)
        .map((c) => c.coinGeckoId!)
        .toSet()
        .toList();
    final customPrices = customPriceIds.isNotEmpty
        ? await getTokenPrices(customPriceIds)
        : <String, double>{};

    for (final custom in customTokens) {
      final alreadyInList = merged.any(
        (t) =>
            (t.contractAddress ?? '').toLowerCase() ==
            custom.address.toLowerCase(),
      );
      if (alreadyInList) continue;

      final bal = await getTokenBalance(
        walletAddress,
        custom.address,
        custom.decimals,
      );
      final price = (custom.coinGeckoId == null || custom.coinGeckoId!.isEmpty)
          ? 0.0
          : (customPrices[custom.coinGeckoId] ?? 0.0);
      final change = (custom.coinGeckoId == null || custom.coinGeckoId!.isEmpty)
          ? 0.0
          : (customPrices['${custom.coinGeckoId}_change'] ?? 0.0);

      merged.add(
        Token(
          symbol: custom.symbol,
          name: custom.name,
          contractAddress: custom.address,
          balance: bal,
          valueUsd: bal * price,
          priceUsd: price,
          changePercent24h: change,
          decimals: custom.decimals,
          imageUrl: custom.imageUrl,
          coinGeckoId: custom.coinGeckoId,
          isCertified: false,
        ),
      );
    }

    return merged;
  }

  Future<List<Token>> collectSupplementalKnownTokens({
    required int chainId,
    required String walletAddress,
    required List<Token> existing,
    required List<Map<String, String>> knownTokens,
  }) async {
    final existingContracts = existing
        .map((t) => (t.contractAddress ?? '').toLowerCase())
        .toSet();
    final candidates = knownTokens.where((t) {
      final address = (t['address'] ?? '').toLowerCase();
      return address.isNotEmpty && !existingContracts.contains(address);
    }).toList();
    if (candidates.isEmpty) return const [];

    final priceIds = candidates
        .map((t) => t['coinGeckoId'])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final prices = priceIds.isNotEmpty
        ? await getTokenPrices(priceIds)
        : <String, double>{};

    final results = <Token>[];
    for (final tDef in candidates) {
      final address = tDef['address']!;
      final decimals = int.tryParse(tDef['decimals'] ?? '') ?? 18;
      final bal = await getTokenBalance(walletAddress, address, decimals);
      if (bal <= 0) continue;

      final coinGeckoId = tDef['coinGeckoId'];
      final price = (coinGeckoId == null || coinGeckoId.isEmpty)
          ? 0.0
          : (prices[coinGeckoId] ?? 0.0);
      final change = (coinGeckoId == null || coinGeckoId.isEmpty)
          ? 0.0
          : (prices['${coinGeckoId}_change'] ?? 0.0);

      results.add(
        Token(
          symbol: tDef['symbol']!,
          name: tDef['name']!,
          contractAddress: address,
          balance: bal,
          valueUsd: bal * price,
          priceUsd: price,
          changePercent24h: change,
          decimals: decimals,
          imageUrl: tDef['imageUrl'] ?? resolveIconUrl(tDef['symbol']!),
          coinGeckoId: coinGeckoId,
          isCertified: tDef['isCertified'] == 'true',
        ),
      );
    }
    return results;
  }
}
