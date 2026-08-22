import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_chain_theme.dart';

class QuickActionsRow extends StatelessWidget {
  final VoidCallback onReceive;
  final VoidCallback onSend;
  final VoidCallback? onWithdraw;

  const QuickActionsRow({
    super.key,
    required this.onReceive,
    required this.onSend,
    this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 360 ? 28.0 : 40.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
          if (onWithdraw != null)
            _QuickActionButton(
              icon: Icons.account_balance_rounded,
              label: l.withdraw,
              onTap: onWithdraw!,
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

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.6, sigmaY: 10.6),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0x33424242),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: theme.accentColor, size: 24),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: const Color(0xFFA5A5A5),
            ),
          ),
        ],
      ),
    );
  }
}
