import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';

/// Shared Bottom Navigation Bar
/// 3 tabs: Wallet, Swap, Me
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.navBackground.withValues(alpha: 0.75),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    Icons.account_balance_wallet_rounded,
                    l.wallet,
                    0,
                  ),
                  _buildNavItem(Icons.swap_horiz_rounded, l.swap, 1),
                  _buildNavItem(Icons.settings_outlined, l.settings, 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = currentIndex == index;
    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.accentRed
                  : Colors.white.withValues(alpha: 0.5),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: isSelected
                    ? AppColors.accentRed
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Standard navigation handler
  static void handleNavigation(
    BuildContext context,
    int index,
    int currentScreenIndex,
  ) {
    if (index == currentScreenIndex) return;

    switch (index) {
      case 0: // Wallet
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        break;
      case 1: // Swap
        if (currentScreenIndex == 0) {
          Navigator.pushNamed(context, '/swap');
        } else {
          Navigator.pushReplacementNamed(context, '/swap');
        }
        break;
      case 2: // Me
        if (currentScreenIndex == 0) {
          Navigator.pushNamed(context, '/profile');
        } else {
          Navigator.pushReplacementNamed(context, '/profile');
        }
        break;
    }
  }
}
