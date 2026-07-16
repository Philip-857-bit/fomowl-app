import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:fomowl_wallet/constants/app_colors.dart';
import 'package:fomowl_wallet/features/discover/browser/browser_session_controller.dart';
import 'package:fomowl_wallet/features/discover/browser/widgets/discover_browser_view.dart';
import 'package:fomowl_wallet/features/discover/provider/dapp_provider_bridge.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/rpc_service.dart';

class DiscoverBrowserTestHarness extends StatelessWidget {
  const DiscoverBrowserTestHarness({
    super.key,
    required this.sessionController,
    required this.providerBridge,
    required this.blockchainService,
    required this.rpcService,
    this.onClose,
    this.tabCount = 1,
    this.onShowTabs,
  });

  final BrowserSessionController sessionController;
  final DappProviderBridge providerBridge;
  final BlockchainService blockchainService;
  final RpcService rpcService;
  final VoidCallback? onClose;
  final int tabCount;
  final VoidCallback? onShowTabs;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BlockchainService>.value(
          value: blockchainService,
        ),
        ChangeNotifierProvider<RpcService>.value(value: rpcService),
      ],
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: DiscoverBrowserView(
            sessionController: sessionController,
            providerBridge: providerBridge,
            onClose: onClose ?? () {},
            tabCount: tabCount,
            onShowTabs: onShowTabs ?? () {},
          ),
        ),
      ),
    );
  }
}
