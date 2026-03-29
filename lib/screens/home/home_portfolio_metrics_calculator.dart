import 'package:decimal/decimal.dart';

import '../../models/token.dart';
import '../../utils/value_formatter.dart';
import 'home_portfolio_metrics.dart';

class HomePortfolioMetricsCalculator {
  const HomePortfolioMetricsCalculator._();

  static HomePortfolioMetrics fromTokens(List<Token> tokens) {
    var totalCurrentValue = Decimal.zero;
    var totalPreviousValue = Decimal.zero;

    for (final token in tokens) {
      final currentValue = token.totalValueUsdDecimal;
      totalCurrentValue += currentValue;
      totalPreviousValue += _estimatePreviousValue(
        currentValue: currentValue,
        changePercent24h: token.changePercent24h,
      );
    }

    final changeAmount = totalCurrentValue - totalPreviousValue;
    final changePercent = totalPreviousValue > Decimal.zero
        ? (ValueFormatter.doubleFromDecimal(changeAmount) /
                  ValueFormatter.doubleFromDecimal(totalPreviousValue)) *
              100
        : 0.0;

    return HomePortfolioMetrics(
      totalBalanceUsd: totalCurrentValue,
      changeAmountUsd24h: changeAmount,
      changePercent24h: changePercent,
    );
  }

  static Decimal _estimatePreviousValue({
    required Decimal currentValue,
    required double changePercent24h,
  }) {
    if (currentValue <= Decimal.zero) {
      return currentValue;
    }

    final factor = 1 + (changePercent24h / 100);
    if (!factor.isFinite || factor <= 0) {
      return currentValue;
    }

    final factorDecimal = ValueFormatter.decimalFromNum(factor);
    if (factorDecimal <= Decimal.zero) {
      return currentValue;
    }

    return ValueFormatter.divide(currentValue, factorDecimal);
  }
}
