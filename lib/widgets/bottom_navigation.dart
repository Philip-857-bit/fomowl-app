import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'floating_navigation_pill.dart';

/// Shared Bottom Navigation Bar
/// 4 destinations: Wallet, Swap, Discover, Settings.
class BottomNavBar extends StatelessWidget {
  static const int _discoverNavigationIndex = -1;

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
    return FloatingNavigationPill(
      destinations: [
        FloatingNavigationDestinationData(
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet_rounded,
          label: l.wallet,
          selected: currentIndex == 0,
          onTap: () => onTap(0),
        ),
        FloatingNavigationDestinationData(
          icon: Icons.swap_horiz_outlined,
          selectedIcon: Icons.swap_horiz_rounded,
          label: l.swap,
          selected: currentIndex == 1,
          onTap: () => onTap(1),
        ),
        FloatingNavigationDestinationData(
          icon: Icons.explore_outlined,
          selectedIcon: Icons.explore_rounded,
          label: l.discoverBrowserFallbackTitle,
          selected: currentIndex == _discoverNavigationIndex,
          onTap: () => onTap(_discoverNavigationIndex),
        ),
        FloatingNavigationDestinationData(
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings_rounded,
          label: l.settings,
          selected: currentIndex == 2,
          onTap: () => onTap(2),
        ),
      ],
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
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/shell',
          (route) => false,
          arguments: 0,
        );
        break;
      case 1: // Swap
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/shell',
          (route) => false,
          arguments: 1,
        );
        break;
      case 2: // Me
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/shell',
          (route) => false,
          arguments: 3,
        );
        break;
      case _discoverNavigationIndex: // Discover
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/shell',
          (route) => false,
          arguments: 2,
        );
        break;
    }
  }
}
