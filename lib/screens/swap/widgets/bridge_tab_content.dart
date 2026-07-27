import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

import '../../../models/chain.dart';
import '../../../models/token.dart';
import '../../../services/blockchain_service.dart';
import '../../../services/bridge_service.dart';
import '../../../services/http_client_service.dart';
import '../../../services/rpc_service.dart';
import '../../../services/transaction_monitor.dart';
import '../../../services/wallet_service.dart';
import '../../../utils/amount_utils.dart';
import '../../../utils/app_error_utils.dart';
import '../../../utils/toast_utils.dart';
import '../../../utils/value_formatter.dart';
import '../../transaction/transaction_processing_screen.dart';
import '../swap_screen_helpers.dart';
import 'swap_figma_icons.dart';
import 'swap_primary_button.dart';
import 'swap_token_chip.dart';
import 'swap_token_selector_dialog.dart';

/// Bridge tab — Relay-powered cross-chain transfers.
///
/// Self-contained: owns its amount/quote/execution state so the swap screen
/// only needs to render it and provide the origin-chain context. The origin
/// chain is always the wallet's active chain; picking a different "from"
/// network switches the active chain through [BlockchainService].
class BridgeTabContent extends StatefulWidget {
  final BlockchainService blockchain;
  final WalletService walletService;
  final String? walletAddress;

  /// Visible tokens on the active (origin) chain, with balances.
  final List<Token> tokens;

  /// Opens the app's network selector (switches the active chain).
  final VoidCallback onSelectFromChain;

  const BridgeTabContent({
    super.key,
    required this.blockchain,
    required this.walletService,
    required this.walletAddress,
    required this.tokens,
    required this.onSelectFromChain,
  });

  @override
  State<BridgeTabContent> createState() => _BridgeTabContentState();
}

class _BridgeTabContentState extends State<BridgeTabContent> {
  final TextEditingController _amountController = TextEditingController();
  final BridgeService _bridgeService = BridgeService();
  final HttpClientService _httpClientService = HttpClientService();
  final RpcService _rpcService = RpcService();
  final TransactionMonitor _transactionMonitor = TransactionMonitor();

  Token? _fromToken;
  EvmChain? _toChain;

  /// Selected destination token; null means the destination chain's native
  /// coin. Relay supports settling into any supported token, not just native.
  BridgeCurrency? _toCurrency;
  int _selectedPercentage = -1;
  BridgeQuote? _quote;
  bool _isQuoting = false;
  bool _isBridging = false;
  String? _quoteError;
  Timer? _debounce;
  int _quoteSeq = 0;
  String? _solanaAddress;
  String? _evmAddress;
  String? _lastNetworkKey;

  /// Relay-supported chain ids; null until loaded (or when unavailable, in
  /// which case filtering is skipped).
  Set<int>? _relayChainIds;

  /// Solana entry for the chain pickers. Solana works as both origin
  /// (instructions compiled + signed via the native Rust builder) and
  /// destination.
  static const EvmChain _solanaChain = EvmChain(
    name: 'Solana',
    symbol: 'SOL',
    chainId: BridgeService.relaySolanaChainId,
    rpcUrl: '',
    family: ChainFamily.solana,
  );

  bool get _isSolanaOrigin =>
      widget.blockchain.activeFamily == ChainFamily.solana;

  @override
  void initState() {
    super.initState();
    _lastNetworkKey = widget.blockchain.activeNetworkKey;
    _syncFromToken();
    _syncToChain();
    unawaited(_loadFamilyAddresses());
    unawaited(_loadRelayChains());
  }

  Future<void> _loadFamilyAddresses() async {
    final solana = await widget.walletService.getWalletAddressForFamily(
      ChainFamily.solana,
    );
    final evm = await widget.walletService.getWalletAddressForFamily(
      ChainFamily.evm,
    );
    if (!mounted) return;
    setState(() {
      if (solana != null && solana.isNotEmpty) _solanaAddress = solana;
      if (evm != null && evm.isNotEmpty) _evmAddress = evm;
    });
  }

  Future<void> _loadRelayChains() async {
    final ids = await _bridgeService.getSupportedChainIds();
    if (mounted && ids != null) {
      setState(() {
        _relayChainIds = ids;
        _syncToChain();
      });
    }
  }

