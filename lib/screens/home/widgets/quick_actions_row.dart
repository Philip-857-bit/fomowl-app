import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_chain_theme.dart';

class QuickActionsRow extends StatelessWidget {
  final VoidCallback onReceive;
  final VoidCallback onSend;
  final VoidCallback? onWithdraw;
  final VoidCallback? onBurst;

  const QuickActionsRow({
    super.key,
    required this.onReceive,
    required this.onSend,
    this.onWithdraw,
    this.onBurst,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          if (onWithdraw != null)
            _QuickActionButton(
              icon: Icons.account_balance_rounded,
              label: l.withdraw,
              onTap: onWithdraw!,
            ),
          if (onBurst != null)
            _QuickActionButton(
              icon: Icons.rocket_launch_outlined,
              label: 'Burst',
              onTap: onBurst!,
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
    final theme = context.chainTheme;
    final isClassic = theme.id == 'fomowl_signature';
    final iconColor = isClassic ? Colors.white : theme.accentColor;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: const Color(0xFF888888),
            ),
          ),
        ],
      ),
    );
  }
}
