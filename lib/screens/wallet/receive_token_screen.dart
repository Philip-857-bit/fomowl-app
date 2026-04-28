import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../widgets/token_selector_modal.dart';
import '../../services/wallet_service.dart';
import '../../services/blockchain_service.dart';
import 'package:provider/provider.dart';
import '../../models/token.dart';
import '../../models/chain.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/toast_utils.dart';
import 'widgets/send/send_header.dart';
import 'widgets/send/token_selector_card.dart';
import 'widgets/receive/receive_warning_banner.dart';
import 'widgets/receive/qr_code_card.dart';
import 'widgets/receive/address_display_card.dart';
import 'widgets/receive/receive_action_buttons.dart';

class ReceiveTokenScreen extends StatefulWidget {
  const ReceiveTokenScreen({super.key});

  @override
  State<ReceiveTokenScreen> createState() => _ReceiveTokenScreenState();
}

class _ReceiveTokenScreenState extends State<ReceiveTokenScreen> {
  Token? _selectedToken;
  ChainFamily? _lastFamily;
  String _walletAddress = '';
  final WalletService _walletService = WalletService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initForFamily());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final blockchain = Provider.of<BlockchainService>(context);
    final currentFamily = blockchain.activeFamily;
    // Re-initialise token + address whenever the active family changes.
    if (_lastFamily != currentFamily) {
      _lastFamily = currentFamily;
      _initForFamily();
    }
  }

  /// Resets the selected token to the native token of the active family and
  /// reloads the correct wallet address for that family.
  Future<void> _initForFamily() async {
    if (!mounted) return;
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final family = blockchain.activeFamily;
    final activeNetworkKey = blockchain.activeNetworkKey;

    // Pick the native token for the active family from the loaded token list.
    final familyTokens = blockchain.tokens
        .where((t) => t.networkKey == activeNetworkKey)
        .toList();
    final nativeToken = familyTokens.firstWhere(
      (t) => t.contractAddress == null || t.contractAddress!.isEmpty,
      orElse: () => familyTokens.isNotEmpty
          ? familyTokens.first
          : blockchain.tokens.first,
    );

    final address = await _walletService.getWalletAddressForFamily(family);
    if (mounted) {
      setState(() {
        _selectedToken = nativeToken;
        _walletAddress = address ?? '';
      });
    }
  }

  void _showTokenSelector() async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    // Only show tokens that belong to the currently active network.
    final activeNetworkKey = blockchain.activeNetworkKey;
    final familyTokens = blockchain.tokens
        .where((t) => t.networkKey == activeNetworkKey)
        .toList();
    final result = await showDialog<Token>(
      context: context,
      builder: (context) => TokenSelectorDialog(tokens: familyTokens),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedToken = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final blockchain = Provider.of<BlockchainService>(context);
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SendHeader(
                title: l.receiveTokenTitle,
                onBack: () => Navigator.pop(context),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TokenSelectorCard(
                  token: _selectedToken,
                  onTap: _showTokenSelector,
                  blockchain: blockchain,
                ),
              ),
              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ReceiveWarningBanner(message: l.receiveExternalWarning),
              ),
              if (_walletAddress.isEmpty &&
                  blockchain.activeFamily != ChainFamily.evm) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ReceiveWarningBanner(
                    message:
                        'This wallet was imported via private key and does not have a ${blockchain.activeFamily == ChainFamily.solana ? 'Solana' : 'Tron'} address. '
                        'Create a new wallet from a seed phrase to receive on this network.',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: AppColors.warning,
                    borderColor: AppColors.warning,
                  ),
                ),
              ],
              const SizedBox(height: 32),

              QrCodeCard(data: _walletAddress),
              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: AddressDisplayCard(
                  value: _walletAddress,
                  isInterTransfer: false,
                  onCopy: () {
                    Clipboard.setData(ClipboardData(text: _walletAddress));
                    ToastUtils.showSuccess(l.addressCopied);
                  },
                ),
              ),

              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ReceiveActionButtons(
                  onShare: () => Navigator.pop(context),
                  onCopy: () {
                    Clipboard.setData(ClipboardData(text: _walletAddress));
                    ToastUtils.showSuccess(l.addressCopied);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
