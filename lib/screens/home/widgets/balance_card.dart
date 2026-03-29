import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/value_formatter.dart';
import '../home_portfolio_metrics.dart';

/// Displays the wallet balance, eye-toggle, and history access.
class BalanceCard extends StatelessWidget {
  final String formattedBalance;
  final HomePortfolioMetrics portfolioMetrics;
  final bool isBalanceVisible;
  final bool isLoadingBalances;
  final VoidCallback onToggleVisibility;
  final VoidCallback onHistoryTap;

  const BalanceCard({
    super.key,
    required this.formattedBalance,
    required this.portfolioMetrics,
    required this.isBalanceVisible,
    required this.isLoadingBalances,
    required this.onToggleVisibility,
    required this.onHistoryTap,
  });

  Color _changeColor() {
    if (portfolioMetrics.hasPositiveChange) {
      return AppColors.success;
    }
    if (portfolioMetrics.hasNegativeChange) {
      return AppColors.accentRed;
    }
    return Colors.white.withValues(alpha: 0.72);
  }

  IconData _changeIcon() {
    if (portfolioMetrics.hasPositiveChange) {
      return Icons.trending_up;
    }
    if (portfolioMetrics.hasNegativeChange) {
      return Icons.trending_down;
    }
    return Icons.remove;
  }

  String _formatChangeText() {
    if (!isBalanceVisible) {
      return '****';
    }

    final amount = portfolioMetrics.changeAmountUsd24h;
    final absoluteAmount = amount < Decimal.zero ? -amount : amount;
    final formattedAmount = ValueFormatter.formatCurrencyWithGrouping(
      absoluteAmount,
    );

    if (portfolioMetrics.hasPositiveChange) {
      return '+$formattedAmount (+${portfolioMetrics.changePercent24h.toStringAsFixed(2)}%)';
    }
    if (portfolioMetrics.hasNegativeChange) {
      return '-$formattedAmount (${portfolioMetrics.changePercent24h.toStringAsFixed(2)}%)';
    }
    return '$formattedAmount (${portfolioMetrics.changePercent24h.toStringAsFixed(2)}%)';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final changeColor = _changeColor();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        gradient: AppColors.balanceGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l.availableBalance,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onToggleVisibility,
                      child: Icon(
                        isBalanceVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    if (isLoadingBalances) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ],
                    const Spacer(),
                    GestureDetector(
                      onTap: onHistoryTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              l.history,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 10,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  formattedBalance,
                  style: GoogleFonts.outfit(
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(_changeIcon(), size: 14, color: changeColor),
                    const SizedBox(width: 4),
                    Text(
                      _formatChangeText(),
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: changeColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
