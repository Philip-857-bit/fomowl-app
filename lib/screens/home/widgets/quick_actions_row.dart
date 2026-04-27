import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class QuickActionsRow extends StatelessWidget {
  final VoidCallback onReceive;
  final VoidCallback onSend;
  final VoidCallback? onSwap;

  const QuickActionsRow({
    super.key,
    required this.onReceive,
    required this.onSend,
    this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _QuickActionButton(
            icon: Icons.arrow_downward_rounded,
            label: l.receive,
            onTap: onReceive,
          ),
          _QuickActionButton(
            icon: Icons.arrow_upward_rounded,
            label: l.send,
            onTap: onSend,
          ),
          if (onSwap != null)
            _QuickActionButton(
              icon: Icons.swap_horiz_rounded,
              label: l.swap,
              onTap: onSwap!,
            ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.darkRed.withValues(alpha: 0.4),
              ),
            ),
            child: Icon(icon, color: AppColors.accentRed, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
