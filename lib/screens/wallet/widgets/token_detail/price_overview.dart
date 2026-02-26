import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';

class PriceOverview extends StatelessWidget {
  final String priceText;
  final String changeText;
  final bool isPositiveChange;
  final String holdingsText;

  const PriceOverview({
    super.key,
    required this.priceText,
    required this.changeText,
    required this.isPositiveChange,
    required this.holdingsText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(priceText, style: GoogleFonts.outfit(fontSize: 46, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              isPositiveChange ? Icons.trending_up : Icons.trending_down,
              size: 18,
              color: isPositiveChange ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 6),
            Text(
              changeText,
              style: GoogleFonts.outfit(color: isPositiveChange ? AppColors.success : AppColors.error),
            ),
            const SizedBox(width: 12),
            Text('Holdings: $holdingsText', style: GoogleFonts.outfit(color: Colors.white70)),
          ],
        ),
      ],
    );
  }
}
