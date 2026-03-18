import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class SwapPrimaryButton extends StatelessWidget {
  final bool enabled;
  final bool isBusy;
  final VoidCallback onPressed;
  final String? label;

  const SwapPrimaryButton({
    super.key,
    required this.enabled,
    required this.isBusy,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GestureDetector(
      onTap: (enabled && !isBusy) ? onPressed : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: (enabled && !isBusy) ? AppColors.primaryGradient : null,
          color: (enabled && !isBusy) ? null : AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            isBusy ? l.loading : (label ?? l.swap),
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: (enabled && !isBusy)
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
