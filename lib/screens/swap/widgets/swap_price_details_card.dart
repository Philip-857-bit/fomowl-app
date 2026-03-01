import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';

class SwapPriceDetailsCard extends StatelessWidget {
  final String priceText;
  final double slippage;
  final double feeAmountUsd;
  final double feeAmountNative;
  final String nativeFeeSymbol;
  final String receiveText;
  final String priceSeparator;

  const SwapPriceDetailsCard({
    super.key,
    required this.priceText,
    required this.slippage,
    required this.feeAmountUsd,
    required this.feeAmountNative,
    required this.nativeFeeSymbol,
    required this.receiveText,
    this.priceSeparator = '->',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDetailRow('Price', priceText),
        const SizedBox(height: 12),
        _buildDetailRow('Slippage', '${slippage.toStringAsFixed(1)}%'),
        const SizedBox(height: 12),
        _buildDetailRow(
          'Network Fee',
          '~\$${feeAmountUsd.toStringAsFixed(2)} (${feeAmountNative.toStringAsFixed(6)} $nativeFeeSymbol)',
        ),
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
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
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
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
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
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
            ),
            TextSpan(
              text: parts[1].trim(),
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.success),
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
      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
    );
  }
}
