import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/token.dart';
import '../../models/chain.dart';
import '../../services/wallet_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/blockchain/blockchain_catalog.dart';
import '../../services/currency_controller.dart';
import '../../services/recipient_book_service.dart';
import '../../utils/toast_utils.dart';
import '../../utils/amount_utils.dart';
import '../../utils/send_amount_utils.dart';
import '../../utils/bitcoin_amount_utils.dart';
import '../../models/bitcoin_account_state.dart';
import '../../services/bitcoin/bitcoin_send_service.dart';
import '../../utils/value_formatter.dart';
import '../../widgets/amount_input_mode_toggle.dart';
import 'widgets/send/amount_font_fit.dart';
import 'widgets/send/send_header.dart';
import 'widgets/send/token_selector_card.dart';
import 'widgets/send/send_primary_button.dart';
import 'widgets/send/send_receiver_step.dart';

/// Send Token Screen
/// Select token, enter recipient address and amount, then proceed to confirmation
class SendTokenScreen extends StatefulWidget {
  const SendTokenScreen({super.key});

  @override
  State<SendTokenScreen> createState() => _SendTokenScreenState();
}

class _SendTokenScreenState extends State<SendTokenScreen> {
  static final BigInt _solanaTransferFeeLamports = BigInt.from(5000);

  final TextEditingController _addressController = TextEditingController();
  // Canonical amount in token units — source of truth for submission.
  final TextEditingController _amountController = TextEditingController();
  // What the user is physically typing; may be in fiat or token units.
  final TextEditingController _displayController = TextEditingController();
  final WalletService _walletService = WalletService();

  Token? _selectedToken;
  AmountInputMode _inputMode = AmountInputMode.token;
  bool _syncingDisplay = false;
  bool _isCalculatingMax = false;
  bool _isPreparingBitcoin = false;
  int? _selectedPercentage;

  double _availableBalance = 0.0;
  BigInt _availableBalanceBaseUnits = BigInt.zero;
  bool _nonEvmAddressMissing = false;

  ChainFamily? _lastFamily;
  bool _didApplyRouteToken = false;
  bool _receiverSelected = false;
  String _recipientLabel = '';

  @override
  void initState() {
    super.initState();
    _displayController.addListener(_handleDisplayChanged);
    // Initial token selection happens in didChangeDependencies, where route
    // arguments (a token forwarded from its detail screen) can be read.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final blockchain = Provider.of<BlockchainService>(context);
    final currentFamily = blockchain.activeFamily;

    // One-time: if the user came here via "Send" on a token's detail screen,
    // pre-select that exact token instead of defaulting to the native token.
    if (!_didApplyRouteToken) {
      _didApplyRouteToken = true;
      final arg = ModalRoute.of(context)?.settings.arguments;
      if (arg is Token) {
        _lastFamily = currentFamily;
        _applySelectedToken(arg);
        return;
      }
    }

    final tokenIsStale =
        _selectedToken != null &&
        _selectedToken!.networkKey != blockchain.activeNetworkKey;
    if (_lastFamily != currentFamily || tokenIsStale) {
      _lastFamily = currentFamily;
      _loadDefaultToken();
    }
  }

