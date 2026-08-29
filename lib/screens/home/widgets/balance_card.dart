import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
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
  final VoidCallback onAddFunds;

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
    required this.onAddFunds,
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
    final addFundsLabel = AppLocalizations.of(context).addFunds;
    final changeColor = _changeColor();
    final isClassicTheme = theme.id == 'fomowl_signature';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isClassicTheme ? const Color(0xFF1C1C1C) : null,
        gradient: isClassicTheme ? null : theme.balanceCardGradient,
        borderRadius: BorderRadius.circular(isClassicTheme ? 16 : 20),
        border: Border.all(
          color: isClassicTheme
              ? Colors.white.withValues(alpha: 0.05)
              : theme.accentColor.withValues(alpha: 0.42),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isClassicTheme
                ? Colors.black.withValues(alpha: 0.25)
                : theme.accentColor.withValues(alpha: 0.12),
            blurRadius: isClassicTheme ? 16 : 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  titleText.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF888888),
                    height: 1.4,
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
                    size: 14,
                    color: const Color(0xFF888888),
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
                    'HISTORY',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF888888),
                      height: 1.4,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formattedBalance,
                      maxLines: 1,
                      style: GoogleFonts.inter(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: Colors.white,
                        letterSpacing: -0.025,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  label: addFundsLabel,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const ValueKey('balance-add-funds'),
                      onTap: onAddFunds,
                      borderRadius: BorderRadius.circular(999),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA2A33),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEA2A33).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          addFundsLabel,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(_changeIcon(), size: 12, color: changeColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _formatChangeText(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: changeColor,
                    ),
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
