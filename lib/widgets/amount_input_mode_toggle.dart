import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../utils/value_formatter.dart';

enum AmountInputMode { token, fiat }

class AmountInputModeToggle extends StatelessWidget {
  final AmountInputMode mode;
  final String tokenSymbol;
  final VoidCallback onToggle;
  final bool enabled;

  const AmountInputModeToggle({
    super.key,
    required this.mode,
    required this.tokenSymbol,
    required this.onToggle,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final primaryLabel = mode == AmountInputMode.token
        ? tokenSymbol
        : ValueFormatter.currencyCode;
    final secondaryLabel = mode == AmountInputMode.token
        ? ValueFormatter.currencyCode
        : tokenSymbol;
    final isDisabled = !enabled || tokenSymbol.isEmpty;

    return Opacity(
      opacity: isDisabled ? 0.4 : 1,
      child: GestureDetector(
        onTap: isDisabled ? null : onToggle,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 46),
                child: Text(
                  primaryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.swap_vert,
                size: 13,
                color: AppColors.accentRed.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 46),
                child: Text(
                  secondaryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
