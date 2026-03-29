import 'package:decimal/decimal.dart';

class HomePortfolioMetrics {
  final Decimal totalBalanceUsd;
  final Decimal changeAmountUsd24h;
  final double changePercent24h;

  const HomePortfolioMetrics._({
    required this.totalBalanceUsd,
    required this.changeAmountUsd24h,
    required this.changePercent24h,
  });

  factory HomePortfolioMetrics({
    required Decimal totalBalanceUsd,
    required Decimal changeAmountUsd24h,
    required double changePercent24h,
  }) {
    return HomePortfolioMetrics._(
      totalBalanceUsd: totalBalanceUsd,
      changeAmountUsd24h: changeAmountUsd24h,
      changePercent24h: changePercent24h.isFinite ? changePercent24h : 0.0,
    );
  }

  factory HomePortfolioMetrics.zero() {
    return HomePortfolioMetrics(
      totalBalanceUsd: Decimal.zero,
      changeAmountUsd24h: Decimal.zero,
      changePercent24h: 0.0,
    );
  }

  bool get hasPositiveChange => changeAmountUsd24h > Decimal.zero;

  bool get hasNegativeChange => changeAmountUsd24h < Decimal.zero;

  bool get hasNeutralChange => changeAmountUsd24h == Decimal.zero;
}
