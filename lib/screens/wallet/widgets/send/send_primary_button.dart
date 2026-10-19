import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class SendPrimaryButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const SendPrimaryButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentRed.withValues(alpha: 0.28),
              blurRadius: 20,
              spreadRadius: 1,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  key: const Key('send-preparing-indicator'),
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textPrimary,
                    semanticsLabel: AppLocalizations.of(context).loading,
                  ),
                )
              : Text(
                  'Send',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}
