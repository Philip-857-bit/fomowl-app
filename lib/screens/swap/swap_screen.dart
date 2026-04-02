import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:decimal/decimal.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bottom_navigation.dart';
import '../../models/token.dart';
import '../../services/swap_service.dart';
import '../../services/wallet_service.dart';
import '../../services/blockchain_service.dart';
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
import '../../widgets/token_selector_modal.dart';
import 'dart:async';
import '../transaction/transaction_processing_screen.dart';
import 'widgets/swap_from_card.dart';
import 'widgets/swap_to_card.dart';
import 'widgets/swap_direction_button.dart';
import 'widgets/swap_price_details_card.dart';
import 'widgets/swap_primary_button.dart';
import 'widgets/swap_gasless_toggle.dart';

/// Swap Screen — DEX token swap interface
class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key, this.showBottomNavigation = true});

  final bool showBottomNavigation;

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  static const String _livePriceScope = 'swap_screen';
  static const Duration _quoteUiTimeout = Duration(seconds: 18);
  static const Duration _gaslessStatusPollInterval = Duration(seconds: 2);
  static const Duration _followUpWalletRefreshDelay = Duration(seconds: 3);
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
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
    } else if (_fromToken == null || _toToken == null) {
      final tokens = _visibleTokens(blockchain.tokens);
      _syncSelectedTokens(tokens);
    }
  }

  bool _isCalculating = false;
  String _pricing = '';

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
  bool _isGasless = false;

  String _formatRateText(double outAmount) {
    final from = _fromToken?.symbol ?? '';
    final to = _toToken?.symbol ?? '';
    if (from.isEmpty || to.isEmpty) {
      return outAmount.toStringAsFixed(6);
    }
    return '1 $from $_priceSeparator ${outAmount.toStringAsFixed(6)} $to';
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
    _loadWalletBalance();
    _activateSwapLiveTracking();
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
    final tokens = _visibleTokens(blockchain.tokens);
    final selectedToken = await showDialog<Token>(
      context: context,
      builder: (ctx) => TokenSelectorDialog(
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
          if (_isGasless && !_tokenRequiresApproval(selectedToken)) {
            _isGasless = false;
          }
        } else {
          _toToken = selectedToken;
        }
        _resetQuoteState();
      });
      // Refresh prices so USD values are immediately available for new token
      _refreshTokenPrices();
      _getQuote();
      // Reactivate live tracking for new token pair
      _activateSwapLiveTracking();
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
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
    if (amount > Decimal.zero) _getQuote();
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
      if (value.isNotEmpty) _getQuote();
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

  void _resetQuoteState({bool clearInputAmounts = false}) {
    _quoteRequestId++;
    _pricing = '';
    _currentQuote = null;
    _feeUsd = 0.0;
    _feeNative = 0.0;
    _platformFeeUsd = 0.0;
    _toController.clear();
    if (clearInputAmounts) {
      _fromController.clear();
      _selectedPercentage = -1;
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

  TransactionProgressController _openProgressFlow() {
    final controller = TransactionProgressController(
      flow: TransactionProgressFlow.swap,
    );
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
    if (raw == null || raw.isEmpty) {
      return 'Something went wrong. Please try again.';
    }
    final lower = raw.toLowerCase();
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final nativeSymbol = blockchain.activeChain.symbol;
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
    if (lower.contains('insufficient funds')) {
      return 'You do not have enough $nativeSymbol to cover the amount and gas fees.';
    }
    if (lower.contains('insufficient_balance') ||
        lower.contains('insufficient balance')) {
      final tokenSymbol = _fromToken?.symbol ?? 'token';
      return 'You do not have enough $tokenSymbol for this swap amount.';
    }
    if (lower.contains('invalid chain id')) {
      return 'Swap is not available on this network yet.';
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
      fallback: 'Swap failed. Please try again.',
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
          unawaited(
            _walletNotificationService.notifySwapConfirmed(
              walletAddress: _walletAddress!,
              fromAmount: fromAmountText,
              fromSymbol: fromSymbol,
              toAmount: toAmountText,
              toSymbol: toSymbol,
              networkName: networkName,
            ),
          );
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
    setState(() => _isCalculating = true);
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    if (!_swapService.isChainSupported(
      blockchain.activeChain.chainId,
      isGasless: _isGasless,
    )) {
      setState(() {
        _pricing = l.networkError;
        _resetQuoteState();
        _isCalculating = false;
      });
      return;
    }
    if (_isGaslessSourceUnsupported()) {
      setState(() {
        _pricing = l.networkError;
        _resetQuoteState();
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
            _pricing = l.enterValidAmount;
            _resetQuoteState();
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
          _toController.text = quote.amountOutFormatted;
          _currentQuote = quote;
          _feeNative = feeNative;
          _feeUsd = feeUsd;
          _platformFeeUsd = quote.platformFeeUsd;
        });
      } else {
        final mapped = _mapErrorMessage(_swapService.lastError);
        setState(() {
          _pricing = mapped;
          _resetQuoteState();
        });
      }
    } on TimeoutException {
      if (mounted && requestId == _quoteRequestId) {
        setState(() {
          _pricing = l.tryAgain;
          _resetQuoteState();
        });
      }
    } catch (e) {
      if (mounted && requestId == _quoteRequestId) {
        setState(() {
          _pricing = _mapErrorMessage(e.toString());
          _resetQuoteState();
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
      _resetQuoteState(clearInputAmounts: true);
      if (_isGasless && _isGaslessSourceUnsupported()) {
        _isGasless = false;
      }
    });
    // Reactivate live tracking for swapped token pair
    _activateSwapLiveTracking();
  }

  void _executeSwap() async {
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

    final progressController = _openProgressFlow();
    progressController.setPreparing();

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
  }

  void _showError(String message) {
    ToastUtils.showError(message);
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
      progressController.setApprovalPending();
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
      final result = await _tokenApprovalService.ensureApproval(
        token: fromToken,
        amountWei: fromAmountWei,
        ownerAddress: _walletAddress!,
        blockchain: blockchain,
        allowanceTarget: quote.allowanceSpender ?? quote.allowanceTarget,
      );

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
    final l = AppLocalizations.of(context);
    final blockchain = Provider.of<BlockchainService>(context);
    final fromAmount = _parseAmount(_fromController);
    final toAmount = _parseAmount(_toController);
    final fromUsdValue = _usdValueFor(_fromToken, fromAmount);
    final toUsdValue = _usdValueFor(_toToken, toAmount);
    final priceText = _pricing.isNotEmpty ? _pricing : '--';
    final receiveText = _toController.text.isNotEmpty
        ? '${_currentQuote?.minAmountOutFormatted ?? _toController.text} ${_toToken?.symbol ?? ''} min'
        : '--';
    final swapBusy = _isApproving || _isSwapping;
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                l.swap,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    SwapFromCard(
                      controller: _fromController,
                      token: _fromToken,
                      usdValue: fromUsdValue,
                      balance: _fromToken?.balance ?? 0,
                      selectedPercentage: _selectedPercentage,
                      onAmountChanged: _onFromAmountChanged,
                      onSelectToken: () => _showTokenSelector(true),
                      onPercentSelected: _setPercentage,
                      chainId: blockchain.activeChain.chainId,
                    ),
                    const SizedBox(height: 4),
                    SwapDirectionButton(onPressed: _swapTokens),
                    const SizedBox(height: 4),
                    SwapToCard(
                      token: _toToken,
                      amountText: _toController.text,
                      usdValue: toUsdValue,
                      balance: _toToken?.balance ?? 0,
                      isCalculating: _isCalculating,
                      onSelectToken: () => _showTokenSelector(false),
                      chainId: blockchain.activeChain.chainId,
                    ),
                    const SizedBox(height: 24),
                    SwapPriceDetailsCard(
                      priceText: priceText,
                      platformFeePercent:
                          _currentQuote?.platformFeePercent ?? 1.0,
                      platformFeeUsd: _platformFeeUsd,
                      feeAmountUsd: _feeUsd,
                      feeAmountNative: _feeNative,
                      nativeFeeSymbol: blockchain.activeChain.symbol,
                      receiveText: receiveText,
                      priceSeparator: _priceSeparator,
                      swapAmountUsd: fromUsdValue,
                      gaslessFeeCovered: _isGasless,
                      nativePriceUsd:
                          _tokenPriceCache[blockchain
                              .activeChain
                              .coinGeckoId] ??
                          0.0,
                    ),
                    const SizedBox(height: 24),
                    SwapPrimaryButton(
                      enabled: swapEnabled,
                      isBusy: swapBusy,
                      onPressed: _executeSwap,
                      label: buttonLabel,
                    ),
                    if (_canOfferGaslessToggle) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SwapGaslessToggle(
                          value: _isGasless,
                          onChanged: (val) {
                            setState(() {
                              _isGasless = val;
                              _resetQuoteState();
                            });
                            _getQuote();
                          },
                        ),
                      ),
                    ],
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
}
