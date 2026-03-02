import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';

class AmountSummary extends StatelessWidget {
  final String amountText;
  final String symbol;
  final String title;

  const AmountSummary({
    super.key,
    required this.amountText,
    required this.symbol,
    this.title = 'AMOUNT TO SEND',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w500,
            color: AppColors.accentRed.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: amountText,
                style: GoogleFonts.outfit(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              TextSpan(
                text: ' $symbol',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentRed,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
