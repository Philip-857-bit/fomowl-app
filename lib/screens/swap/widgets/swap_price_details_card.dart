import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/value_formatter.dart';

class SwapPriceDetailsCard extends StatelessWidget {
  final String priceText;
  final double platformFeePercent;
  final double platformFeeUsd;
  final double feeAmountUsd;
  final double feeAmountNative;
  final String nativeFeeSymbol;
  final String receiveText;
  final String priceSeparator;
  final double swapAmountUsd;
  final bool gaslessFeeCovered;

  /// Native token price in USD from the frontend CoinGecko cache.
  /// Used to compute network fee in USD when the backend returns 0.
  final double nativePriceUsd;

  const SwapPriceDetailsCard({
    super.key,
    required this.priceText,
    required this.platformFeePercent,
    required this.platformFeeUsd,
    required this.feeAmountUsd,
    required this.feeAmountNative,
    required this.nativeFeeSymbol,
    required this.receiveText,
    this.priceSeparator = '->',
    this.swapAmountUsd = 0.0,
    this.nativePriceUsd = 0.0,
    this.gaslessFeeCovered = false,
  });

  String _formatFeeDisplay() {
    if (platformFeeUsd > 0) {
      return '${platformFeePercent.toStringAsFixed(2)}% (~${ValueFormatter.formatUsdValue(ValueFormatter.decimalFromNum(platformFeeUsd))})';
    }
    if (swapAmountUsd <= 0) return '--';
    final feeUsd = swapAmountUsd * (platformFeePercent / 100);
    return '${platformFeePercent.toStringAsFixed(2)}% (~${ValueFormatter.formatUsdValue(ValueFormatter.decimalFromNum(feeUsd))})';
  }

  String _formatNetworkFee() {
    // Try backend-provided USD first
    double usd = feeAmountUsd;
    // If backend didn't provide USD, compute from native amount × native price
    if (usd <= 0 && feeAmountNative > 0 && nativePriceUsd > 0) {
      usd = feeAmountNative * nativePriceUsd;
    }
    if (feeAmountNative > 0) {
      if (usd > 0) {
        return '~${ValueFormatter.formatUsdValue(ValueFormatter.decimalFromNum(usd))} (${feeAmountNative.toStringAsFixed(6)} $nativeFeeSymbol)';
      }
      return '${feeAmountNative.toStringAsFixed(6)} $nativeFeeSymbol';
    }
    return '--';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        _buildDetailRow(l.priceLabel, priceText, isPrice: true),
        const SizedBox(height: 12),
        _buildDetailRow(l.platformFeeLabel, _formatFeeDisplay()),
        const SizedBox(height: 12),
        _buildDetailRow(
          l.networkFeeLabel,
          gaslessFeeCovered ? l.coveredByOwllet : _formatNetworkFee(),
        ),
        const SizedBox(height: 12),
        _buildDetailRow(l.toReceiveLabel, receiveText),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isPrice = false}) {
    final priceRow = isPrice && value.contains(priceSeparator);
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Align(
            alignment: Alignment.centerRight,
            child: priceRow
                ? _buildPriceText(value)
                : Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceText(String text) {
    final parts = text.split(priceSeparator);
    if (parts.length == 2) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${parts[0]}$priceSeparator ',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            TextSpan(
              text: parts[1].trim(),
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
      );
    }
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    );
  }
}
