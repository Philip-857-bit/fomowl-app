import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
          color: (enabled && !isBusy)
              ? const Color(0xFFEA2A33)
              : const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(12),
          boxShadow: (enabled && !isBusy)
              ? [
                  const BoxShadow(
                    color: Color(0x4CEA2A33),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            isBusy ? l.loading : (label ?? l.swap),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: (enabled && !isBusy)
                  ? Colors.white
                  : const Color(0x66E2E2E2),
              height: 1.56,
            ),
          ),
        ),
      ),
    );
  }
}
