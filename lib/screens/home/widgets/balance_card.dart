import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/value_formatter.dart';
import '../home_portfolio_metrics.dart';

/// Displays the wallet balance, eye-toggle, and history access.
class BalanceCard extends StatelessWidget {
  final String titleText;
  final String formattedBalance;
  final HomePortfolioMetrics portfolioMetrics;
  final String? statusText;
  final bool isBalanceVisible;
  final bool isLoadingBalances;
  final VoidCallback onToggleVisibility;
  final VoidCallback onHistoryTap;

  const BalanceCard({
    super.key,
    required this.titleText,
    required this.formattedBalance,
    required this.portfolioMetrics,
    this.statusText,
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
      padding: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: AppColors.balanceGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentRed.withValues(alpha: 0.14),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        titleText.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.82),
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onToggleVisibility,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            isBalanceVisible
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
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
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
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
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (statusText != null && statusText!.trim().isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusText!,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formattedBalance,
                      maxLines: 1,
                      style: GoogleFonts.outfit(
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_changeIcon(), size: 14, color: changeColor),
                      const SizedBox(width: 6),
                      Text(
                        _formatChangeText(),
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: changeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
