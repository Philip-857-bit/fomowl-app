import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/constants/app_colors.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/screens/home/home_portfolio_metrics.dart';
import 'package:fomowl_wallet/screens/home/widgets/balance_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpCard(
    WidgetTester tester, {
    required HomePortfolioMetrics metrics,
    bool isBalanceVisible = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BalanceCard(
            formattedBalance: '\$222.62',
            portfolioMetrics: metrics,
            isBalanceVisible: isBalanceVisible,
            isLoadingBalances: false,
            onToggleVisibility: () {},
            onHistoryTap: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('renders positive portfolio change', (tester) async {
    await pumpCard(
      tester,
      metrics: HomePortfolioMetrics(
        totalBalanceUsd: Decimal.parse('222.62'),
        changeAmountUsd24h: Decimal.parse('12.34'),
        changePercent24h: 5.67,
      ),
    );

    expect(find.text('+\$12.34 (+5.67%)'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up), findsOneWidget);

    final textWidget = tester.widget<Text>(find.text('+\$12.34 (+5.67%)'));
    expect(textWidget.style?.color, AppColors.success);
  });

  testWidgets('renders negative portfolio change', (tester) async {
    await pumpCard(
      tester,
      metrics: HomePortfolioMetrics(
        totalBalanceUsd: Decimal.parse('222.62'),
        changeAmountUsd24h: Decimal.parse('-3.20'),
        changePercent24h: -1.25,
      ),
    );

    expect(find.text('-\$3.20 (-1.25%)'), findsOneWidget);
    expect(find.byIcon(Icons.trending_down), findsOneWidget);

    final textWidget = tester.widget<Text>(find.text('-\$3.20 (-1.25%)'));
    expect(textWidget.style?.color, AppColors.accentRed);
  });

  testWidgets('masks the portfolio change when balance is hidden', (
    tester,
  ) async {
    await pumpCard(
      tester,
      metrics: HomePortfolioMetrics(
        totalBalanceUsd: Decimal.parse('222.62'),
        changeAmountUsd24h: Decimal.parse('12.34'),
        changePercent24h: 5.67,
      ),
      isBalanceVisible: false,
    );

    expect(find.text('****'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up), findsOneWidget);
  });

  testWidgets('renders neutral portfolio change without profit styling', (
    tester,
  ) async {
    await pumpCard(
      tester,
      metrics: HomePortfolioMetrics(
        totalBalanceUsd: Decimal.parse('222.62'),
        changeAmountUsd24h: Decimal.zero,
        changePercent24h: 0,
      ),
    );

    expect(find.text('\$0.00 (0.00%)'), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);

    final textWidget = tester.widget<Text>(find.text('\$0.00 (0.00%)'));
    expect(textWidget.style?.color, Colors.white.withValues(alpha: 0.72));
  });
}
