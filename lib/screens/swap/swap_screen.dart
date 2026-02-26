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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fromToken == null) {
      final tokens = Provider.of<BlockchainService>(context).tokens;
      if (tokens.isNotEmpty) {
        _fromToken = tokens.first;
        _toToken = tokens.length > 1 ? tokens[1] : tokens.first;
      }
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
        final ethBalance = await blockchain.getEthBalance(address);
        if (mounted && _fromToken?.symbol == blockchain.activeChain.symbol) {
          setState(() {
            _fromToken = Token(
              symbol: _fromToken!.symbol, name: _fromToken!.name,
              balance: ethBalance, valueUsd: _fromToken!.valueUsd, priceUsd: _fromToken!.priceUsd, changePercent24h: 0,
              contractAddress: _fromToken!.contractAddress, decimals: _fromToken!.decimals,
              coinGeckoId: _fromToken!.coinGeckoId,
            );
          });
        }
      } catch (e) {
        debugPrint('Error fetching balance for swap: $e');
      }
    }
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

  String _shortHash(String hash) {
    if (hash.length <= 10) return hash;
    return '${hash.substring(0, 6)}...${hash.substring(hash.length - 4)}';
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
    if (lower.contains('user denied') || lower.contains('user rejected') || lower.contains('user canceled')) {
      return 'Transaction was cancelled.';
    }
    if (lower.contains('nonce too low')) {
      return 'Transaction nonce is too low. Please wait for pending transactions to finish.';
    }
    return raw;
  }

  Future<void> _refreshWalletState() async {
    final address = _walletAddress;
    if (address == null) return;
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    await blockchain.fetchWalletTokens(address);
    if (!mounted) return;
    final tokens = blockchain.tokens;

    Token? findMatch(Token? current) {
      if (current == null) return null;
      final addr = (current.contractAddress ?? '').toLowerCase();
      if (addr.isNotEmpty) {
        try {
          return tokens.firstWhere(
            (t) => (t.contractAddress ?? '').toLowerCase() == addr,
          );
        } catch (_) {}
      }
      try {
        return tokens.firstWhere((t) => t.symbol == current.symbol);
      } catch (_) {
        return current;
      }
    }

    setState(() {
      _fromToken = findMatch(_fromToken) ?? _fromToken;
      _toToken = findMatch(_toToken) ?? _toToken;
    });
  }

  Future<void> _waitForTxConfirmation(
    String txHash, {
    required String successMessage,
  }) async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final confirmed = await _transactionMonitor.waitForConfirmation(
      txHash: txHash,
      blockchain: blockchain,
    );
    if (!mounted) return;
    if (confirmed) {
      _showSnack(successMessage);
      await _refreshWalletState();
    } else {
      _showError('Transaction pending confirmation. Please check later.');
    }
  }

  Future<void> _getQuote() async {
    if (_fromToken == null || _toToken == null) return;
    if (_tokensAreIdentical(_fromToken, _toToken)) return;
    final amountText = _fromController.text;
    final amount = double.tryParse(amountText.replaceAll(',', '')) ?? 0.0;
    if (amount <= 0) {
      setState(() => _pricing = '');
      return;
    }

    setState(() => _isCalculating = true);
    final blockchain = Provider.of<BlockchainService>(context, listen: false);

    try {
      final amountWei = (amount * (BigInt.from(10).pow(_fromToken!.decimals).toDouble())).toStringAsFixed(0);
      final quote = await _swapService.get0xQuote(
        chainId: blockchain.activeChain.chainId,
        fromTokenAddress: _fromToken!.contractAddress ?? '',
        toTokenAddress: _toToken!.contractAddress ?? '',
        amountWei: amountWei,
        isGasless: _isGasless,
      );

      if (!mounted) return;

      if (quote != null) {
        setState(() {
          _pricing = quote.amountOutFormatted;
          _toController.text = quote.amountOutFormatted;
          _currentQuote = quote;
          _fees = quote.estimatedGasUsd;
        });
      } else {
        setState(() {
          _pricing = 'Route not found';
          _toController.clear();
          _currentQuote = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _pricing = 'Error calculating quote');
    } finally {
      if (mounted) setState(() => _isCalculating = false);
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
    });
  }

  void _executeSwap() async {
    if (_walletAddress == null) { _showError('Wallet not connected'); return; }
    final fromAmount = double.tryParse(_fromController.text.replaceAll(',', ''));
    if (fromAmount == null || fromAmount <= 0) { _showError('Invalid amount'); return; }
    final fromToken = _fromToken;
    final toToken = _toToken;
    if (fromToken == null || toToken == null) { _showError('Select tokens'); return; }
    if (_currentQuote == null) { _showError('No quote available'); return; }

    if (_tokenRequiresApproval(fromToken)) {
      final approvalOk = await _handleTokenApproval(fromToken, fromAmount);
      if (!approvalOk) return;
    }
    
    await _performSwap(
      fromToken: fromToken,
      toToken: toToken,
      fromAmount: fromAmount,
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

  Future<bool> _handleTokenApproval(Token fromToken, double fromAmount) async {
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
        amount: fromAmount,
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
        _waitForTxConfirmation(result.transactionHash!, successMessage: 'Approval confirmed');
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
    required double fromAmount,
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
        fromAmount: fromAmount,
        expectedToAmount: expectedToAmount,
        slippagePercent: _slippage,
        blockchain: blockchain,
        recipientAddress: _walletAddress!,
        isGasless: _isGasless, // Pass the beta toggle selection
      );

      if (!result.success || result.transactionHash == null) {
        _showError(_mapErrorMessage(result.error));
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
    final fromAmount = _parseAmount(_fromController);
    final toAmount = _parseAmount(_toController);
    final fromUsdValue = _usdValueFor(_fromToken, fromAmount);
    final toUsdValue = _usdValueFor(_toToken, toAmount);
    final priceText = _pricing.isNotEmpty ? _pricing : '--';
    final receiveText = _toController.text.isNotEmpty ? '\$${toUsdValue.toStringAsFixed(2)}' : '\$0.00';
    final swapBusy = _isApproving || _isSwapping;
    final swapEnabled = _fromController.text.isNotEmpty && _fromController.text != '0' && !swapBusy;
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
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SwapGaslessToggle(
                        value: _isGasless,
                        onChanged: (val) {
                          setState(() {
                            _isGasless = val;
                            _getQuote();
                          });
                        },
                      ),
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

}
