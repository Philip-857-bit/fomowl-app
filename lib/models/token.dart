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
  });

  /// Best-effort per-token USD price.
  double get unitPriceUsd {
    if (priceUsd > 0) return priceUsd;
    if (balance > 0 && valueUsd > 0) {
      return valueUsd / balance;
    }
    return 0.0;
  }

  /// Total USD value of the holdings.
  double get totalValueUsd {
    final inferredValue = balance * priceUsd;
    if (valueUsd > 0) return valueUsd;
    if (inferredValue > 0) return inferredValue;
    if (balance > 0 && unitPriceUsd > 0) {
      return balance * unitPriceUsd;
    }
    return 0.0;
  }

  /// Format balance with appropriate decimals
  String get formattedBalance {
    if (balance >= 1000000000) {
      return '${(balance / 1000000000).toStringAsFixed(2)}B $symbol';
    } else if (balance >= 1000000) {
      return '${(balance / 1000000).toStringAsFixed(2)}M $symbol';
    } else if (balance >= 1000) {
      return '${(balance / 1000).toStringAsFixed(2)}K $symbol';
    } else if (balance >= 1) {
      return '${balance.toStringAsFixed(2)} $symbol';
    } else {
      return '${balance.toStringAsFixed(6)} $symbol';
    }
  }

  /// Format USD value
  String get formattedValue {
    final usd = totalValueUsd;
    if (usd >= 1000000) {
      return '\$${(usd / 1000000).toStringAsFixed(2)}M';
    } else if (usd >= 1000) {
      return '\$${(usd / 1000).toStringAsFixed(2)}K';
    } else {
      return '\$${usd.toStringAsFixed(2)}';
    }
  }

  /// Format per-token price for UI
  String get formattedPrice {
    final price = unitPriceUsd;
    if (price >= 1000) {
      return '\$${price.toStringAsFixed(0)}';
    } else if (price >= 1) {
      return '\$${price.toStringAsFixed(2)}';
    } else if (price == 0) {
      return '\$0.00';
    } else {
      return '\$${price.toStringAsFixed(6)}';
    }
  }

  /// Format percentage change
  String get formattedChange {
    final sign = changePercent24h >= 0 ? '+' : '';
    return '$sign${changePercent24h.toStringAsFixed(2)}%';
  }

  /// Check if token is gaining value
  bool get isPositiveChange => changePercent24h >= 0;
}
