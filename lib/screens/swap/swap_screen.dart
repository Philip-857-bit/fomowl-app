import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:decimal/decimal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bottom_navigation.dart';
import '../../models/token.dart';
import '../../services/cow_limit_order_signing.dart';
import '../../services/swap_service.dart';
import '../../services/wallet_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/currency_controller.dart';
import '../../services/token_approval_service.dart';
import '../../services/swap_execution_service.dart';
import '../../services/token_visibility_service.dart';
import '../../services/transaction_monitor.dart';
import '../../services/referral_service.dart';
import '../../services/wallet_history_service.dart';
import '../../services/wallet_notification_service.dart';
import '../../utils/amount_utils.dart';
import '../../utils/app_error_utils.dart';
import '../../utils/toast_utils.dart';
import '../../utils/token_visibility_utils.dart';
import '../../utils/value_formatter.dart';
import 'dart:convert';
import 'dart:async';
import '../transaction/transaction_processing_screen.dart';
import '../home/widgets/network_selector_sheet.dart';
import 'widgets/swap_limit_widgets.dart';
import 'widgets/swap_tab_content.dart';
import 'widgets/swap_token_selector_dialog.dart';

enum _LimitExpiryOption {
  minutes15,
  hour1,
  hours4,
  hours24,
  days7,
  never,
  custom,
}

