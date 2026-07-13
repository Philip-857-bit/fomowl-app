import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:decimal/decimal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../constants/app_colors.dart';
import '../../features/shell/app_shell_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bottom_navigation.dart';
import '../../models/token.dart';
import '../../models/token_standard.dart';
import '../../services/cow_limit_order_signing.dart';
import '../../services/swap_service.dart';
import '../../services/bridge_service.dart';
import '../../services/relay_swap_execution_service.dart';
import '../../services/solana_swap_service.dart';
import '../../services/tron_swap_service.dart';
import '../../services/solana_limit_service.dart';
import '../../services/solana_swap_execution_service.dart';
import '../../services/tron_swap_execution_service.dart';
import '../../services/wallet_service.dart';
import '../../models/chain.dart';
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
import '../../utils/sensitive_access_guard.dart';
import '../../utils/toast_utils.dart';
import '../../utils/token_visibility_utils.dart';
import '../../utils/value_formatter.dart';
import '../../widgets/amount_input_mode_toggle.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import '../transaction/transaction_processing_screen.dart';
import '../home/widgets/network_selector_sheet.dart';
import 'swap_screen_helpers.dart';
import 'widgets/bridge_tab_content.dart';
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
  // What the user is typing in the `from` field. May be token or fiat.
  // `_fromController` is always kept in token units — it's the source of
  // truth for quotes and limit-order submission.
  final TextEditingController _fromDisplayController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _limitPriceController = TextEditingController();
  final TextEditingController _limitUsdController = TextEditingController();
  AmountInputMode _fromInputMode = AmountInputMode.token;
  AmountInputMode _limitPriceInputMode = AmountInputMode.token;
  bool _syncingFromDisplay = false;
  final SwapService _swapService = SwapService();
  final BridgeService _relaySwapService = BridgeService();
  final RelaySwapExecutionService _relaySwapExecutionService =
      RelaySwapExecutionService();
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
  late final SolanaSwapService _solanaSwapService;
  late final TronSwapService _tronSwapService;
  late final SolanaLimitService _solanaLimitService;
  late final SolanaSwapExecutionService _solanaSwapExecutionService;
  late final TronSwapExecutionService _tronSwapExecutionService;
  // Solana limit orders (kept separate from EVM LimitOrderSummary list)
  List<SolanaLimitOrder> _solanaLimitOrders = const [];
  bool _isLoadingSolanaLimitOrders = false;
  final Set<String> _cancellingSolanaOrderAccounts = <String>{};
  static const String _priceSeparator = '->';

  Timer? _debounceTimer;

  Token? _fromToken;
  Token? _toToken;
  // Set when the user opened Swap from a token's detail screen; forces that
  // token as the "from" side on the next token sync, then is cleared.
  Token? _initialFromOverride;
  String? _lastNetworkKey;
  String? _lastWalletKey;
  String? _lastTokenSignature;
  int _walletBalanceLoadGeneration = 0;
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

    // If the user launched Swap from a token's detail screen, pre-select that
    // token as the "from" side. Consumed once so normal tab switching is
    // unaffected.
    final pendingFrom = context
        .read<AppShellController>()
        .consumePendingSwapFromToken();
    if (pendingFrom != null) {
      _initialFromOverride = pendingFrom;
      _fromToken = pendingFrom;
      // Let the counter token re-pick a sensible default relative to the new
      // "from" token rather than keeping a stale pairing.
      _toToken = null;
    }

    final networkKey = blockchain.activeNetworkKey;
    final walletKey = _walletSyncKey(blockchain);
    final visibleTokens = _visibleTokens(blockchain.tokens);
    final tokenSignature = _tokenSignature(visibleTokens);
    final walletChanged = _lastWalletKey != null && _lastWalletKey != walletKey;
    final tokensChanged = _lastTokenSignature != tokenSignature;
    if (_activeTab == SwapTab.limit && !_supportsLimitTab(blockchain)) {
      _activeTab = SwapTab.swap;
    }
    // Bridge supports EVM and Solana origins; Tron isn't on Relay.
    if (_activeTab == SwapTab.bridge &&
        blockchain.activeFamily == ChainFamily.tron) {
      _activeTab = SwapTab.swap;
    }
    if (_lastNetworkKey != networkKey || walletChanged) {
      _lastNetworkKey = networkKey;
      _lastWalletKey = walletKey;
      _lastTokenSignature = tokenSignature;
      _resetQuoteState(clearInputAmounts: true);
      if (_isGasless && !_isGaslessSupported) {
        _isGasless = false;
      }
      _walletAddress = null;
      _syncSelectedTokens(visibleTokens);
      _loadWalletBalance();
    } else if (_fromToken == null || _toToken == null || tokensChanged) {
      _lastWalletKey = walletKey;
      _lastTokenSignature = tokenSignature;
      _syncSelectedTokens(visibleTokens);
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
  int _slippageBps = 50;
  double _feeUsd = 0.0;
  double _feeNative = 0.0;
  double _platformFeeUsd = 0.0;
  String? _walletAddress;
  SwapQuote? _currentQuote;
  BridgeQuote? _currentRelayQuote;
  int _selectedPercentage = -1; // -1 = none selected
  /// Cached per-token USD prices fetched from CoinGecko.
  /// Made static to persist across screen navigation. Entries carry a fetch
  /// timestamp and are treated as stale after [_priceCacheTtl] so token↔fiat
  /// conversions never use arbitrarily old prices.
  static final Map<String, double> _tokenPriceCache = {};
  static final Map<String, DateTime> _tokenPriceCacheTime = {};
  static const Duration _priceCacheTtl = Duration(minutes: 2);

  /// Reads a cached price, returning null when missing or stale.
  double? _cachedTokenPrice(String? key) {
    if (key == null || key.isEmpty) return null;
    final price = _tokenPriceCache[key];
    if (price == null) return null;
    final at = _tokenPriceCacheTime[key];
    if (at == null || DateTime.now().difference(at) > _priceCacheTtl) {
      return null;
    }
    return price;
  }

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
      final cached = _cachedTokenPrice(coinGeckoId);
      if (cached != null && cached > 0) {
        return cached;
      }
    }
    return 0.0;
  }

  String? _fromEquivalentText() {
    final tokenValue =
        double.tryParse(_fromController.text.replaceAll(',', '')) ?? 0.0;
    if (tokenValue <= 0) return null;
    final tokenPriceUsd = _resolvedTokenUnitPriceUsd(_fromToken);
    if (tokenPriceUsd <= 0) return null;
    if (_fromInputMode == AmountInputMode.token) {
      return '≈ ${ValueFormatter.formatCurrencyWithGrouping(ValueFormatter.decimalFromNum(tokenValue * tokenPriceUsd))}';
    }
    return '≈ ${ValueFormatter.formatTokenRateAmount(tokenValue)} ${_fromToken?.symbol ?? ''}';
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
    // Solana SPL tokens don't use ERC-20 approval — any token pair is valid.
    if (blockchain.activeFamily == ChainFamily.solana) return false;
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
    _syncFromDisplayFromTokenAmount();
    _toController.clear();
    _limitPriceController.clear();
    _limitUsdController.clear();
    _selectedLimitPriceAdjustment = 0;
    return true;
  }

  String _limitButtonLabel() {
    final bc = Provider.of<BlockchainService>(context, listen: false);
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
    if (bc.activeFamily != ChainFamily.solana &&
        (_fromToken != null && _toToken != null) &&
        (!_tokenRequiresApproval(_fromToken!) ||
            !_tokenRequiresApproval(_toToken!))) {
      return 'Use ERC-20 Tokens';
    }
    if (parseDecimalAmount(_fromController.text) <= Decimal.zero) {
      return _isBuyMode ? 'Enter Max Spend' : 'Enter Sell Amount';
    }
    if (parseDecimalAmount(_limitPriceController.text) <= Decimal.zero) {
      return 'Set Target Price';
    }
    return 'Place $sideLabel Order';
  }

  String _limitStatusMessage() {
    final bc = Provider.of<BlockchainService>(context, listen: false);
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
    if (bc.activeFamily != ChainFamily.solana &&
        (_fromToken != null && _toToken != null) &&
        (!_tokenRequiresApproval(_fromToken!) ||
            !_tokenRequiresApproval(_toToken!))) {
      return 'Limit orders currently support ERC-20 token pairs only.';
    }
    if (parseDecimalAmount(_fromController.text) <= Decimal.zero) {
      return _isBuyMode
          ? 'Enter the maximum amount you want to spend.'
          : 'Enter how much you want to sell.';
    }
    if (parseDecimalAmount(_limitPriceController.text) <= Decimal.zero) {
      return 'Set the execution price that should trigger this order.';
    }
    if (_isSubmittingLimit) {
      return 'Submitting your signed ${_currentLimitKind.toUpperCase()} limit order...';
    }
    return 'You pay no gas to place or cancel a limit order. Your first sell-token approval may still need a network fee.';
  }

  bool get _isGaslessSupported {
    final bc = Provider.of<BlockchainService>(context, listen: false);
    if (bc.activeFamily != ChainFamily.evm) return false;
    final chainId = bc.activeChain.chainId;
    // 0x Gasless v2 chains. Fantom (250), Celo (42220), and Polygon zkEVM
    // (1101) were v1-only and are rejected by the v2 API — keep this list in
    // sync with SwapService.supportedGaslessChainIds.
    return SwapService.supportedGaslessChainIds.contains(chainId);
  }

  bool get _isLimitSupported {
    final bc = Provider.of<BlockchainService>(context, listen: false);
    if (bc.activeFamily == ChainFamily.solana) return true;
    if (bc.activeFamily != ChainFamily.evm) return false;
    return _swapService.isLimitChainSupported(bc.activeChain.chainId);
  }

  bool _supportsLimitTab(BlockchainService blockchain) {
    return blockchain.activeFamily == ChainFamily.evm ||
        blockchain.activeFamily == ChainFamily.solana;
  }

  int _tokenStorageChainId(BlockchainService blockchain) {
    return blockchain.activeTokenStorageChainId;
  }

  String _limitUnsupportedMessage() {
    return 'Limit orders are available on Solana and on supported OpenOcean EVM networks such as Ethereum, BNB, Polygon, Base, Arbitrum, Avalanche, Optimism, Fantom, Linea, Sonic, and Berachain.';
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
    _solanaSwapService = SolanaSwapService();
    _tronSwapService = TronSwapService();
    _solanaLimitService = SolanaLimitService();
    _solanaSwapExecutionService = SolanaSwapExecutionService(
      walletService: _walletService,
      swapService: _solanaSwapService,
    );
    _tronSwapExecutionService = TronSwapExecutionService(
      walletService: _walletService,
      swapService: _tronSwapService,
    );
    _fromDisplayController.addListener(_handleFromDisplayChanged);
    unawaited(_loadLimitTutorialPreferences());
    _loadWalletBalance();
    _activateSwapLiveTracking();
  }

  void _handleFromDisplayChanged() {
    if (_syncingFromDisplay) return;
    final raw = _fromDisplayController.text.replaceAll(',', '');
    if (_fromInputMode == AmountInputMode.token) {
      // In token mode the display controller is the canonical input.
      _fromController.text = raw;
      _onFromAmountChanged(raw);
      return;
    }
    // Fiat mode: user types fiat; derive the token amount.
    final entered = double.tryParse(raw) ?? 0.0;
    final tokenPriceUsd = _resolvedTokenUnitPriceUsd(_fromToken);
    if (entered <= 0 || tokenPriceUsd <= 0) {
      _fromController.text = '';
      _onFromAmountChanged('');
      return;
    }
    final usdValue = ValueFormatter.doubleFromDecimal(
      ValueFormatter.convertToUsdDecimal(
        ValueFormatter.decimalFromNum(entered),
      ),
    );
    final tokenAmount = usdValue / tokenPriceUsd;
    final decimals = _fromToken?.decimals ?? 18;
    final displayDecimals = decimals > 8 ? 8 : decimals;
    var tokenText = tokenAmount.toStringAsFixed(displayDecimals);
    while (tokenText.contains('.') && tokenText.endsWith('0')) {
      tokenText = tokenText.substring(0, tokenText.length - 1);
    }
    if (tokenText.endsWith('.')) {
      tokenText = tokenText.substring(0, tokenText.length - 1);
    }
    _fromController.text = tokenText;
    _onFromAmountChanged(tokenText);
  }

  void _syncFromDisplayFromTokenAmount() {
    _syncingFromDisplay = true;
    final tokenText = _fromController.text;
    if (_fromInputMode == AmountInputMode.token) {
      if (_fromDisplayController.text != tokenText) {
        _fromDisplayController.text = tokenText;
      }
    } else {
      final tokenValue = double.tryParse(tokenText.replaceAll(',', '')) ?? 0.0;
      final tokenPriceUsd = _resolvedTokenUnitPriceUsd(_fromToken);
      if (tokenValue > 0 && tokenPriceUsd > 0) {
        final fiatValue = ValueFormatter.doubleFromDecimal(
          ValueFormatter.convertFromUsdDecimal(
            ValueFormatter.decimalFromNum(tokenValue * tokenPriceUsd),
          ),
        );
        _fromDisplayController.text = fiatValue.toStringAsFixed(2);
      } else {
        _fromDisplayController.text = '';
      }
    }
    _syncingFromDisplay = false;
  }

  void _toggleFromInputMode() {
    final tokenPriceUsd = _resolvedTokenUnitPriceUsd(_fromToken);
    if (tokenPriceUsd <= 0 && _fromInputMode == AmountInputMode.token) {
      ToastUtils.showError(
        'Price unavailable for ${_fromToken?.symbol ?? 'this token'}',
      );
      return;
    }
    setState(() {
      _fromInputMode = _fromInputMode == AmountInputMode.token
          ? AmountInputMode.fiat
          : AmountInputMode.token;
    });
    _syncFromDisplayFromTokenAmount();
  }

  void _toggleLimitPriceInputMode() {
    final quotePriceUsd = _resolvedTokenUnitPriceUsd(_limitQuoteToken);
    if (quotePriceUsd <= 0 && _limitPriceInputMode == AmountInputMode.token) {
      ToastUtils.showError(
        'Price unavailable for ${_limitQuoteToken?.symbol ?? 'the quote token'}',
      );
      return;
    }
    setState(() {
      _limitPriceInputMode = _limitPriceInputMode == AmountInputMode.token
          ? AmountInputMode.fiat
          : AmountInputMode.token;
    });
    // Refresh the fiat field from the canonical token price, so switching
    // into fiat mode shows the current equivalent rather than stale text.
    final limitPriceValue =
        double.tryParse(_limitPriceController.text.replaceAll(',', '')) ?? 0.0;
    if (limitPriceValue > 0) {
      _syncLimitUsdField(limitPriceValue);
    }
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
    final loadGeneration = ++_walletBalanceLoadGeneration;
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final family = blockchain.activeFamily;
    final networkKey = blockchain.activeNetworkKey;
    final address = await _walletService.getActiveAddressForFamily(family);
    if (!mounted) return;
    if (loadGeneration != _walletBalanceLoadGeneration ||
        blockchain.activeFamily != family ||
        blockchain.activeNetworkKey != networkKey) {
      return;
    }
    await _tokenVisibilityService.loadHiddenTokens(
      _tokenStorageChainId(blockchain),
    );
    // Always sync with whatever token set we currently have so selectors never look empty.
    _syncVisibleTokensFrom(blockchain);
    if (mounted) {
      setState(() => _walletAddress = address);
    }

    if (address == null || address.isEmpty) {
      if (mounted) {
        setState(() {
          _limitOrders = const [];
          _solanaLimitOrders = const [];
          _quoteStatusMessage =
              'This wallet does not support ${blockchain.activeNetworkName}.';
        });
      }
    } else {
      unawaited(_refreshLimitOrders(showLoading: false));
    }

    if (address != null && address.isNotEmpty) {
      if (!mounted) return;
      try {
        await blockchain.fetchWalletTokens(address);
        if (loadGeneration != _walletBalanceLoadGeneration ||
            blockchain.activeFamily != family ||
            blockchain.activeNetworkKey != networkKey) {
          return;
        }
        if (mounted) {
          setState(() {
            _syncVisibleTokensFrom(blockchain);
          });
        }
      } catch (e) {
        debugPrint('Error fetching balance for swap: $e');
        if (loadGeneration != _walletBalanceLoadGeneration ||
            blockchain.activeFamily != family ||
            blockchain.activeNetworkKey != networkKey) {
          return;
        }
        if (mounted) {
          setState(() {
            _syncVisibleTokensFrom(blockchain);
          });
        }
      }
    } else if (mounted) {
      setState(() {
        _syncVisibleTokensFrom(blockchain);
      });
    }

    // Fetch live prices for all tokens with coinGeckoId to fill price gaps.
    await _refreshTokenPrices();
    _activateSwapLiveTracking();
  }

  String _walletSyncKey(BlockchainService blockchain) {
    return [
      blockchain.activeNetworkKey,
      blockchain.activeWalletAddress.trim().toLowerCase(),
    ].join(':');
  }

  String _tokenSignature(List<Token> tokens) {
    return tokens
        .map((token) {
          final contract = token.contractAddress?.trim().toLowerCase() ?? '';
          final networkKey = token.networkKey?.trim().toLowerCase() ?? '';
          return [
            networkKey,
            contract,
            token.symbol.trim().toLowerCase(),
            token.balance.toStringAsPrecision(12),
            token.valueUsd.toStringAsPrecision(12),
            token.priceUsd.toStringAsPrecision(12),
            token.decimals.toString(),
          ].join(':');
        })
        .join('|');
  }

  void _syncVisibleTokensFrom(BlockchainService blockchain) {
    final tokens = _visibleTokens(blockchain.tokens);
    _lastWalletKey = _walletSyncKey(blockchain);
    _lastTokenSignature = _tokenSignature(tokens);
    _syncSelectedTokens(tokens);
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
    final nativeCoinGeckoId = blockchain.activeNetworkCoinGeckoId;
    if (nativeCoinGeckoId != null && nativeCoinGeckoId.isNotEmpty) {
      priceIds.add(nativeCoinGeckoId);
    }
    if (priceIds.isEmpty) return;
    try {
      final prices = await blockchain.getTokenPrices(priceIds.toList());
      if (mounted) {
        setState(() {
          _tokenPriceCache.addAll(prices);
          final now = DateTime.now();
          for (final key in prices.keys) {
            _tokenPriceCacheTime[key] = now;
          }
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
          if ((t.contractAddress ?? '').toLowerCase() == addr &&
              _tokensShareNetwork(current, t)) {
            return t;
          }
        }
      }
      for (final t in tokens) {
        if (t.symbol.toLowerCase() == current.symbol.toLowerCase() &&
            _tokensShareNetwork(current, t)) {
          return t;
        }
      }
      return null;
    }

    // A token explicitly chosen on the detail screen takes priority for "from";
    // keep it even if it is not in the live list (it is still tradable).
    final override = _initialFromOverride;
    final from =
        (override != null
            ? (findMatch(override) ?? override)
            : findMatch(_fromToken)) ??
        tokens.first;
    Token to = findMatch(_toToken) ?? _defaultCounterToken(from, tokens);
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
    // One-shot override is now applied.
    _initialFromOverride = null;
    _applySuggestedLimitSide();
  }

  /// Picks a sensible default counter ("to") token instead of an arbitrary
  /// list position: prefer the chain-native token, otherwise a major stablecoin,
  /// and only then any other distinct token. Keeps swaps defaulting to
  /// blockchain/stablecoin pairs rather than random tokens.
  Token _defaultCounterToken(Token from, List<Token> tokens) {
    bool isNative(Token t) => (t.contractAddress ?? '').isEmpty;
    const stableSymbols = {
      'USDT',
      'USDC',
      'USDC.E',
      'DAI',
      'BUSD',
      'TUSD',
      'FDUSD',
      'USDD',
      'USDP',
    };
    bool isStable(Token t) => stableSymbols.contains(t.symbol.toUpperCase());

    final candidates = tokens
        .where((t) => !_tokensAreIdentical(t, from))
        .toList();
    if (candidates.isEmpty) {
      return from;
    }

    Token? firstWhere(bool Function(Token) test) {
      for (final t in candidates) {
        if (test(t)) return t;
      }
      return null;
    }

    // Selling a non-native asset → default the counter to the native coin.
    if (!isNative(from)) {
      final native = firstWhere(isNative);
      if (native != null) return native;
    }
    // Otherwise (e.g. selling the native coin) prefer a stablecoin.
    final stable = firstWhere(isStable);
    if (stable != null) return stable;

    // Fall back to the native coin, then any distinct token.
    return firstWhere(isNative) ?? candidates.first;
  }

  List<Token> _visibleTokens(List<Token> tokens) {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final chainId = blockchain.activeTokenStorageChainId;
    final base = _visibleTokensForChain(tokens, chainId);

    // Merge custom tokens added by the user that may not yet appear in the live
    // wallet-tokens list (e.g. zero-balance tokens the backend omits).
    final existing = {
      for (final t in base)
        (t.contractAddress?.trim().toLowerCase() ?? '').isNotEmpty
            ? t.contractAddress!.trim().toLowerCase()
            : t.symbol.toLowerCase(),
    };

    final extra = <Token>[];
    for (final custom in blockchain.customTokensForActiveChain) {
      final addr = custom.address.trim().toLowerCase();
      if (addr.isNotEmpty && existing.contains(addr)) continue;
      extra.add(
        Token(
          symbol: custom.symbol,
          name: custom.name,
          contractAddress: custom.address,
          balance: 0,
          valueUsd: 0,
          priceUsd: 0,
          changePercent24h: 0,
          decimals: custom.decimals,
          imageUrl: custom.imageUrl,
          coinGeckoId: custom.coinGeckoId,
          isCertified: false,
          networkKey: custom.networkKey,
          tokenStandard: custom.tokenStandard,
        ),
      );
    }

    if (extra.isEmpty) return base;
    return [...base, ...extra];
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
      return !TokenVisibilityUtils.contains(hiddenTokens, token);
    }).toList();
  }

  Future<void> _showTokenSelector(bool isFrom) async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final allTokens = _visibleTokens(blockchain.tokens);
    final tokens =
        _activeTab == SwapTab.limit &&
            blockchain.activeFamily == ChainFamily.evm
        ? _limitOrderEligibleTokens(allTokens)
        : allTokens;
    if (tokens.isEmpty) {
      _showError(
        _activeTab == SwapTab.limit &&
                blockchain.activeFamily == ChainFamily.evm
            ? 'No ERC-20 tokens available for limit orders on this network.'
            : 'No tokens available on this network.',
      );
      return;
    }
    final selectedToken = await showDialog<Token>(
      context: context,
      builder: (ctx) => SwapTokenSelectorDialog(
        tokens: tokens,
        chainId: _tokenStorageChainId(blockchain),
      ),
    );

    if (selectedToken != null) {
      setState(() {
        if (isFrom) {
          _fromToken = selectedToken;
          _selectedPercentage = -1;
          _fromController.clear();
          // If the new token has no USD price, drop back to token mode.
          if (_fromInputMode == AmountInputMode.fiat &&
              _resolvedTokenUnitPriceUsd(selectedToken) <= 0) {
            _fromInputMode = AmountInputMode.token;
          }
          _syncFromDisplayFromTokenAmount();
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
    _fromDisplayController.removeListener(_handleFromDisplayChanged);
    _fromDisplayController.dispose();
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

  /// Applies a slippage floor to a base-unit output amount, returning the
  /// reduced raw amount and its formatted string. Used so the "minimum
  /// received" shown for Solana/Tron reflects slippage instead of the
  /// optimistic quote.
  ({String raw, String formatted}) _applySlippageFloor(
    String amountOutRaw,
    int slippageBps,
    int decimals,
  ) {
    final outRaw = BigInt.tryParse(amountOutRaw) ?? BigInt.zero;
    final bps = slippageBps.clamp(0, 10000);
    final minRaw = outRaw * BigInt.from(10000 - bps) ~/ BigInt.from(10000);
    final formatted = AmountUtils.formatBaseUnits(
      minRaw,
      decimals,
      maxFractionDigits: math.min(decimals, 8),
    );
    return (raw: minRaw.toString(), formatted: formatted);
  }

  /// Converts a token's `double` balance to a Decimal without losing tiny
  /// values: `double.toString()` renders small numbers in scientific notation
  /// (e.g. `1e-7`), which `Decimal.tryParse` rejects → 0.
  Decimal _balanceAsDecimal(Token token) {
    final fixed = token.balance.toStringAsFixed(token.decimals.clamp(0, 18));
    return Decimal.tryParse(fixed) ?? Decimal.zero;
  }

  /// Native-token gas headroom to leave when the user taps MAX, so a 100% swap
  /// of the gas token doesn't fail at execution for lack of fee funds.
  ///
  /// For EVM this is a LIVE estimate (current gas price × typical swap gas), so
  /// it shrinks when the network is cheap — letting users MAX-swap small native
  /// balances when gas actually allows it — and only grows under congestion.
  /// The per-chain constants are conservative fallbacks used only when the live
  /// estimate can't be fetched. Non-EVM chains use a flat headroom.
  Future<Decimal> _nativeGasBuffer(BlockchainService blockchain) async {
    if (blockchain.activeFamily == ChainFamily.solana) {
      // Solana fees are near-deterministic, so a live "gas price" estimate
      // doesn't apply. Size the flat buffer to cover the worst realistic case:
      // a SOL→new-token swap that must create an associated token account
      // (~0.00204 SOL rent) plus the base signature fee and a priority-fee
      // margin. 0.003 SOL keeps that swap from stranding the user.
      return Decimal.parse('0.003');
    }
    if (blockchain.activeFamily == ChainFamily.tron) {
      // Tron meters Energy/Bandwidth, not a fetchable gas price. A precise
      // figure needs simulating the swap's energy and accounting for the
      // wallet's staked resources; this flat headroom covers the common case.
      return Decimal.parse('3'); // TRX energy/bandwidth headroom
    }

    // EVM: prefer a live estimate so the buffer matches real gas cost.
    final estimatedWei = await _tokenApprovalService.estimateNativeSwapGasWei(
      blockchain: blockchain,
    );
    if (estimatedWei != null && estimatedWei > BigInt.zero) {
      // EVM gas tokens are 18-decimal.
      final buffer = Decimal.tryParse(
        AmountUtils.formatBaseUnits(estimatedWei, 18, maxFractionDigits: 18),
      );
      if (buffer != null && buffer > Decimal.zero) {
        return buffer;
      }
    }

    // Fallback constants (live estimate unavailable).
    switch (blockchain.activeChain.chainId) {
      case 1: // Ethereum mainnet
        return Decimal.parse('0.005');
      case 42161: // Arbitrum
      case 10: // Optimism
      case 8453: // Base
      case 59144: // Linea
      case 534352: // Scroll
        return Decimal.parse('0.0005');
      case 56: // BNB
        return Decimal.parse('0.002');
      case 137: // Polygon
        return Decimal.parse('0.03');
      case 43114: // Avalanche
        return Decimal.parse('0.01');
      default:
        return Decimal.parse('0.002');
    }
  }

  Future<void> _setPercentage(int percent) async {
    if (_fromToken == null) return;
    final balance = _balanceAsDecimal(_fromToken!);
    var amount = balance * Decimal.parse((percent / 100).toStringAsFixed(2));

    if (percent == 100 &&
        _fromToken!.effectiveTokenStandard == TokenStandard.native) {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final gasBuffer = await _nativeGasBuffer(blockchain);
      if (!mounted) return;
      amount = amount - gasBuffer;
      if (amount < Decimal.zero) {
        amount = Decimal.zero;
      }
    }

    final displayDecimals = _fromToken!.decimals > 6 ? 6 : _fromToken!.decimals;
    setState(() {
      _selectedPercentage = percent;
      _fromController.text = amount > Decimal.zero
          ? formatDecimalInput(amount, displayDecimals)
          : '0';
    });
    _syncFromDisplayFromTokenAmount();
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

  double _usdValueFor(Token? token, double amount) {
    if (token == null || amount <= 0) return 0.0;
    double price = token.unitPriceUsd;
    // Fallback: use cached CoinGecko price when the token model has no price.
    if (price <= 0 &&
        token.coinGeckoId != null &&
        token.coinGeckoId!.isNotEmpty) {
      price = _cachedTokenPrice(token.coinGeckoId) ?? 0.0;
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
          otherPrice = _cachedTokenPrice(other.coinGeckoId) ?? 0.0;
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

    final feeRate = quote.platformFeePercent / 100.0;
    if (feeRate > 0) {
      return feeUsd / feeRate;
    }

    return 0.0;
  }

  /// Returns the native token's USD price from the cache or token model.
  double get _nativeTokenPriceUsd {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final nativeId = blockchain.activeNetworkCoinGeckoId;
    if (nativeId != null && nativeId.isNotEmpty) {
      final cached = _cachedTokenPrice(nativeId);
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
    if (!_tokensShareNetwork(a, b)) return false;
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

  bool _tokensShareNetwork(Token a, Token b) {
    final keyA = a.networkKey?.trim().toLowerCase() ?? '';
    final keyB = b.networkKey?.trim().toLowerCase() ?? '';
    return keyA.isEmpty || keyB.isEmpty || keyA == keyB;
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
    _currentRelayQuote = null;
    _currentSolanaQuote = null;
    _currentTronQuote = null;
    _feeUsd = 0.0;
    _feeNative = 0.0;
    _platformFeeUsd = 0.0;
    _toController.clear();
    if (clearInputAmounts) {
      _fromController.clear();
      _syncFromDisplayFromTokenAmount();
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

  String? _transactionDetailsUrl(String hash) {
    // Accept EVM (0x + 64 hex), Solana (base58 ~87 chars), Tron (64 hex).
    // Reject short gasless trade-order IDs (typically <40 chars).
    if (hash.length < 40) return null;
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final explorerUrl = blockchain.activeNetworkExplorerUrl?.trim();
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
    String? networkKey,
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
        networkKey: networkKey,
      ),
    );
  }

  String _gaslessApprovalFundingMessage({
    required Token token,
    required BlockchainService blockchain,
    BigInt? estimatedApprovalFeeWei,
  }) {
    final nativeSymbol = blockchain.activeNetworkSymbol;
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
    final nativeSymbol = blockchain.activeNetworkSymbol;
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

  String _mapErrorMessage(String? raw) {
    final l = AppLocalizations.of(context);
    if (raw == null || raw.isEmpty) {
      return '${l.swapFailedTitle}. ${l.tryAgain}.';
    }
    final lower = raw.toLowerCase();
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final nativeSymbol = blockchain.activeNetworkSymbol;

    if (isSolanaSwapBalanceError(lower)) {
      return 'You don\'t have enough SOL to complete this swap. Add more SOL to cover the swap amount plus network fees.';
    }
    if (isSolanaSwapAddressError(lower)) {
      return 'Selected Solana wallet address is invalid. Switch to a Solana wallet and try again.';
    }
    if (isSwapPriceMovementError(lower)) {
      return 'Swap failed due to price movement. Try increasing your slippage tolerance.';
    }

    if (lower.contains('failed to get quotes') ||
        lower.contains('could not find any route') ||
        lower.contains('no solana swap route') ||
        lower.contains('no swap route') ||
        lower.contains('route not found') ||
        lower.contains('amount too low')) {
      return 'Amount is too low for this swap. Try a larger amount.';
    }
    if (lower.contains('swap quote response was missing') ||
        lower.contains('missing the unsigned transaction') ||
        lower.contains('transaction":""') ||
        lower.contains('transaction is empty')) {
      return 'Amount is too low for this swap. Try a larger amount.';
    }
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
      return 'Amount is too low for this swap. Try a larger amount.';
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
      return 'Amount is too low for this swap. Try a larger amount.';
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
    final chainId = blockchain.activeTokenStorageChainId;
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
      _syncVisibleTokensFrom(blockchain);
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

      final status = extractGaslessStatusValue(statusData)?.toLowerCase();
      final txHash = extractGaslessTxHash(statusData);

      if (txHash != null && looksLikeTxHash(txHash)) {
        progressController.setSwapPending(
          reference: shortHash(txHash),
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
              networkKey: blockchain.activeNetworkKey,
            );
          }
          progressController.setSuccess(
            reference: shortHash(txHash),
            detailsUrl: _transactionDetailsUrl(txHash),
          );
        } else {
          progressController.setError(
            l.transactionPendingConfirmation,
            reference: shortHash(txHash),
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
          final notificationTxHash = looksLikeTxHash(tradeHash)
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
            txHash: looksLikeTxHash(tradeHash) ? tradeHash : null,
            fromAmount: fromAmountText,
            fromTokenName: fromSymbol,
            fromTokenSymbol: fromSymbol,
            toAmount: toAmountText,
            toTokenSymbol: toSymbol,
            networkName: networkName,
            chainId: chainId,
            networkKey: blockchain.activeNetworkKey,
          );
        }
        progressController.setSuccess(reference: shortHash(tradeHash));
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
          reference: shortHash(tradeHash),
        );
        return;
      }

      if (status == null || pendingStates.contains(status)) {
        failedStatusStreak = 0;
        continue;
      }
    }

    if (mounted) {
      progressController.setGaslessPending(reference: shortHash(tradeHash));
    }
  }

  Future<void> _refreshWalletState({BlockchainService? blockchain}) async {
    final address = _walletAddress;
    if (address == null) return;
    final activeBlockchain =
        blockchain ?? Provider.of<BlockchainService>(context, listen: false);
    if (activeBlockchain.activeFamily == ChainFamily.evm) {
      await activeBlockchain.refreshWalletTokens(
        address,
        chainId: activeBlockchain.activeChain.chainId,
      );
    } else {
      await activeBlockchain.refreshWalletTokens(address);
    }
    await _refreshTokenPrices();
    if (!mounted) return;
    setState(() {
      _syncVisibleTokensFrom(activeBlockchain);
    });
    unawaited(
      Future<void>.delayed(_followUpWalletRefreshDelay, () async {
        try {
          if (activeBlockchain.activeFamily == ChainFamily.evm) {
            await activeBlockchain.refreshWalletTokens(
              address,
              chainId: activeBlockchain.activeChain.chainId,
            );
          } else {
            await activeBlockchain.refreshWalletTokens(address);
          }
          await _refreshTokenPrices();
          if (!mounted) return;
          setState(() {
            _syncVisibleTokensFrom(activeBlockchain);
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
        looksLikeTxHash(txHash)) {
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
    final amount = parseDecimalAmount(amountText);
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

    // Route to chain-specific quote handler
    if (blockchain.activeFamily == ChainFamily.solana) {
      await _getSolanaQuote(requestId: requestId);
      return;
    }
    if (blockchain.activeFamily == ChainFamily.tron) {
      await _getTronQuote(requestId: requestId);
      return;
    }

    // EVM path
    if (!_swapService.isChainSupported(
      blockchain.activeChain.chainId,
      isGasless: _isGasless,
    )) {
      if (!_isGasless &&
          await _tryRelaySwapQuote(
            requestId: requestId,
            blockchain: blockchain,
            amountWei: toWeiAmount(_fromController.text, _fromToken!.decimals),
          )) {
        return;
      }
      if (mounted && requestId == _quoteRequestId) {
        setState(() {
          _quoteStatusMessage = l.networkError;
          _resetQuoteState(clearQuoteStatusMessage: false);
          _isCalculating = false;
        });
      }
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
      final amountWei = toWeiAmount(_fromController.text, _fromToken!.decimals);
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
        final usedRelay =
            !_isGasless &&
            await _tryRelaySwapQuote(
              requestId: requestId,
              blockchain: blockchain,
              amountWei: amountWei,
            );
        if (!usedRelay && mounted && requestId == _quoteRequestId) {
          final mapped = _mapErrorMessage(_swapService.lastError);
          setState(() {
            _quoteStatusMessage = mapped;
            _resetQuoteState(
              preserveRequestId: true,
              clearQuoteStatusMessage: false,
            );
          });
        }
      }
    } on TimeoutException {
      final amountWei = toWeiAmount(_fromController.text, _fromToken!.decimals);
      final usedRelay =
          !_isGasless &&
          await _tryRelaySwapQuote(
            requestId: requestId,
            blockchain: blockchain,
            amountWei: amountWei,
          );
      if (!usedRelay && mounted && requestId == _quoteRequestId) {
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

  Future<bool> _tryRelaySwapQuote({
    required int requestId,
    required BlockchainService blockchain,
    required String? amountWei,
  }) async {
    final from = _fromToken;
    final to = _toToken;
    final wallet = _walletAddress;
    if (from == null ||
        to == null ||
        wallet == null ||
        wallet.isEmpty ||
        amountWei == null ||
        amountWei == '0') {
      return false;
    }
    final chainId = blockchain.activeChain.chainId;
    final quote = await _relaySwapService
        .getQuote(
          originChainId: chainId,
          destinationChainId: chainId,
          originCurrency: (from.contractAddress ?? '').isEmpty
              ? BridgeService.nativeCurrency
              : from.contractAddress!,
          destinationCurrency: (to.contractAddress ?? '').isEmpty
              ? BridgeService.nativeCurrency
              : to.contractAddress!,
          amountWei: amountWei,
          walletAddress: wallet,
          recipientAddress: wallet,
          amountUsd: from.priceUsd > 0
              ? _parseAmount(_fromController) * from.priceUsd
              : null,
        )
        .timeout(_quoteUiTimeout);
    if (quote == null || !mounted || requestId != _quoteRequestId) return false;

    final rawOut = BigInt.tryParse(quote.amountOut) ?? BigInt.zero;
    if (rawOut <= BigInt.zero) return false;
    final formatted = AmountUtils.formatBaseUnits(
      rawOut,
      to.decimals,
      maxFractionDigits: 8,
    );
    final inAmount = _parseAmount(_fromController);
    final outAmount = double.tryParse(formatted) ?? 0;
    final synthetic = SwapQuote(
      amountOutWei: quote.amountOut,
      minAmountOutWei: quote.amountOut,
      amountOutFormatted: formatted,
      minAmountOutFormatted: formatted,
      networkFeeUsd: quote.gasFeeUsd + quote.bridgeFeeUsd,
      networkFeeNative: 0,
      allowanceTarget: '',
      allowanceSpender: null,
      needsAllowance: false,
      hasBalanceIssue: false,
      balanceNeeded: null,
      balanceActual: null,
      platformFeeBps: quote.platformFeeBps ?? 0,
      platformFeeUsd: quote.platformFeeUsd ?? 0,
    );
    setState(() {
      _currentRelayQuote = quote;
      _currentQuote = synthetic;
      _toController.text = formatted;
      _pricing = _formatRateText(inAmount > 0 ? outAmount / inAmount : 0);
      _feeUsd = synthetic.networkFeeUsd;
      _feeNative = 0;
      _platformFeeUsd = synthetic.platformFeeUsd;
      _quoteStatusMessage = null;
      _isCalculating = false;
    });
    return true;
  }

  // ── Cached Solana/Tron quote objects (used during execution) ─────────────
  SolanaSwapQuote? _currentSolanaQuote;
  TronSwapQuote? _currentTronQuote;

  Future<void> _getSolanaQuote({required int requestId}) async {
    try {
      final fromMint = _fromToken!.contractAddress?.isNotEmpty == true
          ? _fromToken!.contractAddress!
          : 'So11111111111111111111111111111111111111112';
      final toMint = _toToken!.contractAddress?.isNotEmpty == true
          ? _toToken!.contractAddress!
          : 'So11111111111111111111111111111111111111112';
      final amountLamports = toWeiAmount(
        _fromController.text,
        _fromToken!.decimals,
      );
      final inAmount = _parseAmount(_fromController);
      final fromTokenPriceUsd = _resolvedTokenUnitPriceUsd(_fromToken);
      final sellAmountUsd = inAmount > 0 && fromTokenPriceUsd > 0
          ? inAmount * fromTokenPriceUsd
          : null;
      if (amountLamports == null || amountLamports == '0') {
        if (mounted && requestId == _quoteRequestId) {
          setState(() {
            _quoteStatusMessage = 'Enter a valid amount.';
            _resetQuoteState(clearQuoteStatusMessage: false);
            _isCalculating = false;
          });
        }
        return;
      }

      final quote = await _solanaSwapService
          .getQuote(
            fromMint: fromMint,
            toMint: toMint,
            amountLamports: amountLamports,
            walletAddress: _walletAddress ?? '',
            sellAmountUsd: sellAmountUsd,
            slippageBps: _slippageBps,
          )
          .timeout(_quoteUiTimeout);

      if (!mounted || requestId != _quoteRequestId) return;

      if (quote != null) {
        final rawOutAmount = double.tryParse(quote.amountOutFormatted) ?? 0.0;
        final unitRate = inAmount > 0 ? (rawOutAmount / inAmount) : 0.0;
        // Display a real slippage-adjusted minimum rather than the optimistic
        // quote, so "minimum received" doesn't understate slippage risk.
        final solMinOut = _applySlippageFloor(
          quote.amountOutRaw,
          _slippageBps,
          _toToken?.decimals ?? 0,
        );
        setState(() {
          _currentSolanaQuote = quote;
          _pricing = _formatRateText(unitRate);
          _quoteStatusMessage = null;
          _toController.text = quote.amountOutFormatted;
          _currentQuote = SwapQuote(
            amountOutWei: quote.amountOutRaw,
            minAmountOutWei: solMinOut.raw,
            amountOutFormatted: quote.amountOutFormatted,
            minAmountOutFormatted: solMinOut.formatted,
            networkFeeNative: 0.0,
            networkFeeUsd: quote.networkFeeUsd,
            platformFeeBps: quote.platformFeeBps,
            platformFeeUsd: quote.platformFeeUsd,
            allowanceTarget: '',
            allowanceSpender: '',
            needsAllowance: false,
            hasBalanceIssue: false,
            balanceNeeded: null,
            balanceActual: null,
          );
          _feeNative = 0.0;
          _feeUsd = quote.networkFeeUsd;
          _platformFeeUsd = quote.platformFeeUsd;
          _isCalculating = false;
        });
      } else {
        final mapped = _mapErrorMessage(_solanaSwapService.lastError);
        setState(() {
          _currentSolanaQuote = null;
          _quoteStatusMessage = mapped;
          _resetQuoteState(
            preserveRequestId: true,
            clearQuoteStatusMessage: false,
          );
          _isCalculating = false;
        });
      }
    } on TimeoutException {
      if (mounted && requestId == _quoteRequestId) {
        setState(() {
          _currentSolanaQuote = null;
          _quoteStatusMessage = 'Quote timed out. Please try again.';
          _resetQuoteState(
            preserveRequestId: true,
            clearQuoteStatusMessage: false,
          );
          _isCalculating = false;
        });
      }
    } catch (e) {
      if (mounted && requestId == _quoteRequestId) {
        setState(() {
          _currentSolanaQuote = null;
          _quoteStatusMessage = _mapErrorMessage(e.toString());
          _resetQuoteState(
            preserveRequestId: true,
            clearQuoteStatusMessage: false,
          );
          _isCalculating = false;
        });
      }
    }
  }

  Future<void> _getTronQuote({required int requestId}) async {
    try {
      final fromToken = _fromToken!.contractAddress?.isNotEmpty == true
          ? _fromToken!.contractAddress!
          : 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb';
      final toToken = _toToken!.contractAddress?.isNotEmpty == true
          ? _toToken!.contractAddress!
          : 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb';
      final amountSun = toWeiAmount(_fromController.text, _fromToken!.decimals);
      final inAmount = _parseAmount(_fromController);
      final fromTokenPriceUsd = _resolvedTokenUnitPriceUsd(_fromToken);
      final sellAmountUsd = inAmount > 0 && fromTokenPriceUsd > 0
          ? inAmount * fromTokenPriceUsd
          : null;
      if (amountSun == null || amountSun == '0') {
        if (mounted && requestId == _quoteRequestId) {
          setState(() {
            _quoteStatusMessage = 'Enter a valid amount.';
            _resetQuoteState(clearQuoteStatusMessage: false);
            _isCalculating = false;
          });
        }
        return;
      }

      final quote = await _tronSwapService
          .getQuote(
            fromToken: fromToken,
            toToken: toToken,
            amountSun: amountSun,
            walletAddress: _walletAddress ?? '',
            sellAmountUsd: sellAmountUsd,
            slippageBps: _slippageBps,
          )
          .timeout(_quoteUiTimeout);

      if (!mounted || requestId != _quoteRequestId) return;

      if (quote != null) {
        final rawOutAmount = double.tryParse(quote.amountOutFormatted) ?? 0.0;
        final unitRate = inAmount > 0 ? (rawOutAmount / inAmount) : 0.0;
        final tronMinOut = _applySlippageFloor(
          quote.amountOutRaw,
          _slippageBps,
          _toToken?.decimals ?? 0,
        );
        setState(() {
          _currentTronQuote = quote;
          _pricing = _formatRateText(unitRate);
          _quoteStatusMessage = null;
          _toController.text = quote.amountOutFormatted;
          _currentQuote = SwapQuote(
            amountOutWei: quote.amountOutRaw,
            minAmountOutWei: tronMinOut.raw,
            amountOutFormatted: quote.amountOutFormatted,
            minAmountOutFormatted: tronMinOut.formatted,
            networkFeeNative: 0.0,
            networkFeeUsd: quote.networkFeeUsd,
            platformFeeBps: quote.platformFeeBps,
            platformFeeUsd: quote.platformFeeUsd,
            allowanceTarget: '',
            allowanceSpender: '',
            needsAllowance: false,
            hasBalanceIssue: false,
            balanceNeeded: null,
            balanceActual: null,
          );
          _feeNative = 0.0;
          _feeUsd = quote.networkFeeUsd;
          _platformFeeUsd = quote.platformFeeUsd;
          _isCalculating = false;
        });
      } else {
        final mapped = _mapErrorMessage(_tronSwapService.lastError);
        setState(() {
          _currentTronQuote = null;
          _quoteStatusMessage = mapped;
          _resetQuoteState(
            preserveRequestId: true,
            clearQuoteStatusMessage: false,
          );
          _isCalculating = false;
        });
      }
    } on TimeoutException {
      if (mounted && requestId == _quoteRequestId) {
        setState(() {
          _currentTronQuote = null;
          _quoteStatusMessage = 'Quote timed out. Please try again.';
          _resetQuoteState(
            preserveRequestId: true,
            clearQuoteStatusMessage: false,
          );
          _isCalculating = false;
        });
      }
    } catch (e) {
      if (mounted && requestId == _quoteRequestId) {
        setState(() {
          _currentTronQuote = null;
          _quoteStatusMessage = _mapErrorMessage(e.toString());
          _resetQuoteState(
            preserveRequestId: true,
            clearQuoteStatusMessage: false,
          );
          _isCalculating = false;
        });
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
      final fromAmount = parseDecimalAmount(_fromController.text);
      final limitPrice = parseDecimalAmount(_limitPriceController.text);
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
        nextToAmount = formatDecimalInput(toAmount, displayDecimals);
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

  /// Returns limit orders for the active chain, adapted for the shared UI widget.
  /// Solana Jupiter Trigger orders are converted to [LimitOrderSummary] shape.
  List<LimitOrderSummary> get _activeChainLimitOrders {
    final bc = Provider.of<BlockchainService>(context, listen: false);
    if (!_supportsLimitTab(bc)) {
      return const [];
    }
    if (bc.activeFamily == ChainFamily.solana) {
      return _solanaLimitOrders
          .map(
            (o) => LimitOrderSummary(
              id: o.orderAccount,
              walletAddress: _walletAddress ?? '',
              chainId: -501,
              sellToken: o.inputMint,
              buyToken: o.outputMint,
              sellAmount: o.inputAmount,
              buyAmount: o.expectedOutputAmount,
              kind: o.triggerCondition == 'below' ? 'buy' : 'sell',
              targetPrice: o.triggerPriceUsd?.toString() ?? '',
              expiry: o.expiredAt ?? 0,
              status: o.status,
              orderUid: o.orderAccount,
            ),
          )
          .toList();
    }
    final chainId = bc.activeChain.chainId;
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
          _solanaLimitOrders = const [];
          _isLoadingLimitOrders = false;
          _isLoadingSolanaLimitOrders = false;
        });
      }
      return;
    }

    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    if (!_supportsLimitTab(blockchain)) {
      if (mounted) {
        setState(() {
          _limitOrders = const [];
          _solanaLimitOrders = const [];
          _isLoadingLimitOrders = false;
          _isLoadingSolanaLimitOrders = false;
        });
      }
      return;
    }

    if (blockchain.activeFamily == ChainFamily.solana) {
      if (!looksLikeSolanaPublicKey(walletAddress)) {
        if (mounted) {
          setState(() {
            _solanaLimitOrders = const [];
            _isLoadingSolanaLimitOrders = false;
          });
        }
        return;
      }
      // Fetch Jupiter Trigger orders for Solana. Authentication signs a
      // challenge with the local wallet key (no user prompt) and the JWT is
      // cached for 24h, so this stays cheap on refresh.
      if (showLoading && mounted) {
        setState(() => _isLoadingSolanaLimitOrders = true);
      }
      final orders = await _solanaLimitService.getOrders(
        walletAddress: walletAddress,
        state: 'active',
        signMessage: (message) =>
            _walletService.signSolanaMessageRaw(walletAddress, message),
      );
      if (!mounted) return;
      if (_solanaLimitService.lastError != null &&
          _solanaLimitService.lastError!.isNotEmpty) {
        setState(() => _isLoadingSolanaLimitOrders = false);
        if (surfaceErrors) {
          _showError(_mapErrorMessage(_solanaLimitService.lastError));
        }
        return;
      }
      setState(() {
        _solanaLimitOrders = orders;
        _isLoadingSolanaLimitOrders = false;
      });
      return;
    }

    // EVM path
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
      final isOpenOcean = order.provider == 'openocean';
      final signature = isOpenOcean
          ? await _walletService.signMessageForAddress(
              walletAddress,
              buildOpenOceanCancelMessage(orderUid),
            )
          : await _walletService.signTypedDataForAddress(
              walletAddress,
              jsonEncode(
                buildCowOrderCancellationTypedData(
                  chainId: order.chainId,
                  orderUids: [orderUid],
                ),
              ),
            );
      final cancelled = await _swapService.cancelLimitOrder(
        orderId: order.id,
        walletAddress: walletAddress,
        signature: signature,
        signingScheme: isOpenOcean ? 'personal_sign' : 'eip712',
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
      // Only include steps whose Showcase target is actually mounted. Some
      // targets are conditional on the limit side (e.g. the amount card's
      // showcase only renders in buy mode), and passing an unmounted key to
      // startShowCase leaves showcaseview stuck on a blank blur barrier that
      // swallows all input — which reads as the whole Limit tab freezing until
      // the session is restarted.
      final showcaseKeys = <GlobalKey>[
        _limitTabShowcaseKey,
        _limitAmountsShowcaseKey,
        _limitExecutionPriceShowcaseKey,
        _limitExpiryShowcaseKey,
        _limitSummaryShowcaseKey,
        _limitSubmitShowcaseKey,
      ].where((key) => key.currentContext != null).toList();
      if (showcaseKeys.isEmpty) {
        return;
      }
      ShowcaseView.get().startShowCase(showcaseKeys);
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

  int _resolveOpenOceanLimitExpiryMs() {
    final targetSeconds = _resolveLimitExpirySeconds();
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final rawSeconds = targetSeconds - nowSeconds;
    final durationSeconds = rawSeconds
        .clamp(10 * 60, 365 * 24 * 60 * 60)
        .toInt();
    return durationSeconds * 1000;
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
    if (_walletAddress == null || _walletAddress!.isEmpty) {
      _showError(l.noActiveWalletFound);
      return;
    }
    if (!_supportsLimitTab(blockchain)) {
      _showError(_limitUnsupportedMessage());
      return;
    }

    // Route to Solana limit order handler
    if (blockchain.activeFamily == ChainFamily.solana) {
      await _submitSolanaLimitOrder();
      return;
    }

    final chainId = blockchain.activeChain.chainId;
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
    final makerAmount = parseDecimalAmount(_fromController.text);
    final limitPrice = parseDecimalAmount(_limitPriceController.text);
    if (makerAmount <= Decimal.zero || limitPrice <= Decimal.zero) {
      _showError(l.enterValidAmount);
      return;
    }
    final makerAmountWei = toWeiAmount(_fromController.text, from.decimals);
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
    // Truncate to the buy token's decimals before converting — buyAmountDecimal
    // can carry up to 18 fraction digits (division / multiplication), and
    // parseDecimalToBaseUnits throws for any token with fewer decimals (e.g.
    // USDC/USDT=6), which would silently fail every submission.
    final buyAmountWei = AmountUtils.parseDecimalToBaseUnits(
      formatDecimalInput(buyAmountDecimal, to.decimals),
      to.decimals,
    ).toString();
    if (buyAmountWei == '0') {
      _showError(l.enterValidAmount);
      return;
    }
    final allowanceTarget = openOceanLimitContractForChain(chainId);
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
          reference: shortHash(txHash),
          detailsUrl: _transactionDetailsUrl(txHash),
        );
        final confirmed = await _waitForTxConfirmation(txHash);
        if (!confirmed) {
          progressController!.setError(
            l.approvalPendingConfirmation,
            reference: shortHash(txHash),
            detailsUrl: _transactionDetailsUrl(txHash),
          );
          return;
        }
      }

      final expireTimeMs = _resolveOpenOceanLimitExpiryMs();
      final order = buildOpenOceanLimitOrderPayload(
        makerAsset: from.contractAddress!,
        takerAsset: to.contractAddress!,
        makerAmount: makerAmountWei,
        takerAmount: buyAmountWei,
        orderMaker: _walletAddress!,
        expireTimeMs: expireTimeMs,
        kind: _currentLimitKind,
      );

      progressController?.setSwapSubmitting();
      final signature = await _walletService.signMessageForAddress(
        _walletAddress!,
        buildOpenOceanLimitOrderMessage(
          makerAsset: from.contractAddress!,
          takerAsset: to.contractAddress!,
          makerAmount: makerAmountWei,
          takerAmount: buyAmountWei,
          expireTimeMs: expireTimeMs,
        ),
      );

      final result = await _swapService.createLimitOrder(
        chainId: chainId,
        walletAddress: _walletAddress!,
        order: order,
        signature: signature,
        signingScheme: 'personal_sign',
        provider: 'openocean',
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

  /// Submit a Jupiter Trigger V2 limit order on Solana.
  ///
  /// V2 flow:
  ///   1. POST /jupiter/limit/create → deposit/craft → unsigned deposit tx
  ///   2. Sign + submit deposit tx on-chain
  ///   3. POST /jupiter/limit/confirm → orders/price → order finalized
  Future<void> _submitSolanaLimitOrder() async {
    final l = AppLocalizations.of(context);
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
    final makerAmount = parseDecimalAmount(_fromController.text);
    final limitPrice = parseDecimalAmount(_limitPriceController.text);
    if (makerAmount <= Decimal.zero || limitPrice <= Decimal.zero) {
      _showError(l.enterValidAmount);
      return;
    }

    final inputMint = from.contractAddress?.isNotEmpty == true
        ? from.contractAddress!
        : 'So11111111111111111111111111111111111111112';
    final outputMint = to.contractAddress?.isNotEmpty == true
        ? to.contractAddress!
        : 'So11111111111111111111111111111111111111112';

    final inputAmountLamports = toWeiAmount(
      _fromController.text,
      from.decimals,
    );
    if (inputAmountLamports == null || inputAmountLamports == '0') {
      _showError(l.enterValidAmount);
      return;
    }

    // Jupiter Trigger V2 enforces a 10 USD minimum order size — fail fast
    // here instead of after the user has signed a deposit.
    final fromUsd = from.priceUsd;
    if (fromUsd > 0 && makerAmount.toDouble() * fromUsd < 10.0) {
      _showError(
        'Jupiter limit orders need a value of at least \$10. Increase the amount and try again.',
      );
      return;
    }

    // Trigger V2 takes a USD trigger price for the target token. The entered
    // limit price is denominated in the quote token, so convert via the quote
    // token's USD price (stables count as $1 when no live price is loaded).
    final quoteToken = _limitQuoteToken;
    final targetToken = _limitTargetToken;
    if (quoteToken == null || targetToken == null) {
      _showError(l.selectTokenTitle);
      return;
    }
    var quoteUsd = quoteToken.priceUsd;
    if (quoteUsd <= 0 && _isStablecoin(quoteToken)) {
      quoteUsd = 1.0;
    }
    if (quoteUsd <= 0) {
      _showError(
        'Live price data for ${quoteToken.symbol} is unavailable, so the trigger price cannot be set. Please try again shortly.',
      );
      return;
    }
    final triggerPriceUsd = limitPrice.toDouble() * quoteUsd;
    // Sell: trigger when the sold token rises to the target price.
    // Buy: trigger when the bought token falls to the target price.
    final triggerMint = _isBuyMode ? outputMint : inputMint;
    final triggerCondition = _isBuyMode ? 'below' : 'above';

    // V2 requires an expiry; "never" maps to roughly one year out.
    final expirySeconds = _limitExpiryOption == _LimitExpiryOption.never
        ? DateTime.now()
                  .add(const Duration(days: 365))
                  .millisecondsSinceEpoch ~/
              1000
        : _resolveLimitExpirySeconds();
    final expiresAtMs = expirySeconds * 1000;

    if (_isSubmittingLimit) return;
    setState(() => _isSubmittingLimit = true);
    TransactionProgressController? progressController;
    try {
      progressController = _openProgressFlow(
        flow: TransactionProgressFlow.generic,
      );
      progressController.setSwapSubmitting();

      // ── Step 0: authenticate (24h JWT) and ensure the vault exists ────────
      final authenticated = await _solanaLimitService.ensureAuthenticated(
        walletAddress: _walletAddress!,
        signMessage: (message) =>
            _walletService.signSolanaMessageRaw(_walletAddress!, message),
      );
      if (!mounted) return;
      if (!authenticated) {
        progressController.setError(
          _mapErrorMessage(_solanaLimitService.lastError ?? l.tryAgain),
        );
        return;
      }
      final hasVault = await _solanaLimitService.ensureVault(
        walletAddress: _walletAddress!,
      );
      if (!mounted) return;
      if (!hasVault) {
        progressController.setError(
          _mapErrorMessage(_solanaLimitService.lastError ?? l.tryAgain),
        );
        return;
      }

      // ── Step 1: deposit/craft ──────────────────────────────────────────────
      final depositResult = await _solanaLimitService.createOrder(
        inputMint: inputMint,
        outputMint: outputMint,
        inputAmountLamports: inputAmountLamports,
        walletAddress: _walletAddress!,
      );

      if (!mounted) return;
      if (depositResult == null) {
        final message = _mapErrorMessage(
          _solanaLimitService.lastError ?? l.tryAgain,
        );
        progressController.setError(message);
        return;
      }

      // ── Step 2: Sign the deposit transaction. Do NOT broadcast it — the
      // signed bytes go to /confirm and Jupiter submits it on-chain. ─────────
      final txBytes = base64Decode(depositResult.transaction);
      final msgOffset =
          SolanaSwapExecutionService.compactU16ByteLenPublic(txBytes, 0) + 64;
      final messageBytes = Uint8List.sublistView(txBytes, msgOffset);
      final signatureBase58 = await _walletService.signSolanaMessageRaw(
        _walletAddress!,
        messageBytes,
      );
      if (!mounted) return;

      final depositSignedTx =
          SolanaSwapExecutionService.assembleSignedTransaction(
            txBytes,
            signatureBase58,
          );

      // ── Step 3: Confirm the order (orders/price) ───────────────────────────
      final confirmResult = await _solanaLimitService.confirmOrder(
        depositRequestId: depositResult.depositRequestId,
        depositSignedTx: depositSignedTx,
        walletAddress: _walletAddress!,
        inputMint: inputMint,
        outputMint: outputMint,
        inputAmountLamports: inputAmountLamports,
        triggerMint: triggerMint,
        triggerCondition: triggerCondition,
        triggerPriceUsd: triggerPriceUsd,
        expiresAtMs: expiresAtMs,
      );

      if (!mounted) return;
      if (confirmResult == null) {
        final message = _mapErrorMessage(
          _solanaLimitService.lastError ?? 'Order confirmation failed.',
        );
        progressController.setError(message);
        return;
      }

      final txSignature = confirmResult['txSignature']?.toString() ?? '';
      if (txSignature.isNotEmpty) {
        progressController.setSuccess(reference: shortHash(txSignature));
      } else {
        progressController.setSuccess();
      }
      unawaited(_refreshLimitOrders(showLoading: false));
    } on TimeoutException {
      const message = 'Order signing timed out. Please try again.';
      progressController?.setError(message);
    } catch (e) {
      final message = _mapErrorMessage(e.toString());
      progressController?.setError(message);
    } finally {
      if (mounted) {
        setState(() => _isSubmittingLimit = false);
      }
    }
  }

  /// Cancel a Solana Jupiter Trigger V2 limit order.
  Future<void> _cancelSolanaLimitOrder(SolanaLimitOrder order) async {
    if (_cancellingSolanaOrderAccounts.contains(order.orderId)) return;
    setState(() => _cancellingSolanaOrderAccounts.add(order.orderId));
    try {
      final txResult = await _solanaLimitService.cancelOrder(
        orderId: order.orderId,
      );
      if (!mounted) return;
      if (txResult == null) {
        _showError(
          _mapErrorMessage(_solanaLimitService.lastError ?? 'Cancel failed.'),
        );
        return;
      }

      final txBytes = base64Decode(txResult.transaction);
      final msgOffset =
          SolanaSwapExecutionService.compactU16ByteLenPublic(txBytes, 0) + 64;
      final messageBytes = Uint8List.sublistView(txBytes, msgOffset);
      final signatureBase58 = await _walletService.signSolanaMessageRaw(
        _walletAddress!,
        messageBytes,
      );
      if (!mounted) return;

      // Sign the withdrawal tx and hand it back to Jupiter via
      // confirm-cancel — Jupiter broadcasts it and returns the funds.
      final signedTxBase64 =
          SolanaSwapExecutionService.assembleSignedTransaction(
            txBytes,
            signatureBase58,
          );
      final confirmResult = await _solanaLimitService.confirmCancel(
        orderId: order.orderId,
        signedTransaction: signedTxBase64,
        cancelRequestId: txResult.requestId,
      );
      if (!mounted) return;

      if (confirmResult != null) {
        ToastUtils.showSuccess('Limit order cancelled');
        unawaited(_refreshLimitOrders(showLoading: false));
      } else {
        _showError(
          _mapErrorMessage(_solanaLimitService.lastError ?? 'Cancel failed.'),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError(_mapErrorMessage(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _cancellingSolanaOrderAccounts.remove(order.orderId));
      }
    }
  }

  /// Assemble a signed Solana transaction from unsigned bytes + base58 signature.
  Future<SwapQuote?> _refreshExecutionQuote({
    required Token fromToken,
    required Token toToken,
    required String fromAmountWei,
  }) async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    if (blockchain.activeFamily != ChainFamily.evm || _isGasless) {
      return _currentQuote;
    }

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
    final fromAmount = parseDecimalAmount(_fromController.text);
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
    if (blockchain.activeFamily == ChainFamily.evm &&
        _currentRelayQuote == null &&
        !_swapService.isChainSupported(
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
    final fromAmountWei = toWeiAmount(_fromController.text, fromToken.decimals);
    if (fromAmountWei == null || fromAmountWei == '0') {
      _showError(l.enterValidAmount);
      return;
    }

    // Require an authentication factor before signing/broadcasting in-app, the
    // same checkpoint the dApp bridge enforces. Without it, an attacker with an
    // unlocked session could drain funds; it's also a human confirmation step.
    final authorized = await SensitiveAccessGuard.verify(
      context,
      reason: 'Authenticate to authorize this swap',
    );
    if (!authorized) {
      return;
    }
    if (!mounted) return;

    TransactionProgressController? progressController;
    if (mounted) {
      setState(() => _isSwapFlowActive = true);
    }

    try {
      progressController = _openProgressFlow();
      progressController.setPreparing();

      final relayQuote = _currentRelayQuote;
      if (relayQuote != null) {
        await _performRelaySwap(
          quote: relayQuote,
          fromToken: fromToken,
          toToken: toToken,
          progressController: progressController,
        );
        return;
      }

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

  Future<void> _performRelaySwap({
    required BridgeQuote quote,
    required Token fromToken,
    required Token toToken,
    required TransactionProgressController progressController,
  }) async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    progressController.setSwapSubmitting();
    final result = await _relaySwapExecutionService.execute(
      quote: quote,
      blockchain: blockchain,
      walletService: _walletService,
      isNativeInput:
          fromToken.contractAddress == null ||
          fromToken.contractAddress!.isEmpty,
    );
    if (!mounted) return;
    if (!result.success || result.transactionHash == null) {
      progressController.setError(
        _mapErrorMessage(result.error ?? 'Relay swap failed.'),
        reference: result.transactionHash == null
            ? null
            : shortHash(result.transactionHash!),
      );
      return;
    }

    final hash = result.transactionHash!;
    final fromAmountText = _fromController.text.trim();
    final toAmountText = _toController.text.trim();
    _recordSwapHistory(
      txHash: hash,
      fromAmount: fromAmountText,
      fromTokenName: fromToken.name,
      fromTokenSymbol: fromToken.symbol,
      toAmount: toAmountText,
      toTokenSymbol: toToken.symbol,
      networkName: blockchain.activeChain.name,
      chainId: blockchain.activeChain.chainId,
      networkKey: blockchain.activeNetworkKey,
    );
    _clearSubmittedSwapState();
    progressController.setSuccess(
      reference: shortHash(hash),
      detailsUrl: _transactionDetailsUrl(hash),
    );
    unawaited(_refreshWalletState(blockchain: blockchain));
  }

  void _showError(String message) {
    ToastUtils.showError(message);
  }

  Widget _buildNonEvmNetworkCard(BlockchainService blockchain) {
    final networkName = blockchain.activeNetworkName;
    final networkColor = switch (blockchain.activeFamily) {
      ChainFamily.solana => AppColors.primaryAccent,
      ChainFamily.tron => AppColors.primaryAccent,
      ChainFamily.evm => AppColors.accentRed,
    };
    final logoUrl = blockchain.activeNetworkLogoUrl;
    // Show 'Change' only when the wallet supports more than one chain family
    // (i.e. a mnemonic wallet). Pure Solana / Tron PK wallets have a single
    // family and have nothing to switch to.
    final canSwitch = blockchain.enabledFamilies.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Network',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF8894A0),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canSwitch ? _showNetworkSelector : null,
            borderRadius: BorderRadius.circular(8),
            child: Ink(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF151C24),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A333D)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: networkColor.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: logoUrl != null && logoUrl.isNotEmpty
                        ? Image.network(
                            logoUrl,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (context, err, stack) => Icon(
                              Icons.language,
                              color: networkColor,
                              size: 16,
                            ),
                          )
                        : Icon(Icons.language, color: networkColor, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      networkName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (canSwitch) ...[
                    Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
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
        entries: blockchain.networkEntries,
        activeNetworkKey: blockchain.activeNetworkKey,
        onSelect: (entry) {
          blockchain.setActiveNetworkKey(entry.networkKey);
          Navigator.pop(ctx);
        },
        onAddCustomNetwork: blockchain.enabledFamilies.contains(ChainFamily.evm)
            ? () async {
                Navigator.pop(ctx);
                await Navigator.pushNamed(context, '/add-network');
              }
            : null,
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
          reference: shortHash(txHash),
          detailsUrl: _transactionDetailsUrl(txHash),
        );
        final confirmed = await _waitForTxConfirmation(txHash);
        if (!confirmed) {
          progressController.setError(
            l.approvalPendingConfirmation,
            reference: shortHash(txHash),
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

      // ── Solana swap ───────────────────────────────────────────────────────
      if (blockchain.activeFamily == ChainFamily.solana) {
        final solanaQuote = _currentSolanaQuote;
        if (solanaQuote == null) {
          progressController.setError(l.noQuoteAvailable);
          return;
        }
        final execResult = await _solanaSwapExecutionService.execute(
          quote: solanaQuote,
          walletAddress: _walletAddress!,
        );
        if (!mounted) return;
        if (!execResult.success || execResult.transactionHash == null) {
          progressController.setError(
            _mapErrorMessage(execResult.error ?? l.tryAgain),
          );
          return;
        }
        final txHash = execResult.transactionHash!;
        _clearSubmittedSwapState();
        _recordSwapHistory(
          txHash: txHash,
          fromAmount: fromAmountText,
          fromTokenName: fromToken.name,
          fromTokenSymbol: fromToken.symbol,
          toAmount: toAmountText,
          toTokenSymbol: toToken.symbol,
          networkName: 'Solana',
          chainId: -501,
          networkKey: blockchain.activeNetworkKey,
        );
        progressController.setSuccess(
          reference: shortHash(txHash),
          detailsUrl: _transactionDetailsUrl(txHash),
        );
        unawaited(_refreshWalletState(blockchain: blockchain));
        return;
      }

      // ── Tron swap ─────────────────────────────────────────────────────────
      if (blockchain.activeFamily == ChainFamily.tron) {
        final tronQuote = _currentTronQuote;
        if (tronQuote == null) {
          progressController.setError(l.noQuoteAvailable);
          return;
        }
        final execResult = await _tronSwapExecutionService.execute(
          quote: tronQuote,
          walletAddress: _walletAddress!,
        );
        if (!mounted) return;
        if (!execResult.success || execResult.transactionHash == null) {
          progressController.setError(
            _mapErrorMessage(execResult.error ?? l.tryAgain),
          );
          return;
        }
        final txHash = execResult.transactionHash!;
        _clearSubmittedSwapState();
        _recordSwapHistory(
          txHash: txHash,
          fromAmount: fromAmountText,
          fromTokenName: fromToken.name,
          fromTokenSymbol: fromToken.symbol,
          toAmount: toAmountText,
          toTokenSymbol: toToken.symbol,
          networkName: 'Tron',
          chainId: -195,
          networkKey: blockchain.activeNetworkKey,
        );
        progressController.setSuccess(
          reference: shortHash(txHash),
          detailsUrl: _transactionDetailsUrl(txHash),
        );
        unawaited(_refreshWalletState(blockchain: blockchain));
        return;
      }

      // ── EVM swap ──────────────────────────────────────────────────────────
      final result = await _swapExecutionService.execute(
        quote: quote,
        fromToken: fromToken,
        toToken: toToken,
        fromAmountWei: fromAmountWei,
        expectedToAmount: expectedToAmount,
        slippageBps: _slippageBps,
        blockchain: blockchain,
        recipientAddress: _walletAddress!,
        isGasless: _isGasless,
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
              reference: shortHash(result.tradeHash!),
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
              networkName: blockchain.activeNetworkName,
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

      if (_isGasless && !looksLikeTxHash(result.transactionHash!)) {
        _clearSubmittedSwapState();
        progressController.setGaslessPending(
          reference: shortHash(result.transactionHash!),
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
          networkName: blockchain.activeNetworkName,
          rewardReferralOnSwap: true,
          swapAmountUsd: referralSwapAmountUsd,
        );
        return;
      }

      final txHash = result.transactionHash!;
      _clearSubmittedSwapState();
      progressController.setSwapPending(
        reference: shortHash(txHash),
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
            networkName: blockchain.activeNetworkName,
          ),
        );
        _recordSwapHistory(
          txHash: txHash,
          fromAmount: fromAmountText,
          fromTokenName: fromToken.name,
          fromTokenSymbol: fromToken.symbol,
          toAmount: toAmountText,
          toTokenSymbol: toToken.symbol,
          networkName: blockchain.activeNetworkName,
          chainId: blockchain.activeChain.chainId,
          networkKey: blockchain.activeNetworkKey,
        );
        progressController.setSuccess(
          reference: shortHash(txHash),
          detailsUrl: _transactionDetailsUrl(txHash),
        );
      } else {
        progressController.setError(
          l.transactionPendingConfirmation,
          reference: shortHash(txHash),
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
    final limitPrice = parseDecimalAmount(_limitPriceController.text);
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
    final hasQuote =
        (_currentQuote != null ||
            _currentSolanaQuote != null ||
            _currentTronQuote != null) &&
        _toController.text.isNotEmpty;
    final chainSupported =
        blockchain.activeFamily == ChainFamily.solana ||
        blockchain.activeFamily == ChainFamily.tron ||
        _swapService.isChainSupported(
          blockchain.activeChain.chainId,
          isGasless: _isGasless,
        );
    final localHasBalance =
        _fromToken != null &&
        parseDecimalAmount(_fromController.text) <=
            _balanceAsDecimal(_fromToken!);
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
              height: _activeTab == SwapTab.limit ? 82 : 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Navigator.of(context).canPop()
                        ? IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            color: Colors.white,
                            iconSize: 20,
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).backButtonTooltip,
                          )
                        : const SizedBox(width: 48),
                  ),
                  Center(
                    child: _activeTab == SwapTab.limit
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Limit Order',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Place a limit order to buy or sell tokens',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF8894A0),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _activeTab == SwapTab.bridge ? 'BRIDGE' : 'SWAP',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.8,
                            ),
                          ),
                  ),
                  if (_activeTab == SwapTab.limit)
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () {
                          unawaited(_startLimitShowcaseIfNeeded(force: true));
                        },
                        icon: const Icon(Icons.help_outline_rounded),
                        color: const Color(0xFF8894A0),
                        tooltip: 'Limit order help',
                      ),
                    ),
                ],
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
                        showLimitTab: _supportsLimitTab(blockchain),
                        showBridgeTab:
                            blockchain.activeFamily == ChainFamily.evm ||
                            blockchain.activeFamily == ChainFamily.solana,
                        onChanged: (tab) {
                          if (_activeTab == tab) return;
                          if (tab == SwapTab.limit &&
                              !_supportsLimitTab(blockchain)) {
                            return;
                          }
                          if (tab == SwapTab.bridge &&
                              blockchain.activeFamily == ChainFamily.tron) {
                            return;
                          }
                          setState(() {
                            _activeTab = tab;
                            if (tab == SwapTab.limit) {
                              _ensureLimitEligiblePair();
                            }
                          });
                          if (tab == SwapTab.swap) {
                            _getQuote();
                          } else if (tab == SwapTab.limit) {
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
                    // The bridge tab embeds its own origin-chain selector in
                    // the "BRIDGE FROM" card, so skip the network card there.
                    if (blockchain.activeFamily == ChainFamily.evm &&
                        _activeTab != SwapTab.bridge)
                      NetworkCard(
                        chain: blockchain.activeChain,
                        onTap: _showNetworkSelector,
                      )
                    else if (blockchain.activeFamily != ChainFamily.evm &&
                        _activeTab != SwapTab.bridge)
                      _buildNonEvmNetworkCard(blockchain),
                    const SizedBox(height: 16),
                    if (_activeTab == SwapTab.swap)
                      SwapTabContent(
                        blockchain: blockchain,
                        fromController: _fromDisplayController,
                        fromToken: _fromToken,
                        fromUsdValue: fromUsdValue,
                        selectedPercentage: _selectedPercentage,
                        onAmountChanged: (_) {},
                        fromInputMode: _fromInputMode,
                        onToggleFromInputMode:
                            _resolvedTokenUnitPriceUsd(_fromToken) > 0
                            ? _toggleFromInputMode
                            : null,
                        fromEquivalentText: _fromEquivalentText(),
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
                            _cachedTokenPrice(
                              blockchain.activeNetworkCoinGeckoId,
                            ) ??
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
                        slippageBps: _slippageBps,
                        onSlippageChanged: (bps) {
                          setState(() => _slippageBps = bps);
                          _resetQuoteState();
                          _getQuote();
                        },
                      )
                    else if (_activeTab == SwapTab.bridge)
                      BridgeTabContent(
                        blockchain: blockchain,
                        walletService: _walletService,
                        walletAddress: _walletAddress,
                        tokens: _visibleTokens(blockchain.tokens),
                        onSelectFromChain: _showNetworkSelector,
                      )
                    else if (blockchain.activeFamily == ChainFamily.evm ||
                        blockchain.activeFamily == ChainFamily.solana)
                      LimitTabContent(
                        blockchain: blockchain,
                        fromController: _fromDisplayController,
                        fromToken: _fromToken,
                        fromUsdValue: fromUsdValue,
                        selectedPercentage: _selectedPercentage,
                        onAmountChanged: (_) {},
                        fromInputMode: _fromInputMode,
                        onToggleFromInputMode:
                            _resolvedTokenUnitPriceUsd(_fromToken) > 0
                            ? _toggleFromInputMode
                            : null,
                        fromEquivalentText: _fromEquivalentText(),
                        limitPriceInputMode: _limitPriceInputMode,
                        onToggleLimitPriceInputMode:
                            _resolvedTokenUnitPriceUsd(_limitQuoteToken) > 0
                            ? _toggleLimitPriceInputMode
                            : null,
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
                            _cachedTokenPrice(
                              blockchain.activeNetworkCoinGeckoId,
                            ) ??
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
                        isLoadingActiveOrders:
                            blockchain.activeFamily == ChainFamily.solana
                            ? _isLoadingSolanaLimitOrders
                            : _isLoadingLimitOrders,
                        onRefreshActiveOrders: () {
                          unawaited(_refreshLimitOrders(surfaceErrors: true));
                        },
                        onCancelActiveOrder: (order) {
                          if (blockchain.activeFamily == ChainFamily.solana) {
                            final solanaOrder = _solanaLimitOrders
                                .where((o) => o.orderAccount == order.id)
                                .firstOrNull;
                            if (solanaOrder != null) {
                              unawaited(_cancelSolanaLimitOrder(solanaOrder));
                            }
                          } else {
                            unawaited(_cancelLimitOrder(order));
                          }
                        },
                        cancellingOrderIds:
                            blockchain.activeFamily == ChainFamily.solana
                            ? _cancellingSolanaOrderAccounts
                            : _cancellingLimitOrderIds,
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
    final fromAmount = parseDecimalAmount(_fromController.text);
    final limitPrice = parseDecimalAmount(_limitPriceController.text);
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final isSolana = blockchain.activeFamily == ChainFamily.solana;
    // On Solana, SPL tokens don't use ERC-20 approval — skip that check.
    final approvalsOk =
        isSolana ||
        (_fromToken != null &&
            _toToken != null &&
            _tokenRequiresApproval(_fromToken!) &&
            _tokenRequiresApproval(_toToken!));
    return (_walletAddress ?? '').isNotEmpty &&
        _isLimitSupported &&
        fromAmount > Decimal.zero &&
        limitPrice > Decimal.zero &&
        !_tokensAreIdentical(_fromToken, _toToken) &&
        _fromToken != null &&
        _toToken != null &&
        approvalsOk &&
        !_isSubmittingLimit;
  }

  String _limitExecutionPriceText() {
    final limitPrice = parseDecimalAmount(_limitPriceController.text);
    if (limitPrice <= Decimal.zero) {
      return _selectedFiatToTokenRateText(_limitTargetToken);
    }
    final target = _limitTargetToken;
    final quote = _limitQuoteToken;
    return '1 ${target?.symbol ?? ''} $_priceSeparator ${limitPrice.toString()} ${quote?.symbol ?? ''}';
  }

  String _limitExecutionPriceUsdText() {
    final limitPrice = parseDecimalAmount(_limitPriceController.text);
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
    final limitPrice = parseDecimalAmount(_limitPriceController.text);
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