  @override
  void didUpdateWidget(covariant BridgeTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The BlockchainService instance is shared, so compare against our own
    // snapshot of the network key rather than oldWidget's live reference.
    final networkKey = widget.blockchain.activeNetworkKey;
    final networkChanged = networkKey != _lastNetworkKey;
    _lastNetworkKey = networkKey;
    if (networkChanged || !_tokenStillVisible()) {
      _syncFromToken(reset: networkChanged);
      _syncToChain();
      if (networkChanged) {
        _resetQuote();
        _requestQuote();
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  bool _tokenStillVisible() {
    final current = _fromToken;
    if (current == null) return false;
    return widget.tokens.any(
      (t) =>
          (t.contractAddress ?? '').toLowerCase() ==
          (current.contractAddress ?? '').toLowerCase(),
    );
  }

  void _syncFromToken({bool reset = false}) {
    if (!reset && _tokenStillVisible()) {
      // Refresh balance/price from the latest token list.
      final address = (_fromToken?.contractAddress ?? '').toLowerCase();
      _fromToken = widget.tokens.firstWhere(
        (t) => (t.contractAddress ?? '').toLowerCase() == address,
        orElse: () => _fromToken!,
      );
      return;
    }
    // Default to the native token of the origin chain.
    _fromToken = widget.tokens.isEmpty
        ? null
        : widget.tokens.firstWhere(
            (t) => t.contractAddress == null || t.contractAddress!.isEmpty,
            orElse: () => widget.tokens.first,
          );
  }

  void _syncToChain() {
    final candidates = _destinationChains();
    if (_toChain == null ||
        !candidates.any((c) => c.chainId == _toChain!.chainId)) {
      _toChain = candidates.isEmpty ? null : candidates.first;
    }
  }

  /// EVM destinations are limited to chains Relay actually supports, so
  /// user-added custom networks don't produce dead-end quotes. When the
  /// Relay chain list is unavailable, no filtering is applied.
  List<EvmChain> _destinationChains() {
    final relayIds = _relayChainIds;
    final evmChains = widget.blockchain.allChains.where((chain) {
      if (chain.family != ChainFamily.evm) return false;
      if (!_isSolanaOrigin &&
          chain.chainId == widget.blockchain.activeChain.chainId) {
        return false;
      }
      return relayIds == null || relayIds.contains(chain.chainId);
    });
    return [
      ...evmChains,
      // Solana destination requires the wallet to have a Solana address.
      if (!_isSolanaOrigin && _solanaAddress != null) _solanaChain,
    ];
  }

  // ── Quote handling ──────────────────────────────────────────────────────

  void _resetQuote() {
    _quote = null;
    _quoteError = null;
  }

  void _onAmountChanged(String _) {
    _selectedPercentage = -1;
    _requestQuote();
  }

  void _requestQuote() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _fetchQuote);
    setState(() {});
  }

  double get _amountValue =>
      double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

  Future<void> _fetchQuote() async {
    final from = _fromToken;
    final toChain = _toChain;
    final wallet = widget.walletAddress;
    if (from == null || toChain == null || wallet == null || wallet.isEmpty) {
      return;
    }
    if (_amountValue <= 0) {
      if (mounted) setState(_resetQuote);
      return;
    }

    // parseDecimalToBaseUnits throws on more-decimals-than-token or scientific
    // notation; _amountValue (double.tryParse) accepts both, so guard here.
    final String amountWei;
    try {
      amountWei = AmountUtils.parseDecimalToBaseUnits(
        _amountController.text.replaceAll(',', ''),
        from.decimals,
      ).toString();
    } catch (_) {
      if (mounted) {
        setState(() {
          _resetQuote();
          _quoteError =
              'Enter an amount with at most ${from.decimals} decimal places.';
        });
      }
      return;
    }
    if (amountWei == '0') return;

    final isSolanaOrigin = _isSolanaOrigin;
    final originChainId = isSolanaOrigin
        ? BridgeService.relaySolanaChainId
        : widget.blockchain.activeChain.chainId;

    // User-added custom networks aren't necessarily on Relay — fail with a
    // clear message before the upstream request can produce a cryptic error.
    final relayIds = _relayChainIds;
    if (!isSolanaOrigin &&
        relayIds != null &&
        !relayIds.contains(originChainId)) {
      setState(() {
        _resetQuote();
        _quoteError =
            'Bridging isn\'t available on ${widget.blockchain.activeChain.name} yet. Switch to a supported network to bridge.';
      });
      return;
    }

    final isSolanaDestination = toChain.family == ChainFamily.solana;
    final recipient = isSolanaDestination
        ? _solanaAddress
        : (isSolanaOrigin ? _evmAddress : wallet);
    if (recipient == null || recipient.isEmpty) {
      setState(() {
        _resetQuote();
        _quoteError = isSolanaDestination
            ? 'This wallet has no Solana address to receive the bridged funds.'
            : 'This wallet has no EVM address to receive the bridged funds.';
      });
      return;
    }

    final originCurrency = isSolanaOrigin
        ? (from.contractAddress?.isNotEmpty == true
              ? from.contractAddress!
              : BridgeService.solanaNativeCurrency)
        : (from.contractAddress ?? '');

    final seq = ++_quoteSeq;
    setState(() {
      _isQuoting = true;
      _quoteError = null;
    });

    // Destination token: a user-selected currency when present, otherwise the
    // chain's native coin. Relay accepts any output token, not only native.
    final destinationCurrency =
        _toCurrency?.address ??
        (isSolanaDestination
            ? BridgeService.solanaNativeCurrency
            : BridgeService.nativeCurrency);

    final quote = await _bridgeService.getQuote(
      originChainId: originChainId,
      destinationChainId: toChain.chainId,
      originCurrency: originCurrency,
      destinationCurrency: destinationCurrency,
      amountWei: amountWei,
      walletAddress: wallet,
      recipientAddress: recipient,
      amountUsd: from.priceUsd > 0 ? _amountValue * from.priceUsd : null,
    );

    if (!mounted || seq != _quoteSeq) return;
    setState(() {
      _isQuoting = false;
      _quote = quote;
      _quoteError = quote == null ? _bridgeService.lastError : null;
    });
  }

  // ── Interactions ────────────────────────────────────────────────────────

  void _setPercentage(int percent) {
    final token = _fromToken;
    if (token == null || token.balance <= 0) return;
    var amount = token.balance * percent / 100;
    final isNative =
        token.contractAddress == null || token.contractAddress!.isEmpty;
    if (percent == 100 && isNative) {
      // Leave headroom for origin-chain gas when bridging the gas token.
      amount = token.balance * 0.98;
    }
    setState(() {
      _selectedPercentage = percent;
      _amountController.text = amount.toStringAsFixed(6);
    });
    _requestQuote();
  }

  Future<void> _selectFromToken() async {
    final selected = await showDialog<Token>(
      context: context,
      builder: (ctx) => SwapTokenSelectorDialog(
        tokens: widget.tokens,
        chainId: widget.blockchain.activeTokenStorageChainId,
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _fromToken = selected;
        _selectedPercentage = -1;
        _resetQuote();
      });
      _requestQuote();
    }
  }

