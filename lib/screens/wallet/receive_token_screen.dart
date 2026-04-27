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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final blockchain = Provider.of<BlockchainService>(context);
    if (_selectedToken == null) {
      final tokens = blockchain.tokens;
      if (tokens.isNotEmpty) {
        _selectedToken = tokens.first;
      }
    }
    // Reload address whenever the active family changes (EVM → Solana → Tron).
    final currentFamily = blockchain.activeFamily;
    if (_lastFamily != currentFamily) {
      _lastFamily = currentFamily;
      _loadAddress();
    }
  }

  String _walletAddress = '';
  final WalletService _walletService = WalletService();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadAddress() async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final family = blockchain.activeFamily;
    final address = family == ChainFamily.evm
        ? await _walletService.getCurrentWalletAddress()
        : await _walletService.getWalletAddressForFamily(family);
    if (mounted) {
      setState(() {
        _walletAddress = address ?? '';
      });
    }
  }

  void _showTokenSelector() async {
    final tokens = Provider.of<BlockchainService>(
      context,
      listen: false,
    ).tokens;
    final result = await showDialog<Token>(
      context: context,
      builder: (context) => TokenSelectorDialog(tokens: tokens),
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
