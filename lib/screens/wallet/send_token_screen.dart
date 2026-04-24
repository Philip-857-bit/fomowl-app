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
import '../../widgets/amount_input_mode_toggle.dart';
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
  // Canonical amount in token units — source of truth for submission.
  final TextEditingController _amountController = TextEditingController();
  // What the user is physically typing; may be in fiat or token units.
  final TextEditingController _displayController = TextEditingController();
  final WalletService _walletService = WalletService();

  Token? _selectedToken;
  AmountInputMode _inputMode = AmountInputMode.token;
  bool _syncingDisplay = false;

  double _availableBalance = 0.0;
  BigInt _availableBalanceBaseUnits = BigInt.zero;

  @override
  void initState() {
    super.initState();
    _displayController.addListener(_handleDisplayChanged);
    _loadDefaultToken();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _displayController.removeListener(_handleDisplayChanged);
    _displayController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _handleDisplayChanged() {
    if (_syncingDisplay) return;
    final raw = _displayController.text.replaceAll(',', '');
    final entered = double.tryParse(raw) ?? 0.0;
    final tokenUsdPrice = _currentTokenUsdPrice();
    String tokenAmountText;
    if (_inputMode == AmountInputMode.token) {
      tokenAmountText = raw;
    } else if (entered > 0 && tokenUsdPrice > 0) {
      final usdValue = ValueFormatter.doubleFromDecimal(
        ValueFormatter.convertToUsdDecimal(
          ValueFormatter.decimalFromNum(entered),
        ),
      );
      final tokenAmount = usdValue / tokenUsdPrice;
      final decimals = _selectedToken?.decimals ?? 18;
      final displayDecimals = decimals > 8 ? 8 : decimals;
      tokenAmountText = tokenAmount.toStringAsFixed(displayDecimals);
      tokenAmountText = _trimTrailingZeros(tokenAmountText);
    } else {
      tokenAmountText = '';
    }
    _amountController.text = tokenAmountText;
    if (mounted) setState(() {});
  }

  String _trimTrailingZeros(String value) {
    var output = value;
    while (output.contains('.') && output.endsWith('0')) {
      output = output.substring(0, output.length - 1);
    }
    if (output.endsWith('.')) {
      output = output.substring(0, output.length - 1);
    }
    return output;
  }

  double _currentTokenUsdPrice() {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    return _selectedTokenUsdPrice(blockchain);
  }

  void _setDisplayFromTokenAmount(String tokenAmount) {
    _syncingDisplay = true;
    if (_inputMode == AmountInputMode.token) {
      _displayController.text = tokenAmount;
    } else {
      final tokenValue = double.tryParse(tokenAmount) ?? 0.0;
      final tokenUsdPrice = _currentTokenUsdPrice();
      if (tokenValue > 0 && tokenUsdPrice > 0) {
        final fiatValue = ValueFormatter.doubleFromDecimal(
          ValueFormatter.convertFromUsdDecimal(
            ValueFormatter.decimalFromNum(tokenValue * tokenUsdPrice),
          ),
        );
        _displayController.text = fiatValue.toStringAsFixed(2);
      } else {
        _displayController.text = '';
      }
    }
    _syncingDisplay = false;
  }

  void _toggleInputMode() {
    final tokenUsdPrice = _currentTokenUsdPrice();
    if (tokenUsdPrice <= 0 && _inputMode == AmountInputMode.token) {
      ToastUtils.showError(
        'Price unavailable for ${_selectedToken?.symbol ?? 'this token'}',
      );
      return;
    }
    setState(() {
      _inputMode = _inputMode == AmountInputMode.token
          ? AmountInputMode.fiat
          : AmountInputMode.token;
    });
    _setDisplayFromTokenAmount(_amountController.text);
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
        // Fall back to token mode if the new token has no USD price.
        if (_inputMode == AmountInputMode.fiat &&
            _currentTokenUsdPrice() <= 0) {
          _inputMode = AmountInputMode.token;
        }
      });
      _setDisplayFromTokenAmount(_amountController.text);
    }
  }

  void _setMax() {
    final decimals = _selectedToken?.decimals ?? 18;
    final tokenText = AmountUtils.formatBaseUnits(
      _availableBalanceBaseUnits,
      decimals,
      maxFractionDigits: decimals,
    );
    _amountController.text = tokenText;
    _setDisplayFromTokenAmount(tokenText);
    if (mounted) setState(() {});
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
    final tokenAmount = double.tryParse(
      _amountController.text.replaceAll(',', ''),
    );
    final tokenUsdPrice = _selectedTokenUsdPrice(blockchain);
    final tokenSymbol = _selectedToken?.symbol ?? '';

    // Equivalent shown beneath the input:
    //   token mode → equivalent fiat value
    //   fiat mode  → equivalent token amount
    String equivalentText = '';
    if (tokenAmount != null && tokenAmount > 0 && tokenUsdPrice > 0) {
      if (_inputMode == AmountInputMode.token) {
        equivalentText = '≈ ${ValueFormatter.formatCurrencyWithGrouping(
          ValueFormatter.decimalFromNum(tokenAmount * tokenUsdPrice),
        )}';
      } else {
        equivalentText =
            '≈ ${ValueFormatter.formatTokenRateAmount(tokenAmount)} $tokenSymbol';
      }
    }

    final tokenRateText = tokenUsdPrice > 0 && tokenSymbol.isNotEmpty
        ? '1 ${ValueFormatter.currencyCode} -> ${ValueFormatter.formatTokenRateAmount(ValueFormatter.doubleFromDecimal(ValueFormatter.convertToUsdDecimal(Decimal.one)) / tokenUsdPrice)} $tokenSymbol'
        : '';

    final inputSuffix = _inputMode == AmountInputMode.token
        ? tokenSymbol
        : ValueFormatter.currencyCode;

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
                      controller: _displayController,
                      availableBalance: _availableBalance,
                      tokenSymbol: tokenSymbol,
                      onMaxTap: _setMax,
                      inputMode: _inputMode,
                      onToggleInputMode: tokenUsdPrice > 0
                          ? _toggleInputMode
                          : null,
                      inputSuffixLabel: inputSuffix,
                      equivalentText: equivalentText,
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
