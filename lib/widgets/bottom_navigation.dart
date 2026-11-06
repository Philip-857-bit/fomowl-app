import 'package:flutter/material.dart';

import '../features/mini_apps/mini_app_host_screen.dart';
import '../features/shell/app_shell_controller.dart';
import '../l10n/app_localizations.dart';
import 'floating_navigation_pill.dart';

/// Legacy wrapper used by standalone screens.
///
/// Wallet, Swap, and Discover are destinations. Pay is an action that opens a
/// full-screen mini app and therefore never has a selected state.
class BottomNavBar extends StatefulWidget {
  const BottomNavBar({
    super.key,
    required this.currentTab,
    this.bitcoinBridgeOnly = false,
    this.onCurrentTabTap,
  });

  final AppShellTab? currentTab;
  final bool bitcoinBridgeOnly;
  final VoidCallback? onCurrentTabTap;

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  bool _openingOwlletPay = false;

  void _openTab(AppShellTab tab) {
    if (widget.currentTab == tab) {
      widget.onCurrentTabTap?.call();
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/shell',
      (route) => false,
      arguments: tab.index,
    );
  }

  Future<void> _openOwlletPay() async {
    if (_openingOwlletPay) {
      return;
    }
    _openingOwlletPay = true;
    try {
      await Navigator.of(context).pushNamed(
        '/owllet-pay',
        arguments: const MiniAppHostArguments(
          miniAppId: 'owllet_pay',
          launchSource: 'bottom_nav_pay',
        ),
      );
    } finally {
      _openingOwlletPay = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FloatingNavigationPill(
      destinations: [
        FloatingNavigationDestinationData(
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet_rounded,
          label: l.wallet,
          selected: widget.currentTab == AppShellTab.wallet,
          onTap: () => _openTab(AppShellTab.wallet),
        ),
        FloatingNavigationDestinationData(
          icon: Icons.swap_horiz_outlined,
          selectedIcon: Icons.swap_horiz_rounded,
          label: widget.bitcoinBridgeOnly ? 'Bridge' : l.swap,
          selected: widget.currentTab == AppShellTab.swap,
          onTap: () => _openTab(AppShellTab.swap),
        ),
        FloatingNavigationActionData(
          icon: Icons.payments_rounded,
          label: l.pay,
          onTap: _openOwlletPay,
        ),
        FloatingNavigationDestinationData(
          icon: Icons.explore_outlined,
          selectedIcon: Icons.explore_rounded,
          label: l.discoverBrowserFallbackTitle,
          selected: widget.currentTab == AppShellTab.discover,
          onTap: () => _openTab(AppShellTab.discover),
        ),
      ],
    );
  }
}
