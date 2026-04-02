import 'package:decimal/decimal.dart';

import '../../models/chain.dart';
import '../../models/token.dart';
import 'home_portfolio_metrics.dart';
import 'home_portfolio_metrics_calculator.dart';

class HomePortfolioSection {
  const HomePortfolioSection({required this.chain, required this.tokens});

  final EvmChain chain;
  final List<Token> tokens;

  Decimal get totalBalanceUsd => tokens.fold(
    Decimal.zero,
    (sum, token) => sum + token.totalValueUsdDecimal,
  );
}

class HomePortfolioData {
  const HomePortfolioData({required this.sections, required this.metrics});

  final List<HomePortfolioSection> sections;
  final HomePortfolioMetrics metrics;

  factory HomePortfolioData.empty() {
    return HomePortfolioData(
      sections: const [],
      metrics: HomePortfolioMetrics.zero(),
    );
  }

  factory HomePortfolioData.fromSections(List<HomePortfolioSection> sections) {
    final allTokens = sections.expand((section) => section.tokens).toList();
    return HomePortfolioData(
      sections: sections,
      metrics: HomePortfolioMetricsCalculator.fromTokens(allTokens),
    );
  }
}
