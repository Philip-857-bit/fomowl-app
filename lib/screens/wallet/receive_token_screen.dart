import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../widgets/token_selector_modal.dart';
import '../../services/wallet_service.dart';
import '../../services/blockchain_service.dart';
import 'package:provider/provider.dart';
import '../../models/token.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/toast_utils.dart';
import '../profile/coming_soon_overlay.dart';
import 'widgets/send/send_header.dart';
import 'widgets/send/token_selector_card.dart';
import 'widgets/send/transfer_type_toggle.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedToken == null) {
      final tokens = Provider.of<BlockchainService>(context).tokens;
      if (tokens.isNotEmpty) {
        _selectedToken = tokens.first;
      }
    }
  }

  final bool _isInterTransfer = false;
  String _walletAddress = '';
  final WalletService _walletService = WalletService();

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    final address = await _walletService.getCurrentWalletAddress();
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
                child: TransferTypeToggle(
                  isInterTransfer: _isInterTransfer,
                  onExternalTap: () {},
                  onInterTransferTap: () => ComingSoonOverlay.show(
                    context,
                    title: l.interTransferTitle,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ReceiveWarningBanner(
                  message: _isInterTransfer
                      ? l.receiveInterTransferWarning
                      : l.receiveExternalWarning,
                  icon: _isInterTransfer
                      ? Icons.info_outline
                      : Icons.warning_amber_rounded,
                  iconColor: _isInterTransfer
                      ? Colors.green
                      : AppColors.accentRed,
                  borderColor: _isInterTransfer
                      ? Colors.green
                      : AppColors.accentRed,
                ),
              ),
              const SizedBox(height: 32),

              QrCodeCard(
                data: _isInterTransfer
                    ? 'fomowl:sample.user@fomowl.com'
                    : _walletAddress,
              ),
              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: AddressDisplayCard(
                  value: _isInterTransfer
                      ? 'sample.user@fomowl.com'
                      : _walletAddress,
                  isInterTransfer: _isInterTransfer,
                  onCopy: () {
                    final copyData = _isInterTransfer
                        ? 'sample.user@fomowl.com'
                        : _walletAddress;
                    Clipboard.setData(ClipboardData(text: copyData));
                    ToastUtils.showSuccess(
                      _isInterTransfer ? l.usernameCopied : l.addressCopied,
                    );
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
                    final copyData = _isInterTransfer
                        ? 'sample.user@fomowl.com'
                        : _walletAddress;
                    Clipboard.setData(ClipboardData(text: copyData));
                    ToastUtils.showSuccess(
                      _isInterTransfer ? l.usernameCopied : l.addressCopied,
                    );
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
