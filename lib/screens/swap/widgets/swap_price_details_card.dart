import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';

class SwapPriceDetailsCard extends StatelessWidget {
  final String priceText;
  final double slippage;
  final double feeAmount;
  final String feeSymbol;
  final String receiveText;
  final String priceSeparator;

  const SwapPriceDetailsCard({
    super.key,
    required this.priceText,
    required this.slippage,
    required this.feeAmount,
    required this.feeSymbol,
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
        _buildDetailRow('Network Fee', '~\$${feeAmount.toStringAsFixed(2)}'),
        const SizedBox(height: 12),
        _buildDetailRow('To Receive', receiveText),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final isPrice = label == 'Price' && value.contains(priceSeparator);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
        isPrice ? _buildPriceText(value) : Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
      ],
    );
  }

  Widget _buildPriceText(String text) {
    final parts = text.split(priceSeparator);
    if (parts.length == 2) {
      return Row(
        children: [
          Text('${parts[0]}$priceSeparator ', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
          Text(parts[1].trim(), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.success)),
        ],
      );
    }
    return Text(text, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white));
  }
}
