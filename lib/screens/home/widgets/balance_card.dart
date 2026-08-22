import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../theme/app_chain_theme.dart';
import '../../../utils/value_formatter.dart';
import '../home_portfolio_metrics.dart';

/// Displays the wallet balance, eye-toggle, dynamic chain gradient, and History access.
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
      return Icons.arrow_upward_rounded;
    }
    if (portfolioMetrics.hasNegativeChange) {
      return Icons.arrow_downward_rounded;
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
    final theme = context.chainTheme;
    final changeColor = _changeColor();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      constraints: const BoxConstraints(minHeight: 140),
      decoration: BoxDecoration(
        gradient: theme.balanceCardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.accentColor.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.accentColor.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  titleText.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.6,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onToggleVisibility,
                  child: Icon(
                    isBalanceVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.8),
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
                  child: Text(
                    'History',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.6,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (statusText != null && statusText!.trim().isNotEmpty) ...[
              Text(
                statusText!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 4),
            ],
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formattedBalance,
                  maxLines: 1,
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: Colors.white,
                    letterSpacing: -0.75,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(_changeIcon(), size: 13, color: changeColor),
                const SizedBox(width: 4),
                Text(
                  _formatChangeText(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: changeColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
