import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/token.dart';
import '../../services/wallet_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/currency_controller.dart';
import '../../utils/toast_utils.dart';
import '../../utils/amount_utils.dart';
import '../../utils/value_formatter.dart';
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
  BigInt _availableBalanceBaseUnits = BigInt.zero;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_handleAmountChanged);
    _loadDefaultToken();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.removeListener(_handleAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  void _handleAmountChanged() {
    if (mounted) {
      setState(() {});
    }
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
        final balanceBaseUnits = await blockchain.getNativeBalanceBaseUnits(
          address,
        );
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
              coinGeckoId: blockchain.activeChain.coinGeckoId,
            );
            _availableBalance = balance;
            _availableBalanceBaseUnits = balanceBaseUnits;
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
            coinGeckoId: blockchain.activeChain.coinGeckoId,
          );
          _availableBalanceBaseUnits = BigInt.zero;
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
          coinGeckoId: blockchain.activeChain.coinGeckoId,
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
        _availableBalanceBaseUnits = AmountUtils.parseDecimalToBaseUnits(
          token.balance.toString(),
          token.decimals,
        );
      });
    }
  }

  void _setMax() {
    final decimals = _selectedToken?.decimals ?? 18;
    setState(() {
      _amountController.text = AmountUtils.formatBaseUnits(
        _availableBalanceBaseUnits,
        decimals,
        maxFractionDigits: decimals,
      );
    });
  }

  void _openQrScanner() {
    Navigator.pushNamed(context, '/qr-scanner');
  }

  void _onSend() {
    final l = AppLocalizations.of(context);
    final destination = _addressController.text.trim();
    final amountText = _amountController.text.trim();

    if (destination.isEmpty) {
      _showError(l.enterReceivingAddress);
      return;
    }

    final isValidEvmAddress = RegExp(
      r'^0x[0-9a-fA-F]{40}$',
    ).hasMatch(destination);
    if (!isValidEvmAddress) {
      _showError(l.invalidEthereumAddress);
      return;
    }

    BigInt amountInBaseUnits;
    try {
      amountInBaseUnits = _walletService.parseAmountToBaseUnits(
        amountText,
        decimals: _selectedToken?.decimals ?? 18,
      );
    } on FormatException catch (e) {
      _showError(e.message.isEmpty ? l.enterValidAmount : e.message);
      return;
    }

    if (amountInBaseUnits <= BigInt.zero) {
      _showError(l.enterValidAmount);
      return;
    }
    if (amountInBaseUnits > _availableBalanceBaseUnits) {
      _showError(l.insufficientBalance);
      return;
    }

    Navigator.pushNamed(
      context,
      '/transfer-confirmation',
      arguments: {
        'token': _selectedToken,
        'toAddress': destination,
        'amount': amountText,
        'amountBaseUnits': amountInBaseUnits,
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

  double _selectedTokenUsdPrice(BlockchainService blockchain) {
    final token = _selectedToken;
    if (token == null) {
      return 0.0;
    }
    if (token.unitPriceUsd > 0) {
      return token.unitPriceUsd;
    }
    final selectedAddress = (token.contractAddress ?? '').toLowerCase();
    for (final candidate in blockchain.tokens) {
      final candidateAddress = (candidate.contractAddress ?? '').toLowerCase();
      if (selectedAddress.isNotEmpty &&
          selectedAddress == candidateAddress &&
          candidate.unitPriceUsd > 0) {
        return candidate.unitPriceUsd;
      }
      if (selectedAddress.isEmpty &&
          candidateAddress.isEmpty &&
          candidate.symbol.toUpperCase() == token.symbol.toUpperCase() &&
          candidate.unitPriceUsd > 0) {
        return candidate.unitPriceUsd;
      }
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    context.select<CurrencyController, String>(
      (controller) => controller.currencyCode,
    );
    final l = AppLocalizations.of(context);
    final blockchain = Provider.of<BlockchainService>(context);
    final enteredAmount = double.tryParse(
      _amountController.text.replaceAll(',', ''),
    );
    final tokenUsdPrice = _selectedTokenUsdPrice(blockchain);
    final fiatAmountText =
        enteredAmount != null && enteredAmount > 0 && tokenUsdPrice > 0
        ? ValueFormatter.formatCurrencyWithGrouping(
            ValueFormatter.decimalFromNum(enteredAmount * tokenUsdPrice),
          )
        : '';
    final tokenRateText =
        tokenUsdPrice > 0 && (_selectedToken?.symbol ?? '').isNotEmpty
        ? '1 ${ValueFormatter.currencyCode} -> ${ValueFormatter.formatTokenRateAmount(ValueFormatter.doubleFromDecimal(ValueFormatter.convertToUsdDecimal(Decimal.one)) / tokenUsdPrice)} ${_selectedToken!.symbol}'
        : '';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SendHeader(
              title: l.sendToken,
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
                      fiatValueText: fiatAmountText,
                      rateText: tokenRateText,
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
