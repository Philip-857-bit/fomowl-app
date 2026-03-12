import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:decimal/decimal.dart';
import '../../constants/app_colors.dart';
import '../../widgets/bottom_navigation.dart';
import '../../models/token.dart';
import '../../services/swap_service.dart';
import '../../services/wallet_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/token_approval_service.dart';
import '../../services/swap_execution_service.dart';
import '../../services/transaction_monitor.dart';
import '../../services/referral_service.dart';
import '../../utils/amount_utils.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/token_selector_modal.dart';
import 'dart:async';
import 'widgets/swap_from_card.dart';
import 'widgets/swap_to_card.dart';
import 'widgets/swap_direction_button.dart';
import 'widgets/swap_price_details_card.dart';
import 'widgets/swap_primary_button.dart';
import 'widgets/swap_gasless_toggle.dart';

/// Swap Screen — DEX token swap interface
class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final SwapService _swapService = SwapService();
  final WalletService _walletService = WalletService();
  final ReferralService _referralService = ReferralService();
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
      _quoteRequestId++;
      _pricing = '';
      _currentQuote = null;
      _feeUsd = 0.0;
      _feeNative = 0.0;
      _toController.clear();
      _fromController.clear();
      _selectedPercentage = -1;
      if (_isGasless && !_isGaslessSupported) {
        _isGasless = false;
      }
      _loadWalletBalance();
    } else if (_fromToken == null || _toToken == null) {
      final tokens = blockchain.tokens;
      _syncSelectedTokens(tokens);
    }
  }

  bool _isCalculating = false;
  String _pricing = '';

  /// Trading slippage tolerance for 0x swap execution (not the platform fee).
  final double _slippage = 0.5;
  double _feeUsd = 0.0;
  double _feeNative = 0.0;
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
    // 0x Tx Relay (Gasless) strictly supports Ethereum(1), Optimism(10), Polygon(137), Base(8453), Arbitrum(42161)
    return [1, 10, 137, 8453, 42161].contains(chainId);
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
  }

  Future<void> _loadWalletBalance() async {
    final address = await _walletService.getCurrentWalletAddress();
    if (!mounted) return;
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    // Always sync with whatever token set we currently have so selectors never look empty.
    _syncSelectedTokens(blockchain.tokens);
    if (mounted) {
      setState(() => _walletAddress = address);
    }

    if (address != null && address.isNotEmpty) {
      if (!mounted) return;
      try {
        await blockchain.fetchWalletTokens(address);
        if (mounted) {
          setState(() {
            _syncSelectedTokens(blockchain.tokens);
          });
        }
      } catch (e) {
        debugPrint('Error fetching balance for swap: $e');
        if (mounted) {
          setState(() {
            _syncSelectedTokens(blockchain.tokens);
          });
        }
      }
    } else if (mounted) {
      setState(() {
        _syncSelectedTokens(blockchain.tokens);
      });
    }

    // Fetch live prices for all tokens with coinGeckoId to fill price gaps.
    await _refreshTokenPrices();
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

  Future<void> _showTokenSelector(bool isFrom) async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final tokens = blockchain.tokens;
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
        _pricing = '';
        _toController.clear();
        _feeUsd = 0.0;
        _feeNative = 0.0;
      });
      // Refresh prices so USD values are immediately available for new token
      _refreshTokenPrices();
      _getQuote();
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
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
    return 'Swap failed: $raw';
  }

  Future<void> _refreshWalletState() async {
    final address = _walletAddress;
    if (address == null) return;
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    await blockchain.fetchWalletTokens(address);
    if (!mounted) return;
    setState(() {
      _syncSelectedTokens(blockchain.tokens);
    });
  }

  Future<bool> _waitForTxConfirmation(
    String txHash, {
    required String successMessage,
    bool rewardReferralOnSwap = false,
  }) async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final confirmed = await _transactionMonitor.waitForConfirmation(
      txHash: txHash,
      blockchain: blockchain,
    );
    if (!mounted) return false;
    if (confirmed) {
      _showSnack(successMessage);
      if (rewardReferralOnSwap && _walletAddress != null) {
        try {
          await _referralService.rewardOnSwap(
            walletAddress: _walletAddress!,
            txHash: txHash,
          );
        } catch (e) {
          // Referral crediting should not block successful swap UX.
          debugPrint('Referral reward-on-swap failed: $e');
        }
      }
      await _refreshWalletState();
      return true;
    } else {
      _showError('Transaction pending confirmation. Please check later.');
      return false;
    }
  }

  Future<void> _getQuote() async {
    if (_fromToken == null || _toToken == null) return;
    if (_tokensAreIdentical(_fromToken, _toToken)) {
      setState(() {
        _pricing = '';
        _toController.clear();
        _currentQuote = null;
        _feeUsd = 0.0;
        _feeNative = 0.0;
      });
      return;
    }
    final amountText = _fromController.text;
    final amount = _parseDecimalAmount(amountText);
    if (amount <= Decimal.zero) {
      setState(() {
        _pricing = '';
        _toController.clear();
        _currentQuote = null;
        _feeUsd = 0.0;
        _feeNative = 0.0;
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
        _pricing = _isGasless
            ? 'Gasless not supported on ${blockchain.activeChain.name}'
            : 'Swap not supported on ${blockchain.activeChain.name}';
        _toController.clear();
        _currentQuote = null;
        _isCalculating = false;
      });
      return;
    }
    if (_isGaslessSourceUnsupported()) {
      setState(() {
        _pricing = 'Gasless requires ERC-20 source token';
        _toController.clear();
        _currentQuote = null;
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
            _pricing = 'Invalid amount';
            _toController.clear();
            _currentQuote = null;
            _feeUsd = 0.0;
            _feeNative = 0.0;
          });
        }
        return;
      }

      final quote = await _swapService.get0xQuote(
        chainId: blockchain.activeChain.chainId,
        fromTokenAddress: _fromToken!.contractAddress ?? '',
        toTokenAddress: _toToken!.contractAddress ?? '',
        amountWei: amountWei,
        buyTokenDecimals: _toToken!.decimals,
        isGasless: _isGasless,
        walletAddress: _walletAddress,
      );

      if (!mounted || requestId != _quoteRequestId) return;

      if (quote != null) {
        final outAmount =
            Decimal.tryParse(quote.amountOutFormatted) ?? Decimal.zero;
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
          _pricing = _formatRateText(
            outAmount > Decimal.zero
                ? (double.tryParse(outAmount.toString()) ?? 0.0)
                : 0.0,
          );
          _toController.text = quote.amountOutFormatted;
          _currentQuote = quote;
          _feeNative = feeNative;
          _feeUsd = feeUsd;
        });
      } else {
        final mapped = _mapErrorMessage(_swapService.lastError);
        setState(() {
          _pricing = mapped;
          _toController.clear();
          _currentQuote = null;
          _feeUsd = 0.0;
          _feeNative = 0.0;
        });
      }
    } catch (e) {
      if (mounted && requestId == _quoteRequestId) {
        setState(() {
          _pricing = _mapErrorMessage(e.toString());
          _toController.clear();
          _currentQuote = null;
          _feeUsd = 0.0;
          _feeNative = 0.0;
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
      _fromController.clear();
      _toController.clear();
      _pricing = '';
      _currentQuote = null;
      _feeUsd = 0.0;
      _feeNative = 0.0;
      _selectedPercentage = -1;
      if (_isGasless && _isGaslessSourceUnsupported()) {
        _isGasless = false;
      }
    });
  }

  void _executeSwap() async {
    if (_walletAddress == null) {
      _showError('Wallet not connected');
      return;
    }
    final fromAmount = _parseDecimalAmount(_fromController.text);
    if (fromAmount <= Decimal.zero) {
      _showError('Invalid amount');
      return;
    }
    final fromToken = _fromToken;
    final toToken = _toToken;
    if (fromToken == null || toToken == null) {
      _showError('Select tokens');
      return;
    }
    if (_tokensAreIdentical(fromToken, toToken)) {
      _showError('Choose different tokens');
      return;
    }
    if (_currentQuote == null) {
      _showError('No quote available');
      return;
    }
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    if (!_swapService.isChainSupported(
      blockchain.activeChain.chainId,
      isGasless: _isGasless,
    )) {
      _showError(
        _isGasless
            ? 'Gasless swaps are not available on this network yet.'
            : 'Swaps are not available on this network yet.',
      );
      return;
    }
    if (_isGaslessSourceUnsupported()) {
      _showError('Gasless mode requires an ERC-20 source token.');
      return;
    }
    final fromAmountWei = _toWeiAmount(
      _fromController.text,
      fromToken.decimals,
    );
    if (fromAmountWei == null || fromAmountWei == '0') {
      _showError('Invalid amount');
      return;
    }

    if (_tokenRequiresApproval(fromToken)) {
      final approvalOk = await _handleTokenApproval(fromToken, fromAmountWei);
      if (!approvalOk) return;
    }

    await _performSwap(
      fromToken: fromToken,
      toToken: toToken,
      fromAmountWei: fromAmountWei,
    );
  }

  void _showError(String message) {
    ToastUtils.showError(message);
  }

  void _showSnack(String message, {Color background = AppColors.success}) {
    if (background == AppColors.error) {
      ToastUtils.showError(message);
    } else if (background == AppColors.success) {
      ToastUtils.showSuccess(message);
    } else {
      ToastUtils.showInfo(message);
    }
  }

  Future<bool> _handleTokenApproval(
    Token fromToken,
    String fromAmountWei,
  ) async {
    if (_walletAddress == null) {
      _showError('Wallet not connected');
      return false;
    }
    final quote = _currentQuote;
    if (quote == null) {
      _showError('No router quote available');
      return false;
    }
    if (_isApproving) return false;

    setState(() => _isApproving = true);
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final result = await _tokenApprovalService.ensureApproval(
        token: fromToken,
        amountWei: fromAmountWei,
        ownerAddress: _walletAddress!,
        blockchain: blockchain,
        allowanceTarget: quote.allowanceTarget,
      );

      if (!mounted) return false;

      if (result.hasError) {
        _showError(_mapErrorMessage(result.error));
        return false;
      }

      if (result.approvalSubmitted && result.transactionHash != null) {
        _showSnack(
          'Approval tx submitted: ${_shortHash(result.transactionHash!)}',
        );
        final confirmed = await _waitForTxConfirmation(
          result.transactionHash!,
          successMessage: 'Approval confirmed',
        );
        if (!confirmed) return false;
      } else {
        _showSnack('Allowance already sufficient');
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
  }) async {
    if (_walletAddress == null) {
      _showError('Wallet not connected');
      return;
    }
    final quote = _currentQuote;
    if (quote == null) {
      _showError('No quote available');
      return;
    }
    if (_isSwapping) return;

    var expectedToAmount = _parseAmount(_toController);
    if (expectedToAmount <= 0) {
      expectedToAmount = double.tryParse(quote.amountOutFormatted) ?? 0.0;
    }

    setState(() => _isSwapping = true);
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final result = await _swapExecutionService.execute(
        quote: quote,
        fromToken: fromToken,
        toToken: toToken,
        fromAmountWei: fromAmountWei,
        expectedToAmount: expectedToAmount,
        slippagePercent: _slippage,
        blockchain: blockchain,
        recipientAddress: _walletAddress!,
        isGasless: _isGasless, // Pass the beta toggle selection
      );

      if (!result.success) {
        _showError(_mapErrorMessage(result.error));
        return;
      }

      if (result.transactionHash == null) {
        if (_isGasless) {
          _showSnack('Gasless order submitted successfully');
          _fromController.clear();
          _toController.clear();
          setState(() {
            _currentQuote = null;
            _pricing = '';
            _feeUsd = 0.0;
            _feeNative = 0.0;
            _selectedPercentage = -1;
          });
          await _refreshWalletState();
          return;
        }
        _showError(
          'Swap submitted but transaction hash was not returned. Please check activity later.',
        );
        return;
      }

      if (_isGasless && !_looksLikeTxHash(result.transactionHash!)) {
        _showSnack(
          'Gasless order accepted: ${_shortHash(result.transactionHash!)}',
        );
        _fromController.clear();
        _toController.clear();
        setState(() {
          _currentQuote = null;
          _pricing = '';
          _feeUsd = 0.0;
          _feeNative = 0.0;
          _selectedPercentage = -1;
        });
        await _refreshWalletState();
        return;
      }

      _showSnack('Swap submitted: ${_shortHash(result.transactionHash!)}');
      _fromController.clear();
      _toController.clear();
      setState(() {
        _currentQuote = null;
        _pricing = '';
        _feeUsd = 0.0;
        _feeNative = 0.0;
        _selectedPercentage = -1;
      });
      _waitForTxConfirmation(
        result.transactionHash!,
        successMessage: 'Swap confirmed',
        rewardReferralOnSwap: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSwapping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final blockchain = Provider.of<BlockchainService>(context);
    final fromAmount = _parseAmount(_fromController);
    final toAmount = _parseAmount(_toController);
    final fromUsdValue = _usdValueFor(_fromToken, fromAmount);
    final toUsdValue = _usdValueFor(_toToken, toAmount);
    final priceText = _pricing.isNotEmpty ? _pricing : '--';
    final receiveText = _toController.text.isNotEmpty
        ? '${_toController.text} ${_toToken?.symbol ?? ''} (\$${toUsdValue.toStringAsFixed(2)})'
        : '--';
    final swapBusy = _isApproving || _isSwapping;
    final hasInputAmount = fromAmount > 0;
    final hasQuote = _currentQuote != null && _toController.text.isNotEmpty;
    final chainSupported = _swapService.isChainSupported(
      blockchain.activeChain.chainId,
      isGasless: _isGasless,
    );
    final swapEnabled =
        hasInputAmount &&
        hasQuote &&
        chainSupported &&
        !_tokensAreIdentical(_fromToken, _toToken) &&
        !_isGaslessSourceUnsupported() &&
        !swapBusy;
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: BottomNavBar(
        currentIndex: 1,
        onTap: (index) => BottomNavBar.handleNavigation(context, index, 1),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Swap',
                style: TextStyle(
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
                      slippage: _currentQuote?.platformFeePercent ?? 1.0,
                      feeAmountUsd: _feeUsd,
                      feeAmountNative: _feeNative,
                      nativeFeeSymbol: blockchain.activeChain.symbol,
                      receiveText: receiveText,
                      priceSeparator: _priceSeparator,
                      swapAmountUsd: fromUsdValue,
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
                    ),
                    if (_isGaslessSupported) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SwapGaslessToggle(
                          value: _isGasless,
                          onChanged: (val) {
                            if (_isGaslessSourceUnsupported(
                              gaslessEnabled: val,
                            )) {
                              _showError(
                                'Gasless mode requires an ERC-20 source token.',
                              );
                              return;
                            }
                            setState(() {
                              _isGasless = val;
                              _getQuote();
                            });
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