  Future<void> _selectToChain() async {
    final chains = _destinationChains();
    final selected = await showModalBottomSheet<EvmChain>(
      context: context,
      backgroundColor: const Color(0xFF0E0E0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ChainPickerSheet(chains: chains),
    );
    if (selected != null && mounted) {
      setState(() {
        _toChain = selected;
        // Reset to native when the destination chain changes; the previously
        // selected token doesn't exist on the new chain.
        _toCurrency = null;
        _resetQuote();
      });
      _requestQuote();
    }
  }

  /// Pick the destination token (native or any Relay-supported token on the
  /// destination chain).
  Future<void> _selectToCurrency() async {
    final toChain = _toChain;
    if (toChain == null) return;
    final selected = await showModalBottomSheet<BridgeCurrency>(
      context: context,
      backgroundColor: const Color(0xFF0E0E0E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _CurrencyPickerSheet(
        bridgeService: _bridgeService,
        chainId: toChain.chainId,
        chainName: toChain.name,
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        // A native selection clears back to the default native handling.
        _toCurrency = selected.isNative ? null : selected;
        _resetQuote();
      });
      _requestQuote();
    }
  }

  /// Flip origin and destination: the old destination becomes the active
  /// network and the old origin becomes the destination.
  void _flipChains() {
    final toChain = _toChain;
    if (toChain == null) return;

    if (_isSolanaOrigin) {
      // Solana → EVM becomes EVM → Solana.
      widget.blockchain.setActiveChainByChainId(toChain.chainId);
      _afterFlip(_solanaChain);
      return;
    }
    if (toChain.family == ChainFamily.solana) {
      if (_solanaAddress == null) {
        ToastUtils.showInfo('This wallet has no Solana address.');
        return;
      }
      // EVM → Solana becomes Solana → EVM.
      final oldOrigin = widget.blockchain.activeChain;
      widget.blockchain.setActiveNetworkKey(NetworkKey.solana('mainnet'));
      _afterFlip(oldOrigin);
      return;
    }
    final oldOrigin = widget.blockchain.activeChain;
    widget.blockchain.setActiveChainByChainId(toChain.chainId);
    _afterFlip(oldOrigin);
  }

  void _afterFlip(EvmChain newDestination) {
    setState(() {
      _toChain = newDestination;
      _toCurrency = null;
      _selectedPercentage = -1;
      _amountController.clear();
      _resetQuote();
    });
  }

  // ── Execution ───────────────────────────────────────────────────────────

  bool get _hasSufficientBalance {
    final token = _fromToken;
    if (token == null) return false;
    return _amountValue > 0 && _amountValue <= token.balance;
  }

  String? get _buttonLabel {
    if (_isBridging) return 'Bridging...';
    if (_amountValue > 0 && !_hasSufficientBalance) {
      return 'Insufficient ${_fromToken?.symbol ?? 'balance'}';
    }
    return 'Bridge';
  }

  bool get _canBridge =>
      !_isBridging &&
      !_isQuoting &&
      _quote != null &&
      _hasSufficientBalance &&
      widget.walletAddress != null &&
      _quote!.steps.isNotEmpty;

  Future<void> _executeBridge() async {
    final quote = _quote;
    final from = _fromToken;
    if (quote == null || from == null || _isBridging) return;

    // SECURITY: bound what the relay-crafted EVM transactions can move. When
    // bridging the native token the total native value across steps must not
    // exceed the quoted input; for ERC-20 bridges no step may carry native
    // value (tokens move via calldata against an allowance). Solana steps
    // are opaque instruction lists — the app already signs provider-built
    // Solana transactions for swaps, so the same trust model applies.
    final isNative =
        from.contractAddress == null || from.contractAddress!.isEmpty;
    final amountIn = BigInt.tryParse(quote.amountIn) ?? BigInt.zero;
    final totalValue = quote.steps
        .where((step) => !step.isSolana)
        .fold<BigInt>(BigInt.zero, (sum, step) => sum + step.value);
    if (isNative ? totalValue > amountIn : totalValue > BigInt.zero) {
      setState(() {
        _quoteError =
            'Bridge transaction values do not match the quote. Aborting for your safety; please refresh the quote.';
      });
      return;
    }

    setState(() => _isBridging = true);
    final controller = TransactionProgressController(
      flow: TransactionProgressFlow.generic,
    );
    unawaited(
      Navigator.of(context)
          .pushNamed(
            '/transaction-processing',
            arguments: TransactionProcessingArguments(controller: controller),
          )
          .whenComplete(controller.dispose),
    );
    controller.setSwapSubmitting();

    try {
      String? firstTxHash;

      for (final step in quote.steps) {
        if (step.isSolana) {
          // Solana origin: compile the Relay instructions into a signed v0
          // transaction via the native Rust builder and broadcast it.
          final context = await _bridgeService.getSolanaContext(
            lookupTableAddresses: step.lookupTableAddresses,
          );
          if (context == null) {
            controller.setError(
              _bridgeService.lastError ??
                  'Unable to prepare the Solana bridge transaction.',
            );
            return;
          }
          final signedTx = await widget.walletService
              .buildAndSignSolanaBridgeTransaction(
                address: widget.walletAddress!,
                recentBlockhash: context.blockhash,
                instructionsJson: step.instructionsJson!,
                lookupTablesJson: context.lookupTablesJson,
              );
          final signature = await _bridgeService.broadcastSolanaTransaction(
            signedTransaction: signedTx,
          );
          if (signature == null) {
            controller.setError(
              _bridgeService.lastError ??
                  'Unable to broadcast the Solana transaction.',
            );
            return;
          }
          firstTxHash ??= signature;
          controller.setSwapPending(reference: shortHash(signature));
          continue;
        }

        final matchingChains = widget.blockchain.allChains.where(
          (chain) => chain.chainId == step.chainId,
        );
        if (matchingChains.isEmpty) {
          controller.setError(
            'The bridge provider requested an unsupported transaction network (${step.chainId}). The transaction was not sent.',
          );
          return;
        }
        final chain = matchingChains.first;
        final rpcUrl = await _rpcService.resolveWorkingRpcUrl(
          chainId: step.chainId,
          primaryRpcUrl: chain.rpcUrl,
        );
        final credentials = await widget.walletService.getCredentials();
        final client = Web3Client(rpcUrl, _httpClientService.client);
        final tx = await _prepareEvmBridgeTransaction(
          client: client,
          credentials: credentials,
          step: step,
          nativeSymbol: chain.symbol,
        );
        final txHash = await client.sendTransaction(
          credentials,
          tx,
          chainId: step.chainId,
          fetchChainIdFromNetworkId: false,
        );
        firstTxHash ??= txHash;
        controller.setSwapPending(reference: shortHash(txHash));

        // Relay may return an approval followed by a deposit. Waiting for each
        // transaction prevents the next step's gas estimation from running
        // against stale allowance state and also stops on an on-chain revert.
        final confirmed = await _transactionMonitor.waitForConfirmation(
          txHash: txHash,
          blockchain: widget.blockchain,
          evmChain: chain,
        );
        if (!confirmed) {
          controller.setError(
            'A bridge transaction was not confirmed successfully. If it is still pending in your wallet, do not submit the bridge again.',
          );
          return;
        }
      }

      // Relay fills the destination side once the origin deposit lands —
      // poll the intent status until it resolves.
      if (quote.requestId.isNotEmpty) {
        var bridgeCompleted = false;
        for (var attempt = 0; attempt < 45; attempt++) {
          await Future<void>.delayed(const Duration(seconds: 4));
          final status = await _bridgeService.getStatus(
            requestId: quote.requestId,
          );
          if (status == null) continue;
          if (status.isFailure) {
            controller.setError(
              'The bridge could not complete and the relayer reported a failure. Any deducted funds are refunded by the relayer.',
            );
            return;
          }
          if (status.isSuccess) {
            bridgeCompleted = true;
            break;
          }
        }
        if (!bridgeCompleted) {
          controller.setError(
            'Your origin transaction was confirmed, but the bridge is still processing. Do not submit it again. Check the transaction later for destination-chain completion.',
          );
          return;
        }
      }

      controller.setSuccess(
        reference: firstTxHash != null ? shortHash(firstTxHash) : null,
      );

      // Best-effort: log the platform fee on this completed bridge for the admin
      // Bridge Fees analytics. Fire-and-forget — never affects the user.
      unawaited(
        _bridgeService.recordExecutedBridge(
          originChainId: _isSolanaOrigin
              ? BridgeService.relaySolanaChainId
              : widget.blockchain.activeChain.chainId,
          destinationChainId: _toChain?.chainId ?? 0,
          walletAddress: widget.walletAddress,
          sellToken: from.symbol,
          buyToken: _toCurrency?.symbol,
          amountUsd: from.priceUsd > 0 ? _amountValue * from.priceUsd : null,
          txHash: firstTxHash,
        ),
      );

      if (mounted) {
        setState(() {
          _amountController.clear();
          _selectedPercentage = -1;
          _resetQuote();
        });
      }
    } catch (e) {
      controller.setError(
        AppErrorUtils.userMessage(
          e,
          fallback: 'Bridge failed. Please check your balance and try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isBridging = false);
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  Future<Transaction> _prepareEvmBridgeTransaction({
    required Web3Client client,
    required EthPrivateKey credentials,
    required BridgeStepTx step,
    required String nativeSymbol,
  }) async {
    final to = EthereumAddress.fromHex(step.to);
    final data = hexToBytes(step.data.replaceFirst('0x', ''));
    final value = EtherAmount.inWei(step.value);
    final symbol = nativeSymbol.trim().isEmpty
        ? 'the native gas token'
        : nativeSymbol.trim();
    final nativeBalanceWei = (await client.getBalance(
      credentials.address,
    )).getInWei;
    if (nativeBalanceWei <= step.value) {
      throw Exception(
        'Not enough $symbol to pay the bridge amount and network fee. Add more $symbol, then try again.',
      );
    }

    final gasPrice = await client.getGasPrice();
    late final BigInt estimatedGas;
    try {
      estimatedGas = await client.estimateGas(
        sender: credentials.address,
        to: to,
        value: value,
        data: data,
      );
    } catch (error) {
      if (_isGasAllowanceError(error)) {
        throw Exception(
          'Not enough $symbol to cover the bridge network fee. Add more $symbol, then try again.',
        );
      }
      rethrow;
    }
    final bufferedGas = _bufferGasLimit(estimatedGas);
    final gasCostWei = gasPrice.getInWei * bufferedGas;
    final requiredNativeWei = step.value + gasCostWei;

    if (nativeBalanceWei < requiredNativeWei) {
      final missingWei = requiredNativeWei - nativeBalanceWei;
      final missing = EtherAmount.inWei(
        missingWei,
      ).getValueInUnit(EtherUnit.ether).toStringAsFixed(6);
      throw Exception(
        'Not enough $symbol to pay the bridge amount and network fee. Add at least $missing $symbol, then try again.',
      );
    }

    return Transaction(
      to: to,
      data: data,
      value: value,
      gasPrice: gasPrice,
      maxGas: bufferedGas.toInt(),
    );
  }

  bool _isGasAllowanceError(Object error) {
    final lower = error.toString().toLowerCase();
    return lower.contains('gas required exceeds allowance') ||
        lower.contains('insufficient funds') ||
        lower.contains('insufficient native gas') ||
        lower.contains('cannot afford') ||
        (lower.contains('not enough') && lower.contains('gas'));
  }

  BigInt _bufferGasLimit(BigInt estimatedGas) {
    final buffered =
        (estimatedGas * BigInt.from(125) + BigInt.from(99)) ~/ BigInt.from(100);
    return buffered > estimatedGas ? buffered : estimatedGas + BigInt.one;
  }

  @override
  Widget build(BuildContext context) {
    final from = _fromToken;
    final toChain = _toChain;
    final quote = _quote;
    // Family-aware origin display: shows "Solana" + its logo when the
    // active network is Solana, the active EVM chain otherwise.
    final fromChainName = widget.blockchain.activeNetworkName;
    final fromChainLogo = widget.blockchain.activeNetworkLogoUrl;
    final fromTokenIconChainId = _isSolanaOrigin
        ? null
        : widget.blockchain.activeChain.chainId;

    final fromUsd = from != null && from.priceUsd > 0
        ? _amountValue * from.priceUsd
        : 0.0;

    String toAmountText = '0.0';
    if (quote != null) {
      final outWei = BigInt.tryParse(quote.amountOut) ?? BigInt.zero;
      // Use the selected token's decimals; otherwise the chain's native
      // decimals (SOL uses 9, EVM gas tokens 18).
      final outDecimals =
          _toCurrency?.decimals ??
          (toChain?.family == ChainFamily.solana ? 9 : 18);
      toAmountText = AmountUtils.formatBaseUnits(
        outWei,
        outDecimals,
        maxFractionDigits: 6,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BridgeCard(
          label: 'BRIDGE FROM',
          chainName: fromChainName,
          chainLogoUrl: fromChainLogo,
          onSelectChain: widget.onSelectFromChain,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final percent in const [25, 50, 75])
                      _BridgePercentChip(
                        label: '$percent%',
                        isSelected: _selectedPercentage == percent,
                        onTap: () => _setPercentage(percent),
                      ),
                    _BridgePercentChip(
                      label: 'MAX',
                      isSelected: _selectedPercentage == 100,
                      alwaysAccent: true,
                      onTap: () => _setPercentage(100),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      onChanged: _onAmountChanged,
                      enabled: !_isBridging,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE2E2E2),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '0.0',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: const Color(0x4DE2E2E2),
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SwapTokenChip(
                    token: from,
                    onTap: _isBridging ? () {} : _selectFromToken,
                    chainId: fromTokenIconChainId,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ValueFormatter.formatCurrencyWithGrouping(
                        ValueFormatter.decimalFromNum(fromUsd),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF848E9C),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 11,
                    color: Color(0xFF848E9C),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(from?.balance ?? 0).toStringAsFixed(4)} ${from?.symbol ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF848E9C),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Flip separator, matching the swap tab's direction button: a full
        // 40px-tall slot keeps the button in a clean gap between the cards
        // instead of overflowing onto (overlapping) the From/To containers.
        SizedBox(
          height: 40,
          child: Center(
            child: GestureDetector(
              onTap: _isBridging ? null : _flipChains,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF000000),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF121212), width: 4),
                ),
                child: const Center(
                  child: FigmaSwapDirectionIcon(
                    color: Color(0xFFEA2A33),
                    width: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
        _BridgeCard(
          label: 'BRIDGE TO',
          chainName: toChain?.name ?? '--',
          chainLogoUrl: toChain?.logoUrl,
          onSelectChain: _isBridging ? null : _selectToChain,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isQuoting ? '…' : toAmountText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: quote == null
                            ? const Color(0x4DE2E2E2)
                            : const Color(0xFFE2E2E2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _DestinationTokenChip(
                    chain: toChain,
                    currency: _toCurrency,
                    onTap: _isBridging ? null : _selectToCurrency,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ValueFormatter.formatCurrencyWithGrouping(
                  ValueFormatter.decimalFromNum(quote?.amountOutUsd ?? 0),
                ),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF848E9C),
                ),
              ),
            ],
          ),
        ),
        if (quote != null || _isQuoting) ...[
          const SizedBox(height: 16),
          _BridgeDetailsCard(quote: quote, isLoading: _isQuoting),
        ],
        if (_quoteError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x1AEA2A33),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x4DEA2A33)),
            ),
            child: Text(
              _quoteError!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFEA8A8F),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SwapPrimaryButton(
          enabled: _canBridge,
          isBusy: _isBridging,
          onPressed: _executeBridge,
          label: _buttonLabel,
        ),
        const SizedBox(height: 12),
        Text(
          'Bridging moves tokens between networks via Owllet routing. You receive the destination network\'s native token.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

/// Card shell with a "BRIDGE FROM/TO" header and a chain selector pill,
/// per the Figma bridge design.
class _BridgeCard extends StatelessWidget {
  final String label;
  final String chainName;
  final String? chainLogoUrl;
  final VoidCallback? onSelectChain;
  final Widget child;

  const _BridgeCard({
    required this.label,
    required this.chainName,
    required this.chainLogoUrl,
    required this.onSelectChain,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF151C24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFB2B5BD),
                  letterSpacing: 1.0,
                ),
              ),
              _ChainPill(
                name: chainName,
                logoUrl: chainLogoUrl,
                onTap: onSelectChain,
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ChainPill extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final VoidCallback? onTap;

  const _ChainPill({required this.name, required this.logoUrl, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF1A222B),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChainLogoDot(url: logoUrl),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const FigmaDropdownIcon(width: 6, color: Color(0xFFC8C6C5)),
          ],
        ),
      ),
    );
  }
}

class _ChainLogoDot extends StatelessWidget {
  final String? url;

