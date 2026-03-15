import 'package:decimal/decimal.dart';

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
  final double changePercent24h;
  final int decimals;
  final String? imageUrl;
  final String? coinGeckoId;
  final bool isCertified;

  const Token({
    required this.symbol,
    required this.name,
    this.contractAddress,
    required this.balance,
    required this.valueUsd,
    this.priceUsd = 0.0,
    required this.changePercent24h,
    this.decimals = 18,
    this.imageUrl,
    this.coinGeckoId,
    this.isCertified = false,
  });

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
    return ValueFormatter.formatUsdValue(totalValueUsdDecimal);
  }

  /// Format per-token price for UI
  String get formattedPrice {
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
