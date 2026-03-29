import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/screens/home/home_portfolio_metrics_calculator.dart';
import 'package:fomowl_wallet/utils/value_formatter.dart';

void main() {
  group('HomePortfolioMetricsCalculator', () {
    test('aggregates mixed token gains and losses into a portfolio total', () {
      final metrics = HomePortfolioMetricsCalculator.fromTokens([
        const Token(
          symbol: 'AAA',
          name: 'Alpha',
          balance: 1,
          valueUsd: 100,
          changePercent24h: 25,
        ),
        const Token(
          symbol: 'BBB',
          name: 'Beta',
          balance: 1,
          valueUsd: 200,
          changePercent24h: -20,
        ),
      ]);

      expect(
        ValueFormatter.doubleFromDecimal(metrics.totalBalanceUsd),
        closeTo(300, 0.0001),
      );
      expect(
        ValueFormatter.doubleFromDecimal(metrics.changeAmountUsd24h),
        closeTo(-30, 0.0001),
      );
      expect(metrics.changePercent24h, closeTo(-9.090909, 0.0001));
    });

    test('returns zero metrics for an empty portfolio', () {
      final metrics = HomePortfolioMetricsCalculator.fromTokens(const []);

      expect(
        ValueFormatter.doubleFromDecimal(metrics.totalBalanceUsd),
        equals(0),
      );
      expect(
        ValueFormatter.doubleFromDecimal(metrics.changeAmountUsd24h),
        equals(0),
      );
      expect(metrics.changePercent24h, equals(0));
    });

    test('ignores zero-value tokens in the aggregate delta math', () {
      final metrics = HomePortfolioMetricsCalculator.fromTokens([
        const Token(
          symbol: 'ZERO',
          name: 'Zero',
          balance: 0,
          valueUsd: 0,
          changePercent24h: 99,
        ),
        const Token(
          symbol: 'LIVE',
          name: 'Live',
          balance: 1,
          valueUsd: 100,
          changePercent24h: 10,
        ),
      ]);

      expect(
        ValueFormatter.doubleFromDecimal(metrics.totalBalanceUsd),
        closeTo(100, 0.0001),
      );
      expect(
        ValueFormatter.doubleFromDecimal(metrics.changeAmountUsd24h),
        closeTo(9.090909, 0.0001),
      );
      expect(metrics.changePercent24h, closeTo(10, 0.0001));
    });

    test('treats unusable percent values as no-change instead of NaN', () {
      final metrics = HomePortfolioMetricsCalculator.fromTokens([
        const Token(
          symbol: 'BAD',
          name: 'Bad',
          balance: 1,
          valueUsd: 100,
          changePercent24h: double.infinity,
        ),
        const Token(
          symbol: 'WORSE',
          name: 'Worse',
          balance: 1,
          valueUsd: 50,
          changePercent24h: -150,
        ),
      ]);

      expect(metrics.changePercent24h.isFinite, isTrue);
      expect(
        ValueFormatter.doubleFromDecimal(metrics.changeAmountUsd24h),
        equals(0),
      );
      expect(metrics.changePercent24h, equals(0));
    });

    test('falls back to inferred token value when valueUsd is missing', () {
      final metrics = HomePortfolioMetricsCalculator.fromTokens([
        const Token(
          symbol: 'INF',
          name: 'Inferred',
          balance: 2,
          valueUsd: 0,
          priceUsd: 50,
          changePercent24h: 25,
        ),
      ]);

      expect(
        ValueFormatter.doubleFromDecimal(metrics.totalBalanceUsd),
        closeTo(100, 0.0001),
      );
      expect(
        ValueFormatter.doubleFromDecimal(metrics.changeAmountUsd24h),
        closeTo(20, 0.0001),
      );
      expect(metrics.changePercent24h, closeTo(25, 0.0001));
    });
  });
}