  const _ChainLogoDot({this.url});

  @override
  Widget build(BuildContext context) {
    const fallback = SizedBox(
      width: 20,
      height: 20,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFF2A2A2A),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.language, color: Color(0xFFC8C6C5), size: 12),
      ),
    );
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        trimmed,
        width: 20,
        height: 20,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// Tappable chip for the destination token: shows the selected token, or the
/// chain's native coin by default. Tapping opens the destination token picker.
class _DestinationTokenChip extends StatelessWidget {
  final EvmChain? chain;
  final BridgeCurrency? currency;
  final VoidCallback? onTap;

  const _DestinationTokenChip({
    required this.chain,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final symbol = currency?.symbol ?? chain?.symbol ?? '--';
    final logo = currency?.logoUri ?? chain?.logoUrl;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF1A222B),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x0DFFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChainLogoDot(url: logo),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 90),
              child: Text(
                symbol,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE5E2E1),
                ),
              ),
            ),
            const SizedBox(width: 7),
            const FigmaDropdownIcon(width: 6, color: Color(0xFFC8C6C5)),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing Relay-supported destination tokens for a chain, with
/// a search box (Relay's `term` filter).
class _CurrencyPickerSheet extends StatefulWidget {
  final BridgeService bridgeService;
  final int chainId;
  final String chainName;

