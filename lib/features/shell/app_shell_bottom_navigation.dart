import 'package:flutter/material.dart';

import '../../widgets/floating_navigation_pill.dart';
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
    return FloatingNavigationPill(
      destinations: [
        FloatingNavigationDestinationData(
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet_rounded,
          label: 'Wallet',
          selected: currentTab == AppShellTab.wallet,
          onTap: () => onTap(AppShellTab.wallet),
        ),
        FloatingNavigationDestinationData(
          icon: Icons.swap_horiz_outlined,
          selectedIcon: Icons.swap_horiz_rounded,
          label: 'Swap',
          selected: currentTab == AppShellTab.swap,
          onTap: () => onTap(AppShellTab.swap),
        ),
        FloatingNavigationDestinationData(
          icon: Icons.explore_outlined,
          selectedIcon: Icons.explore_rounded,
          label: 'Discover',
          selected: currentTab == AppShellTab.discover,
          onTap: () => onTap(AppShellTab.discover),
        ),
        FloatingNavigationDestinationData(
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings_rounded,
          label: 'Settings',
          selected: currentTab == AppShellTab.settings,
          onTap: () => onTap(AppShellTab.settings),
        ),
      ],
    );
  }
}
