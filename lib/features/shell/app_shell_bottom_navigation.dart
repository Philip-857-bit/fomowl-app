import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/floating_navigation_pill.dart';
import 'app_shell_controller.dart';

class AppShellBottomNavigation extends StatelessWidget {
  const AppShellBottomNavigation({
    super.key,
    required this.currentTab,
    required this.onTabTap,
    required this.onPayTap,
  });

  final AppShellTab currentTab;
  final ValueChanged<AppShellTab> onTabTap;
  final VoidCallback onPayTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FloatingNavigationPill(
      destinations: [
        FloatingNavigationDestinationData(
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet_rounded,
          label: l.wallet,
          selected: currentTab == AppShellTab.wallet,
          onTap: () => onTabTap(AppShellTab.wallet),
        ),
        FloatingNavigationDestinationData(
          icon: Icons.swap_horiz_outlined,
          selectedIcon: Icons.swap_horiz_rounded,
          label: l.swap,
          selected: currentTab == AppShellTab.swap,
          onTap: () => onTabTap(AppShellTab.swap),
        ),
        FloatingNavigationActionData(
          icon: Icons.payments_rounded,
          label: l.pay,
          onTap: onPayTap,
        ),
        FloatingNavigationDestinationData(
          icon: Icons.explore_outlined,
          selectedIcon: Icons.explore_rounded,
          label: l.discoverBrowserFallbackTitle,
          selected: currentTab == AppShellTab.discover,
          onTap: () => onTabTap(AppShellTab.discover),
        ),
      ],
    );
  }
}