  const _CurrencyPickerSheet({
    required this.bridgeService,
    required this.chainId,
    required this.chainName,
  });

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<BridgeCurrency> _currencies = const [];
  bool _loading = true;
  String? _loadError;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({String? term}) async {
    setState(() => _loading = true);
    final results = await widget.bridgeService.getDestinationCurrencies(
      chainId: widget.chainId,
      term: term,
    );
    if (!mounted) return;
    setState(() {
      _currencies = results;
      _loadError = results.isEmpty ? widget.bridgeService.lastError : null;
      _loading = false;
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _load(term: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(
                  'Receive on ${widget.chainName}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search token or symbol',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF6B7280),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF848E9C),
                      size: 18,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF151C24),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _currencies.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _loadError ?? 'No tokens found.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF848E9C),
                              ),
                            ),
                            if (_loadError != null) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () =>
                                    _load(term: _searchController.text),
                                child: Text(
                                  'Retry',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFEA2A33),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _currencies.length,
                        itemBuilder: (ctx, index) {
                          final c = _currencies[index];
                          return ListTile(
                            onTap: () => Navigator.of(ctx).pop(c),
                            leading: _ChainLogoDot(url: c.logoUri),
                            title: Text(
                              c.symbol,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF848E9C),
                              ),
                            ),
                            trailing: c.isNative
                                ? Text(
                                    'Native',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF848E9C),
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BridgePercentChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool alwaysAccent;
  final VoidCallback onTap;

