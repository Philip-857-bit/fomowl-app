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
        // PATCH: Preserve backend price source metadata during enrichment.
        priceSource: t.priceSource,
        // PATCH: Preserve backend DEX liquidity metadata during enrichment.
        liquidityUsd: t.liquidityUsd,
        // PATCH: Preserve backend DEX-only marker during enrichment.
        isDexOnly: t.isDexOnly,
        // PATCH: Preserve network key during enrichment.
        networkKey: t.networkKey,
        // PATCH: Preserve token standard during enrichment.
        tokenStandard: t.tokenStandard,
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

    final missingCustom = customTokens.where((custom) {
      return !merged.any(
        (t) =>
            (t.contractAddress ?? '').toLowerCase() ==
            custom.address.toLowerCase(),
      );
    }).toList();

    final balanceByAddress =
        await _fetchBalancesInBatches<CustomTokenDefinition>(
          items: missingCustom,
          addressOf: (custom) => custom.address,
          decimalsOf: (custom) => custom.decimals,
          walletAddress: walletAddress,
          batchSize: 6,
        );

    for (final custom in missingCustom) {
      final bal = balanceByAddress[custom.address.toLowerCase()] ?? 0.0;
      final customCoinGeckoId = custom.coinGeckoId;
      final price = (customCoinGeckoId == null || customCoinGeckoId.isEmpty)
          ? 0.0
          : (customPrices[customCoinGeckoId] ?? 0.0);
      final change = (customCoinGeckoId == null || customCoinGeckoId.isEmpty)
          ? 0.0
          : (customPrices['${customCoinGeckoId}_change'] ?? 0.0);

      // Ensure we only merge custom tokens that belong to the correct network.
      // If networkKey is missing (legacy), we assume it matches.
      final matchesNetwork =
          custom.networkKey == null ||
          custom.networkKey == existing.firstOrNull?.networkKey;
      if (!matchesNetwork) continue;

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
          isCertified: custom.isCertified,
          // PATCH: Custom token prices from simple price lookup have no source metadata.
          priceSource: 'Unknown',
          networkKey: custom.networkKey ?? existing.firstOrNull?.networkKey,
          tokenStandard: custom.tokenStandard,
        ),
      );
    }

    return merged;
  }

  Future<List<Token>> collectSupplementalKnownTokens({
    required String walletAddress,
    required List<Token> existing,
    required List<Map<String, String>> knownTokens,
    int maxResults = 8,
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

    final balanceByAddress = await _fetchBalancesInBatches<Map<String, String>>(
      items: candidates,
      addressOf: (token) => token['address'] ?? '',
      decimalsOf: (token) => int.tryParse(token['decimals'] ?? '') ?? 18,
      walletAddress: walletAddress,
      batchSize: 8,
    );

    final results = <Token>[];
    for (final tDef in candidates) {
      final address = tDef['address']!;
      final decimals = int.tryParse(tDef['decimals'] ?? '') ?? 18;
      final bal = balanceByAddress[address.toLowerCase()] ?? 0.0;
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
          // PATCH: Supplemental token prices from simple price lookup have no source metadata.
          priceSource: 'Unknown',
        ),
      );

      if (results.length >= maxResults) {
        break;
      }
    }
    return results;
  }

  Future<Map<String, double>> _fetchBalancesInBatches<T>({
    required List<T> items,
    required String Function(T item) addressOf,
    required int Function(T item) decimalsOf,
    required String walletAddress,
    int batchSize = 6,
  }) async {
    final balances = <String, double>{};
    if (items.isEmpty) return balances;

    final effectiveBatchSize = batchSize <= 0 ? 1 : batchSize;
    for (var index = 0; index < items.length; index += effectiveBatchSize) {
      final end = (index + effectiveBatchSize) > items.length
          ? items.length
          : (index + effectiveBatchSize);
      final batch = items.sublist(index, end);

      final batchResults = await Future.wait(
        batch.map((item) async {
          final address = addressOf(item);
          final decimals = decimalsOf(item);
          final balance = await getTokenBalance(
            walletAddress,
            address,
            decimals,
          );
          return MapEntry(address.toLowerCase(), balance);
        }),
      );

      for (final entry in batchResults) {
        balances[entry.key] = entry.value;
      }
    }
    return balances;
  }
}
