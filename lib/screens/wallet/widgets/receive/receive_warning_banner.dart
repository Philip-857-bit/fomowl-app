import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';

class ReceiveWarningBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color borderColor;

  const ReceiveWarningBanner({
    super.key,
    required this.message,
    this.icon = Icons.warning_amber_rounded,
    this.iconColor = AppColors.accentRed,
    this.borderColor = AppColors.accentRed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.white.withValues(alpha: 0.8), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
