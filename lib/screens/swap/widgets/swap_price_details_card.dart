import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';

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
      return '${platformFeePercent.toStringAsFixed(2)}% (~\$${platformFeeUsd.toStringAsFixed(2)})';
    }
    if (swapAmountUsd <= 0) return '--';
    final feeUsd = swapAmountUsd * (platformFeePercent / 100);
    return '${platformFeePercent.toStringAsFixed(2)}% (~\$${feeUsd.toStringAsFixed(2)})';
  }

  String _formatNetworkFee() {
    if (gaslessFeeCovered) {
      return 'Covered by Owllet';
    }
    // Try backend-provided USD first
    double usd = feeAmountUsd;
    // If backend didn't provide USD, compute from native amount × native price
    if (usd <= 0 && feeAmountNative > 0 && nativePriceUsd > 0) {
      usd = feeAmountNative * nativePriceUsd;
    }
    if (feeAmountNative > 0) {
      if (usd > 0) {
        return '~\$${usd.toStringAsFixed(2)} (${feeAmountNative.toStringAsFixed(6)} $nativeFeeSymbol)';
      }
      return '${feeAmountNative.toStringAsFixed(6)} $nativeFeeSymbol';
    }
    return '--';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDetailRow('Price', priceText),
        const SizedBox(height: 12),
        _buildDetailRow('Platform Fee', _formatFeeDisplay()),
        const SizedBox(height: 12),
        _buildDetailRow('Network Fee', _formatNetworkFee()),
        const SizedBox(height: 12),
        _buildDetailRow('To Receive', receiveText),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final isPrice = label == 'Price' && value.contains(priceSeparator);
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
            child: isPrice
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
