import 'package:decimal/decimal.dart';

import 'token_standard.dart';
import '../utils/value_formatter.dart';

/// Token Model
/// Represents a cryptocurrency token with its details
class Token {
  final String symbol;
  final String name;
  final String? contractAddress;
  final double balance;

  /// Stores the total USD value of holdings when known.
  final double valueUsd;

  /// Per-token USD price, used for swap math and detail screens.
  final double priceUsd;
  final String priceStatus;
  final DateTime? priceUpdatedAt;
  final double changePercent24h;
  final int decimals;
  final String? imageUrl;
  final String? coinGeckoId;
  final bool isCertified;
  final String? networkKey;
  final TokenStandard tokenStandard;
  // PATCH: Backend price resolver source for provider/DEX badges.
  final String priceSource;
  // PATCH: DEX liquidity when the backend can estimate it.
  final double? liquidityUsd;
  // PATCH: True when the price was found only through DEX fallback.
  final bool isDexOnly;

  const Token({
    required this.symbol,
    required this.name,
    this.contractAddress,
    required this.balance,
    required this.valueUsd,
    this.priceUsd = 0.0,
    this.priceStatus = 'price_unavailable',
    this.priceUpdatedAt,
    required this.changePercent24h,
    this.decimals = 18,
    this.imageUrl,
    this.coinGeckoId,
    this.isCertified = false,
    this.networkKey,
    this.tokenStandard = TokenStandard.erc20,
    // PATCH: Default preserves existing callers that do not provide source metadata.
    this.priceSource = 'Unknown',
    // PATCH: Default preserves existing callers that do not provide liquidity metadata.
    this.liquidityUsd,
    // PATCH: Default preserves existing provider-priced tokens.
    this.isDexOnly = false,
  });

  TokenStandard get effectiveTokenStandard {
    if (contractAddress == null && tokenStandard == TokenStandard.erc20) {
      return TokenStandard.native;
    }
    return tokenStandard;
  }

  Token copyWith({
    String? symbol,
    String? name,
    String? contractAddress,
    double? balance,
    double? valueUsd,
    double? priceUsd,
    String? priceStatus,
    DateTime? priceUpdatedAt,
    double? changePercent24h,
    int? decimals,
    String? imageUrl,
    String? coinGeckoId,
    bool? isCertified,
    String? networkKey,
    TokenStandard? tokenStandard,
    // PATCH: Copy source metadata through local token mutations.
    String? priceSource,
    // PATCH: Copy DEX liquidity metadata through local token mutations.
    double? liquidityUsd,
    // PATCH: Copy DEX-only flag through local token mutations.
    bool? isDexOnly,
  }) {
    return Token(
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      contractAddress: contractAddress ?? this.contractAddress,
      balance: balance ?? this.balance,
      valueUsd: valueUsd ?? this.valueUsd,
      priceUsd: priceUsd ?? this.priceUsd,
      priceStatus: priceStatus ?? this.priceStatus,
      priceUpdatedAt: priceUpdatedAt ?? this.priceUpdatedAt,
      changePercent24h: changePercent24h ?? this.changePercent24h,
      decimals: decimals ?? this.decimals,
      imageUrl: imageUrl ?? this.imageUrl,
      coinGeckoId: coinGeckoId ?? this.coinGeckoId,
      isCertified: isCertified ?? this.isCertified,
      networkKey: networkKey ?? this.networkKey,
      tokenStandard: tokenStandard ?? this.tokenStandard,
      // PATCH: Preserve price source unless explicitly replaced.
      priceSource: priceSource ?? this.priceSource,
      // PATCH: Preserve liquidity unless explicitly replaced.
      liquidityUsd: liquidityUsd ?? this.liquidityUsd,
      // PATCH: Preserve DEX-only status unless explicitly replaced.
      isDexOnly: isDexOnly ?? this.isDexOnly,
    );
  }

  Decimal get balanceDecimal => ValueFormatter.decimalFromNum(balance);
  Decimal get valueUsdDecimal => ValueFormatter.decimalFromNum(valueUsd);
  Decimal get priceUsdDecimal => ValueFormatter.decimalFromNum(priceUsd);

  /// Best-effort per-token USD price.
  double get unitPriceUsd {
    return ValueFormatter.doubleFromDecimal(unitPriceUsdDecimal);
  }

  Decimal get unitPriceUsdDecimal {
    if (priceUsdDecimal > Decimal.zero) return priceUsdDecimal;
    if (balanceDecimal > Decimal.zero && valueUsdDecimal > Decimal.zero) {
      return ValueFormatter.divide(valueUsdDecimal, balanceDecimal);
    }
    return Decimal.zero;
  }

  /// Total USD value of the holdings.
  double get totalValueUsd {
    return ValueFormatter.doubleFromDecimal(totalValueUsdDecimal);
  }

  // PATCH: Used to render unavailable prices instead of a fake $0.00.
  bool get hasKnownPrice => unitPriceUsdDecimal > Decimal.zero;

  bool get hasProviderError => priceStatus == 'provider_error';

  // PATCH: Used by wallet/home rows to show a compact DEX badge.
  bool get isDexPriced {
    return isDexOnly ||
        priceSource == 'DexScreener' ||
        priceSource == 'PancakeSwapV2' ||
        priceSource == 'UniswapV3';
  }

  Decimal get totalValueUsdDecimal {
    final inferredValue = balanceDecimal * priceUsdDecimal;
    if (valueUsdDecimal > Decimal.zero) return valueUsdDecimal;
    if (inferredValue > Decimal.zero) return inferredValue;
    if (balanceDecimal > Decimal.zero && unitPriceUsdDecimal > Decimal.zero) {
      return balanceDecimal * unitPriceUsdDecimal;
    }
    return Decimal.zero;
  }

  /// Format balance with appropriate decimals
  String get formattedBalance {
    return ValueFormatter.formatCompactTokenAmount(
      balanceDecimal,
      symbol: symbol,
    );
  }

  /// Format USD value
  String get formattedValue {
    if (balanceDecimal > Decimal.zero &&
        valueUsdDecimal <= Decimal.zero &&
        !hasKnownPrice) {
      return r'$0';
    }
    return ValueFormatter.formatUsdValue(totalValueUsdDecimal);
  }

  /// Format per-token price for UI
  String get formattedPrice {
    if (!hasKnownPrice) return r'$0';
    return ValueFormatter.formatUsdPrice(unitPriceUsdDecimal);
  }

  /// Format percentage change
  String get formattedChange {
    final sign = changePercent24h >= 0 ? '+' : '';
    return '$sign${changePercent24h.toStringAsFixed(2)}%';
  }

  /// Check if token is gaining value
  bool get isPositiveChange => changePercent24h >= 0;
}