/// Swap Screen — DEX token swap interface
class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key, this.showBottomNavigation = true});

  final bool showBottomNavigation;

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  static const String _livePriceScope = 'swap_screen';
  static const String _limitShowcaseSeenKey = 'swap_limit_showcase_seen_v1';
  static const String _limitTutorialControlHiddenKey =
      'swap_limit_tutorial_control_hidden_v1';
  static const Duration _quoteUiTimeout = Duration(seconds: 18);
  static const Duration _approvalUiTimeout = Duration(seconds: 90);
  static const Duration _gaslessStatusPollInterval = Duration(seconds: 2);
  static const Duration _followUpWalletRefreshDelay = Duration(seconds: 3);

  /// Known stablecoin symbols used to detect buy vs sell mode in limit orders.
  static const Set<String> _stablecoinSymbols = {
    'USDT',
    'USDC',
    'BUSD',
    'DAI',
    'TUSD',
    'USDP',
    'FRAX',
    'GUSD',
    'LUSD',
    'PYUSD',
    'USDD',
    'SUSD',
    'CUSD',
    'USDCE',
    'USDC.E',
    'USDT.E',
  };

  bool _isStablecoin(Token? token) {
    if (token == null) return false;
    return _stablecoinSymbols.contains(token.symbol.toUpperCase());
  }

  bool get _isBuyMode => _isLimitBuyMode;

  /// The token whose price the user is targeting in limit orders.
  Token? get _limitTargetToken => _isBuyMode ? _toToken : _fromToken;

  /// The quote token used to denominate the limit price.
  Token? get _limitQuoteToken => _isBuyMode ? _fromToken : _toToken;

  bool _suggestLimitBuyMode() {
    return _isStablecoin(_fromToken) && !_isStablecoin(_toToken);
  }

  void _applySuggestedLimitSide() {
    if (_hasManualLimitSideSelection) {
      return;
    }
    _isLimitBuyMode = _suggestLimitBuyMode();
  }

  void _setLimitOrderSide(bool isBuyMode) {
    if (_isLimitBuyMode == isBuyMode && _hasManualLimitSideSelection) {
      return;
    }
    setState(() {
      _isLimitBuyMode = isBuyMode;
      _hasManualLimitSideSelection = true;
      _limitPriceController.clear();
      _limitUsdController.clear();
      _selectedLimitPriceAdjustment = 0;
      _toController.clear();
      _platformFeeUsd = 0.0;
      _feeUsd = 0.0;
      _feeNative = 0.0;
    });
  }

  String get _currentLimitKind => _isBuyMode ? 'buy' : 'sell';
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _limitPriceController = TextEditingController();
  final TextEditingController _limitUsdController = TextEditingController();
  final SwapService _swapService = SwapService();
  final WalletService _walletService = WalletService();
  final ReferralService _referralService = ReferralService();
  final TokenVisibilityService _tokenVisibilityService =
      TokenVisibilityService();
  final WalletNotificationService _walletNotificationService =
      WalletNotificationService();
  final WalletHistoryService _walletHistoryService = WalletHistoryService();
  late final TokenApprovalService _tokenApprovalService;
  late final SwapExecutionService _swapExecutionService;
  late final TransactionMonitor _transactionMonitor;
  static const String _priceSeparator = '->';

  Timer? _debounceTimer;

  Token? _fromToken;
  Token? _toToken;
  int? _lastChainId;
  int _quoteRequestId = 0;
  SwapTab _activeTab = SwapTab.swap;
  _LimitExpiryOption _limitExpiryOption = _LimitExpiryOption.hours24;
  DateTime? _customExpiryDate;
  bool _isSubmittingLimit = false;
  bool _isLimitBuyMode = false;
  bool _hasManualLimitSideSelection = false;
  bool _isLoadingLimitOrders = false;
  bool _limitTutorialControlHidden = false;
  List<LimitOrderSummary> _limitOrders = const [];
  final Set<String> _cancellingLimitOrderIds = <String>{};
  int _selectedLimitPriceAdjustment = 0;
  String? _lastFiatCurrencyCode;

  /// Whether the +/- price adjustment chips are in positive mode.
  bool _isPositiveAdjust = false;
  bool _limitShowcaseScheduled = false;
  final GlobalKey _limitTabShowcaseKey = GlobalKey();
  final GlobalKey _limitAmountsShowcaseKey = GlobalKey();
  final GlobalKey _limitExecutionPriceShowcaseKey = GlobalKey();
  final GlobalKey _limitExpiryShowcaseKey = GlobalKey();
  final GlobalKey _limitSummaryShowcaseKey = GlobalKey();
  final GlobalKey _limitSubmitShowcaseKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final blockchain = Provider.of<BlockchainService>(context);
    final chainId = blockchain.activeChain.chainId;
    if (_lastChainId != chainId) {
      _lastChainId = chainId;
      _resetQuoteState(clearInputAmounts: true);
      if (_isGasless && !_isGaslessSupported) {
        _isGasless = false;
      }
      _loadWalletBalance();
      if (_activeTab == SwapTab.limit) {
        unawaited(_refreshLimitOrders(showLoading: false));
      }
    } else if (_fromToken == null || _toToken == null) {
      final tokens = _visibleTokens(blockchain.tokens);
      _syncSelectedTokens(tokens);
    }
    if (_activeTab == SwapTab.limit) {
      _ensureLimitEligiblePair();
      unawaited(_refreshLimitOrders(showLoading: false));
    }
  }

  bool _isCalculating = false;
  String _pricing = '';
  String? _quoteStatusMessage;

  /// Trading slippage tolerance for 0x swap execution (not the platform fee).
  final int _slippageBps = 50;
  double _feeUsd = 0.0;
  double _feeNative = 0.0;
  double _platformFeeUsd = 0.0;
  String? _walletAddress;
  SwapQuote? _currentQuote;
  int _selectedPercentage = -1; // -1 = none selected
  /// Cached per-token USD prices fetched from CoinGecko.
  /// Made static to persist across screen navigation.
  static final Map<String, double> _tokenPriceCache = {};
  bool _isApproving = false;
  bool _isSwapping = false;
  bool _isSwapFlowActive = false;
  bool _isGasless = false;

  String _formatRateText(double outAmount) {
    final from = _fromToken?.symbol ?? '';
    final to = _toToken?.symbol ?? '';
    if (from.isEmpty || to.isEmpty) {
      return outAmount.toStringAsFixed(6);
    }
    return '1 $from $_priceSeparator ${outAmount.toStringAsFixed(6)} $to';
  }

  double _resolvedTokenUnitPriceUsd(Token? token) {
    if (token == null) {
      return 0.0;
    }
    final directPrice = token.unitPriceUsd;
    if (directPrice > 0) {
      return directPrice;
    }
    final coinGeckoId = token.coinGeckoId;
    if (coinGeckoId != null && coinGeckoId.isNotEmpty) {
      final cached = _tokenPriceCache[coinGeckoId];
      if (cached != null && cached > 0) {
        return cached;
      }
    }
    return 0.0;
  }

  String _selectedFiatToTokenRateText(Token? token) {
    final symbol = token?.symbol ?? '';
    final tokenPriceUsd = _resolvedTokenUnitPriceUsd(token);
    if (symbol.isEmpty || tokenPriceUsd <= 0) {
      return '--';
    }
    final fiatUnitInUsd = ValueFormatter.doubleFromDecimal(
      ValueFormatter.convertToUsdDecimal(Decimal.one),
    );
    if (fiatUnitInUsd <= 0) {
      return '--';
    }
    final tokenAmount = fiatUnitInUsd / tokenPriceUsd;
    return '1 ${ValueFormatter.currencyCode} $_priceSeparator ${ValueFormatter.formatTokenRateAmount(tokenAmount)} $symbol';
  }

  List<Token> _limitOrderEligibleTokens(List<Token> tokens) {
    return tokens
        .where((token) => _tokenRequiresApproval(token))
        .toList(growable: false);
  }

  bool _ensureLimitEligiblePair() {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final eligible = _limitOrderEligibleTokens(
      _visibleTokens(blockchain.tokens),
    );
    if (eligible.isEmpty) {
      return false;
    }

    final currentFrom = _fromToken;
    final currentTo = _toToken;
    Token resolvedFrom =
        currentFrom != null && _tokenRequiresApproval(currentFrom)
        ? currentFrom
        : eligible.first;
    Token resolvedTo = currentTo != null && _tokenRequiresApproval(currentTo)
        ? currentTo
        : eligible.first;

    if (_tokensAreIdentical(resolvedFrom, resolvedTo)) {
      final alternative = eligible
          .where((token) => !_tokensAreIdentical(token, resolvedFrom))
          .toList(growable: false);
      if (alternative.isNotEmpty) {
        resolvedTo = alternative.first;
      }
    }

    final changed =
        !_tokensAreIdentical(resolvedFrom, currentFrom) ||
        !_tokensAreIdentical(resolvedTo, currentTo);
    if (!changed) {
      return false;
    }

    _fromToken = resolvedFrom;
    _toToken = resolvedTo;
    _applySuggestedLimitSide();
    _selectedPercentage = -1;
    _fromController.clear();
    _toController.clear();
    _limitPriceController.clear();
    _limitUsdController.clear();
    _selectedLimitPriceAdjustment = 0;
    return true;
  }

  String _limitButtonLabel() {
    final sideLabel = _isBuyMode ? 'Buy' : 'Sell';
    if (_isSubmittingLimit) {
      return 'Submitting $sideLabel...';
    }
    if ((_walletAddress ?? '').isEmpty) {
      return 'Connect Wallet';
    }
    if (!_isLimitSupported) {
      return 'Network Unsupported';
    }
    if (_fromToken == null || _toToken == null) {
      return 'Select Tokens';
    }
    if (_tokensAreIdentical(_fromToken, _toToken)) {
      return 'Choose Different Tokens';
    }
    if (!_tokenRequiresApproval(_fromToken!) ||
        !_tokenRequiresApproval(_toToken!)) {
      return 'Use ERC-20 Tokens';
    }
    if (_parseDecimalAmount(_fromController.text) <= Decimal.zero) {
      return _isBuyMode ? 'Enter Max Spend' : 'Enter Sell Amount';
    }
    if (_parseDecimalAmount(_limitPriceController.text) <= Decimal.zero) {
      return 'Set Target Price';
    }
    return 'Place $sideLabel Order';
  }

  String _limitStatusMessage() {
    if ((_walletAddress ?? '').isEmpty) {
      return 'Connect your wallet to create limit orders.';
    }
    if (!_isLimitSupported) {
      return _limitUnsupportedMessage();
    }
    if (_fromToken == null || _toToken == null) {
      return 'Select both sell and receive tokens to continue.';
    }
    if (_tokensAreIdentical(_fromToken, _toToken)) {
      return 'Choose two different tokens for the limit pair.';
    }
    if (!_tokenRequiresApproval(_fromToken!) ||
        !_tokenRequiresApproval(_toToken!)) {
      return 'Limit orders currently support ERC-20 token pairs only.';
    }
    if (_parseDecimalAmount(_fromController.text) <= Decimal.zero) {
      return _isBuyMode
          ? 'Enter the maximum amount you want to spend.'
          : 'Enter how much you want to sell.';
    }
    if (_parseDecimalAmount(_limitPriceController.text) <= Decimal.zero) {
      return 'Set the execution price that should trigger this order.';
    }
    if (_isSubmittingLimit) {
      return 'Submitting your signed ${_currentLimitKind.toUpperCase()} limit order...';
    }
    return 'You pay no gas to place or cancel a limit order. Your first sell-token approval may still need a network fee.';
  }

  bool get _isGaslessSupported {
    final chainId = Provider.of<BlockchainService>(
      context,
      listen: false,
    ).activeChain.chainId;
    // 0x Tx Relay (Gasless) supports 11+ chains: Ethereum, BSC, Polygon, Avalanche, Arbitrum, Optimism, Fantom, Base, Celo, Linea, and Polygon zkEVM.
    return [
      1,
      56,
      137,
      43114,
      42161,
      10,
      250,
      8453,
      42220,
      59144,
      1101,
    ].contains(chainId);
  }

  bool get _isLimitSupported {
    final chainId = Provider.of<BlockchainService>(
      context,
      listen: false,
    ).activeChain.chainId;
    return _swapService.isLimitChainSupported(chainId);
  }

  String _limitUnsupportedMessage() {
    return 'Limit orders are only available on Ethereum, BNB, Gnosis, Polygon, Base, Arbitrum, Avalanche, and Linea.';
  }

  @override
  void initState() {
    super.initState();
    _tokenApprovalService = TokenApprovalService(
      walletService: _walletService,
      swapService: _swapService,
    );
    _swapExecutionService = SwapExecutionService(
      walletService: _walletService,
      swapService: _swapService,
    );
    _transactionMonitor = TransactionMonitor();
    unawaited(_loadLimitTutorialPreferences());
    _loadWalletBalance();
    _activateSwapLiveTracking();
  }

  Future<void> _loadLimitTutorialPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _limitTutorialControlHidden =
          prefs.getBool(_limitTutorialControlHiddenKey) ?? false;
    });
  }

  Future<void> _loadWalletBalance() async {
    final address = await _walletService.getCurrentWalletAddress();
    if (!mounted) return;
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    await _tokenVisibilityService.loadHiddenTokens(
      blockchain.activeChain.chainId,
    );
    // Always sync with whatever token set we currently have so selectors never look empty.
    _syncSelectedTokens(_visibleTokens(blockchain.tokens));
    if (mounted) {
      setState(() => _walletAddress = address);
    }

    if (address == null || address.isEmpty) {
      if (mounted) {
        setState(() => _limitOrders = const []);
      }
    } else {
      unawaited(_refreshLimitOrders(showLoading: false));
    }

    if (address != null && address.isNotEmpty) {
      if (!mounted) return;
      try {
        await blockchain.fetchWalletTokens(address);
        if (mounted) {
          setState(() {
            _syncSelectedTokens(_visibleTokens(blockchain.tokens));
          });
        }
      } catch (e) {
        debugPrint('Error fetching balance for swap: $e');
        if (mounted) {
          setState(() {
            _syncSelectedTokens(_visibleTokens(blockchain.tokens));
          });
        }
      }
    } else if (mounted) {
      setState(() {
        _syncSelectedTokens(_visibleTokens(blockchain.tokens));
      });
    }

    // Fetch live prices for all tokens with coinGeckoId to fill price gaps.
    await _refreshTokenPrices();
    _activateSwapLiveTracking();
  }

  /// Fetches live prices from CoinGecko for tokens whose priceUsd is 0.
  Future<void> _refreshTokenPrices() async {
    if (!mounted) return;
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final priceIds = <String>{};
    for (final t in blockchain.tokens) {
      if (t.coinGeckoId != null && t.coinGeckoId!.isNotEmpty) {
        priceIds.add(t.coinGeckoId!);
      }
    }
    // Also include the active chain's native token CoinGecko ID for fee estimation.
    final nativeCoinGeckoId = blockchain.activeChain.coinGeckoId;
    if (nativeCoinGeckoId != null && nativeCoinGeckoId.isNotEmpty) {
      priceIds.add(nativeCoinGeckoId);
    }
    if (priceIds.isEmpty) return;
    try {
      final prices = await blockchain.getTokenPrices(priceIds.toList());
      if (mounted) {
        setState(() {
          _tokenPriceCache.addAll(prices);
        });
      }
    } catch (_) {
      // Non-fatal: USD values will just show $0.00
    }
  }

  void _syncSelectedTokens(List<Token> tokens) {
    if (tokens.isEmpty) {
      _fromToken = null;
      _toToken = null;
      return;
    }

    Token? findMatch(Token? current) {
      if (current == null) return null;
      final addr = (current.contractAddress ?? '').toLowerCase();
      if (addr.isNotEmpty) {
        for (final t in tokens) {
          if ((t.contractAddress ?? '').toLowerCase() == addr) return t;
        }
      }
      for (final t in tokens) {
        if (t.symbol.toLowerCase() == current.symbol.toLowerCase()) return t;
      }
      return null;
    }

    final from = findMatch(_fromToken) ?? tokens.first;
    Token to =
        findMatch(_toToken) ?? (tokens.length > 1 ? tokens[1] : tokens.first);
    if (_tokensAreIdentical(from, to)) {
      final alternative = tokens
          .where((t) => !_tokensAreIdentical(t, from))
          .toList();
      if (alternative.isNotEmpty) {
        to = alternative.first;
      }
    }

    _fromToken = from;
    _toToken = to;
    _applySuggestedLimitSide();
  }

  List<Token> _visibleTokens(List<Token> tokens) {
    final chainId = Provider.of<BlockchainService>(
      context,
      listen: false,
    ).activeChain.chainId;
    return _visibleTokensForChain(tokens, chainId);
  }

  List<Token> _visibleTokensForChain(List<Token> tokens, int chainId) {
    final hiddenTokens = _tokenVisibilityService.getHiddenTokens(chainId);
    if (hiddenTokens.isEmpty) {
      return tokens;
    }
    return tokens.where((token) {
      final contractAddress = token.contractAddress ?? '';
      if (contractAddress.isEmpty) {
        return true;
      }
      return !hiddenTokens.contains(TokenVisibilityUtils.identifier(token));
    }).toList();
  }

  Future<void> _showTokenSelector(bool isFrom) async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final allTokens = _visibleTokens(blockchain.tokens);
    final tokens = _activeTab == SwapTab.limit
        ? _limitOrderEligibleTokens(allTokens)
        : allTokens;
    if (tokens.isEmpty) {
      _showError(
        'No ERC-20 tokens available for limit orders on this network.',
      );
      return;
    }
    final selectedToken = await showDialog<Token>(
      context: context,
      builder: (ctx) => SwapTokenSelectorDialog(
        tokens: tokens,
        chainId: blockchain.activeChain.chainId,
      ),
    );

    if (selectedToken != null) {
      setState(() {
        if (isFrom) {
          _fromToken = selectedToken;
          _selectedPercentage = -1;
          _fromController.clear();
          _selectedLimitPriceAdjustment = 0;
          _limitPriceController.clear();
          _limitUsdController.clear();
          if (_isGasless && !_tokenRequiresApproval(selectedToken)) {
            _isGasless = false;
          }
        } else {
          _toToken = selectedToken;
          _selectedLimitPriceAdjustment = 0;
          _limitPriceController.clear();
          _limitUsdController.clear();
        }
        _applySuggestedLimitSide();
        _resetQuoteState();
      });
      // Refresh prices so USD values are immediately available for new token
      _refreshTokenPrices();
      if (_activeTab == SwapTab.limit) {
        _updateLimitPreview();
      } else {
        _getQuote();
      }
      // Reactivate live tracking for new token pair
      _activateSwapLiveTracking();
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _limitPriceController.dispose();
    _limitUsdController.dispose();
    _debounceTimer?.cancel();
    // Clear only swap-owned tracking so Home continues receiving updates.
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    blockchain.clearLivePriceTracking(scope: _livePriceScope);
    super.dispose();
  }

  /// Activate live price tracking for swap tokens to ensure quote freshness
  void _activateSwapLiveTracking() {
    Future.microtask(() {
      if (!mounted) return;
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      if (_fromToken != null && _toToken != null) {
        // 5s refresh cadence for swap (hot - user actively trading)
        blockchain.setLivePriceTrackingForTokens(
          [_fromToken!, _toToken!],
          interval: const Duration(seconds: 5),
          scope: _livePriceScope,
        );
      }
    });
  }

  void _setPercentage(int percent) {
    if (_fromToken == null) return;
    final balance =
        Decimal.tryParse(_fromToken!.balance.toString()) ?? Decimal.zero;
    final amount = balance * Decimal.parse((percent / 100).toStringAsFixed(2));
    final displayDecimals = _fromToken!.decimals > 6 ? 6 : _fromToken!.decimals;
    setState(() {
      _selectedPercentage = percent;
      _fromController.text = amount > Decimal.zero
          ? _formatDecimalInput(amount, displayDecimals)
          : '0';
    });
    if (amount > Decimal.zero) {
      if (_activeTab == SwapTab.limit) {
        _updateLimitPreview();
      } else {
        _getQuote();
      }
    }
  }

  void _onFromAmountChanged(String value) {
    setState(() => _selectedPercentage = -1);
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _resetQuoteState();
        _isCalculating = false;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (value.isNotEmpty) {
        if (_activeTab == SwapTab.limit) {
          _updateLimitPreview();
        } else {
          _getQuote();
        }
      }
    });
  }

  double _parseAmount(TextEditingController controller) {
    return double.tryParse(controller.text.replaceAll(',', '')) ?? 0.0;
  }

  Decimal _parseDecimalAmount(String rawValue) {
    final cleaned = rawValue.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return Decimal.zero;
    return Decimal.tryParse(cleaned) ?? Decimal.zero;
  }

  String? _toWeiAmount(String amountText, int decimals) {
    final cleaned = amountText.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    try {
      return AmountUtils.parseDecimalToBaseUnits(cleaned, decimals).toString();
    } on FormatException {
      return null;
    }
  }

  String _formatDecimalInput(Decimal value, int fractionDigits) {
    final raw = value.toString();
    if (!raw.contains('.')) return raw;
    final parts = raw.split('.');
    var fraction = parts[1];
    if (fraction.length > fractionDigits) {
      fraction = fraction.substring(0, fractionDigits);
    }
    fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty ? parts[0] : '${parts[0]}.$fraction';
  }

  double _usdValueFor(Token? token, double amount) {
    if (token == null || amount <= 0) return 0.0;
    double price = token.unitPriceUsd;
    // Fallback: use cached CoinGecko price when the token model has no price.
    if (price <= 0 &&
        token.coinGeckoId != null &&
        token.coinGeckoId!.isNotEmpty) {
      price = _tokenPriceCache[token.coinGeckoId] ?? 0.0;
    }
    // Fallback: infer from the counterpart token via quote rate.
    if (price <= 0 && _currentQuote != null) {
      final fromAmt = _parseAmount(_fromController);
      final toAmt = _parseAmount(_toController);
      if (fromAmt > 0 && toAmt > 0) {
        final isFrom = _tokensAreIdentical(token, _fromToken);
        final other = isFrom ? _toToken : _fromToken;
        double otherPrice = other?.unitPriceUsd ?? 0.0;
        if (otherPrice <= 0 &&
            other?.coinGeckoId != null &&
            other!.coinGeckoId!.isNotEmpty) {
          otherPrice = _tokenPriceCache[other.coinGeckoId] ?? 0.0;
        }
        if (otherPrice > 0) {
          // Total USD of the counterpart side
          final otherUsd = (isFrom ? toAmt : fromAmt) * otherPrice;
          final thisAmt = isFrom ? fromAmt : toAmt;
          price = otherUsd / thisAmt;
        }
      }
    }
    return amount * price;
  }

  double _estimateReferralSwapAmountUsd({
    required Token fromToken,
    required String fromAmountText,
    required SwapQuote quote,
  }) {
    final typedAmount = _parseAmount(_fromController);
    final directAmount = typedAmount > 0
        ? typedAmount
        : (double.tryParse(fromAmountText.replaceAll(',', '')) ?? 0.0);
    final directUsd = _usdValueFor(fromToken, directAmount);
    if (directUsd > 0) {
      return directUsd;
    }

    final feeUsd = quote.platformFeeUsd;
    if (feeUsd <= 0) {
      return 0.0;
    }

    if (quote.platformFeeBps >= 1000) {
      return feeUsd / 0.10;
    }

    if ((feeUsd - 1.0).abs() < 0.0001 || (quote.platformFeeBps > 100)) {
      return 10.0;
    }

    if (quote.platformFeeBps == 100) {
      return feeUsd / 0.01;
    }

    final feeRate = quote.platformFeePercent / 100.0;
    if (feeRate > 0) {
      return feeUsd / feeRate;
    }

    return 0.0;
  }

  /// Returns the native token's USD price from the cache or token model.
  double get _nativeTokenPriceUsd {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final nativeId = blockchain.activeChain.coinGeckoId;
    if (nativeId != null && nativeId.isNotEmpty) {
      final cached = _tokenPriceCache[nativeId];
      if (cached != null && cached > 0) return cached;
    }
    // Fallback: check the first token (native) in the list.
    final tokens = blockchain.tokens;
    if (tokens.isNotEmpty && tokens.first.unitPriceUsd > 0) {
      return tokens.first.unitPriceUsd;
    }
    return 0.0;
  }

  bool _tokensAreIdentical(Token? a, Token? b) {
    if (a == null || b == null) return false;
    final addrA = (a.contractAddress ?? '').toLowerCase();
    final addrB = (b.contractAddress ?? '').toLowerCase();
    if (addrA.isNotEmpty && addrB.isNotEmpty) {
      return addrA == addrB;
    }
    if (addrA.isEmpty && addrB.isEmpty) {
      return a.symbol.toLowerCase() == b.symbol.toLowerCase();
    }
    return false;
  }

  bool _tokenRequiresApproval(Token token) {
    final contract = token.contractAddress ?? '';
    return contract.isNotEmpty;
  }

  bool get _canOfferGaslessToggle {
    final from = _fromToken;
    return _isGaslessSupported && from != null && _tokenRequiresApproval(from);
  }

  void _resetQuoteState({
    bool clearInputAmounts = false,
    bool preserveRequestId = false,
    bool clearQuoteStatusMessage = true,
  }) {
    if (!preserveRequestId) {
      _quoteRequestId++;
    }
    _pricing = '';
    if (clearQuoteStatusMessage) {
      _quoteStatusMessage = null;
    }
    _currentQuote = null;
    _feeUsd = 0.0;
    _feeNative = 0.0;
    _platformFeeUsd = 0.0;
    _toController.clear();
    if (clearInputAmounts) {
      _fromController.clear();
      _selectedPercentage = -1;
      _selectedLimitPriceAdjustment = 0;
    }
  }

  bool _isGaslessSourceUnsupported({bool? gaslessEnabled}) {
    final from = _fromToken;
    if (from == null) return false;
    final enabled = gaslessEnabled ?? _isGasless;
    return enabled && !_tokenRequiresApproval(from);
  }

  String _shortHash(String hash) {
    if (hash.length <= 10) return hash;
    return '${hash.substring(0, 6)}...${hash.substring(hash.length - 4)}';
  }

  String? _transactionDetailsUrl(String hash) {
    if (!_looksLikeTxHash(hash)) {
      return null;
    }
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final explorerUrl = blockchain.activeChain.explorerUrl?.trim();
    if (explorerUrl == null || explorerUrl.isEmpty) {
      return null;
    }
    final normalized = explorerUrl.endsWith('/')
        ? explorerUrl.substring(0, explorerUrl.length - 1)
        : explorerUrl;
    return '$normalized/tx/$hash';
  }

  void _recordSwapHistory({
    required String fromAmount,
    required String fromTokenName,
    required String fromTokenSymbol,
    required String toAmount,
    required String toTokenSymbol,
    required String networkName,
    required int chainId,
    String? txHash,
  }) {
    if (_walletAddress == null) {
      return;
    }
    unawaited(
      _walletHistoryService.recordSwapConfirmed(
        walletAddress: _walletAddress!,
        txHash: txHash,
        chainId: chainId,
        networkName: networkName,
        fromTokenName: fromTokenName,
        fromTokenSymbol: fromTokenSymbol,
        fromAmount: fromAmount,
        toAmount: toAmount,
        toTokenSymbol: toTokenSymbol,
      ),
    );
  }

  String _gaslessApprovalFundingMessage({
    required Token token,
    required BlockchainService blockchain,
    BigInt? estimatedApprovalFeeWei,
  }) {
    final nativeSymbol = blockchain.activeChain.symbol;
    final tokenSymbol = token.symbol;
    final approxFee =
        estimatedApprovalFeeWei != null && estimatedApprovalFeeWei > BigInt.zero
        ? AmountUtils.formatBaseUnits(
            estimatedApprovalFeeWei,
            18,
            maxFractionDigits: 6,
          )
        : null;
    final feeSuffix = approxFee != null && approxFee != '0'
        ? ' Add about $approxFee $nativeSymbol to cover that approval.'
        : ' Add a small amount of $nativeSymbol to cover that approval.';
    return 'Gasless swap still needs a one-time $tokenSymbol approval paid in $nativeSymbol.$feeSuffix';
  }

  String _limitApprovalFundingMessage({
    required Token token,
    required BlockchainService blockchain,
    BigInt? estimatedApprovalFeeWei,
  }) {
    final nativeSymbol = blockchain.activeChain.symbol;
    final tokenSymbol = token.symbol;
    final approxFee =
        estimatedApprovalFeeWei != null && estimatedApprovalFeeWei > BigInt.zero
        ? AmountUtils.formatBaseUnits(
            estimatedApprovalFeeWei,
            18,
            maxFractionDigits: 6,
          )
        : null;
    final feeSuffix = approxFee != null && approxFee != '0'
        ? ' Add about $approxFee $nativeSymbol to continue.'
        : ' Add a small amount of $nativeSymbol to continue.';
    return '$tokenSymbol needs a one-time approval before limit orders can use it.$feeSuffix';
  }

  Future<bool> _ensureGaslessApprovalFunding({
    required Token token,
    required SwapQuote quote,
    required BlockchainService blockchain,
    required TransactionProgressController progressController,
  }) async {
    if (!_isGasless ||
        !quote.needsAllowance ||
        quote.gaslessApprovalAvailable ||
        _walletAddress == null) {
      return true;
    }

    final estimatedApprovalFeeWei = await _tokenApprovalService
        .estimateApprovalFeeWei(
          token: token,
          ownerAddress: _walletAddress!,
          blockchain: blockchain,
          allowanceTarget: quote.allowanceSpender ?? quote.allowanceTarget,
        );

    if (estimatedApprovalFeeWei == null ||
        estimatedApprovalFeeWei <= BigInt.zero) {
      return true;
    }

    final nativeBalanceWei = await blockchain.getNativeBalanceBaseUnits(
      _walletAddress!,
    );
    if (nativeBalanceWei >= estimatedApprovalFeeWei) {
      return true;
    }

    progressController.setError(
      _gaslessApprovalFundingMessage(
        token: token,
        blockchain: blockchain,
        estimatedApprovalFeeWei: estimatedApprovalFeeWei,
      ),
    );
    return false;
  }

  void _clearSubmittedSwapState() {
    if (!mounted) return;
    setState(() {
      _resetQuoteState(clearInputAmounts: true);
    });
  }

  TransactionProgressController _openProgressFlow({
    TransactionProgressFlow flow = TransactionProgressFlow.swap,
  }) {
    final controller = TransactionProgressController(flow: flow);
    unawaited(
      Navigator.of(context)
          .pushNamed(
            '/transaction-processing',
            arguments: TransactionProcessingArguments(controller: controller),
          )
          .whenComplete(controller.dispose),
    );
    return controller;
  }

  bool _looksLikeTxHash(String value) {
    return RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(value);
  }

  String _mapErrorMessage(String? raw) {
    final l = AppLocalizations.of(context);
    if (raw == null || raw.isEmpty) {
      return '${l.swapFailedTitle}. ${l.tryAgain}.';
    }
    final lower = raw.toLowerCase();
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final nativeSymbol = blockchain.activeChain.symbol;
    if (lower.contains('unable to fetch a swap price right now') ||
        lower.contains('upstream request failed') ||
        lower.contains('unable to fetch a swap quote right now') ||
        lower.contains('unable to prepare the swap transaction right now')) {
      return l.noQuoteAvailable;
    }
    if (_isGasless &&
        _currentQuote?.needsAllowance == true &&
        (lower.contains('insufficient funds') ||
            lower.contains('insufficient native gas') ||
            lower.contains('funds for gas') ||
            lower.contains('gas required exceeds allowance'))) {
      final fromToken = _fromToken;
      if (fromToken != null) {
        return _gaslessApprovalFundingMessage(
          token: fromToken,
          blockchain: blockchain,
        );
      }
      return 'Gasless swap still needs a one-time token approval paid in $nativeSymbol.';
    }
    if (_activeTab == SwapTab.limit &&
        (lower.contains('insufficient funds') ||
            lower.contains('insufficient native gas') ||
            lower.contains('funds for gas') ||
            lower.contains('gas required exceeds allowance'))) {
      final fromToken = _fromToken;
      if (fromToken != null) {
        return _limitApprovalFundingMessage(
          token: fromToken,
          blockchain: blockchain,
        );
      }
      return 'A one-time token approval needs network gas paid in $nativeSymbol.';
    }
    if (lower.contains('insufficientallowance') ||
        lower.contains('order owner must give allowance') ||
        lower.contains('token approval is required') ||
        lower.contains('missing allowance target')) {
      final tokenSymbol = _fromToken?.symbol ?? 'sell token';
      return 'Approve $tokenSymbol first, then submit the limit order again.';
    }
    if (lower.contains('insufficient funds')) {
      return 'You do not have enough $nativeSymbol to cover the amount and gas fees.';
    }
    if (lower.contains('insufficient_balance') ||
        lower.contains('insufficient balance')) {
      final tokenSymbol = _fromToken?.symbol ?? 'token';
      return 'You do not have enough $tokenSymbol for this swap amount.';
    }
    if (lower.contains('sell_amount_too_small') ||
        lower.contains('buy_amount_too_small') ||
        lower.contains('provided sell amount is too small') ||
        lower.contains('provided buy amount is too small') ||
        lower.contains('minsellamount') ||
        lower.contains('minbuyamount') ||
        lower.contains('minimum sell amount') ||
        lower.contains('minimum buy amount') ||
        lower.contains('too small to cover fees required to execute swap')) {
      return 'Swap output amount is too small to cover fees required to execute swap';
    }
    if (lower.contains('invalid chain id')) {
      return l.noQuoteAvailable;
    }
    if (lower.contains('swap validation failed') ||
        lower.contains('swap_validation_failed')) {
      return 'Route unavailable or insufficient liquidity for this pair. Please adjust the amount or try a different pair.';
    }
    if (lower.contains('connection refused') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('timed out')) {
      return 'Swap service is temporarily unavailable. Please try again shortly.';
    }
    if (lower.contains(
      'selling native token is not supported for gasless trades',
    )) {
      return 'Gasless mode only supports ERC-20 source tokens. Select a token like USDC/USDT.';
    }
    if (lower.contains('no route found') || lower.contains('no liquidity')) {
      return 'No route found for this pair on this network right now.';
    }
    if (lower.contains('user denied') ||
        lower.contains('user rejected') ||
        lower.contains('user canceled')) {
      return 'Transaction was cancelled.';
    }
    if (lower.contains('nonce too low')) {
      return 'Transaction nonce is too low. Please wait for pending transactions to finish.';
    }
    return AppErrorUtils.userMessage(
      raw,
      fallback: '${l.swapFailedTitle}. ${l.tryAgain}.',
    );
  }

  String? _extractGaslessStatusValue(Map<String, dynamic> data) {
    final direct = data['status']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final trade = data['trade'];
    if (trade is Map<String, dynamic>) {
      final nested = trade['status']?.toString();
      if (nested != null && nested.isNotEmpty) return nested;
    }
    final result = data['result'];
    if (result is Map<String, dynamic>) {
      final nested = result['status']?.toString();
      if (nested != null && nested.isNotEmpty) return nested;
    }
    return null;
  }

  String? _extractGaslessTxHash(Map<String, dynamic> data) {
    final direct = _extractExplicitGaslessTxHash(data);
    if (direct != null) return direct;
    final trade = data['trade'];
    if (trade is Map<String, dynamic>) {
      final nested = _extractExplicitGaslessTxHash(trade);
      if (nested != null) return nested;
      final listed = _extractTransactionListHash(trade['transactions']);
      if (listed != null) return listed;
    }
    final result = data['result'];
    if (result is Map<String, dynamic>) {
      final nested = _extractExplicitGaslessTxHash(result);
      if (nested != null) return nested;
      final listed = _extractTransactionListHash(result['transactions']);
      if (listed != null) return listed;
    }
    return null;
  }

  String? _extractExplicitGaslessTxHash(Map<String, dynamic> data) {
    const candidateKeys = [
      'transactionHash',
      'txHash',
      'settlementTxHash',
      'settledTxHash',
      'fillTxHash',
    ];
    for (final key in candidateKeys) {
      final value = data[key]?.toString();
      if (value != null && _looksLikeTxHash(value)) {
        return value;
      }
    }
    return null;
  }

  String? _extractTransactionListHash(dynamic transactions) {
    if (transactions is! List) {
      return null;
    }
    for (final entry in transactions) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }
      final explicit = _extractExplicitGaslessTxHash(entry);
      if (explicit != null) {
        return explicit;
      }
      final listedHash = entry['hash']?.toString();
      if (listedHash != null && _looksLikeTxHash(listedHash)) {
        return listedHash;
      }
    }
    return null;
  }

  void _applyOptimisticSwapResult({
    required BlockchainService blockchain,
    required Token fromToken,
    required Token toToken,
    required String fromAmountText,
    required String toAmountText,
  }) {
    final address = _walletAddress;
    if (address == null || address.isEmpty) {
      return;
    }
    final chainId = blockchain.activeChain.chainId;
    blockchain.applyOptimisticSwap(
      walletAddress: address,
      chainId: chainId,
      fromToken: fromToken,
      toToken: toToken,
      fromAmountText: fromAmountText,
      toAmountText: toAmountText,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _syncSelectedTokens(_visibleTokensForChain(blockchain.tokens, chainId));
    });
  }

  Future<void> _trackGaslessOrder(
    String tradeHash, {
    required TransactionProgressController progressController,
    required BlockchainService blockchain,
    required int chainId,
    required Token fromToken,
    required Token toToken,
    required String fromAmountText,
    required String fromSymbol,
    required String toAmountText,
    required String toSymbol,
    required String networkName,
    bool rewardReferralOnSwap = false,
    double swapAmountUsd = 0.0,
  }) async {
    final l = AppLocalizations.of(context);
    const pendingStates = {
      'pending',
      'submitted',
      'queued',
      'processing',
      'validating',
      'open',
    };
    const successStates = {
      'success',
      'succeeded',
      'complete',
      'completed',
      'confirmed',
      'settled',
      'executed',
      'filled',
    };
    const failedStates = {
      'failed',
      'expired',
      'cancelled',
      'canceled',
      'rejected',
      'invalid',
    };

    var failedStatusStreak = 0;
    for (var attempt = 0; attempt < 20; attempt++) {
      await Future<void>.delayed(_gaslessStatusPollInterval);
      if (!mounted) return;

      final statusData = await _swapService.getGaslessStatus(
        tradeHash: tradeHash,
        chainId: chainId,
      );
      if (statusData == null) {
        continue;
      }

      final status = _extractGaslessStatusValue(statusData)?.toLowerCase();
      final txHash = _extractGaslessTxHash(statusData);

      if (txHash != null && _looksLikeTxHash(txHash)) {
        progressController.setSwapPending(
          reference: _shortHash(txHash),
          detailsUrl: _transactionDetailsUrl(txHash),
        );
        final confirmed = await _waitForTxConfirmation(
          txHash,
          rewardReferralOnSwap: rewardReferralOnSwap,
          swapAmountUsd: swapAmountUsd,
        );
        if (!mounted) return;
        if (confirmed) {
          _applyOptimisticSwapResult(
            blockchain: blockchain,
            fromToken: fromToken,
            toToken: toToken,
            fromAmountText: fromAmountText,
            toAmountText: toAmountText,
          );
          if (_walletAddress != null) {
            unawaited(
              _walletNotificationService.notifySwapConfirmed(
                walletAddress: _walletAddress!,
                chainId: chainId,
                txHash: txHash,
                fromAmount: fromAmountText,
                fromSymbol: fromSymbol,
                toAmount: toAmountText,
                toSymbol: toSymbol,
                networkName: networkName,
              ),
            );
            _recordSwapHistory(
              txHash: txHash,
              fromAmount: fromAmountText,
              fromTokenName: fromSymbol,
              fromTokenSymbol: fromSymbol,
              toAmount: toAmountText,
              toTokenSymbol: toSymbol,
              networkName: networkName,
              chainId: chainId,
            );
          }
          progressController.setSuccess(
            reference: _shortHash(txHash),
            detailsUrl: _transactionDetailsUrl(txHash),
          );
        } else {
          progressController.setError(
            l.transactionPendingConfirmation,
            reference: _shortHash(txHash),
            detailsUrl: _transactionDetailsUrl(txHash),
          );
        }
        return;
      }

      if (status != null && successStates.contains(status)) {
        failedStatusStreak = 0;
        _applyOptimisticSwapResult(
          blockchain: blockchain,
          fromToken: fromToken,
          toToken: toToken,
          fromAmountText: fromAmountText,
          toAmountText: toAmountText,
        );
        if (_walletAddress != null) {
          final notificationTxHash = _looksLikeTxHash(tradeHash)
              ? tradeHash
              : null;
          if (notificationTxHash != null) {
            unawaited(
              _walletNotificationService.notifySwapConfirmed(
                walletAddress: _walletAddress!,
                chainId: chainId,
                txHash: notificationTxHash,
                fromAmount: fromAmountText,
                fromSymbol: fromSymbol,
                toAmount: toAmountText,
                toSymbol: toSymbol,
                networkName: networkName,
              ),
            );
          }
          _recordSwapHistory(
            txHash: _looksLikeTxHash(tradeHash) ? tradeHash : null,
            fromAmount: fromAmountText,
            fromTokenName: fromSymbol,
            fromTokenSymbol: fromSymbol,
            toAmount: toAmountText,
            toTokenSymbol: toSymbol,
            networkName: networkName,
            chainId: chainId,
          );
        }
        progressController.setSuccess(reference: _shortHash(tradeHash));
        unawaited(
          _runPostConfirmSwapSideEffects(
            blockchain: blockchain,
            txHash: null,
            rewardReferralOnSwap: rewardReferralOnSwap,
            swapAmountUsd: swapAmountUsd,
          ),
        );
        return;
      }

      if (status != null && failedStates.contains(status)) {
        failedStatusStreak += 1;
        if (failedStatusStreak < 3 && attempt < 19) {
          continue;
        }
        progressController.setError(
          l.gaslessOrderFailedRetry,
          reference: _shortHash(tradeHash),
        );
        return;
      }

      if (status == null || pendingStates.contains(status)) {
        failedStatusStreak = 0;
        continue;
      }
    }

    if (mounted) {
      progressController.setGaslessPending(reference: _shortHash(tradeHash));
    }
  }

  Future<void> _refreshWalletState({BlockchainService? blockchain}) async {
    final address = _walletAddress;
    if (address == null) return;
    final activeBlockchain =
        blockchain ?? Provider.of<BlockchainService>(context, listen: false);
    final chainId = activeBlockchain.activeChain.chainId;
    await activeBlockchain.refreshWalletTokens(address, chainId: chainId);
    await _refreshTokenPrices();
    if (!mounted) return;
    setState(() {
      _syncSelectedTokens(
        _visibleTokensForChain(activeBlockchain.tokens, chainId),
      );
    });
    unawaited(
      Future<void>.delayed(_followUpWalletRefreshDelay, () async {
        try {
          await activeBlockchain.refreshWalletTokens(address, chainId: chainId);
          await _refreshTokenPrices();
          if (!mounted) return;
          setState(() {
            _syncSelectedTokens(
              _visibleTokensForChain(activeBlockchain.tokens, chainId),
            );
          });
        } catch (_) {}
      }),
    );
  }

  Future<void> _runPostConfirmSwapSideEffects({
    required BlockchainService blockchain,
    required String? txHash,
    required bool rewardReferralOnSwap,
    required double swapAmountUsd,
  }) async {
    if (rewardReferralOnSwap &&
        _walletAddress != null &&
        txHash != null &&
        _looksLikeTxHash(txHash)) {
      try {
        await _referralService.rewardOnSwap(
          walletAddress: _walletAddress!,
          txHash: txHash,
          swapAmountUsd: swapAmountUsd,
        );
      } catch (e) {
        debugPrint('Referral reward-on-swap failed: $e');
      }
    }

    await _refreshWalletState(blockchain: blockchain);
  }

  Future<bool> _waitForTxConfirmation(
    String txHash, {
    bool rewardReferralOnSwap = false,
    double swapAmountUsd = 0.0,
  }) async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final confirmed = await _transactionMonitor.waitForConfirmation(
      txHash: txHash,
      blockchain: blockchain,
    );
    if (confirmed) {
      unawaited(
        _runPostConfirmSwapSideEffects(
          blockchain: blockchain,
          txHash: txHash,
          rewardReferralOnSwap: rewardReferralOnSwap,
          swapAmountUsd: swapAmountUsd,
        ),
      );
      return true;
    }
    return false;
  }

  Future<void> _getQuote() async {
    final l = AppLocalizations.of(context);
    if (_fromToken == null || _toToken == null) return;
    if (_tokensAreIdentical(_fromToken, _toToken)) {
      setState(() {
        _resetQuoteState();
      });
      return;
    }
    final amountText = _fromController.text;
    final amount = _parseDecimalAmount(amountText);
    if (amount <= Decimal.zero) {
      setState(() {
        _resetQuoteState();
      });
      return;
    }

    final requestId = ++_quoteRequestId;
    setState(() {
      _isCalculating = true;
      _quoteStatusMessage = null;
    });
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    if (!_swapService.isChainSupported(
      blockchain.activeChain.chainId,
      isGasless: _isGasless,
    )) {
      setState(() {
        _quoteStatusMessage = l.networkError;
        _resetQuoteState(clearQuoteStatusMessage: false);
        _isCalculating = false;
      });
      return;
    }
    if (_isGaslessSourceUnsupported()) {
      setState(() {
        _quoteStatusMessage = l.networkError;
        _resetQuoteState(clearQuoteStatusMessage: false);
        _isCalculating = false;
      });
      return;
    }

    try {
      final amountWei = _toWeiAmount(
        _fromController.text,
        _fromToken!.decimals,
      );
      if (amountWei == null || amountWei == '0') {
        if (mounted && requestId == _quoteRequestId) {
          setState(() {
            _quoteStatusMessage = l.enterValidAmount;
            _resetQuoteState(clearQuoteStatusMessage: false);
          });
        }
        return;
      }

      final quote = await _swapService
          .get0xQuote(
            chainId: blockchain.activeChain.chainId,
            fromTokenAddress: _fromToken!.contractAddress ?? '',
            toTokenAddress: _toToken!.contractAddress ?? '',
            amountWei: amountWei,
            buyTokenDecimals: _toToken!.decimals,
            isGasless: _isGasless,
            walletAddress: _walletAddress,
            slippageBps: _slippageBps,
          )
          .timeout(_quoteUiTimeout);

      if (!mounted || requestId != _quoteRequestId) return;

      if (quote != null) {
        final rawOutAmount = double.tryParse(quote.amountOutFormatted) ?? 0.0;
        final inAmount = _parseAmount(_fromController);
        final unitRate = inAmount > 0 ? (rawOutAmount / inAmount) : 0.0;
        double feeNative = quote.networkFeeNative;
        double feeUsd = quote.networkFeeUsd > 0
            ? quote.networkFeeUsd
            : quote.networkFeeNative * _nativeTokenPriceUsd;

        // Fallback: estimate gas fee if backend did not return fee fields.
        if (!_isGasless && feeNative <= 0 && feeUsd <= 0) {
          var nativePrice = _nativeTokenPriceUsd;
          if (nativePrice <= 0) {
            await _refreshTokenPrices();
            nativePrice = _nativeTokenPriceUsd;
          }
          final estimate = await blockchain.estimateGasFee(
            nativePriceUsd: nativePrice,
          );
          feeNative = estimate['totalFeeEth'] ?? 0.0;
          feeUsd = estimate['totalFeeUsd'] ?? 0.0;
        }

        if (!mounted || requestId != _quoteRequestId) return;
        setState(() {
          _pricing = _formatRateText(unitRate);
          _quoteStatusMessage = null;
          _toController.text = quote.amountOutFormatted;
          _currentQuote = quote;
          _feeNative = feeNative;
          _feeUsd = feeUsd;
          _platformFeeUsd = quote.platformFeeUsd;
        });
      } else {
        final mapped = _mapErrorMessage(_swapService.lastError);
        setState(() {
          _quoteStatusMessage = mapped;
          _resetQuoteState(
            preserveRequestId: true,
            clearQuoteStatusMessage: false,
          );
        });
      }
    } on TimeoutException {
      if (mounted && requestId == _quoteRequestId) {
        setState(() {
          _quoteStatusMessage = l.tryAgain;
          _resetQuoteState(
            preserveRequestId: true,
            clearQuoteStatusMessage: false,
          );
        });
      }
    } catch (e) {
      if (mounted && requestId == _quoteRequestId) {
        setState(() {
          _quoteStatusMessage = _mapErrorMessage(e.toString());
          _resetQuoteState(
            preserveRequestId: true,
            clearQuoteStatusMessage: false,
          );
        });
      }
    } finally {
      if (mounted && requestId == _quoteRequestId) {
        setState(() => _isCalculating = false);
      }
    }
  }

  void _swapTokens() {
    setState(() {
      final temp = _fromToken;
      _fromToken = _toToken;
      _toToken = temp;
      _applySuggestedLimitSide();
      _resetQuoteState(clearInputAmounts: true);
      if (_isGasless && _isGaslessSourceUnsupported()) {
        _isGasless = false;
      }
    });
    // Reactivate live tracking for swapped token pair
    _activateSwapLiveTracking();
    if (_activeTab == SwapTab.limit) {
      _updateLimitPreview();
    }
  }

  void _updateLimitPreview() {
    final from = _fromToken;
    final to = _toToken;
    var nextToAmount = '';
    if (from == null || to == null) {
    } else {
      final fromAmount = _parseDecimalAmount(_fromController.text);
      final limitPrice = _parseDecimalAmount(_limitPriceController.text);
      if (fromAmount > Decimal.zero && limitPrice > Decimal.zero) {
        // Buy mode: user enters price of toToken in fromToken units.
        //   toAmount = fromAmount / limitPrice
        // Sell mode: user enters price of fromToken in toToken units.
        //   toAmount = fromAmount * limitPrice
        final Decimal toAmount;
        if (_isBuyMode) {
          // Compute fromAmount / limitPrice using Rational intermediary
          final rational = fromAmount.toRational() / limitPrice.toRational();
          toAmount = rational.toDecimal(scaleOnInfinitePrecision: 18);
        } else {
          toAmount = fromAmount * limitPrice;
        }
        final displayDecimals = to.decimals > 6 ? 6 : to.decimals;
        nextToAmount = _formatDecimalInput(toAmount, displayDecimals);
      }
    }

    final shouldClearFeePreview =
        _platformFeeUsd != 0.0 || _feeUsd != 0.0 || _feeNative != 0.0;

    if (_toController.text == nextToAmount && !shouldClearFeePreview) {
      return;
    }

    if (!mounted) {
      _toController.text = nextToAmount;
      _platformFeeUsd = 0.0;
      _feeUsd = 0.0;
      _feeNative = 0.0;
      return;
    }

    setState(() {
      _toController.text = nextToAmount;
      _platformFeeUsd = 0.0;
      _feeUsd = 0.0;
      _feeNative = 0.0;
    });
  }

  List<LimitOrderSummary> get _activeChainLimitOrders {
    final chainId = Provider.of<BlockchainService>(
      context,
      listen: false,
    ).activeChain.chainId;
    final orders = _limitOrders.where((order) {
      return order.chainId == chainId && order.status.toLowerCase() == 'open';
    }).toList();
    orders.sort((left, right) => left.expiry.compareTo(right.expiry));
    return orders;
  }

  Future<void> _refreshLimitOrders({
    bool showLoading = true,
    bool surfaceErrors = false,
  }) async {
    final walletAddress = _walletAddress;
    if (walletAddress == null || walletAddress.isEmpty) {
      if (mounted) {
        setState(() {
          _limitOrders = const [];
          _isLoadingLimitOrders = false;
        });
      }
      return;
    }

    if (showLoading && mounted) {
      setState(() => _isLoadingLimitOrders = true);
    }

    final orders = await _swapService.getLimitOrders(
      walletAddress: walletAddress,
    );
    if (!mounted) return;

    if (_swapService.lastError != null && _swapService.lastError!.isNotEmpty) {
      setState(() => _isLoadingLimitOrders = false);
      if (surfaceErrors) {
        _showError(_mapErrorMessage(_swapService.lastError));
      }
      return;
    }

    setState(() {
      _limitOrders = orders;
      _isLoadingLimitOrders = false;
    });
  }

  Future<void> _cancelLimitOrder(LimitOrderSummary order) async {
    final walletAddress = _walletAddress;
    final orderUid = order.orderUid;
    if (walletAddress == null || walletAddress.isEmpty) {
      _showError('Connect your wallet to manage limit orders.');
      return;
    }
    if (orderUid == null || orderUid.isEmpty) {
      _showError('This limit order cannot be cancelled right now.');
      return;
    }
    if (_cancellingLimitOrderIds.contains(order.id)) {
      return;
    }

    setState(() => _cancellingLimitOrderIds.add(order.id));
    try {
      final typedData = buildCowOrderCancellationTypedData(
        chainId: order.chainId,
        orderUids: [orderUid],
      );
      final signature = await _walletService.signTypedDataForAddress(
        walletAddress,
        jsonEncode(typedData),
      );
      final cancelled = await _swapService.cancelLimitOrder(
        orderId: order.id,
        walletAddress: walletAddress,
        signature: signature,
      );
      if (!mounted) return;

      if (!cancelled) {
        _showError(_mapErrorMessage(_swapService.lastError));
        return;
      }

      ToastUtils.showSuccess('Limit order cancelled');
      await _refreshLimitOrders(showLoading: false);
    } catch (e) {
      _showError(_mapErrorMessage(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _cancellingLimitOrderIds.remove(order.id));
      }
    }
  }

  Future<void> _hideLimitTutorialControl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_limitTutorialControlHiddenKey, true);
    if (!mounted) return;
    setState(() => _limitTutorialControlHidden = true);
  }

  Future<void> _startLimitShowcaseIfNeeded({bool force = false}) async {
    if ((!force && _limitShowcaseScheduled) ||
        !mounted ||
        _activeTab != SwapTab.limit) {
      return;
    }
    if (!force) {
      _limitShowcaseScheduled = true;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!force) {
      final hasSeenShowcase = prefs.getBool(_limitShowcaseSeenKey) ?? false;
      if (hasSeenShowcase || !mounted || _activeTab != SwapTab.limit) {
        return;
      }
      await prefs.setBool(_limitShowcaseSeenKey, true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeTab != SwapTab.limit) {
        return;
      }
      ShowcaseView.get().startShowCase([
        _limitTabShowcaseKey,
        _limitAmountsShowcaseKey,
        _limitExecutionPriceShowcaseKey,
        _limitExpiryShowcaseKey,
        _limitSummaryShowcaseKey,
        _limitSubmitShowcaseKey,
      ]);
    });
  }

  int _resolveLimitExpirySeconds() {
    final now = DateTime.now();
    switch (_limitExpiryOption) {
      case _LimitExpiryOption.minutes15:
        return now.add(const Duration(minutes: 15)).millisecondsSinceEpoch ~/
            1000;
      case _LimitExpiryOption.hour1:
        return now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      case _LimitExpiryOption.hours4:
        return now.add(const Duration(hours: 4)).millisecondsSinceEpoch ~/ 1000;
      case _LimitExpiryOption.hours24:
        return now.add(const Duration(hours: 24)).millisecondsSinceEpoch ~/
            1000;
      case _LimitExpiryOption.days7:
        return now.add(const Duration(days: 7)).millisecondsSinceEpoch ~/ 1000;
      case _LimitExpiryOption.never:
        return resolveCowNeverValidTo(now: now);
      case _LimitExpiryOption.custom:
        final custom = _customExpiryDate ?? now.add(const Duration(days: 1));
        final normalized = DateTime(
          custom.year,
          custom.month,
          custom.day,
          23,
          59,
        );
        return normalized.millisecondsSinceEpoch ~/ 1000;
    }
  }

  String _limitExpiryLabel() {
    switch (_limitExpiryOption) {
      case _LimitExpiryOption.minutes15:
        return '15M';
      case _LimitExpiryOption.hour1:
        return '1H';
      case _LimitExpiryOption.hours4:
        return '4H';
      case _LimitExpiryOption.hours24:
        return '24H';
      case _LimitExpiryOption.days7:
        return '7D';
      case _LimitExpiryOption.never:
        return 'Never';
      case _LimitExpiryOption.custom:
        final custom = _customExpiryDate;
        if (custom == null) return 'Custom';
        return '${custom.day}/${custom.month}/${custom.year}';
    }
  }

  Future<void> _pickCustomExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customExpiryDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _customExpiryDate = picked;
      _limitExpiryOption = _LimitExpiryOption.custom;
    });
  }

  Future<void> _submitLimitOrder() async {
    final l = AppLocalizations.of(context);
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final chainId = blockchain.activeChain.chainId;
    if (_walletAddress == null || _walletAddress!.isEmpty) {
      _showError(l.noActiveWalletFound);
      return;
    }
    if (!_swapService.isLimitChainSupported(chainId)) {
      _showError(_limitUnsupportedMessage());
      return;
    }
    final from = _fromToken;
    final to = _toToken;
    if (from == null || to == null) {
      _showError(l.selectTokenTitle);
      return;
    }
    if (_tokensAreIdentical(from, to)) {
      _showError(l.tryAgain);
      return;
    }
    if ((from.contractAddress ?? '').isEmpty ||
        (to.contractAddress ?? '').isEmpty) {
      _showError('Limit orders require ERC-20 tokens.');
      return;
    }
    if (!_tokenRequiresApproval(from) || !_tokenRequiresApproval(to)) {
      _showError('Limit orders currently support ERC-20 token pairs only.');
      return;
    }
    final makerAmount = _parseDecimalAmount(_fromController.text);
    final limitPrice = _parseDecimalAmount(_limitPriceController.text);
    if (makerAmount <= Decimal.zero || limitPrice <= Decimal.zero) {
      _showError(l.enterValidAmount);
      return;
    }
    final makerAmountWei = _toWeiAmount(_fromController.text, from.decimals);
    if (makerAmountWei == null || makerAmountWei == '0') {
      _showError(l.enterValidAmount);
      return;
    }
    // Buy mode: the user is selling a stablecoin to buy the target token.
    // Sell mode: the user is selling the target token for the quote token.
    final Decimal buyAmountDecimal;
    if (_isBuyMode) {
      final rational = makerAmount.toRational() / limitPrice.toRational();
      buyAmountDecimal = rational.toDecimal(scaleOnInfinitePrecision: 18);
    } else {
      buyAmountDecimal = makerAmount * limitPrice;
    }
    final buyAmountWei = AmountUtils.parseDecimalToBaseUnits(
      buyAmountDecimal.toString(),
      to.decimals,
    ).toString();
    if (buyAmountWei == '0') {
      _showError(l.enterValidAmount);
      return;
    }
    final allowanceTarget = cowVaultRelayerForChain(chainId);
    if (allowanceTarget == null || allowanceTarget.isEmpty) {
      _showError(_limitUnsupportedMessage());
      return;
    }

    if (_isSubmittingLimit) return;
    setState(() => _isSubmittingLimit = true);
    TransactionProgressController? progressController;
    try {
      final approvalResult = await _tokenApprovalService
          .ensureApproval(
            token: from,
            amountWei: makerAmountWei,
            ownerAddress: _walletAddress!,
            blockchain: blockchain,
            allowanceTarget: allowanceTarget,
            onApprovalNeeded: () {
              if (!mounted) return;
              progressController ??= _openProgressFlow(
                flow: TransactionProgressFlow.generic,
              );
              progressController!.setApprovalPending();
            },
          )
          .timeout(_approvalUiTimeout);

      if (!mounted) return;

      if (approvalResult.hasError) {
        final message = _mapErrorMessage(approvalResult.error);
        progressController?.setError(message);
        if (progressController == null) {
          _showError(message);
        }
        return;
      }

      if (approvalResult.approvalSubmitted &&
          approvalResult.transactionHash != null) {
        final txHash = approvalResult.transactionHash!;
        progressController ??= _openProgressFlow(
          flow: TransactionProgressFlow.generic,
        );
        progressController!.setApprovalPending(
          reference: _shortHash(txHash),
          detailsUrl: _transactionDetailsUrl(txHash),
        );
        final confirmed = await _waitForTxConfirmation(txHash);
        if (!confirmed) {
          progressController!.setError(
            l.approvalPendingConfirmation,
            reference: _shortHash(txHash),
            detailsUrl: _transactionDetailsUrl(txHash),
          );
          return;
        }
      }

      final order = buildCowLimitOrderPayload(
        sellToken: from.contractAddress!,
        buyToken: to.contractAddress!,
        receiver: _walletAddress!,
        sellAmount: makerAmountWei,
        buyAmount: buyAmountWei,
        validTo: _resolveLimitExpirySeconds(),
        kind: _currentLimitKind,
      );

      progressController?.setSwapSubmitting();
      final typedData = buildCowOrderTypedData(chainId: chainId, order: order);
      final signature = await _walletService.signTypedDataForAddress(
        _walletAddress!,
        jsonEncode(typedData),
      );

      final result = await _swapService.createLimitOrder(
        chainId: chainId,
        walletAddress: _walletAddress!,
        order: order,
        signature: signature,
        signingScheme: 'eip712',
        targetPrice: limitPrice.toString(),
      );

      if (result == null) {
        final message = _mapErrorMessage(_swapService.lastError ?? l.tryAgain);
        progressController?.setError(message);
        if (progressController == null) {
          _showError(message);
        }
        return;
      }
      if (progressController != null) {
        progressController!.setSuccess();
      } else {
        ToastUtils.showSuccess('Limit order submitted');
      }
      unawaited(_refreshLimitOrders(showLoading: false));
    } on TimeoutException {
      const message =
          'Approval or order signing timed out. Reopen your wallet and try again.';
      progressController?.setError(message);
      if (progressController == null) {
        _showError(message);
      }
    } catch (e) {
      final message = _mapErrorMessage(e.toString());
      progressController?.setError(message);
      if (progressController == null) {
        _showError(message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingLimit = false);
      }
    }
  }

  Future<SwapQuote?> _refreshExecutionQuote({
    required Token fromToken,
    required Token toToken,
    required String fromAmountWei,
  }) async {
    if (_isGasless) {
      return _currentQuote;
    }

    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final quote = await _swapService
        .get0xQuote(
          chainId: blockchain.activeChain.chainId,
          fromTokenAddress: fromToken.contractAddress ?? '',
          toTokenAddress: toToken.contractAddress ?? '',
          amountWei: fromAmountWei,
          buyTokenDecimals: toToken.decimals,
          isGasless: false,
          walletAddress: _walletAddress,
          slippageBps: _slippageBps,
          useFirmQuote: true,
        )
        .timeout(_quoteUiTimeout);

    if (quote == null || !mounted) {
      return quote;
    }

    final rawOutAmount = double.tryParse(quote.amountOutFormatted) ?? 0.0;
    final inAmount = _parseAmount(_fromController);
    final unitRate = inAmount > 0 ? (rawOutAmount / inAmount) : 0.0;
    var feeNative = quote.networkFeeNative;
    var feeUsd = quote.networkFeeUsd > 0
        ? quote.networkFeeUsd
        : quote.networkFeeNative * _nativeTokenPriceUsd;

    if (feeNative <= 0 && feeUsd <= 0) {
      var nativePrice = _nativeTokenPriceUsd;
      if (nativePrice <= 0) {
        await _refreshTokenPrices();
        nativePrice = _nativeTokenPriceUsd;
      }
      final estimate = await blockchain.estimateGasFee(
        nativePriceUsd: nativePrice,
      );
      feeNative = estimate['totalFeeEth'] ?? 0.0;
      feeUsd = estimate['totalFeeUsd'] ?? 0.0;
    }

    if (!mounted) {
      return quote;
    }

    setState(() {
      _pricing = _formatRateText(unitRate);
      _toController.text = quote.amountOutFormatted;
      _currentQuote = quote;
      _feeNative = feeNative;
      _feeUsd = feeUsd;
      _platformFeeUsd = quote.platformFeeUsd;
    });

    return quote;
  }

  void _executeSwap() async {
    if (_isSwapFlowActive || _isApproving || _isSwapping) {
      return;
    }

    final l = AppLocalizations.of(context);
    if (_walletAddress == null) {
      _showError(l.noActiveWalletFound);
      return;
    }
    final fromAmount = _parseDecimalAmount(_fromController.text);
    if (fromAmount <= Decimal.zero) {
      _showError(l.enterValidAmount);
      return;
    }
    final fromToken = _fromToken;
    final toToken = _toToken;
    if (fromToken == null || toToken == null) {
      _showError(l.selectTokenTitle);
      return;
    }
    if (_tokensAreIdentical(fromToken, toToken)) {
      _showError(l.tryAgain);
      return;
    }
    if (_currentQuote == null) {
      _showError(l.noQuoteAvailable);
      return;
    }
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    if (!_swapService.isChainSupported(
      blockchain.activeChain.chainId,
      isGasless: _isGasless,
    )) {
      _showError(_isGasless ? l.networkError : l.networkError);
      return;
    }
    if (_isGaslessSourceUnsupported()) {
      _showError(l.networkError);
      return;
    }
    final fromAmountWei = _toWeiAmount(
      _fromController.text,
      fromToken.decimals,
    );
    if (fromAmountWei == null || fromAmountWei == '0') {
      _showError(l.enterValidAmount);
      return;
    }

    TransactionProgressController? progressController;
    if (mounted) {
      setState(() => _isSwapFlowActive = true);
    }

    try {
      progressController = _openProgressFlow();
      progressController.setPreparing();

      final executionQuote = await _refreshExecutionQuote(
        fromToken: fromToken,
        toToken: toToken,
        fromAmountWei: fromAmountWei,
      );
      if (!mounted) return;
      if (executionQuote == null) {
        progressController.setError(
          _mapErrorMessage(_swapService.lastError ?? l.noQuoteAvailable),
        );
        return;
      }

      if (_tokenRequiresApproval(fromToken)) {
        final approvalOk = await _handleTokenApproval(
          fromToken,
          fromAmountWei,
          progressController: progressController,
        );
        if (!approvalOk) return;
      }

      await _performSwap(
        fromToken: fromToken,
        toToken: toToken,
        fromAmountWei: fromAmountWei,
        progressController: progressController,
      );
    } catch (error, stackTrace) {
      debugPrint('Swap flow error: $error\n$stackTrace');
      if (progressController != null) {
        progressController.setError(_mapErrorMessage(error.toString()));
      } else {
        _showError(_mapErrorMessage(error.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _isSwapFlowActive = false);
      }
    }
  }

  void _showError(String message) {
    ToastUtils.showError(message);
  }

  void _showNetworkSelector() {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => NetworkSelectorSheet(
        chains: blockchain.allChains,
        activeChainId: blockchain.activeChain.chainId,
        onSelect: (chain) {
          blockchain.setActiveChain(chain);
          Navigator.pop(ctx);
        },
        onAddCustomNetwork: () async {
          Navigator.pop(ctx);
          await Navigator.pushNamed(context, '/add-network');
        },
      ),
    );
  }

  Future<bool> _handleTokenApproval(
    Token fromToken,
    String fromAmountWei, {
    required TransactionProgressController progressController,
  }) async {
    final l = AppLocalizations.of(context);
    if (_walletAddress == null) {
      progressController.setError(l.noActiveWalletFound);
      return false;
    }
    final quote = _currentQuote;
    if (quote == null) {
      progressController.setError(l.noRouterQuoteAvailable);
      return false;
    }
    if (_isGasless && quote.gaslessApprovalAvailable) {
      return true;
    }
    if (!quote.needsAllowance) {
      return true;
    }
    if (_isApproving) return false;

    setState(() => _isApproving = true);
    try {
      // Don't show "Approval Processing" yet — wait until we confirm
      // that an on-chain approval tx is actually needed.
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final gaslessApprovalFunded = await _ensureGaslessApprovalFunding(
        token: fromToken,
        quote: quote,
        blockchain: blockchain,
        progressController: progressController,
      );
      if (!gaslessApprovalFunded) {
        return false;
      }
      final result = await _tokenApprovalService
          .ensureApproval(
            token: fromToken,
            amountWei: fromAmountWei,
            ownerAddress: _walletAddress!,
            blockchain: blockchain,
            allowanceTarget: quote.allowanceSpender ?? quote.allowanceTarget,
            onApprovalNeeded: () {
              if (mounted) {
                progressController.setApprovalPending();
              }
            },
          )
          .timeout(_approvalUiTimeout);

      if (!mounted) return false;

      if (result.hasError) {
        progressController.setError(_mapErrorMessage(result.error));
        return false;
      }

      if (result.approvalSubmitted && result.transactionHash != null) {
        final txHash = result.transactionHash!;
        progressController.setApprovalPending(
          reference: _shortHash(txHash),
          detailsUrl: _transactionDetailsUrl(txHash),
        );
        final confirmed = await _waitForTxConfirmation(txHash);
        if (!confirmed) {
          progressController.setError(
            l.approvalPendingConfirmation,
            reference: _shortHash(txHash),
            detailsUrl: _transactionDetailsUrl(txHash),
          );
          return false;
        }
      }

      return true;
    } on TimeoutException {
      progressController.setError(
        'Approval request timed out. Reopen your wallet and try again.',
      );
      return false;
    } catch (error, stackTrace) {
      debugPrint('Token approval flow error: $error\n$stackTrace');
      progressController.setError(_mapErrorMessage(error.toString()));
      return false;
    } finally {
      if (mounted) {
        setState(() => _isApproving = false);
      }
    }
  }

  Future<void> _performSwap({
    required Token fromToken,
    required Token toToken,
    required String fromAmountWei,
    required TransactionProgressController progressController,
  }) async {
    final l = AppLocalizations.of(context);
    if (_walletAddress == null) {
      progressController.setError(l.noActiveWalletFound);
      return;
    }
    final quote = _currentQuote;
    if (quote == null) {
      progressController.setError(l.noQuoteAvailable);
      return;
    }
    if (_isSwapping) return;

    var expectedToAmount = _parseAmount(_toController);
    if (expectedToAmount <= 0) {
      expectedToAmount = double.tryParse(quote.amountOutFormatted) ?? 0.0;
    }
    final fromAmountText = _fromController.text.trim();
    final toAmountText = _toController.text.trim().isNotEmpty
        ? _toController.text.trim()
        : quote.amountOutFormatted;
    final referralSwapAmountUsd = _estimateReferralSwapAmountUsd(
      fromToken: fromToken,
      fromAmountText: fromAmountText,
      quote: quote,
    );

    setState(() => _isSwapping = true);
    try {
      progressController.setSwapSubmitting(gasless: _isGasless);
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final result = await _swapExecutionService.execute(
        quote: quote,
        fromToken: fromToken,
        toToken: toToken,
        fromAmountWei: fromAmountWei,
        expectedToAmount: expectedToAmount,
        slippageBps: _slippageBps,
        blockchain: blockchain,
        recipientAddress: _walletAddress!,
        isGasless: _isGasless, // Pass the beta toggle selection
      );

      if (!result.success) {
        progressController.setError(_mapErrorMessage(result.error));
        return;
      }

      if (result.transactionHash == null) {
        if (_isGasless) {
          if (result.tradeHash != null) {
            _clearSubmittedSwapState();
            progressController.setGaslessPending(
              reference: _shortHash(result.tradeHash!),
            );
            await _trackGaslessOrder(
              result.tradeHash!,
              progressController: progressController,
              blockchain: blockchain,
              chainId: blockchain.activeChain.chainId,
              fromToken: fromToken,
              toToken: toToken,
              fromAmountText: fromAmountText,
              fromSymbol: fromToken.symbol,
              toAmountText: toAmountText,
              toSymbol: toToken.symbol,
              networkName: blockchain.activeChain.name,
              rewardReferralOnSwap: true,
              swapAmountUsd: referralSwapAmountUsd,
            );
          } else {
            progressController.setGaslessPending();
          }
          return;
        }
        progressController.setError(l.swapMissingHash);
        return;
      }

      if (_isGasless && !_looksLikeTxHash(result.transactionHash!)) {
        _clearSubmittedSwapState();
        progressController.setGaslessPending(
          reference: _shortHash(result.transactionHash!),
        );
        await _trackGaslessOrder(
          result.tradeHash ?? result.transactionHash!,
          progressController: progressController,
          blockchain: blockchain,
          chainId: blockchain.activeChain.chainId,
          fromToken: fromToken,
          toToken: toToken,
          fromAmountText: fromAmountText,
          fromSymbol: fromToken.symbol,
          toAmountText: toAmountText,
          toSymbol: toToken.symbol,
          networkName: blockchain.activeChain.name,
          rewardReferralOnSwap: true,
          swapAmountUsd: referralSwapAmountUsd,
        );
        return;
      }

      final txHash = result.transactionHash!;
      _clearSubmittedSwapState();
      progressController.setSwapPending(
        reference: _shortHash(txHash),
        detailsUrl: _transactionDetailsUrl(txHash),
      );
      final confirmed = await _waitForTxConfirmation(
        txHash,
        rewardReferralOnSwap: true,
        swapAmountUsd: referralSwapAmountUsd,
      );
      if (!mounted) return;
      if (confirmed) {
        _applyOptimisticSwapResult(
          blockchain: blockchain,
          fromToken: fromToken,
          toToken: toToken,
          fromAmountText: fromAmountText,
          toAmountText: toAmountText,
        );
        unawaited(
          _walletNotificationService.notifySwapConfirmed(
            walletAddress: _walletAddress!,
            chainId: blockchain.activeChain.chainId,
            txHash: txHash,
            fromAmount: fromAmountText,
            fromSymbol: fromToken.symbol,
            toAmount: toAmountText,
            toSymbol: toToken.symbol,
            networkName: blockchain.activeChain.name,
          ),
        );
        _recordSwapHistory(
          txHash: txHash,
          fromAmount: fromAmountText,
          fromTokenName: fromToken.name,
          fromTokenSymbol: fromToken.symbol,
          toAmount: toAmountText,
          toTokenSymbol: toToken.symbol,
          networkName: blockchain.activeChain.name,
          chainId: blockchain.activeChain.chainId,
        );
        progressController.setSuccess(
          reference: _shortHash(txHash),
          detailsUrl: _transactionDetailsUrl(txHash),
        );
      } else {
        progressController.setError(
          l.transactionPendingConfirmation,
          reference: _shortHash(txHash),
          detailsUrl: _transactionDetailsUrl(txHash),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSwapping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCurrencyCode = context.select<CurrencyController, String>(
      (controller) => controller.currencyCode,
    );
    final l = AppLocalizations.of(context);
    final blockchain = Provider.of<BlockchainService>(context);
    final fromAmount = _parseAmount(_fromController);
    final toAmount = _parseAmount(_toController);
    final fromUsdValue = _usdValueFor(_fromToken, fromAmount);
    final toUsdValue = _usdValueFor(_toToken, toAmount);
    final priceText = _pricing.isNotEmpty
        ? _pricing
        : (_selectedFiatToTokenRateText(_toToken));
    final receiveText = _toController.text.isNotEmpty
        ? '${_currentQuote?.minAmountOutFormatted ?? _toController.text} ${_toToken?.symbol ?? ''} min'
        : '--';
    final limitPrice = _parseDecimalAmount(_limitPriceController.text);
    if (_lastFiatCurrencyCode != selectedCurrencyCode) {
      _lastFiatCurrencyCode = selectedCurrencyCode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (limitPrice > Decimal.zero) {
          final limitPriceValue = double.tryParse(limitPrice.toString()) ?? 0.0;
          if (limitPriceValue > 0) {
            _syncLimitUsdField(limitPriceValue);
          }
        }
      });
    }
    final swapBusy = _isSwapFlowActive || _isApproving || _isSwapping;
    final hasInputAmount = fromAmount > 0;
    final hasQuote = _currentQuote != null && _toController.text.isNotEmpty;
    final chainSupported = _swapService.isChainSupported(
      blockchain.activeChain.chainId,
      isGasless: _isGasless,
    );
    final localHasBalance =
        _fromToken != null &&
        _parseDecimalAmount(_fromController.text) <=
            (Decimal.tryParse(_fromToken!.balance.toString()) ?? Decimal.zero);
    final hasBalance = localHasBalance;
    final swapEnabled =
        hasInputAmount &&
        hasQuote &&
        hasBalance &&
        chainSupported &&
        !_tokensAreIdentical(_fromToken, _toToken) &&
        !_isGaslessSourceUnsupported() &&
        !swapBusy;
    final limitButtonLabel = _limitButtonLabel();
    final limitStatusMessage = _limitStatusMessage();

    String? buttonLabel;
    if (hasQuote && !hasBalance) {
      buttonLabel = l.insufficientBalance;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: widget.showBottomNavigation
          ? BottomNavBar(
              currentIndex: 1,
              onTap: (index) =>
                  BottomNavBar.handleNavigation(context, index, 1),
            )
          : null,
      floatingActionButton:
          _activeTab == SwapTab.limit && !_limitTutorialControlHidden
          ? Padding(
              padding: EdgeInsets.only(
                bottom: widget.showBottomNavigation ? 72 : 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'limitTutorialReplay',
                    tooltip: 'Replay limit tutorial',
                    backgroundColor: const Color(0xFFEA2A33),
                    foregroundColor: Colors.white,
                    onPressed: () {
                      unawaited(_startLimitShowcaseIfNeeded(force: true));
                    },
                    child: const Icon(Icons.play_circle_fill_rounded),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.small(
                    heroTag: 'limitTutorialHide',
                    tooltip: 'Hide tutorial button',
                    backgroundColor: const Color(0xFF1F1F1F),
                    foregroundColor: const Color(0xFFC8C6C5),
                    onPressed: () {
                      unawaited(_hideLimitTutorialControl());
                    },
                    child: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 63,
              child: Center(
                child: Text(
                  l.swap,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFE2E2E2),
                    height: 1.4,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Showcase(
                      key: _limitTabShowcaseKey,
                      title: 'Limit orders',
                      description:
                          'Use Swap for instant market execution. Use Limit to set a target price and let Owllet place the order when the market reaches it.',
                      child: SwapTabSelector(
                        activeTab: _activeTab,
                        onChanged: (tab) {
                          if (_activeTab == tab) return;
                          setState(() {
                            _activeTab = tab;
                            if (tab == SwapTab.limit) {
                              _ensureLimitEligiblePair();
                            }
                          });
                          if (tab == SwapTab.swap) {
                            _getQuote();
                          } else {
                            _updateLimitPreview();
                            unawaited(
                              _refreshLimitOrders(
                                showLoading: _limitOrders.isEmpty,
                              ),
                            );
                            unawaited(_startLimitShowcaseIfNeeded());
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 19),
                    NetworkCard(
                      chain: blockchain.activeChain,
                      onTap: _showNetworkSelector,
                    ),
                    const SizedBox(height: 16),
                    if (_activeTab == SwapTab.swap)
                      SwapTabContent(
                        blockchain: blockchain,
                        fromController: _fromController,
                        fromToken: _fromToken,
                        fromUsdValue: fromUsdValue,
                        selectedPercentage: _selectedPercentage,
                        onAmountChanged: _onFromAmountChanged,
                        onSelectFromToken: () => _showTokenSelector(true),
                        onPercentSelected: _setPercentage,
                        onSwapTokens: _swapTokens,
                        toToken: _toToken,
                        toAmountText: _toController.text,
                        toUsdValue: toUsdValue,
                        toBalance: _toToken?.balance ?? 0,
                        isCalculating: _isCalculating,
                        onSelectToToken: () => _showTokenSelector(false),
                        currentQuote: _currentQuote,
                        platformFeeUsd: _platformFeeUsd,
                        feeUsd: _feeUsd,
                        feeNative: _feeNative,
                        priceText: priceText,
                        receiveText: receiveText,
                        priceSeparator: _priceSeparator,
                        nativePriceUsd:
                            _tokenPriceCache[blockchain
                                .activeChain
                                .coinGeckoId] ??
                            0.0,
                        gaslessFeeCovered: _isGasless,
                        quoteStatusMessage: _quoteStatusMessage,
                        swapEnabled: swapEnabled,
                        swapBusy: swapBusy,
                        onSwapPressed: _executeSwap,
                        buttonLabel: buttonLabel,
                        showGaslessToggle: _canOfferGaslessToggle,
                        isGasless: _isGasless,
                        onGaslessChanged: (val) {
                          setState(() {
                            _isGasless = val;
                            _resetQuoteState();
                          });
                          _getQuote();
                        },
                      )
                    else
                      LimitTabContent(
                        blockchain: blockchain,
                        fromController: _fromController,
                        fromToken: _fromToken,
                        fromUsdValue: fromUsdValue,
                        selectedPercentage: _selectedPercentage,
                        onAmountChanged: _onFromAmountChanged,
                        onSelectFromToken: () => _showTokenSelector(true),
                        onPercentSelected: _setPercentage,
                        onSwapTokens: _swapTokens,
                        toToken: _toToken,
                        toAmountText: _toController.text,
                        toUsdValue: toUsdValue,
                        toBalance: _toToken?.balance ?? 0,
                        onSelectToToken: () => _showTokenSelector(false),
                        isBuyMode: _isBuyMode,
                        onSelectBuyMode: () => _setLimitOrderSide(true),
                        onSelectSellMode: () => _setLimitOrderSide(false),
                        limitBusy: _isSubmittingLimit,
                        limitEnabled: _limitEnabled(),
                        limitButtonLabel: limitButtonLabel,
                        limitStatusMessage: limitStatusMessage,
                        limitPriceController: _limitPriceController,
                        onLimitPriceChanged: (_) {
                          setState(() {
                            _selectedLimitPriceAdjustment = 0;
                          });
                          _updateLimitPreview();
                        },
                        priceSeparator: _priceSeparator,
                        executionPriceText: _limitExecutionPriceText(),
                        executionPriceUsdLabel: _limitExecutionPriceUsdText(),
                        receiveText: _toController.text.isNotEmpty
                            ? '${_toController.text} ${_toToken?.symbol ?? ''}'
                            : '--',
                        nativePriceUsd:
                            _tokenPriceCache[blockchain
                                .activeChain
                                .coinGeckoId] ??
                            0.0,
                        platformFeePercent: 0.0,
                        platformFeeUsd: _platformFeeUsd,
                        feeUsd: _feeUsd,
                        feeNative: _feeNative,
                        targetTokenSymbol: _limitTargetToken?.symbol ?? '',
                        quoteToken: _limitQuoteToken,
                        priceDeviationLabel: _limitPriceDeviationLabel(),
                        onPriceAdjust: _adjustLimitPrice,
                        selectedPriceAdjustment: _selectedLimitPriceAdjustment,
                        isPositiveAdjust: _isPositiveAdjust,
                        onToggleAdjustDirection: () {
                          setState(() {
                            _isPositiveAdjust = !_isPositiveAdjust;
                            _selectedLimitPriceAdjustment = 0;
                          });
                        },
                        limitUsdController: _limitUsdController,
                        onLimitUsdChanged: (value) {
                          setState(() {
                            _selectedLimitPriceAdjustment = 0;
                          });
                          _onLimitUsdChanged(value);
                        },
                        onSubmitLimit: _submitLimitOrder,
                        activeOrders: _activeChainLimitOrders,
                        isLoadingActiveOrders: _isLoadingLimitOrders,
                        onRefreshActiveOrders: () {
                          unawaited(_refreshLimitOrders(surfaceErrors: true));
                        },
                        onCancelActiveOrder: (order) {
                          unawaited(_cancelLimitOrder(order));
                        },
                        cancellingOrderIds: _cancellingLimitOrderIds,
                        amountShowcaseKey: _limitAmountsShowcaseKey,
                        executionPriceShowcaseKey:
                            _limitExecutionPriceShowcaseKey,
                        expiryShowcaseKey: _limitExpiryShowcaseKey,
                        summaryShowcaseKey: _limitSummaryShowcaseKey,
                        submitShowcaseKey: _limitSubmitShowcaseKey,
                        expiryLabel: _limitExpiryLabel(),
                        onSelect15m: () => setState(
                          () =>
                              _limitExpiryOption = _LimitExpiryOption.minutes15,
                        ),
                        onSelect1h: () => setState(
                          () => _limitExpiryOption = _LimitExpiryOption.hour1,
                        ),
                        onSelect4h: () => setState(
                          () => _limitExpiryOption = _LimitExpiryOption.hours4,
                        ),
                        onSelect24h: () => setState(
                          () => _limitExpiryOption = _LimitExpiryOption.hours24,
                        ),
                        onSelect7d: () => setState(
                          () => _limitExpiryOption = _LimitExpiryOption.days7,
                        ),
                        onSelectNever: () => setState(
                          () => _limitExpiryOption = _LimitExpiryOption.never,
                        ),
                        onPickCustomExpiry: _pickCustomExpiry,
                        is15mSelected:
                            _limitExpiryOption == _LimitExpiryOption.minutes15,
                        is1hSelected:
                            _limitExpiryOption == _LimitExpiryOption.hour1,
                        is4hSelected:
                            _limitExpiryOption == _LimitExpiryOption.hours4,
                        is24hSelected:
                            _limitExpiryOption == _LimitExpiryOption.hours24,
                        is7dSelected:
                            _limitExpiryOption == _LimitExpiryOption.days7,
                        isNeverSelected:
                            _limitExpiryOption == _LimitExpiryOption.never,
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _limitEnabled() {
    final fromAmount = _parseDecimalAmount(_fromController.text);
    final limitPrice = _parseDecimalAmount(_limitPriceController.text);
    return (_walletAddress ?? '').isNotEmpty &&
        _isLimitSupported &&
        fromAmount > Decimal.zero &&
        limitPrice > Decimal.zero &&
        !_tokensAreIdentical(_fromToken, _toToken) &&
        _fromToken != null &&
        _toToken != null &&
        _tokenRequiresApproval(_fromToken!) &&
        _tokenRequiresApproval(_toToken!) &&
        !_isSubmittingLimit;
  }

  String _limitExecutionPriceText() {
    final limitPrice = _parseDecimalAmount(_limitPriceController.text);
    if (limitPrice <= Decimal.zero) {
      return _selectedFiatToTokenRateText(_limitTargetToken);
    }
    final target = _limitTargetToken;
    final quote = _limitQuoteToken;
    return '1 ${target?.symbol ?? ''} $_priceSeparator ${limitPrice.toString()} ${quote?.symbol ?? ''}';
  }

  String _limitExecutionPriceUsdText() {
    final limitPrice = _parseDecimalAmount(_limitPriceController.text);
    if (limitPrice <= Decimal.zero) {
      return ValueFormatter.formatCurrencyWithGrouping(Decimal.zero);
    }
    final limitPriceValue = double.tryParse(limitPrice.toString()) ?? 0.0;
    if (limitPriceValue <= 0) {
      return ValueFormatter.formatCurrencyWithGrouping(Decimal.zero);
    }
    // The limit price is denominated in the quote token, so use its USD rate.
    final usdValue = _usdValueFor(_limitQuoteToken, limitPriceValue);
    if (usdValue <= 0) {
      return ValueFormatter.formatCurrencyWithGrouping(Decimal.zero);
    }
    return ValueFormatter.formatCurrencyWithGrouping(
      ValueFormatter.decimalFromNum(usdValue),
    );
  }

  /// Calculates the percentage deviation of the user's limit price from the
  /// current market price of the target token. Returns e.g. "+1.2%" or "-5.0%".
  String? _limitPriceDeviationLabel() {
    final limitPrice = _parseDecimalAmount(_limitPriceController.text);
    if (limitPrice <= Decimal.zero) return null;
    final limitPriceValue = double.tryParse(limitPrice.toString()) ?? 0.0;
    if (limitPriceValue <= 0) return null;

    // Compute the market price of the target token in terms of the quote token.
    final targetUsd = _resolvedTokenUnitPriceUsd(_limitTargetToken);
    final quoteUsd = _resolvedTokenUnitPriceUsd(_limitQuoteToken);
    if (targetUsd <= 0 || quoteUsd <= 0) return null;

    final marketPrice = targetUsd / quoteUsd;
    if (marketPrice <= 0) return null;

    final deviation = ((limitPriceValue - marketPrice) / marketPrice) * 100;
    final sign = deviation >= 0 ? '+' : '';
    return '$sign${deviation.toStringAsFixed(1)}%';
  }

  /// Adjusts the limit price by a percentage relative to market price.
  /// [percent] can be negative (e.g. -25 means 25% below market).
  void _adjustLimitPrice(int percent) {
    final targetUsd = _resolvedTokenUnitPriceUsd(_limitTargetToken);
    final quoteUsd = _resolvedTokenUnitPriceUsd(_limitQuoteToken);
    if (targetUsd <= 0 || quoteUsd <= 0) return;

    final marketPrice = targetUsd / quoteUsd;
    final adjusted = marketPrice * (1 + percent / 100.0);
    if (adjusted <= 0) return;

    final decimals = _limitQuoteToken?.decimals ?? 6;
    final displayDecimals = decimals > 6 ? 6 : decimals;
    _limitPriceController.text = adjusted.toStringAsFixed(displayDecimals);
    // Sync the USD field with the adjusted price
    _syncLimitUsdField(adjusted);
    _updateLimitPreview();
    setState(() {
      _selectedLimitPriceAdjustment = percent;
    });
  }

  /// Called when the user edits the USD field in the execution card.
  /// Converts the entered USD value back to a token price.
  void _onLimitUsdChanged(String usdText) {
    final displayValue =
        Decimal.tryParse(usdText.replaceAll(',', '')) ?? Decimal.zero;
    if (displayValue <= Decimal.zero) return;

    // We need the quote token's USD price to convert.
    // selected-fiat / rate = USD; USD / quoteTokenUsdPrice = priceInQuoteTokens
    final quoteUsd = _resolvedTokenUnitPriceUsd(_limitQuoteToken);
    if (quoteUsd <= 0) return;

    final usdValue = ValueFormatter.doubleFromDecimal(
      ValueFormatter.convertToUsdDecimal(displayValue),
    );
    final tokenPrice = usdValue / quoteUsd;
    final decimals = _limitQuoteToken?.decimals ?? 6;
    final displayDecimals = decimals > 6 ? 6 : decimals;
    _limitPriceController.text = tokenPrice.toStringAsFixed(displayDecimals);
    _updateLimitPreview();
    setState(() {});
  }

  /// Syncs the USD input field when the token price changes.
  void _syncLimitUsdField(double tokenPrice) {
    final quoteUsd = _resolvedTokenUnitPriceUsd(_limitQuoteToken);
    if (quoteUsd <= 0) {
      _limitUsdController.text = '';
      return;
    }
    final usdValue = tokenPrice * quoteUsd;
    _limitUsdController.text = ValueFormatter.formatPlainFiatFromUsd(
      ValueFormatter.decimalFromNum(usdValue),
      trimTrailingZeros: false,
    );
  }
}