  /// Applies a fully-formed token (from the token selector or a detail-screen
  /// hand-off) as the active send token, refreshing the available balance.
  void _applySelectedToken(Token token) {
    if (!mounted) return;
    setState(() {
      _selectedToken = token;
      _selectedPercentage = null;
      _availableBalance = token.balance;
      _availableBalanceBaseUnits = AmountUtils.parseDecimalToBaseUnits(
        token.balance.toString(),
        token.decimals,
      );
      // Fall back to token mode if the new token has no USD price.
      if (_inputMode == AmountInputMode.fiat && _currentTokenUsdPrice() <= 0) {
        _inputMode = AmountInputMode.token;
      }
    });
    _setDisplayFromTokenAmount(_amountController.text);
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
    if (_selectedToken?.networkKey?.startsWith('bitcoin:') == true) {
      _amountController.text = _displayController.text;
      if (mounted) setState(() => _selectedPercentage = null);
      return;
    }
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
    if (mounted) {
      setState(() => _selectedPercentage = null);
    }
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

  Future<void> _loadDefaultToken() async {
    if (!mounted) return;
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final family = blockchain.activeFamily;

    // Native token decimals differ per family.
    final int nativeDecimals = switch (family) {
      ChainFamily.bitcoin => 8,
      ChainFamily.solana => 9,
      ChainFamily.tron => 6,
      ChainFamily.evm => 18,
    };

    final String nativeSymbol = blockchain.activeNetworkSymbol;
    final String nativeName = blockchain.activeNetworkName;
    final String? nativeCoinGeckoId = blockchain.activeNetworkCoinGeckoId;

    final address = family == ChainFamily.bitcoin
        ? await _walletService.getCurrentWalletAddress()
        : await _walletService.getWalletAddressForFamily(family);
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
      if (family == ChainFamily.bitcoin) {
        balanceBaseUnits = await blockchain.getNativeBalanceBaseUnits(address);
        balance = double.parse(BitcoinAmountUtils.format(balanceBaseUnits));
        _inputMode = AmountInputMode.token;
      } else if (family == ChainFamily.evm) {
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
    if (Provider.of<BlockchainService>(context, listen: false).activeFamily ==
        ChainFamily.bitcoin) {
      return;
    }
    final token = await Navigator.pushNamed(context, '/select-token');
    if (token is Token && mounted) {
      _applySelectedToken(token);
    }
  }

  Future<BigInt> _evmNativeFeeReserve(BlockchainService blockchain) async {
    try {
      final fromAddress = await _walletService.getActiveAddressForFamily(
        ChainFamily.evm,
      );
      final toAddress = _addressController.text.trim();
      if (fromAddress != null &&
          fromAddress.isNotEmpty &&
          _isValidAddressForFamily(toAddress, ChainFamily.evm)) {
        final gasData = await _walletService.estimateTransferFee(
          fromAddress: fromAddress,
          toAddress: toAddress,
          amountInBaseUnits: BigInt.one,
          rpcUrl: blockchain.activeChain.rpcUrl,
        );
        final fee = gasData['totalFeeWei'];
        if (fee is BigInt && fee > BigInt.zero) {
          return fee;
        }
      }
    } catch (_) {
      // Fall back to the chain-level estimate below.
    }

    final gasData = await blockchain.estimateGasFee();
    final fee = gasData['totalFeeWei'];
    if (fee is! BigInt || fee <= BigInt.zero) {
      throw StateError('The network returned an invalid fee estimate.');
    }
    // The generic estimate uses 21,000 gas without a buffer. Keep a margin
    // for a small gas-price movement between this screen and confirmation.
    return (fee * BigInt.from(12)) ~/ BigInt.from(10);
  }

  Future<void> _setMax() async {
    if (_isCalculatingMax) return;
    final decimals = _selectedToken?.decimals ?? 18;
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final selectedToken = _selectedToken;
    if (blockchain.activeFamily == ChainFamily.bitcoin) {
      final networkKey = blockchain.activeNetworkKey;
      final identity = await _walletService.getCurrentWalletAddress();
      if (!mounted || identity == null) return;
      final recipient = _addressController.text.trim();
      final productNetwork = BitcoinProductNetwork.fromId(
        NetworkKey.bitcoinNetworkIdOf(networkKey),
      );
      if (!BitcoinAmountUtils.recipientLooksCompatible(
        recipient,
        productNetwork,
      )) {
        ToastUtils.showError('Enter the recipient before calculating Max.');
        return;
      }
      setState(() => _isCalculatingMax = true);
      try {
        final max = await BitcoinSendService().maximumAmount(
          identity,
          productNetwork,
          recipient,
          isCurrent: () =>
              mounted &&
              blockchain.activeNetworkKey == networkKey &&
              blockchain.activeWalletAddress.toLowerCase() ==
                  identity.toLowerCase(),
        );
        if (!mounted ||
            blockchain.activeNetworkKey != networkKey ||
            !identical(_selectedToken, selectedToken)) {
          return;
        }
        _amountController.text = BitcoinAmountUtils.format(max);
        _setDisplayFromTokenAmount(_amountController.text);
        setState(() => _selectedPercentage = 100);
      } catch (_) {
        ToastUtils.showError(
          'Unable to calculate Bitcoin amount and network fee.',
        );
      } finally {
        if (mounted) setState(() => _isCalculatingMax = false);
      }
      return;
    }
    final isNative =
        selectedToken?.contractAddress == null ||
        (selectedToken?.contractAddress?.isEmpty ?? true);
    var maxBaseUnits = _availableBalanceBaseUnits;
    if (isNative) {
      if (blockchain.activeFamily == ChainFamily.solana) {
        maxBaseUnits = SendAmountUtils.maxAfterFeeReserve(
          maxBaseUnits,
          _solanaTransferFeeLamports,
        );
      } else if (blockchain.activeFamily == ChainFamily.evm) {
        setState(() => _isCalculatingMax = true);
        try {
          final feeReserve = await _evmNativeFeeReserve(blockchain);
          maxBaseUnits = SendAmountUtils.maxAfterFeeReserve(
            maxBaseUnits,
            feeReserve,
          );
        } catch (_) {
          ToastUtils.showError('Unable to estimate the network fee.');
          return;
        } finally {
          if (mounted) {
            setState(() => _isCalculatingMax = false);
          }
        }
      }
    } else if (blockchain.activeFamily == ChainFamily.evm) {
      final tokenAddress = selectedToken?.contractAddress?.trim() ?? '';
      setState(() => _isCalculatingMax = true);
      try {
        final walletAddress = await _walletService.getActiveAddressForFamily(
          ChainFamily.evm,
        );
        if (walletAddress == null ||
            walletAddress.isEmpty ||
            tokenAddress.isEmpty) {
          throw StateError('The token balance cannot be refreshed.');
        }
        maxBaseUnits = await blockchain.getTokenBalanceBaseUnits(
          walletAddress,
          tokenAddress,
        );
        if (maxBaseUnits <= BigInt.zero &&
            _availableBalanceBaseUnits > BigInt.zero) {
          throw StateError('The token balance cannot be refreshed.');
        }
      } catch (_) {
        ToastUtils.showError('Unable to refresh the token balance.');
        return;
      } finally {
        if (mounted) {
          setState(() => _isCalculatingMax = false);
        }
      }
    }
    if (!mounted || !identical(_selectedToken, selectedToken)) return;
    if (!isNative && blockchain.activeFamily == ChainFamily.evm) {
      _availableBalanceBaseUnits = maxBaseUnits;
    }
    final tokenText = AmountUtils.formatBaseUnits(
      maxBaseUnits,
      decimals,
      maxFractionDigits: decimals,
    );
    _amountController.text = tokenText;
    _setDisplayFromTokenAmount(tokenText);
    setState(() => _selectedPercentage = 100);
  }

  Future<String?> _openQrScanner() async {
    final value = await Navigator.pushNamed(context, '/qr-scanner');
    return value?.toString();
  }

  void _selectReceiver(WalletRecipient recipient) {
    _addressController.text = recipient.address;
    setState(() {
      _recipientLabel = recipient.label;
      _receiverSelected = true;
      _inputMode = AmountInputMode.token;
    });
    _setDisplayFromTokenAmount(_amountController.text);
  }

  Future<void> _setPercentage(int percentage) async {
    if (percentage == 100) {
      await _setMax();
      return;
    }
    final baseUnits = SendAmountUtils.percentageOf(
      _availableBalanceBaseUnits,
      percentage,
    );
    final decimals = _selectedToken?.decimals ?? 18;
    final amount = AmountUtils.formatBaseUnits(
      baseUnits,
      decimals,
      maxFractionDigits: decimals > 8 ? 8 : decimals,
    );
    _amountController.text = amount;
    _setDisplayFromTokenAmount(amount);
    setState(() => _selectedPercentage = percentage);
  }

  Future<void> _onSend() async {
    if (_isPreparingBitcoin) return;
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
      _showError(
        family == ChainFamily.bitcoin
            ? 'Enter a Bitcoin address for the selected network.'
            : l.invalidEthereumAddress,
      );
      return;
    }

    BigInt amountInBaseUnits;
    try {
      amountInBaseUnits = family == ChainFamily.bitcoin
          ? BitcoinAmountUtils.parse(amountText)
          : _walletService.parseAmountToBaseUnits(
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
    final String activeNetworkKey =
        _selectedToken?.networkKey ?? blockchain.activeNetworkKey;
    final isNative =
        _selectedToken?.contractAddress == null ||
        (_selectedToken?.contractAddress?.isEmpty ?? true);
    if (family == ChainFamily.solana &&
        isNative &&
        amountInBaseUnits + _solanaTransferFeeLamports >
            _availableBalanceBaseUnits) {
      _showError(
        'Insufficient SOL to cover the transfer amount and network fee.',
      );
      return;
    }

    BitcoinPreparedTransfer? bitcoinTransfer;
    if (family == ChainFamily.bitcoin) {
      setState(() => _isPreparingBitcoin = true);
      try {
        final identity = await _walletService.getCurrentWalletAddress();
        if (!mounted || identity == null) return;
        bitcoinTransfer = await BitcoinSendService().prepareTransfer(
          identity,
          BitcoinProductNetwork.fromId(
            NetworkKey.bitcoinNetworkIdOf(activeNetworkKey),
          ),
          destination,
          amountInBaseUnits,
          isCurrent: () =>
              mounted &&
              blockchain.activeNetworkKey == activeNetworkKey &&
              blockchain.activeWalletAddress.toLowerCase() ==
                  identity.toLowerCase(),
        );
        if (!mounted) return;
      } on BitcoinSplitFundsException catch (error) {
        if (mounted) _showError(error.toString());
        return;
      } catch (_) {
        if (mounted) {
          _showError(
            'Unable to prepare Bitcoin transfer. Check funds, address and network connection.',
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _isPreparingBitcoin = false);
      }
    }
    if (!mounted) return;

    Navigator.pushNamed(
      context,
      '/transfer-confirmation',
      arguments: {
        'token': _selectedToken,
        'bitcoinTransfer': ?bitcoinTransfer,
        'toAddress': destination,
        'recipientLabel': _recipientLabel,
        'recipientBookWalletScope': blockchain.activeWalletAddress,
        'amount': amountText,
        'amountBaseUnits': amountInBaseUnits,
        'network': activeNetworkDisplayName,
        'networkKey': activeNetworkKey,
        'chainFamily': family.wireValue,
        'chainId': family == ChainFamily.evm
            ? blockchain.activeChain.chainId
            : null,
        'networkSymbol': blockchain.activeNetworkSymbol,
        'isInterTransfer': false,
      },
    );
  }

  bool _isValidAddressForFamily(String address, ChainFamily family) {
    switch (family) {
      case ChainFamily.bitcoin:
        final network = Provider.of<BlockchainService>(
          context,
          listen: false,
        ).activeNetworkKey;
        return BitcoinAmountUtils.recipientLooksCompatible(
          address,
          BitcoinProductNetwork.fromId(NetworkKey.bitcoinNetworkIdOf(network)),
        );
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

  /// Shrinks the amount so a long value (e.g. from the 100% button) always fits
  /// before the token symbol suffix instead of overflowing into it.
  double _amountFontSizeFor(String text, String suffix, double boxWidth) {
    return fittedAmountFontSize(
      amountText: text,
      amountStyleFor: (fontSize) =>
          GoogleFonts.inter(fontSize: fontSize, fontWeight: FontWeight.w700),
      suffixText: suffix,
      suffixStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      boxWidth: boxWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    context.select<CurrencyController, String>(
      (controller) => controller.currencyCode,
    );
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

    if (!_receiverSelected) {
      return SendReceiverStep(
        networkKey: blockchain.activeNetworkKey,
        walletScope: blockchain.activeWalletAddress,
        controller: _addressController,
        isValidAddress: (address) =>
            _isValidAddressForFamily(address, blockchain.activeFamily),
        onSelected: _selectReceiver,
        onBack: () => Navigator.pop(context),
        onQrTap: _openQrScanner,
      );
    }

    final receiverName = _recipientLabel.trim().isEmpty
        ? '${_addressController.text.substring(0, 6)}...${_addressController.text.substring(_addressController.text.length - 5)}'
        : _recipientLabel;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SendHeader(
              title: 'Send',
              onBack: () => setState(() => _receiverSelected = false),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13161B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2A333D)),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Color(0xFF1E293B),
                            child: Icon(
                              Icons.person_outline,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SENDING TO',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  receiverName,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _receiverSelected = false),
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'ASSET',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TokenSelectorCard(
                      token: _selectedToken,
                      onTap: _openTokenSelector,
                      blockchain: blockchain,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Balance  ${ValueFormatter.formatTokenRateAmount(_availableBalance)} $tokenSymbol',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'AMOUNT',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 64,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13161B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2A333D)),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _displayController,
                            builder: (context, value, _) {
                              // Shrink the amount so a long value (e.g. from the
                              // 100% button) always fits before the token symbol
                              // instead of overflowing into it.
                              final amountFontSize = _amountFontSizeFor(
                                value.text,
                                tokenSymbol,
                                constraints.maxWidth,
                              );
                              return TextField(
                                controller: _displayController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: amountFontSize,
                                  fontWeight: FontWeight.w700,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '0',
                                  hintStyle: GoogleFonts.inter(
                                    color: const Color(0xFF64748B),
                                    fontSize: amountFontSize,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  suffixText: tokenSymbol,
                                  suffixStyle: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    if (equivalentText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        equivalentText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [25, 50, 75, 100]
                          .map(
                            (percentage) => Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: percentage == 100 ? 0 : 8,
                                ),
                                child: OutlinedButton(
                                  key: ValueKey('send-percentage-$percentage'),
                                  onPressed:
                                      percentage == 100 && _isCalculatingMax
                                      ? null
                                      : () => _setPercentage(percentage),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 40),
                                    foregroundColor:
                                        _selectedPercentage == percentage
                                        ? Colors.white
                                        : const Color(0xFF94A3B8),
                                    backgroundColor:
                                        _selectedPercentage == percentage
                                        ? const Color(0xFFEA2A33)
                                        : const Color(0xFF13161B),
                                    side: BorderSide(
                                      color: _selectedPercentage == percentage
                                          ? const Color(0xFFEA2A33)
                                          : const Color(0xFF2A333D),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text('$percentage%'),
                                ),
                              ),
                            ),
                          )
                          .toList(),
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
