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
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

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
    this.primaryActionLabel,
    this.onPrimaryAction,
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
    final showPrimaryAction =
        onPrimaryAction != null &&
        primaryActionLabel != null &&
        primaryActionLabel!.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: AppColors.balanceGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentRed.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 15, 20, showPrimaryAction ? 20 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  titleText.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.78),
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onToggleVisibility,
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(
                        isBalanceVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 17,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
                if (isLoadingBalances) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 11,
                    height: 11,
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
                      horizontal: 15,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          l.history,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.94),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (statusText != null && statusText!.trim().isNotEmpty) ...[
              Text(
                statusText!,
                style: GoogleFonts.outfit(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 11),
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
                    fontSize: 41,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_changeIcon(), size: 16, color: changeColor),
                const SizedBox(width: 5),
                Text(
                  _formatChangeText(),
                  style: GoogleFonts.outfit(
                    fontSize: 13.8,
                    fontWeight: FontWeight.w600,
                    color: changeColor,
                  ),
                ),
              ],
            ),
            if (showPrimaryAction) ...[
              const SizedBox(height: 22),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPrimaryAction,
                  borderRadius: BorderRadius.circular(999),
                  child: Ink(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_circle_outline_rounded,
                          color: Colors.black,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          primaryActionLabel!,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
