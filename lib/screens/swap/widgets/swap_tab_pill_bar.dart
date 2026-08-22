import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_chain_theme.dart';

enum SwapTab { swap, limit, bridge }

class SwapTabPillBar extends StatelessWidget {
  final SwapTab activeTab;
  final ValueChanged<SwapTab> onTabSelected;
  final bool isLimitSupported;

  const SwapTabPillBar({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
    this.isLimitSupported = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.chainTheme;

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF151C24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          _TabPill(
            label: 'SWAP',
            isActive: activeTab == SwapTab.swap,
            onTap: () => onTabSelected(SwapTab.swap),
            activeColor: theme.accentColor,
          ),
          _TabPill(
            label: 'LIMIT',
            isActive: activeTab == SwapTab.limit,
            onTap: isLimitSupported ? () => onTabSelected(SwapTab.limit) : null,
            activeColor: theme.accentColor,
            isDisabled: !isLimitSupported,
          ),
          _TabPill(
            label: 'BRIDGE',
            isActive: activeTab == SwapTab.bridge,
            onTap: () => onTabSelected(SwapTab.bridge),
            activeColor: theme.accentColor,
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  final Color activeColor;
  final bool isDisabled;

  const _TabPill({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.activeColor,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2A333D) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: isActive
                ? Border.all(
                    color: activeColor.withValues(alpha: 0.4),
                    width: 1,
                  )
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: isDisabled
                  ? Colors.white.withValues(alpha: 0.25)
                  : (isActive ? Colors.white : const Color(0xFFA1A1A1)),
            ),
          ),
        ),
      ),
    );
  }
}
