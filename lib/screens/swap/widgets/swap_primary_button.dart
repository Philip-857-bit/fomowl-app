import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';

class SwapPrimaryButton extends StatelessWidget {
  final bool enabled;
  final bool isBusy;
  final VoidCallback onPressed;

  const SwapPrimaryButton({
    super.key,
    required this.enabled,
    required this.isBusy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.primaryGradient : null,
          color: enabled ? null : AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            isBusy ? 'Processing...' : 'Swap Now',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