  const _BridgePercentChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.alwaysAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isSelected || alwaysAccent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x1AEA2A33) : const Color(0xFF131313),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: accent ? const Color(0x4DEA2A33) : const Color(0x0DFFFFFF),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            color: accent ? const Color(0xFFEA2A33) : const Color(0xFFA1A1A1),
          ),
        ),
      ),
    );
  }
}

/// Fee/details box: platform fee, bridge fee, estimated gas, arrival.
class _BridgeDetailsCard extends StatelessWidget {
  final BridgeQuote? quote;
  final bool isLoading;

  const _BridgeDetailsCard({required this.quote, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final q = quote;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0x801E2228),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: isLoading && q == null
          ? Center(
              child: Text(
                'Fetching bridge route…',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            )
          : Column(
              children: [
                if (q?.platformFeeBps != null)
                  _DetailRow(
                    label: 'Platform Fee',
                    value: _usdLabel(q!.platformFeeUsd),
                  ),
                _DetailRow(
                  label: 'Bridge Fee',
                  value: _usdLabel(q?.bridgeFeeUsd),
                ),
                _DetailRow(
                  label: 'Estimated Gas',
                  value: '~${_usdLabel(q?.gasFeeUsd)}',
                ),
                _DetailRow(
                  label: 'Estimated Arrival',
                  value: q?.arrivalLabel ?? '~minutes',
                  isLast: true,
                ),
              ],
            ),
    );
  }

  static String _usdLabel(double? value) {
    if (value == null || value <= 0) return r'$0.00';
    if (value < 0.01) return r'<$0.01';
    return '\$${value.toStringAsFixed(2)}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF9CA3AF),
              letterSpacing: 0.24,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFE5E2E1),
              letterSpacing: 0.24,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChainPickerSheet extends StatelessWidget {
  final List<EvmChain> chains;

  const _ChainPickerSheet({required this.chains});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Text(
                'Bridge to network',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: chains.length,
                itemBuilder: (ctx, index) {
                  final chain = chains[index];
                  return ListTile(
                    onTap: () => Navigator.of(ctx).pop(chain),
                    leading: _ChainLogoDot(url: chain.logoUrl),
                    title: Text(
                      chain.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    trailing: Text(
                      chain.symbol,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF848E9C),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
