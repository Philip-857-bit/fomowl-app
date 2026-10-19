import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../features/shell/app_shell_controller.dart';
import '../../services/blockchain_service.dart';
import '../../services/runtime_config_service.dart';
import '../../services/wallet_service.dart';
import '../../models/bitcoin_account_state.dart';
import '../../theme/app_chain_theme.dart';
import '../../widgets/bottom_navigation.dart';
import '../home/widgets/network_selector_sheet.dart';
import 'widgets/bridge_tab_content.dart';
import 'widgets/swap_network_card.dart';

/// Reuses the bridge product surface without initializing legacy Swap/Limit
/// state against Bitcoin's HD account. It never exposes a BTC swap pair.
class BitcoinBridgeScreen extends StatefulWidget {
  final bool showBottomNavigation;
  const BitcoinBridgeScreen({super.key, this.showBottomNavigation = true});
  @override
  State<BitcoinBridgeScreen> createState() => _BitcoinBridgeScreenState();
}

class _BitcoinBridgeScreenState extends State<BitcoinBridgeScreen> {
  final WalletService _wallet = WalletService();

  void _selectNetwork(BlockchainService chain) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => NetworkSelectorSheet(
        entries: chain.networkEntries,
        activeNetworkKey: chain.activeNetworkKey,
        onSelect: (entry) {
          chain.setActiveNetworkKey(entry.networkKey);
          Navigator.pop(sheet);
        },
        onAddCustomNetwork: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chain = context.watch<BlockchainService>();
    final identity = chain.activeWalletAddress;
    return ListenableBuilder(
      listenable: RuntimeConfigService.instance,
      builder: (context, _) {
        final policy = RuntimeConfigService.instance.snapshot;
        final mainnet = chain.activeNetworkKey == 'bitcoin:mainnet';
        final available =
            chain.isBitcoinNetworkAvailable('bitcoin:mainnet') &&
            policy.allows(RuntimeFeature.bridges) &&
            policy.allows(RuntimeFeature.transfers);
        return Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: widget.showBottomNavigation
              ? const BottomNavBar(
                  currentTab: AppShellTab.swap,
                  bitcoinBridgeOnly: true,
                )
              : null,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/shell',
                              (_) => false,
                              arguments: AppShellTab.wallet.index,
                            );
                          }
                        },
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const Expanded(
                        child: Text(
                          'Bridge',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SwapNetworkCard(
                    networkName: chain.activeNetworkName,
                    logoUrl: chain.activeNetworkLogoUrl,
                    accentColor: context.chainTheme.accentColor,
                    canSwitch: chain.networkEntries.length > 1,
                    onChangeNetwork: () => _selectNetwork(chain),
                  ),
                  const SizedBox(height: 20),
                  if (!mainnet)
                    const Text(
                      'Bitcoin bridges use Mainnet. Testnet4 is available for wallet transfer testing.',
                      style: TextStyle(color: Colors.white70),
                    )
                  else if (!available || identity.isEmpty)
                    const Text(
                      'Bitcoin bridging is unavailable right now.',
                      style: TextStyle(color: Colors.white70),
                    )
                  else
                    BridgeTabContent(
                      blockchain: chain,
                      walletService: _wallet,
                      walletAddress: identity,
                      tokens: chain.tokens,
                      onSelectFromChain: () => _selectNetwork(chain),
                      onBridgeCompleted: () =>
                          chain.refreshBitcoinAccountAfterTransaction(
                            identity,
                            BitcoinProductNetwork.mainnet,
                            isCurrent: () =>
                                mounted &&
                                chain.activeWalletAddress == identity &&
                                chain.activeNetworkKey == 'bitcoin:mainnet',
                          ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
