import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import 'app_shell_controller.dart';

class AppShellBottomNavigation extends StatelessWidget {
  const AppShellBottomNavigation({
    super.key,
    required this.currentTab,
    required this.onTap,
  });

  final AppShellTab currentTab;
  final ValueChanged<AppShellTab> onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.navBackground.withValues(alpha: 0.78),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ShellNavItem(
                    icon: Icons.account_balance_wallet_outlined,
                    activeIcon: Icons.account_balance_wallet_rounded,
                    label: 'Wallet',
                    selected: currentTab == AppShellTab.wallet,
                    onTap: () => onTap(AppShellTab.wallet),
                  ),
                  _ShellNavItem(
                    icon: Icons.swap_horiz_outlined,
                    activeIcon: Icons.swap_horiz_rounded,
                    label: 'Swap',
                    selected: currentTab == AppShellTab.swap,
                    onTap: () => onTap(AppShellTab.swap),
                  ),
                  _ShellNavItem(
                    icon: Icons.explore_outlined,
                    activeIcon: Icons.explore_rounded,
                    label: 'Discover',
                    selected: currentTab == AppShellTab.discover,
                    onTap: () => onTap(AppShellTab.discover),
                  ),
                  _ShellNavItem(
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings_rounded,
                    label: 'Settings',
                    selected: currentTab == AppShellTab.settings,
                    onTap: () => onTap(AppShellTab.settings),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellNavItem extends StatelessWidget {
  const _ShellNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryAccent.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? activeIcon : icon,
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.58),
                size: 22,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.52),
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
