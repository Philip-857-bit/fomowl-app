import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../widgets/bottom_navigation.dart';
import '../../models/token.dart';
import '../../services/swap_service.dart';
import '../../services/wallet_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/token_approval_service.dart';
import '../../services/swap_execution_service.dart';
import '../../services/transaction_monitor.dart';
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
  final double _slippage = 0.5;
  double _fees = 0.0;
  String? _walletAddress;
  SwapQuote? _currentQuote;
  int _selectedPercentage = -1; // -1 = none selected
  bool _isApproving = false;
  bool _isSwapping = false;
  bool _isGasless = false;

  bool get _isGaslessSupported {
    final chainId = Provider.of<BlockchainService>(context, listen: false).activeChain.chainId;
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
    if (mounted) {
      setState(() => _walletAddress = address);
    }

    if (address != null && address.isNotEmpty) {
      if (!mounted) return;
      try {
        final blockchain = Provider.of<BlockchainService>(context, listen: false);
        await blockchain.fetchWalletTokens(address);
        if (mounted) {
          setState(() {
            _syncSelectedTokens(blockchain.tokens);
          });
        }
      } catch (e) {
        debugPrint('Error fetching balance for swap: $e');
      }
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
    Token to = findMatch(_toToken) ?? (tokens.length > 1 ? tokens[1] : tokens.first);
    if (_tokensAreIdentical(from, to)) {
      final alternative = tokens.where((t) => !_tokensAreIdentical(t, from)).toList();
      if (alternative.isNotEmpty) {
        to = alternative.first;
      }
    }

    _fromToken = from;
    _toToken = to;
  }

  Future<void> _showTokenSelector(bool isFrom) async {
    final tokens = Provider.of<BlockchainService>(context, listen: false).tokens;
    final selectedToken = await showDialog<Token>(
      context: context,
      builder: (ctx) => TokenSelectorDialog(tokens: tokens),
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
      });
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
    final balance = _fromToken!.balance;
    final amount = balance * (percent / 100.0);
    setState(() {
      _selectedPercentage = percent;
      _fromController.text = amount > 0 ? amount.toStringAsFixed(_fromToken!.decimals > 6 ? 6 : _fromToken!.decimals) : '0';
    });
    if (amount > 0) _getQuote();
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

  String? _toWeiAmount(String amountText, int decimals) {
    final cleaned = amountText.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    final parts = cleaned.split('.');
    if (parts.length > 2) return null;

    final whole = parts.first.isEmpty ? '0' : parts.first;
    final fractionalRaw = parts.length == 2 ? parts[1] : '';
    final digitRegex = RegExp(r'^\d+$');
    if (!digitRegex.hasMatch(whole)) return null;
    if (fractionalRaw.isNotEmpty && !digitRegex.hasMatch(fractionalRaw)) return null;

    final fractional = fractionalRaw.length > decimals
        ? fractionalRaw.substring(0, decimals)
        : fractionalRaw.padRight(decimals, '0');
    final combined = '$whole$fractional';
    final normalized = combined.replaceFirst(RegExp(r'^0+'), '');
    return normalized.isEmpty ? '0' : normalized;
  }

  double _usdValueFor(Token? token, double amount) {
    if (token == null) return 0.0;
    return amount * token.unitPriceUsd;
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
    if (lower.contains('invalid chain id')) {
      return 'Swap is not available on this network yet.';
    }
    if (lower.contains('selling native token is not supported for gasless trades')) {
      return 'Gasless mode only supports ERC-20 source tokens. Select a token like USDC/USDT.';
    }
    if (lower.contains('no route found') || lower.contains('no liquidity')) {
      return 'No route found for this pair on this network right now.';
    }
    if (lower.contains('user denied') || lower.contains('user rejected') || lower.contains('user canceled')) {
      return 'Transaction was cancelled.';
    }
    if (lower.contains('nonce too low')) {
      return 'Transaction nonce is too low. Please wait for pending transactions to finish.';
    }
    return 'Swap failed. Please verify your token selection and balance.';
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
  }) async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final confirmed = await _transactionMonitor.waitForConfirmation(
      txHash: txHash,
      blockchain: blockchain,
    );
    if (!mounted) return false;
    if (confirmed) {
      _showSnack(successMessage);
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
      });
      return;
    }
    final amountText = _fromController.text;
    final amount = double.tryParse(amountText.replaceAll(',', '')) ?? 0.0;
    if (amount <= 0) {
      setState(() {
        _pricing = '';
        _toController.clear();
        _currentQuote = null;
      });
      return;
    }

    final requestId = ++_quoteRequestId;
    setState(() => _isCalculating = true);
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    if (!_swapService.isChainSupported(blockchain.activeChain.chainId, isGasless: _isGasless)) {
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
      final amountWei = _toWeiAmount(_fromController.text, _fromToken!.decimals);
      if (amountWei == null || amountWei == '0') {
        if (mounted && requestId == _quoteRequestId) {
          setState(() {
            _pricing = 'Invalid amount';
            _toController.clear();
            _currentQuote = null;
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
        setState(() {
          _pricing = quote.amountOutFormatted;
          _toController.text = quote.amountOutFormatted;
          _currentQuote = quote;
          _fees = quote.estimatedGasUsd;
        });
      } else {
        final mapped = _mapErrorMessage(_swapService.lastError);
        setState(() {
          _pricing = mapped;
          _toController.clear();
          _currentQuote = null;
        });
      }
    } catch (e) {
      if (mounted && requestId == _quoteRequestId) {
        setState(() {
          _pricing = _mapErrorMessage(e.toString());
          _toController.clear();
          _currentQuote = null;
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
      _selectedPercentage = -1;
      if (_isGasless && _isGaslessSourceUnsupported()) {
        _isGasless = false;
      }
    });
  }

  void _executeSwap() async {
    if (_walletAddress == null) { _showError('Wallet not connected'); return; }
    final fromAmount = double.tryParse(_fromController.text.replaceAll(',', ''));
    if (fromAmount == null || fromAmount <= 0) { _showError('Invalid amount'); return; }
    final fromToken = _fromToken;
    final toToken = _toToken;
    if (fromToken == null || toToken == null) { _showError('Select tokens'); return; }
    if (_tokensAreIdentical(fromToken, toToken)) { _showError('Choose different tokens'); return; }
    if (_currentQuote == null) { _showError('No quote available'); return; }
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    if (!_swapService.isChainSupported(blockchain.activeChain.chainId, isGasless: _isGasless)) {
      _showError(_isGasless
          ? 'Gasless swaps are not available on this network yet.'
          : 'Swaps are not available on this network yet.');
      return;
    }
    if (_isGaslessSourceUnsupported()) {
      _showError('Gasless mode requires an ERC-20 source token.');
      return;
    }
    final fromAmountWei = _toWeiAmount(_fromController.text, fromToken.decimals);
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

  Future<bool> _handleTokenApproval(Token fromToken, String fromAmountWei) async {
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
        _showSnack('Approval tx submitted: ${_shortHash(result.transactionHash!)}');
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
            _selectedPercentage = -1;
          });
          await _refreshWalletState();
          return;
        }
        _showError('Swap submitted but transaction hash was not returned. Please check activity later.');
        return;
      }

      if (_isGasless && !_looksLikeTxHash(result.transactionHash!)) {
        _showSnack('Gasless order accepted: ${_shortHash(result.transactionHash!)}');
        _fromController.clear();
        _toController.clear();
        setState(() {
          _currentQuote = null;
          _pricing = '';
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
        _selectedPercentage = -1;
      });
      _waitForTxConfirmation(result.transactionHash!, successMessage: 'Swap confirmed');
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
    final receiveText = _toController.text.isNotEmpty ? '\$${toUsdValue.toStringAsFixed(2)}' : '\$0.00';
    final swapBusy = _isApproving || _isSwapping;
    final hasInputAmount = fromAmount > 0;
    final hasQuote = _currentQuote != null && _toController.text.isNotEmpty;
    final chainSupported = _swapService.isChainSupported(
      blockchain.activeChain.chainId,
      isGasless: _isGasless,
    );
    final swapEnabled = hasInputAmount &&
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
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
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
                    ),
                    const SizedBox(height: 24),
                    SwapPriceDetailsCard(
                      priceText: priceText,
                      slippage: _slippage,
                      feeAmount: _fees,
                      feeSymbol: _fromToken?.symbol ?? '',
                      receiveText: receiveText,
                      priceSeparator: _priceSeparator,
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
                            if (_isGaslessSourceUnsupported(gaslessEnabled: val)) {
                              _showError('Gasless mode requires an ERC-20 source token.');
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
