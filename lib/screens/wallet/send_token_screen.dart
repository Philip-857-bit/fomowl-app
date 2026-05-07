import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/token.dart';
import '../../models/chain.dart';
import '../../services/wallet_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/blockchain/blockchain_catalog.dart';
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
  bool _nonEvmAddressMissing = false;

  ChainFamily? _lastFamily;

  @override
  void initState() {
    super.initState();
    _displayController.addListener(_handleDisplayChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDefaultToken());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final blockchain = Provider.of<BlockchainService>(context);
    final currentFamily = blockchain.activeFamily;
    final tokenIsStale =
        _selectedToken != null &&
        _selectedToken!.networkKey != blockchain.activeNetworkKey;
    if (_lastFamily != currentFamily || tokenIsStale) {
      _lastFamily = currentFamily;
      _loadDefaultToken();
    }
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
    if (!mounted) return;
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final family = blockchain.activeFamily;

    // Native token decimals differ per family.
    final int nativeDecimals = switch (family) {
      ChainFamily.solana => 9,
      ChainFamily.tron => 6,
      ChainFamily.evm => 18,
    };

    final String nativeSymbol = blockchain.activeNetworkSymbol;
    final String nativeName = blockchain.activeNetworkName;
    final String? nativeCoinGeckoId = blockchain.activeNetworkCoinGeckoId;

    final address = await _walletService.getWalletAddressForFamily(family);
    if (!mounted) return;

    if (address == null || address.isEmpty) {
      setState(() {
        _selectedToken = Token(
          symbol: nativeSymbol,
          name: nativeName,
          balance: 0,
          valueUsd: 0,
          changePercent24h: 0,
          contractAddress: '',
          decimals: nativeDecimals,
          coinGeckoId: nativeCoinGeckoId,
          imageUrl: BlockchainCatalog.iconUrlForSymbol(nativeSymbol),
          networkKey: blockchain.activeNetworkKey,
        );
        _availableBalanceBaseUnits = BigInt.zero;
        _nonEvmAddressMissing = family != ChainFamily.evm;
      });
      return;
    }
    if (_nonEvmAddressMissing) {
      setState(() => _nonEvmAddressMissing = false);
    }

    try {
      double balance = 0;
      BigInt balanceBaseUnits = BigInt.zero;

      // Only EVM has a local RPC path; Solana/Tron balances come from the
      // backend token list that BlockchainService already fetched.
      if (family == ChainFamily.evm) {
        balance = await blockchain.getEthBalance(address);
        balanceBaseUnits = await blockchain.getNativeBalanceBaseUnits(address);
      } else {
        // For non-EVM, pull from the already-loaded token list.
        final cached = blockchain.tokens;
        final native = cached
            .where(
              (t) => t.contractAddress == null || t.contractAddress!.isEmpty,
            )
            .firstOrNull;
        if (native != null) {
          balance = native.balance;
          balanceBaseUnits = AmountUtils.parseDecimalToBaseUnits(
            native.balance.toString(),
            nativeDecimals,
          );
        }
      }

      if (mounted) {
        setState(() {
          _selectedToken = Token(
            symbol: nativeSymbol,
            name: nativeName,
            balance: balance,
            valueUsd: 0,
            changePercent24h: 0,
            contractAddress: '',
            decimals: nativeDecimals,
            coinGeckoId: nativeCoinGeckoId,
            imageUrl: BlockchainCatalog.iconUrlForSymbol(nativeSymbol),
            networkKey: blockchain.activeNetworkKey,
          );
          _availableBalance = balance;
          _availableBalanceBaseUnits = balanceBaseUnits;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _selectedToken = Token(
          symbol: nativeSymbol,
          name: nativeName,
          balance: 0,
          valueUsd: 0,
          changePercent24h: 0,
          contractAddress: '',
          decimals: nativeDecimals,
          coinGeckoId: nativeCoinGeckoId,
          imageUrl: BlockchainCatalog.iconUrlForSymbol(nativeSymbol),
          networkKey: blockchain.activeNetworkKey,
        );
        _availableBalanceBaseUnits = BigInt.zero;
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
    if (_nonEvmAddressMissing) {
      _showError(
        'This wallet was imported via private key and does not have a Solana or Tron address. '
        'Create a new wallet from a seed phrase to send on this network.',
      );
      return;
    }
    final l = AppLocalizations.of(context);
    final destination = _addressController.text.trim();
    final amountText = _amountController.text.trim();

    if (destination.isEmpty) {
      _showError(l.enterReceivingAddress);
      return;
    }

    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final family = blockchain.activeFamily;
    final isValidAddress = _isValidAddressForFamily(destination, family);
    if (!isValidAddress) {
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

    final String activeNetworkDisplayName = blockchain.activeNetworkName;

    Navigator.pushNamed(
      context,
      '/transfer-confirmation',
      arguments: {
        'token': _selectedToken,
        'toAddress': destination,
        'amount': amountText,
        'amountBaseUnits': amountInBaseUnits,
        'network': activeNetworkDisplayName,
        'isInterTransfer': false,
      },
    );
  }

  bool _isValidAddressForFamily(String address, ChainFamily family) {
    switch (family) {
      case ChainFamily.evm:
        return RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address);
      case ChainFamily.solana:
        // Base58 public key: 32–44 chars, no 0/O/I/l
        return RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(address);
      case ChainFamily.tron:
        // Tron base58check addresses start with T and are 34 chars
        return RegExp(r'^T[1-9A-HJ-NP-Za-km-z]{33}$').hasMatch(address);
    }
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
        equivalentText =
            '≈ ${ValueFormatter.formatCurrencyWithGrouping(ValueFormatter.decimalFromNum(tokenAmount * tokenUsdPrice))}';
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

                    if (_nonEvmAddressMissing)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.warning.withAlpha(128),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.warning,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'This wallet was imported via private key and does not have a Solana/Tron address. Create a new wallet from a seed phrase to use this network.',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
