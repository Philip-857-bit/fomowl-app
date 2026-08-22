import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_chain_theme.dart';

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
    final theme = context.chainTheme;
    final isActive = enabled && !isBusy;

    return GestureDetector(
      onTap: isActive ? onPressed : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isActive ? theme.buttonGradient : null,
          color: isActive ? null : const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: theme.accentColor.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            isBusy ? l.loading : (label ?? l.swap),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : const Color(0x66E2E2E2),
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
