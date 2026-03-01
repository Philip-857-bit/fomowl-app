import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/token.dart';
import '../../services/wallet_service.dart';
import '../../services/blockchain_service.dart';
import '../../utils/toast_utils.dart';
import 'widgets/send/send_header.dart';
import 'widgets/send/token_selector_card.dart';
import 'widgets/send/address_input_field.dart';
import 'widgets/send/amount_input_field.dart';
import 'widgets/send/send_primary_button.dart';

/// Send Token Screen
/// Select token, enter recipient address and amount, then proceed to confirmation
class SendTokenScreen extends StatefulWidget {
  const SendTokenScreen({super.key});

  @override
  State<SendTokenScreen> createState() => _SendTokenScreenState();
}

class _SendTokenScreenState extends State<SendTokenScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final WalletService _walletService = WalletService();

  Token? _selectedToken;

  double _availableBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDefaultToken();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultToken() async {
    final address = await _walletService.getCurrentWalletAddress();
    if (address != null) {
      if (!mounted) return;
      try {
        final blockchain = Provider.of<BlockchainService>(
          context,
          listen: false,
        );
        final balance = await blockchain.getEthBalance(address);
        if (mounted) {
          setState(() {
            _selectedToken = Token(
              symbol: blockchain.activeChain.symbol,
              name: blockchain.activeChain.name,
              balance: balance,
              valueUsd: 0,
              changePercent24h: 0,
              contractAddress: '',
              decimals: 18,
              coinGeckoId: blockchain.activeChain.coinGeckoId.isNotEmpty
                  ? blockchain.activeChain.coinGeckoId
                  : null,
            );
            _availableBalance = balance;
          });
        }
      } catch (e) {
        if (!mounted) return;
        final blockchain = Provider.of<BlockchainService>(
          context,
          listen: false,
        );
        setState(() {
          _selectedToken = Token(
            symbol: blockchain.activeChain.symbol,
            name: blockchain.activeChain.name,
            balance: 0,
            valueUsd: 0,
            changePercent24h: 0,
            contractAddress: '',
            decimals: 18,
            coinGeckoId: blockchain.activeChain.coinGeckoId.isNotEmpty
                ? blockchain.activeChain.coinGeckoId
                : null,
          );
        });
      }
    } else {
      if (!mounted) return;
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      setState(() {
        _selectedToken = Token(
          symbol: blockchain.activeChain.symbol,
          name: blockchain.activeChain.name,
          balance: 0,
          valueUsd: 0,
          changePercent24h: 0,
          contractAddress: '',
          decimals: 18,
          coinGeckoId: blockchain.activeChain.coinGeckoId.isNotEmpty
              ? blockchain.activeChain.coinGeckoId
              : null,
        );
      });
    }
  }

  Future<void> _openTokenSelector() async {
    final token = await Navigator.pushNamed(context, '/select-token');
    if (token is Token && mounted) {
      setState(() {
        _selectedToken = token;
        _availableBalance = token.balance;
      });
    }
  }

  void _setMax() {
    setState(() {
      _amountController.text = _availableBalance.toStringAsFixed(
        _availableBalance < 1 ? 6 : 2,
      );
    });
  }

  void _openQrScanner() {
    Navigator.pushNamed(context, '/qr-scanner');
  }

  void _onSend() {
    final destination = _addressController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));

    if (destination.isEmpty) {
      _showError('Please enter a receiving address');
      return;
    }

    if (!destination.startsWith('0x') || destination.length != 42) {
      _showError('Invalid Ethereum address');
      return;
    }

    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }
    if (amount > _availableBalance) {
      _showError('Insufficient balance');
      return;
    }

    // Navigate to confirmation screen
    Navigator.pushNamed(
      context,
      '/transfer-confirmation',
      arguments: {
        'token': _selectedToken,
        'toAddress': destination,
        'amount': amount,
        'network': Provider.of<BlockchainService>(
          context,
          listen: false,
        ).activeChain.name,
        'isInterTransfer': false,
      },
    );
  }

  void _showError(String message) {
    ToastUtils.showError(message);
  }

  @override
  Widget build(BuildContext context) {
    final blockchain = Provider.of<BlockchainService>(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SendHeader(
              title: 'Send Token',
              onBack: () => Navigator.pop(context),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),

                    TokenSelectorCard(
                      token: _selectedToken,
                      onTap: _openTokenSelector,
                      blockchain: blockchain,
                    ),
                    const SizedBox(height: 26),

                    AddressInputField(
                      controller: _addressController,
                      isInterTransfer: false,
                      onQrTap: _openQrScanner,
                    ),
                    const SizedBox(height: 26),

                    AmountInputField(
                      controller: _amountController,
                      availableBalance: _availableBalance,
                      tokenSymbol: _selectedToken?.symbol ?? '',
                      onMaxTap: _setMax,
                    ),
                  ],
                ),
              ),
            ),

            // Send button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              child: SendPrimaryButton(onPressed: _onSend),
            ),
          ],
        ),
      ),
    );
  }
}
