import 'dart:async';
import '../../widgets/bitcoin_capability_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../screens/home/home_screen.dart';
import '../../screens/swap/swap_screen.dart';
import '../../services/blockchain_service.dart';
import '../../models/chain.dart';
import '../discover/discover_screen.dart';
import '../mini_apps/mini_app_host_screen.dart';
import '../../services/runtime_config_service.dart';
import '../../services/wallet_service.dart';
import 'app_shell_bottom_navigation.dart';
import 'app_shell_controller.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  final RuntimeConfigService _runtimeConfig = RuntimeConfigService.instance;
  bool _appliedInitialArgs = false;
  bool _openingOwlletPay = false;
  int _walletRefreshRevision = 0;

  @override
  void initState() {
    super.initState();
    _runtimeConfig.addListener(_recoverFromDisabledFeature);
    unawaited(_migrateWalletVaults());
  }

  Future<void> _migrateWalletVaults() async {
    try {
      await WalletService().migrateWalletVaults();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some wallets could not be opened. Please try again.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _runtimeConfig.removeListener(_recoverFromDisabledFeature);
    super.dispose();
  }

  void _recoverFromDisabledFeature() {
    if (!mounted || _canOpenTradingScreen()) {
      return;
    }
    final controller = context.read<AppShellController>();
    if (controller.currentTab == AppShellTab.swap) {
      controller.selectTab(AppShellTab.wallet);
    }
  }

  void _selectTab(AppShellTab tab) {
    if (tab == AppShellTab.swap && !_canOpenTradingScreen()) {
      _showUnavailable(RuntimeFeature.swaps);
      return;
    }
    context.read<AppShellController>().selectTab(tab);
  }

  bool _canOpenTradingScreen() {
    final family = context.read<BlockchainService>().activeFamily;
    // Bitcoin's destination exposes Bridge only and enforces route/runtime
    // availability itself. Keep it reachable for network selection and review.
    if (family == ChainFamily.bitcoin) return true;
    return _runtimeConfig.snapshot.allowsTradingScreen(
      limitSupported: family == ChainFamily.evm || family == ChainFamily.solana,
    );
  }

  void _showUnavailable(RuntimeFeature feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_runtimeConfig.snapshot.unavailableMessage(feature)),
      ),
    );
  }

  Future<void> _openOwlletPay() async {
    if (context.read<BlockchainService>().activeFamily == ChainFamily.bitcoin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitcoin payments are not available yet.'),
        ),
      );
      return;
    }
    if (_openingOwlletPay) {
      return;
    }
    if (!_runtimeConfig.snapshot.allows(RuntimeFeature.miniApps)) {
      _showUnavailable(RuntimeFeature.miniApps);
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
      if (mounted) {
        // Home stays mounted inside IndexedStack while OwlletPay is open.
        // Invalidate the active-chain snapshot before triggering its live read.
        final blockchain = context.read<BlockchainService>();
        final wallet = blockchain.activeWalletAddress.trim();
        if (wallet.isNotEmpty) {
          await blockchain.requestTransactionBalanceRefresh(
            walletAddress: wallet,
            networkKey: blockchain.activeNetworkKey,
            family: 'transfer',
            operationReference:
                'owllet-pay-return-${DateTime.now().microsecondsSinceEpoch}',
          );
        }
        if (mounted) {
          setState(() => _walletRefreshRevision += 1);
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedInitialArgs) {
      return;
    }
    _appliedInitialArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    final initialIndex = switch (args) {
      int value => value,
      String value => int.tryParse(value),
      Map<String, dynamic> value => switch (value['tab']) {
        int tab => tab,
        String tab => int.tryParse(tab),
        _ => null,
      },
      _ => null,
    };
    final initialDiscoverUrl = switch (args) {
      Map<String, dynamic> value => value['discoverUrl']?.toString(),
      _ => null,
    };
    if (initialDiscoverUrl != null && initialDiscoverUrl.trim().isNotEmpty) {
      context.read<AppShellController>().openDiscoverUrl(initialDiscoverUrl);
    }
    if (initialIndex != null) {
      final tab = initialIndex >= 0 && initialIndex < AppShellTab.values.length
          ? AppShellTab.values[initialIndex]
          : null;
      if (tab != null && (tab != AppShellTab.swap || _canOpenTradingScreen())) {
        context.read<AppShellController>().selectTab(tab);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppShellController>();
    // The shell is the root route. Without this guard, the hardware back button
    // pops the shell off the Navigator, leaving an empty stack (black screen).
    // Standard Android behavior: back from a sub-tab returns to the first tab;
    // back from the first tab backgrounds the app instead of popping the route.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        // On the Discover tab, let the in-app browser go back (page history /
        // close page) before leaving the tab.
        if (controller.currentTab == AppShellTab.discover &&
            await controller.handleDiscoverBack()) {
          return;
        }
        if (controller.currentTab != AppShellTab.wallet) {
          controller.selectTab(AppShellTab.wallet);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: controller.currentIndex,
          children: [
            HomeScreen(
              showBottomNavigation: false,
              refreshRevision: _walletRefreshRevision,
            ),
            const SwapScreen(showBottomNavigation: false),
            BitcoinCapabilityGate(
              feature: 'DApps',
              builder: (_) => const DiscoverScreen(),
            ),
          ],
        ),
        bottomNavigationBar: AppShellBottomNavigation(
          bitcoinBridgeOnly:
              context.watch<BlockchainService>().activeFamily ==
              ChainFamily.bitcoin,
          currentTab: controller.currentTab,
          onTabTap: _selectTab,
          onPayTap: _openOwlletPay,
        ),
      ),
    );
  }
}
