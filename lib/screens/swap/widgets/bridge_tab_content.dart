import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web3dart/web3dart.dart';

import '../../../models/chain.dart';
import '../../../models/bitcoin_account_state.dart';
import '../../../models/bitcoin_discovery.dart';
import '../../../models/bitcoin_wallet_balance.dart';
import '../../../services/bitcoin/bitcoin_address_allocator.dart';
import '../../../services/bitcoin/bitcoin_bridge_funding_service.dart';
import '../../../services/bitcoin/bitcoin_broadcast_service.dart';
import '../../../services/bitcoin/bitcoin_protected_record.dart';
import '../../../services/bitcoin/bitcoin_send_service.dart'
    show BitcoinSplitFundsException, BitcoinPendingInputsException;
import '../../../services/storage_service.dart';
import '../../../services/runtime_config_service.dart';
import '../../../services/wallet_vault_service.dart';
import '../../../utils/wallet_unlock_navigation.dart';
import '../../../utils/sensitive_access_guard.dart';
import '../../../utils/bitcoin_amount_utils.dart';
import '../../wallet/bitcoin_transfer_confirmation_screen.dart';
import '../../../models/token.dart';
import '../../../services/blockchain/asset_chain_bridge_client.dart';
import '../../../services/blockchain/asset_chain_native_bridge_service.dart';
import '../../../services/blockchain/blockchain_catalog.dart';
import '../../../services/blockchain/solana_catalog.dart';
import '../../../services/blockchain/bitcoin_catalog.dart';
import '../../../services/blockchain/tron_catalog.dart';
import '../../../services/blockchain_service.dart';
import '../../../services/bridge_service.dart';
import '../../../services/bridge_operation_store.dart';
import '../../../services/http_client_service.dart';
import '../../../services/transaction_monitor.dart';
import '../../../services/swap_service.dart';
import '../../../services/tron_swap_service.dart';
import '../../../services/wallet_service.dart';
import '../../../services/evm_transaction_service.dart';
import '../../../services/evm_bridge_transaction_service.dart';
import '../../../services/wallet_history_service.dart';
import '../../../services/wallet_notification_service.dart';
import '../../../theme/app_chain_theme.dart';
import '../../../utils/amount_utils.dart';
import '../../../utils/app_error_utils.dart';
import '../../../utils/toast_utils.dart';
import '../../../utils/token_trust_utils.dart';
import '../../../utils/value_formatter.dart';
import '../../../widgets/chain_logo_image.dart';
import '../../../widgets/token_icon.dart';
import '../../transaction/transaction_processing_screen.dart';
import '../../transaction/transactions_screen.dart';
import '../swap_screen_helpers.dart';
import 'swap_figma_icons.dart';
import 'swap_primary_button.dart';
import 'swap_slippage_section.dart';
import 'swap_token_chip.dart';
import 'swap_token_selector_dialog.dart';

/// Number of foreground status checks to run after the origin deposit lands
/// before handing long-running settlement tracking off to background polling.
int bridgeStatusPollAttempts(BridgeQuote quote) {
  if (quote.bitcoinQuote != null ||
      quote.destinationChainId == BridgeService.relayBitcoinChainId) {
    return 3;
  }
  return 15;
}

List<Token> filterBridgeOriginTokens({
  required List<Token> tokens,
  required String activeNetworkKey,
  required ChainFamily activeFamily,
  required String nativeSymbol,
}) {
  final expectedKey = activeNetworkKey.trim().toLowerCase();
  final evmChainId =
      activeFamily == ChainFamily.evm && expectedKey.startsWith('evm:')
      ? int.tryParse(expectedKey.substring(4))
      : null;
  return tokens
      .where((token) {
        if (evmChainId != null &&
            !isSwapEligibleTokenForChain(token, evmChainId)) {
          return false;
        }
        final tokenKey = token.networkKey?.trim().toLowerCase();
        if (tokenKey != null && tokenKey.isNotEmpty) {
          return tokenKey == expectedKey;
        }
        if (activeFamily == ChainFamily.evm) return true;
        final contract = token.contractAddress?.trim();
        return (contract == null || contract.isEmpty) &&
            token.symbol.trim().toUpperCase() ==
                nativeSymbol.trim().toUpperCase();
      })
      .toList(growable: false);
}

Widget buildBridgeOriginTokenDialog({
  required List<Token> tokens,
  required int chainId,
  required String activeNetworkKey,
  required ChainFamily activeFamily,
  required String nativeSymbol,
}) {
  return SwapTokenSelectorDialog(
    tokens: filterBridgeOriginTokens(
      tokens: tokens,
      activeNetworkKey: activeNetworkKey,
      activeFamily: activeFamily,
      nativeSymbol: nativeSymbol,
    ),
    chainId: chainId,
  );
}

String? bridgeFamilyLogoUrl(ChainFamily family) => switch (family) {
  ChainFamily.bitcoin => BitcoinCatalog.mainnet.logoUrl,
  ChainFamily.solana => SolanaCatalog.mainnet.logoUrl,
  ChainFamily.tron => TronCatalog.mainnet.logoUrl,
  ChainFamily.evm => null,
};

double? destinationAmountUsd({
  required double quoteAmountUsd,
  required String amountText,
  required String destinationSymbol,
  double? destinationPriceUsd,
}) {
  if (quoteAmountUsd > 0) return quoteAmountUsd;
  final normalizedSymbol = destinationSymbol.trim().toUpperCase();
  final stablePrice =
      const {
        'USDC',
        'USDT',
        'DAI',
        'USDE',
        'USDS',
        'PYUSD',
      }.contains(normalizedSymbol)
      ? 1.0
      : null;
  final price = destinationPriceUsd != null && destinationPriceUsd > 0
      ? destinationPriceUsd
      : stablePrice;
  final amount = double.tryParse(amountText.replaceAll(',', ''));
  if (price == null || amount == null || amount <= 0) return null;
  return amount * price;
}

bool committedBridgeQuoteIsFresh(BridgeQuote quote, {required DateTime now}) {
  final deadline = quote.deadline;
  // Same-chain providers return immediately executable transactions rather
  // than a cross-chain deposit intent, so they may omit an intent TTL. When a
  // provider does include one, still enforce it.
  if (deadline == null) {
    return quote.originChainId == quote.destinationChainId;
  }
  return deadline.toUtc().isAfter(now.toUtc().add(const Duration(seconds: 30)));
}

Token _bridgeCurrencyAsToken(BridgeCurrency currency) => Token(
  symbol: currency.symbol,
  name: currency.name,
  contractAddress: currency.isNative ? null : currency.address,
  balance: 0,
  valueUsd: 0,
  changePercent24h: 0,
  decimals: currency.decimals,
  imageUrl: currency.logoUri,
  isCertified: currency.isNative,
);

bool _bridgeCurrencyBlocked(BridgeCurrency currency) =>
    TokenTrustUtils.blocksDestination(
      _bridgeCurrencyAsToken(currency),
      chainId: currency.chainId,
    );

String formatBridgeFeeUsd(double? value) {
  if (value == null || value <= 0) return r'$0.00';
  if (value < 0.01) return r'<$0.01';
  return '\$${value.toStringAsFixed(2)}';
}

String formatBridgePlatformFee({
  required double swapAmountUsd,
  required double? feeUsd,
  required int? feeBps,
}) {
  if (swapAmountUsd > 100 && feeBps != null) {
    return '${(feeBps / 100).toStringAsFixed(2)}%';
  }
  if (feeUsd != null) return '\$${feeUsd.toStringAsFixed(2)}';
  if (feeBps != null) return '${(feeBps / 100).toStringAsFixed(2)}%';
  return r'$0.00';
}

bool hasQuotedOriginNetworkFee(double? value) => value != null && value > 0;

/// Require discovered funds in one account and headroom for the Core-planned fee.
bool bitcoinBridgeHasFunds(BitcoinWalletSnapshot? snapshot, BigInt amount) =>
    snapshot != null &&
    amount > BigInt.zero &&
    snapshot.balances.values.any((balance) => balance.spendableSats > amount);

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
  final Future<void> Function()? onBridgeCompleted;
  final AssetChainNativeBridgeService? assetChainBridgeService;

  const BridgeTabContent({
    super.key,
    required this.blockchain,
    required this.walletService,
    required this.walletAddress,
    required this.tokens,
    required this.onSelectFromChain,
    this.onBridgeCompleted,
    this.assetChainBridgeService,
  });

  @override
  State<BridgeTabContent> createState() => _BridgeTabContentState();
}

class _BridgeTabContentState extends State<BridgeTabContent> {
  final TextEditingController _amountController = TextEditingController();
  final BridgeService _bridgeService = BridgeService();
  final HttpClientService _httpClientService = HttpClientService();
  final TransactionMonitor _transactionMonitor = TransactionMonitor();
  final TronSwapService _tronSwapService = TronSwapService();
  final BridgeOperationStore _bridgeOperationStore = BridgeOperationStore();
  final WalletHistoryService _walletHistoryService = WalletHistoryService();
  final WalletNotificationService _walletNotificationService =
      WalletNotificationService();
  late final AssetChainNativeBridgeService _assetChainBridgeService =
      widget.assetChainBridgeService ??
      AssetChainNativeBridgeService(wallet: widget.walletService);

  Token? _fromToken;
  EvmChain? _toChain;

  /// Selected destination token; null means the destination chain's native
  /// coin. Relay supports settling into any supported token, not just native.
  BridgeCurrency? _toCurrency;
  int _selectedPercentage = -1;
  BridgeQuote? _quote;
  AssetChainNativeBridgeQuote? _assetChainQuote;
  bool _isQuoting = false;
  bool _isBridging = false;
  bool _bridgeActionActive = false;
  String? _quoteError;
  int _slippageBps = 50;
  Timer? _debounce;
  int _quoteSeq = 0;
  String? _solanaAddress;
  String? _evmAddress;
  String? _tronAddress;
  String? _lastNetworkKey;
  PendingBridgeOperation? _pendingOperation;
  bool _isCheckingPending = false;
  Timer? _pendingPoll;
  List<AssetChainNativeBridgeRoute> _assetChainRoutes = const [];
  bool _assetChainRoutesLoading = false;
  String? _assetChainRoutesError;
  List<AssetChainBridgeTransaction> _assetChainTransfers = const [];
  List<Map<String, dynamic>> _assetChainPending = const [];
  String? _claimingAssetChainTransferId;
  bool _isRefreshingAssetChain = false;
  int _assetChainRouteGeneration = 0;
  final BitcoinBridgeFundingService _bitcoinFunding =
      BitcoinBridgeFundingService();
  BitcoinDerivedAddress? _bitcoinReceive;
  BitcoinBridgeFundingRecovery? _bitcoinRecovery;
  bool _bitcoinHasPending = false;
  bool _bitcoinRecoveryLoaded = false;
  bool _bitcoinBalanceLoading = false;
  int _bitcoinLoadGeneration = 0;
  bool _isCheckingBitcoin = false;
  Timer? _bitcoinPoll;

  /// Relay-supported chain ids; null until loaded (or when unavailable, in
  /// which case filtering is skipped).
  Set<int>? _relayChainIds;

  /// Solana entry for the chain pickers. Solana works as both origin
  /// (instructions compiled + signed via the native Rust builder) and
  /// destination.
  static final EvmChain _solanaChain = EvmChain(
    name: 'Solana',
    symbol: 'SOL',
    chainId: BridgeService.relaySolanaChainId,
    rpcUrl: '',
    family: ChainFamily.solana,
    logoUrl: bridgeFamilyLogoUrl(ChainFamily.solana),
  );

  static final EvmChain _tronChain = EvmChain(
    name: 'TRON',
    symbol: 'TRX',
    chainId: BridgeService.tronBridgeChainId,
    rpcUrl: '',
    family: ChainFamily.tron,
    logoUrl: bridgeFamilyLogoUrl(ChainFamily.tron),
  );
  static final EvmChain _bitcoinChain = EvmChain(
    name: 'Bitcoin',
    symbol: 'BTC',
    chainId: BridgeService.relayBitcoinChainId,
    rpcUrl: '',
    family: ChainFamily.bitcoin,
    logoUrl: bridgeFamilyLogoUrl(ChainFamily.bitcoin),
  );

  bool get _isBitcoinOrigin =>
      widget.blockchain.activeFamily == ChainFamily.bitcoin;
  bool get _bitcoinAllowed {
    final chain = widget.blockchain;
    final runtime = RuntimeConfigService.instance.snapshot;
    return chain.activeWalletSupportedFamilies.contains(ChainFamily.bitcoin) &&
        chain.enabledFamilies.contains(ChainFamily.bitcoin) &&
        chain.isBitcoinNetworkAvailable('bitcoin:mainnet') &&
        runtime.allows(RuntimeFeature.bridges) &&
        runtime.allows(RuntimeFeature.transfers);
  }

  bool get _isSolanaOrigin =>
      widget.blockchain.activeFamily == ChainFamily.solana;
  bool get _isTronOrigin => widget.blockchain.activeFamily == ChainFamily.tron;
  bool get _isAssetChainOrigin =>
      widget.blockchain.activeFamily == ChainFamily.evm &&
      SwapService.isAssetChain(widget.blockchain.activeChain.chainId);
  bool get _isAssetChainDestination =>
      widget.blockchain.activeFamily == ChainFamily.evm &&
      _toChain != null &&
      _toChain!.family == ChainFamily.evm &&
      SwapService.isAssetChain(_toChain!.chainId);
  bool get _isAssetChainRoute =>
      _isAssetChainOrigin || _isAssetChainDestination;

  List<Token> get _originTokens {
    final scoped = filterBridgeOriginTokens(
      tokens: widget.tokens,
      activeNetworkKey: widget.blockchain.activeNetworkKey,
      activeFamily: widget.blockchain.activeFamily,
      nativeSymbol: widget.blockchain.activeNetworkSymbol,
    );
    if (scoped.isNotEmpty) return scoped;
    return filterBridgeOriginTokens(
      tokens: widget.blockchain.tokens,
      activeNetworkKey: widget.blockchain.activeNetworkKey,
      activeFamily: widget.blockchain.activeFamily,
      nativeSymbol: widget.blockchain.activeNetworkSymbol,
    );
  }

  @override
  void initState() {
    super.initState();
    _lastNetworkKey = widget.blockchain.activeNetworkKey;
    _syncFromToken();
    _syncToChain();
    unawaited(_loadFamilyAddresses());
    unawaited(_loadRelayChains());
    unawaited(_loadAssetChainRoutes());
    unawaited(_loadAssetChainTransfers());
  }

  Future<void> _loadFamilyAddresses() async {
    final originalWallet = widget.walletAddress;
    Future<String?> address(ChainFamily family) async {
      try {
        return await widget.walletService.getWalletAddressForFamily(family);
      } catch (_) {
        return null;
      }
    }

    final solana = await address(ChainFamily.solana);
    final evm = await address(ChainFamily.evm);
    final tron = await address(ChainFamily.tron);
    if (!mounted || widget.walletAddress != originalWallet) return;
    setState(() {
      if (solana != null && solana.isNotEmpty) _solanaAddress = solana;
      if (evm != null && evm.isNotEmpty) _evmAddress = evm;
      if (tron != null && tron.isNotEmpty) _tronAddress = tron;
    });
    await _loadBitcoinAddress();
    await _loadPendingBridge();
  }

  Future<void> _loadBitcoinAddress() async {
    final identity = widget.blockchain.activeWalletAddress.trim().toLowerCase();
    if (!_bitcoinAllowed || identity.isEmpty) return;
    final networkKey = widget.blockchain.activeNetworkKey;
    final generation = ++_bitcoinLoadGeneration;
    bool current() =>
        mounted &&
        generation == _bitcoinLoadGeneration &&
        widget.blockchain.activeNetworkKey == networkKey &&
        _bitcoinAllowed &&
        widget.blockchain.activeWalletAddress.trim().toLowerCase() == identity;
    if (_isBitcoinOrigin) setState(() => _bitcoinBalanceLoading = true);
    try {
      final storage = StorageService();
      final accounts = await storage.getWalletAccounts();
      if (!current()) return;
      final account = accounts
          .where((value) => value.address.toLowerCase() == identity)
          .firstOrNull;
      if (account == null || !account.supportsFamily(ChainFamily.bitcoin)) {
        return;
      }
      final receive =
          await BitcoinAddressAllocator(
            store: storage.bitcoinAccounts,
          ).currentReceive(
            BitcoinAccountSlot(
              walletIdentity: identity,
              network: BitcoinProductNetwork.mainnet,
              accountIndex: account.derivationIndex ?? 0,
              purpose: BitcoinPurpose.bip84,
            ),
          );
      final pending = await _bitcoinFunding.journal.pending(identity);
      if (_isBitcoinOrigin && current()) {
        await _bitcoinFunding.planner.wallet.refresh(
          identity,
          BitcoinProductNetwork.mainnet,
          isCurrent: current,
        );
      }
      if (!current()) return;
      setState(() {
        _bitcoinReceive = receive;
        _bitcoinHasPending = pending != null;
        _bitcoinRecoveryLoaded = true;
        _syncToChain();
      });
      if (pending != null) unawaited(_checkBitcoinBridge());
      if (_isBitcoinOrigin) _requestQuote();
    } catch (_) {
      if (current() && _isBitcoinOrigin) {
        setState(
          () => _quoteError =
              'Unable to load the Bitcoin bridge account. Refresh the BTC balance to try again.',
        );
      }
    } finally {
      if (current()) setState(() => _bitcoinBalanceLoading = false);
    }
  }

  Future<void> _checkBitcoinBridge() async {
    if (_isCheckingBitcoin) return;
    final identity = widget.blockchain.activeWalletAddress.trim().toLowerCase();
    bool current() =>
        mounted &&
        widget.blockchain.activeWalletAddress.trim().toLowerCase() == identity;
    setState(() => _isCheckingBitcoin = true);
    try {
      final result = await _bitcoinFunding.recover(
        identity,
        isCurrent: current,
      );
      final pending = await _bitcoinFunding.journal.pending(identity);
      if (!current()) return;
      setState(() {
        _bitcoinRecovery = result;
        _bitcoinHasPending = pending != null;
      });
      final refresh = widget.onBridgeCompleted;
      if ((result.delivered || result.refunded) && refresh != null) {
        unawaited(Future<void>.sync(refresh).catchError((Object _) {}));
      }
    } catch (_) {
      if (current()) {
        ToastUtils.showInfo(
          'Unable to verify the saved bridge yet. Do not pay it again.',
        );
      }
    } finally {
      if (current()) {
        setState(() => _isCheckingBitcoin = false);
        _scheduleBitcoinObservation();
      }
    }
  }

  void _scheduleBitcoinObservation() {
    _bitcoinPoll?.cancel();
    if (!mounted || !_bitcoinHasPending) return;
    _bitcoinPoll = Timer(const Duration(seconds: 15), () {
      if (mounted && _bitcoinHasPending && !_isCheckingBitcoin) {
        unawaited(_checkBitcoinBridge());
      }
    });
  }

  Future<void> _loadPendingBridge() async {
    final wallet = widget.walletAddress;
    if (wallet == null || wallet.isEmpty) return;
    final pending = await _bridgeOperationStore.load(wallet);
    if (!mounted) return;
    setState(() => _pendingOperation = pending);
    if (pending != null) unawaited(_checkPendingBridge());
  }

  Future<void> _checkPendingBridge() async {
    final pending = _pendingOperation;
    if (pending == null || _isCheckingPending) return;
    setState(() => _isCheckingPending = true);
    try {
      if (pending.requestId.startsWith('near:')) {
        await _bridgeService.submitNearDeposit(
          requestId: pending.requestId,
          txHash: pending.originTxHash,
        );
      }
      final status = await _bridgeService.getStatus(
        requestId: pending.requestId,
      );
      if (!mounted) return;
      if (status?.isSuccess == true || status?.isFailure == true) {
        await _bridgeOperationStore.clear(pending.walletAddress);
        if (!mounted) return;
        setState(() => _pendingOperation = null);
        if (status!.isSuccess) {
          _scheduleCompletedBridgeRecording(pending);
          ToastUtils.showSuccess('Your pending bridge completed.');
        } else {
          ToastUtils.showInfo(status.userFacingFailureMessage);
        }
        return;
      }
    } catch (_) {
      // Transient status check failure; keep pending and retry on timer.
    } finally {
      if (mounted) {
        setState(() => _isCheckingPending = false);
        _schedulePendingObservation();
      }
    }
  }

  void _schedulePendingObservation() {
    _pendingPoll?.cancel();
    if (!mounted || _pendingOperation == null) return;
    _pendingPoll = Timer(const Duration(seconds: 15), () {
      if (mounted && _pendingOperation != null && !_isCheckingPending) {
        unawaited(_checkPendingBridge());
      }
    });
  }

  Future<void> _persistPendingBridge(BridgeQuote quote, String txHash) async {
    final wallet = widget.walletAddress;
    if (wallet == null || wallet.isEmpty || quote.requestId.isEmpty) return;
    final alreadyTracked =
        _pendingOperation?.requestId == quote.requestId &&
        _pendingOperation?.originTxHash == txHash;
    final operation = PendingBridgeOperation(
      walletAddress: wallet,
      requestId: quote.requestId,
      originTxHash: txHash,
      originChainId: quote.originChainId,
      destinationChainId: quote.destinationChainId,
      sellToken: _fromToken?.symbol,
      buyToken: _toCurrency?.symbol ?? _toChain?.symbol,
      amount: _amountValue > 0 ? _amountValue : null,
      amountUsd: _fromToken != null && _fromToken!.priceUsd > 0
          ? _amountValue * _fromToken!.priceUsd
          : null,
      createdAt: DateTime.now().toUtc(),
      deadline: quote.deadline,
    );
    await _bridgeOperationStore.save(operation);
    if (mounted) setState(() => _pendingOperation = operation);
    if (!alreadyTracked) {
      await _recordBridgeSubmission(operation);
    }
  }

  String _originExplorerTxUrl(String? txHash, {EvmChain? evmChain}) {
    if (txHash == null || txHash.trim().length < 40) return '';
    final explorerUrl =
        (evmChain?.explorerUrl ?? widget.blockchain.activeNetworkExplorerUrl)
            ?.trim();
    if (explorerUrl == null || explorerUrl.isEmpty) return '';
    final normalized = explorerUrl.endsWith('/')
        ? explorerUrl.substring(0, explorerUrl.length - 1)
        : explorerUrl;
    return '$normalized/tx/${txHash.trim()}';
  }

  String _bridgeChainName(int chainId) {
    if (chainId == BridgeService.relayBitcoinChainId) return 'Bitcoin';
    if (chainId == BridgeService.relaySolanaChainId) return 'Solana';
    if (chainId == BridgeService.tronBridgeChainId) return 'TRON';
    for (final chain in widget.blockchain.allChains) {
      if (chain.chainId == chainId) return chain.name;
    }
    return 'Chain $chainId';
  }

  String _bridgeNetworkKey(int chainId) {
    if (chainId == BridgeService.relayBitcoinChainId) return 'bitcoin:mainnet';
    if (chainId == BridgeService.relaySolanaChainId) return 'solana:mainnet';
    if (chainId == BridgeService.tronBridgeChainId) return 'tron:mainnet';
    return 'evm:$chainId';
  }

  Future<void> _recordBridgeSubmission(PendingBridgeOperation operation) {
    return _walletHistoryService.recordBridgeSubmitted(
      walletAddress: operation.walletAddress,
      txHash: operation.originTxHash,
      chainId: operation.originChainId,
      networkName: _bridgeChainName(operation.originChainId),
      networkKey: _bridgeNetworkKey(operation.originChainId),
      fromTokenSymbol: operation.sellToken ?? 'Token',
      fromAmount: operation.amount?.toString() ?? '0',
      toTokenSymbol: operation.buyToken ?? 'token',
      destinationNetworkName: _bridgeChainName(operation.destinationChainId),
    );
  }

  void _scheduleCompletedBridgeRecording(PendingBridgeOperation operation) {
    unawaited(
      Future.wait([
        _walletNotificationService.notifyBridgeCompleted(
          walletAddress: operation.walletAddress,
          originChainId: operation.originChainId,
          txHash: operation.originTxHash,
          fromSymbol: operation.sellToken ?? 'Tokens',
          toSymbol: operation.buyToken ?? 'tokens',
          destinationNetworkName: _bridgeChainName(
            operation.destinationChainId,
          ),
        ),
        _bridgeService.recordExecutedBridge(
          originChainId: operation.originChainId,
          destinationChainId: operation.destinationChainId,
          walletAddress: operation.walletAddress,
          sellToken: operation.sellToken,
          buyToken: operation.buyToken,
          amountUsd: operation.amountUsd,
          txHash: operation.originTxHash,
        ),
      ]).catchError((Object error, StackTrace stackTrace) {
        debugPrint('Bridge completion bookkeeping failed: $error\n$stackTrace');
        return <void>[];
      }),
    );
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
        _bitcoinRecoveryLoaded = false;
        _bitcoinBalanceLoading = false;
        _toCurrency = null;
        if (_isAssetChainRoute) {
          _autoPairAssetChainFromTokenIfNeeded();
          _syncAssetChainDestinationCurrency();
        }
        unawaited(_loadBitcoinAddress());
        unawaited(_loadAssetChainTransfers());
        _resetQuote();
        _requestQuote();
      } else if (_isAssetChainRoute) {
        _syncAssetChainDestinationCurrency();
      }
    }
    if (oldWidget.walletAddress != widget.walletAddress) {
      _bitcoinPoll?.cancel();
      _isCheckingBitcoin = false;
      _bitcoinReceive = null;
      _bitcoinRecovery = null;
      _bitcoinHasPending = false;
      _bitcoinRecoveryLoaded = false;
      _bitcoinBalanceLoading = false;
      _bitcoinLoadGeneration++;
      _resetQuote();
      unawaited(_loadFamilyAddresses());
      unawaited(_loadAssetChainTransfers());
    }
  }

  @override
  void dispose() {
    _assetChainRouteGeneration++;
    _bitcoinPoll?.cancel();
    _pendingPoll?.cancel();
    _debounce?.cancel();
    _amountController.dispose();
    if (widget.assetChainBridgeService == null) {
      _assetChainBridgeService.dispose();
    }
    super.dispose();
  }

  bool _tokenStillVisible() {
    final current = _fromToken;
    if (current == null) return false;
    return _originTokens.any(
      (t) =>
          (t.contractAddress ?? '').toLowerCase() ==
          (current.contractAddress ?? '').toLowerCase(),
    );
  }

  void _syncFromToken({bool reset = false}) {
    if (!reset && _tokenStillVisible()) {
      // Refresh balance/price from the latest token list.
      final address = (_fromToken?.contractAddress ?? '').toLowerCase();
      _fromToken = _originTokens.firstWhere(
        (t) => (t.contractAddress ?? '').toLowerCase() == address,
        orElse: () => _fromToken!,
      );
      return;
    }
    // Default to the native token of the origin chain.
    final originTokens = _originTokens;
    _fromToken = originTokens.isEmpty
        ? null
        : originTokens.firstWhere(
            (t) => t.contractAddress == null || t.contractAddress!.isEmpty,
            orElse: () => originTokens.first,
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
  /// user-added custom networks don't produce dead-end quotes. When Asset
  /// Chain is origin or destination, routes resolve through the Asset Chain
  /// BridgeAssist service under the hood instead of Relay.
  List<EvmChain> _destinationChains() {
    if (_isAssetChainOrigin) {
      final activeId = widget.blockchain.activeChain.chainId;
      final configured = <EvmChain>[];
      final seenIds = <int>{};
      for (final route in _assetChainRoutes) {
        if (route.sourceChain.chainId == activeId &&
            !SwapService.isAssetChain(route.destinationChain.chainId) &&
            seenIds.add(route.destinationChain.chainId)) {
          configured.add(route.destinationChain);
        }
      }
      if (configured.isNotEmpty) return configured;
      return widget.blockchain.allChains
          .where(
            (chain) =>
                chain.family == ChainFamily.evm &&
                !SwapService.isAssetChain(chain.chainId),
          )
          .toList(growable: false);
    }

    final relayIds = _relayChainIds;
    if (_isBitcoinOrigin && relayIds == null) return [];
    final evmChains = widget.blockchain.allChains.where((chain) {
      if (chain.family != ChainFamily.evm) return false;
      if (SwapService.isAssetChain(chain.chainId)) return false;
      if (!_isBitcoinOrigin &&
          !_isSolanaOrigin &&
          chain.chainId == widget.blockchain.activeChain.chainId) {
        return false;
      }
      return relayIds == null || relayIds.contains(chain.chainId);
    });

    final assetChainDestinations = <EvmChain>[];
    if (widget.blockchain.activeFamily == ChainFamily.evm) {
      final activeId = widget.blockchain.activeChain.chainId;
      final seenIds = <int>{};
      for (final route in _assetChainRoutes) {
        if (route.sourceChain.chainId == activeId &&
            SwapService.isAssetChain(route.destinationChain.chainId) &&
            seenIds.add(route.destinationChain.chainId)) {
          assetChainDestinations.add(route.destinationChain);
        }
      }
      if (assetChainDestinations.isEmpty) {
        final mainnet =
            widget.blockchain.allChains
                .where((c) => c.chainId == 42420)
                .firstOrNull ??
            BlockchainCatalog.findChain(42420);
        if (mainnet != null) {
          assetChainDestinations.add(mainnet);
        }
      }
    }

    return [
      ...evmChains,
      ...assetChainDestinations,
      // Solana destination requires the wallet to have a Solana address.
      if (!_isSolanaOrigin && _solanaAddress != null) _solanaChain,
      if (!_isTronOrigin && !_isBitcoinOrigin && _tronAddress != null)
        _tronChain,
      if (!_isBitcoinOrigin &&
          !_isTronOrigin &&
          _bitcoinAllowed &&
          _bitcoinReceive != null &&
          relayIds?.contains(BridgeService.relayBitcoinChainId) == true)
        _bitcoinChain,
    ];
  }

  // ── Asset Chain Bridge helpers ──────────────────────────────────────────

  String _cleanAssetChainError(Object error) {
    if (error is AssetChainBridgeException) {
      final msg = error.message.trim();
      final lower = msg.toLowerCase();
      final code = error.errorCode?.trim().toUpperCase() ?? '';
      if (error.statusCode >= 500 ||
          code == 'INTERNAL_ERROR' ||
          lower.contains('postgres') ||
          lower.contains('password authentication') ||
          lower.contains('failed to parse upstream') ||
          lower.contains('<!doctype') ||
          lower.contains('<html') ||
          msg.isEmpty) {
        return 'Asset Chain bridge service is temporarily unavailable. Please try again later.';
      }
      return msg;
    }
    return error
        .toString()
        .replaceFirst(RegExp(r'^(Bad state: |Exception: )'), '')
        .trim();
  }

  bool _isAssetChainNativeAddress(String? address) {
    final normalized = (address ?? '').trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == '0x0000000000000000000000000000000000000000' ||
        normalized == AssetChainNativeBridgeService.nativeToken;
  }

  bool _isDisallowedAssetChainBridgeToken(
    AssetChainBridgeToken? token,
    int chainId,
  ) {
    if (token == null || !SwapService.isAssetChain(chainId)) return false;
    final addr = token.tokenAddress.trim().toLowerCase();
    final wrwa = BlockchainCatalog.wrappedNativeAddress(chainId)?.toLowerCase();
    if (_isAssetChainNativeAddress(addr) || (wrwa != null && addr == wrwa)) {
      return true;
    }
    final sym = token.symbol.trim().toUpperCase();
    return sym == 'RWA' || sym == 'WRWA';
  }

  bool _isBridgeEligibleAssetChainRoute(AssetChainNativeBridgeRoute route) =>
      !_isDisallowedAssetChainBridgeToken(
        route.source.token,
        route.sourceChain.chainId,
      ) &&
      !_isDisallowedAssetChainBridgeToken(
        route.destination.token,
        route.destinationChain.chainId,
      );

  List<AssetChainNativeBridgeRoute> _assetChainRoutesForPair(
    int originChainId,
    int destinationChainId,
  ) {
    return _assetChainRoutes
        .where(
          (route) =>
              route.sourceChain.chainId == originChainId &&
              route.destinationChain.chainId == destinationChainId,
        )
        .toList(growable: false);
  }

  bool _tokenMatchesAssetChainRoute(
    Token token,
    AssetChainNativeBridgeRoute route,
  ) {
    final srcToken = route.source.token;
    if (srcToken == null) return false;
    final tokenContract = (token.contractAddress ?? '').trim().toLowerCase();
    final tokenIsNative = _isAssetChainNativeAddress(tokenContract);
    final routeContract = srcToken.tokenAddress.trim().toLowerCase();
    final routeIsNative = _isAssetChainNativeAddress(routeContract);
    if (tokenIsNative && routeIsNative) return true;
    if (!tokenIsNative && !routeIsNative && tokenContract == routeContract) {
      return true;
    }
    return AssetChainNativeBridgeService.normalizedSymbol(token.symbol) ==
        AssetChainNativeBridgeService.normalizedSymbol(srcToken.symbol);
  }

  void _autoPairAssetChainFromTokenIfNeeded() {
    if (widget.blockchain.activeFamily != ChainFamily.evm) return;
    final toChain = _toChain;
    if (toChain == null || !_isAssetChainRoute) return;
    final routes = _assetChainRoutesForPair(
      widget.blockchain.activeChain.chainId,
      toChain.chainId,
    );
    if (routes.isEmpty) return;
    final currentFrom = _fromToken;
    if (currentFrom != null &&
        routes.any(
          (route) => _tokenMatchesAssetChainRoute(currentFrom, route),
        )) {
      return;
    }
    if (_amountValue > 0) return;
    for (final candidate in _originTokens) {
      if (routes.any(
        (route) => _tokenMatchesAssetChainRoute(candidate, route),
      )) {
        _fromToken = candidate;
        return;
      }
    }
  }

  AssetChainNativeBridgeRoute? _matchingAssetChainRoute({
    Token? fromToken,
    EvmChain? toChain,
    BridgeCurrency? toCurrency,
  }) {
    if (widget.blockchain.activeFamily != ChainFamily.evm) return null;
    final destinationChainId = (toChain ?? _toChain)?.chainId;
    if (destinationChainId == null) return null;
    final routes = _assetChainRoutesForPair(
      widget.blockchain.activeChain.chainId,
      destinationChainId,
    );
    if (routes.isEmpty) return null;

    final effectiveFrom = fromToken ?? _fromToken;
    final effectiveToCurrency = toCurrency ?? _toCurrency;

    if (effectiveFrom != null) {
      final fromContract = (effectiveFrom.contractAddress ?? '')
          .trim()
          .toLowerCase();
      final fromIsNative = _isAssetChainNativeAddress(fromContract);
      final fromSymbol = AssetChainNativeBridgeService.normalizedSymbol(
        effectiveFrom.symbol,
      );

      for (final route in routes) {
        final srcToken = route.source.token;
        if (srcToken == null) continue;
        final routeContract = srcToken.tokenAddress.trim().toLowerCase();
        if (fromIsNative && _isAssetChainNativeAddress(routeContract)) {
          return route;
        }
        if (!fromIsNative && routeContract == fromContract) {
          return route;
        }
      }
      for (final route in routes) {
        final srcToken = route.source.token;
        if (srcToken == null) continue;
        if (AssetChainNativeBridgeService.normalizedSymbol(srcToken.symbol) ==
            fromSymbol) {
          return route;
        }
      }
      return null;
    }

    if (effectiveToCurrency != null) {
      final toSymbol = AssetChainNativeBridgeService.normalizedSymbol(
        effectiveToCurrency.symbol,
      );
      for (final route in routes) {
        final dstToken = route.destination.token;
        if (dstToken == null) continue;
        if (effectiveToCurrency.isNative &&
            _isAssetChainNativeAddress(dstToken.tokenAddress)) {
          return route;
        }
        if (!effectiveToCurrency.isNative &&
            dstToken.tokenAddress.toLowerCase() ==
                effectiveToCurrency.address.toLowerCase()) {
          return route;
        }
        if (AssetChainNativeBridgeService.normalizedSymbol(dstToken.symbol) ==
            toSymbol) {
          return route;
        }
      }
    }

    return null;
  }

  BridgeCurrency? _assetChainDestinationCurrency(
    AssetChainNativeBridgeRoute route,
  ) {
    final dstToken = route.destination.token;
    if (dstToken == null) return null;
    final native = _isAssetChainNativeAddress(dstToken.tokenAddress);
    if (native) return null;
    final symbolLower = dstToken.symbol.trim().toLowerCase();
    final logoUrl = switch (symbolLower) {
      'usdt' || 'usdt0' || 'usd₮0' =>
        'https://assets.coingecko.com/coins/images/325/large/Tether.png',
      'usdc' => 'https://assets.coingecko.com/coins/images/6319/large/usdc.png',
      _ => BlockchainCatalog.defaultChainLogoUrl(
        route.destinationChain.chainId,
      ),
    };
    return BridgeCurrency(
      chainId: route.destinationChain.chainId,
      address: dstToken.tokenAddress,
      symbol: dstToken.symbol,
      name: dstToken.name,
      decimals: route.destination.tokenDecimal,
      isNative: false,
      logoUri: logoUrl,
      priceUsd:
          _fromToken != null &&
              AssetChainNativeBridgeService.normalizedSymbol(
                    _fromToken!.symbol,
                  ) ==
                  AssetChainNativeBridgeService.normalizedSymbol(
                    dstToken.symbol,
                  ) &&
              _fromToken!.priceUsd > 0
          ? _fromToken!.priceUsd
          : null,
    );
  }

  void _syncAssetChainDestinationCurrency() {
    if (!_isAssetChainRoute) return;
    final route = _matchingAssetChainRoute();
    _toCurrency = route == null ? null : _assetChainDestinationCurrency(route);
  }

  Future<void> _loadAssetChainRoutes() async {
    if (_assetChainRoutesLoading) return;
    final generation = ++_assetChainRouteGeneration;
    _assetChainRoutesLoading = true;
    try {
      final deployments = await _assetChainBridgeService.api.getBridges();
      final routes = AssetChainNativeBridgeService.routes(
        deployments,
        widget.blockchain.allChains,
      ).where(_isBridgeEligibleAssetChainRoute).toList(growable: false);
      if (!mounted || generation != _assetChainRouteGeneration) return;
      final hadNoRoutes = _assetChainRoutes.isEmpty;
      setState(() {
        _assetChainRoutes = routes;
        _assetChainRoutesError = null;
        _syncToChain();
        if (_isAssetChainRoute) {
          _autoPairAssetChainFromTokenIfNeeded();
          _syncAssetChainDestinationCurrency();
        }
      });
      if (_isAssetChainRoute) {
        unawaited(_loadAssetChainTransfers());
        if (hadNoRoutes && _amountValue > 0) {
          _requestQuote();
        }
      }
    } catch (error) {
      if (!mounted || generation != _assetChainRouteGeneration) return;
      setState(() {
        _assetChainRoutesError = _cleanAssetChainError(error);
      });
    } finally {
      _assetChainRoutesLoading = false;
    }
  }

  Future<void> _loadAssetChainTransfers() async {
    final wallet = widget.walletAddress?.trim();
    if (wallet == null || wallet.isEmpty) {
      if (mounted &&
          (_assetChainTransfers.isNotEmpty || _assetChainPending.isNotEmpty)) {
        setState(() {
          _assetChainTransfers = const [];
          _assetChainPending = const [];
        });
      }
      return;
    }
    if (mounted) {
      setState(() => _isRefreshingAssetChain = true);
    }
    try {
      final pending = await _assetChainBridgeService.pending(wallet);
      List<AssetChainBridgeTransaction> claimable = const [];
      if (_isAssetChainRoute ||
          _assetChainRoutes.isNotEmpty ||
          pending.isNotEmpty) {
        final history = await _assetChainBridgeService.api.getTransactions(
          userAddress: wallet,
          forceSync: true,
          limit: 50,
        );
        final lowerWallet = wallet.toLowerCase();
        claimable = history.items
            .where(
              (tx) =>
                  !tx.fulfilled &&
                  tx.fromUser.toLowerCase() == lowerWallet &&
                  tx.toUser.toLowerCase() == lowerWallet,
            )
            .toList(growable: false);
      }
      if (!mounted) return;
      setState(() {
        _assetChainPending = pending;
        _assetChainTransfers = claimable;
      });
    } catch (_) {
      // Non-fatal: bridge quotes and standard Relay flows still operate.
    } finally {
      if (mounted) {
        setState(() => _isRefreshingAssetChain = false);
      }
    }
  }

  AssetChainNativeBridgeRoute? _claimRouteForAssetChain(
    AssetChainBridgeTransaction transfer,
  ) {
    final matches = _assetChainRoutes
        .where(
          (route) =>
              route.source.chainId ==
                  transfer.fromChain.replaceFirst('evm.', '') &&
              route.destination.chainId ==
                  transfer.toChain.replaceFirst('evm.', '') &&
              AssetChainNativeBridgeService.normalizedSymbol(route.symbol) ==
                  AssetChainNativeBridgeService.normalizedSymbol(
                    transfer.symbol,
                  ) &&
              (transfer.bridgeInfoId == null ||
                  transfer.bridgeInfoId == route.source.id),
        )
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  // ── Quote handling ──────────────────────────────────────────────────────

  void _resetQuote() {
    _quote = null;
    _assetChainQuote = null;
    _quoteError = null;
  }

  void _onAmountChanged(String _) {
    _selectedPercentage = -1;
    _requestQuote();
  }

  void _requestQuote() {
    _debounce?.cancel();
    if (_isBitcoinOrigin) {
      _quoteSeq++;
      _quote = null;
    }
    if (_isAssetChainRoute) {
      _quoteSeq++;
      _assetChainQuote = null;
    }
    _debounce = Timer(const Duration(milliseconds: 600), _fetchQuote);
    setState(() {});
  }

  double get _amountValue =>
      double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

  Future<void> _fetchAssetChainQuote() async {
    final from = _fromToken;
    final toChain = _toChain;
    if (from == null || toChain == null) return;

    final amountText = _amountController.text.replaceAll(',', '').trim();
    if (amountText.isEmpty || _amountValue <= 0) {
      if (mounted) setState(_resetQuote);
      return;
    }

    final seq = ++_quoteSeq;
    setState(() {
      _isQuoting = true;
      _quote = null;
      _assetChainQuote = null;
      _quoteError = null;
    });

    if (_assetChainRoutes.isEmpty) {
      await _loadAssetChainRoutes();
    }
    if (!mounted || seq != _quoteSeq) return;

    final route = _matchingAssetChainRoute(fromToken: from, toChain: toChain);
    if (route == null) {
      final pairRoutes = _assetChainRoutesForPair(
        widget.blockchain.activeChain.chainId,
        toChain.chainId,
      );
      final supportedSymbols = pairRoutes.map((r) => r.symbol).toSet().toList();
      final String message;
      if (_assetChainRoutes.isEmpty && _assetChainRoutesError != null) {
        message =
            'Unable to load Asset Chain bridge routes: $_assetChainRoutesError';
      } else if (supportedSymbols.isNotEmpty) {
        message =
            'Asset Chain bridge supports ${supportedSymbols.join(', ')} between ${widget.blockchain.activeChain.name} and ${toChain.name}. Select a supported token.';
      } else {
        message =
            'No Asset Chain bridge route is configured between ${widget.blockchain.activeChain.name} and ${toChain.name}.';
      }
      setState(() {
        _isQuoting = false;
        _assetChainQuote = null;
        _quoteError = message;
      });
      return;
    }

    try {
      final amountUsd = _amountValue > 0 && from.priceUsd > 0
          ? _amountValue * from.priceUsd
          : null;
      final nativeQuote = await _assetChainBridgeService.quote(
        route,
        amountText,
        amountUsd: amountUsd,
      );
      if (!mounted || seq != _quoteSeq) return;
      setState(() {
        _isQuoting = false;
        _quote = null;
        _assetChainQuote = nativeQuote;
        _toCurrency = _assetChainDestinationCurrency(route);
        _quoteError = null;
      });
    } catch (error) {
      if (!mounted || seq != _quoteSeq) return;
      setState(() {
        _isQuoting = false;
        _assetChainQuote = null;
        _quoteError = _cleanAssetChainError(error);
      });
    }
  }

  Future<void> _fetchQuote() async {
    if (_isAssetChainRoute) {
      await _fetchAssetChainQuote();
      return;
    }
    final from = _fromToken;
    final toChain = _toChain;
    final wallet = widget.walletAddress;
    if (from == null || toChain == null || wallet == null || wallet.isEmpty) {
      return;
    }
    if (_isBitcoinOrigin &&
        (!_bitcoinAllowed ||
            widget.blockchain.activeNetworkKey != 'bitcoin:mainnet' ||
            _bitcoinReceive == null)) {
      if (mounted) {
        setState(() {
          _resetQuote();
          _quoteError =
              'Bitcoin bridges require an available Mainnet seed account.';
        });
      }
      return;
    }
    if (_isTronOrigin && widget.blockchain.activeNetworkKey != 'tron:mainnet') {
      setState(() {
        _resetQuote();
        _quoteError =
            'TRON bridges use Mainnet assets. Switch from Nile to TRON Mainnet to bridge.';
      });
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
    final isTronOrigin = _isTronOrigin;
    final originChainId = _isBitcoinOrigin
        ? BridgeService.relayBitcoinChainId
        : isSolanaOrigin
        ? BridgeService.relaySolanaChainId
        : isTronOrigin
        ? BridgeService.tronBridgeChainId
        : widget.blockchain.activeChain.chainId;

    // User-added custom networks aren't necessarily on Relay — fail with a
    // clear message before the upstream request can produce a cryptic error.
    final relayIds = _relayChainIds;
    if (!isSolanaOrigin &&
        !isTronOrigin &&
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
    final isTronDestination = toChain.family == ChainFamily.tron;
    final recipient = toChain.family == ChainFamily.bitcoin
        ? _bitcoinReceive?.address
        : isSolanaDestination
        ? _solanaAddress
        : isTronDestination
        ? _tronAddress
        : (isSolanaOrigin || isTronOrigin || _isBitcoinOrigin
              ? _evmAddress
              : wallet);
    if (recipient == null || recipient.isEmpty) {
      setState(() {
        _resetQuote();
        _quoteError = isSolanaDestination
            ? 'This wallet has no Solana address to receive the bridged funds.'
            : isTronDestination
            ? 'This wallet has no TRON address to receive the bridged funds.'
            : 'This wallet has no EVM address to receive the bridged funds.';
      });
      return;
    }

    final originCurrency = _isBitcoinOrigin
        ? BridgeService.bitcoinNativeCurrency
        : isSolanaOrigin
        ? (from.contractAddress?.isNotEmpty == true
              ? from.contractAddress!
              : BridgeService.solanaNativeCurrency)
        : isTronOrigin
        ? (from.contractAddress?.isNotEmpty == true
              ? from.contractAddress!
              : BridgeService.tronNativeCurrency)
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
        (toChain.family == ChainFamily.bitcoin
            ? BridgeService.bitcoinNativeCurrency
            : isSolanaDestination
            ? BridgeService.solanaNativeCurrency
            : isTronDestination
            ? BridgeService.tronNativeCurrency
            : BridgeService.nativeCurrency);

    final quote = await _bridgeService.getQuote(
      originChainId: originChainId,
      destinationChainId: toChain.chainId,
      originCurrency: originCurrency,
      destinationCurrency: destinationCurrency,
      amountWei: amountWei,
      walletAddress: _isBitcoinOrigin ? _bitcoinReceive!.address : wallet,
      recipientAddress: recipient,
      amountUsd: from.priceUsd > 0 ? _amountValue * from.priceUsd : null,
      slippageBps: _slippageBps,
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
    if (_isBitcoinOrigin) {
      unawaited(_setBitcoinPercentage(percent));
      return;
    }
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

  Future<void> _setBitcoinPercentage(int percent) async {
    if (_isBridging ||
        _isQuoting ||
        _bitcoinHasPending ||
        percent <= 0 ||
        percent > 100) {
      return;
    }
    final identity = widget.blockchain.activeWalletAddress.trim().toLowerCase();
    final preview = _quote?.bitcoinQuote;
    if (percent == 100 && preview == null) {
      ToastUtils.showInfo(
        'Enter an amount to find a bridge route before using Max.',
      );
      return;
    }
    final originalText = _amountController.text;
    final sequence = _quoteSeq;
    final destination = _toChain?.chainId;
    bool current() =>
        mounted &&
        _isBitcoinOrigin &&
        _bitcoinAllowed &&
        widget.blockchain.activeNetworkKey == 'bitcoin:mainnet' &&
        widget.blockchain.activeWalletAddress.trim().toLowerCase() ==
            identity &&
        _quoteSeq == sequence &&
        _amountController.text == originalText &&
        _toChain?.chainId == destination;
    if (!current()) return;
    setState(() => _isQuoting = true);
    var changed = false;
    try {
      BigInt amount;
      if (percent == 100) {
        final request = preview!.request;
        final committed = await _bridgeService.commitQuote(
          originChainId: request.originChainId,
          destinationChainId: request.destinationChainId,
          originCurrency: request.originCurrency,
          destinationCurrency: request.destinationCurrency,
          amountWei: request.amount.toString(),
          walletAddress: request.sender,
          recipientAddress: request.recipient,
          slippageBps: _slippageBps,
        );
        if (!current() || committed?.bitcoinQuote?.depositAddress == null) {
          return;
        }
        // Rust calculates the maximum against an actual provider destination;
        // no percentage gas buffer or transaction-weight formula lives here.
        amount = await _bitcoinFunding.planner.maximumAmount(
          identity,
          BitcoinProductNetwork.mainnet,
          committed!.bitcoinQuote!.depositAddress!,
          isCurrent: current,
        );
      } else {
        final snapshot = await _bitcoinFunding.planner.wallet.refresh(
          identity,
          BitcoinProductNetwork.mainnet,
          isCurrent: current,
        );
        amount =
            snapshot.spendableSats * BigInt.from(percent) ~/ BigInt.from(100);
      }
      if (!current() || amount <= BigInt.zero) return;
      setState(() {
        _selectedPercentage = percent;
        _amountController.text = BitcoinAmountUtils.format(amount);
      });
      changed = true;
    } catch (_) {
      if (mounted) {
        ToastUtils.showInfo(
          'Unable to calculate the Bitcoin amount. Refresh the bridge route.',
        );
      }
    } finally {
      if (mounted && _quoteSeq == sequence) setState(() => _isQuoting = false);
      if (mounted && changed) _requestQuote();
    }
  }

  Future<void> _selectFromToken() async {
    final candidates = _originTokens;
    if (candidates.isEmpty) {
      ToastUtils.showInfo(
        _isAssetChainOrigin
            ? 'No bridgeable tokens available on ${widget.blockchain.activeChain.name}. RWA and WRWA cannot be bridged.'
            : 'No bridgeable tokens available on this network.',
      );
      return;
    }
    final selected = await showDialog<Object?>(
      context: context,
      builder: (ctx) => buildBridgeOriginTokenDialog(
        tokens: candidates,
        chainId: widget.blockchain.activeTokenStorageChainId,
        activeNetworkKey: widget.blockchain.activeNetworkKey,
        activeFamily: widget.blockchain.activeFamily,
        nativeSymbol: widget.blockchain.activeNetworkSymbol,
      ),
    );
    if (!mounted || selected == null) return;
    if (selected is Token) {
      setState(() {
        _fromToken = selected;
        _selectedPercentage = -1;
        _resetQuote();
        if (_isAssetChainRoute) {
          _syncAssetChainDestinationCurrency();
        }
      });
      _requestQuote();
    }
  }

  Future<void> _selectToChain() async {
    final chains = _destinationChains();
    final selected = await showModalBottomSheet<EvmChain>(
      context: context,
      isScrollControlled: true,
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
        if (_isAssetChainRoute) {
          _autoPairAssetChainFromTokenIfNeeded();
          _syncAssetChainDestinationCurrency();
        }
      });
      if (_isAssetChainRoute) {
        unawaited(_loadAssetChainTransfers());
      }
      _requestQuote();
    }
  }

  /// Pick the destination token (Relay-supported tokens for Relay routes, or
  /// configured BridgeAssist tokens when bridging to/from Asset Chain).
  Future<void> _selectToCurrency() async {
    final toChain = _toChain;
    if (toChain == null) return;
    if (toChain.family == ChainFamily.bitcoin) return;

    if (_isAssetChainRoute) {
      if (_assetChainRoutes.isEmpty) {
        await _loadAssetChainRoutes();
        if (!mounted) return;
      }
      final routes = _assetChainRoutesForPair(
        widget.blockchain.activeChain.chainId,
        toChain.chainId,
      );
      final seenKeys = <String>{};
      final options = <BridgeCurrency>[];
      for (final route in routes) {
        final dst = route.destination.token;
        if (dst == null) continue;
        final isNative = _isAssetChainNativeAddress(dst.tokenAddress);
        final key =
            '${dst.symbol.toUpperCase()}:${dst.tokenAddress.toLowerCase()}';
        if (!seenKeys.add(key)) continue;
        options.add(
          BridgeCurrency(
            chainId: toChain.chainId,
            address: isNative ? BridgeService.nativeCurrency : dst.tokenAddress,
            symbol: dst.symbol,
            name: dst.name,
            decimals: route.destination.tokenDecimal,
            isNative: isNative,
            logoUri: _assetChainDestinationCurrency(route)?.logoUri,
          ),
        );
      }
      final selected = await showModalBottomSheet<BridgeCurrency>(
        context: context,
        backgroundColor: const Color(0xFF0E0E0E),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => _AssetChainCurrencyPickerSheet(
          chainName: toChain.name,
          chainId: toChain.chainId,
          currencies: options,
        ),
      );
      if (selected != null && mounted) {
        setState(() {
          _toCurrency = selected.isNative ? null : selected;
          final matchedRoute = _matchingAssetChainRoute(
            toChain: toChain,
            toCurrency: selected,
          );
          if (matchedRoute != null) {
            for (final candidate in _originTokens) {
              if (_tokenMatchesAssetChainRoute(candidate, matchedRoute)) {
                _fromToken = candidate;
                break;
              }
            }
          }
          _resetQuote();
        });
        _requestQuote();
      }
      return;
    }

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
    if (toChain.family == ChainFamily.bitcoin) {
      if (!_bitcoinAllowed || _bitcoinReceive == null) return;
      final oldOrigin = _isSolanaOrigin
          ? _solanaChain
          : widget.blockchain.activeChain;
      widget.blockchain.setActiveNetworkKey(NetworkKey.bitcoin('mainnet'));
      _afterFlip(oldOrigin);
      return;
    }
    if (_isBitcoinOrigin) {
      if (toChain.family == ChainFamily.solana) {
        widget.blockchain.setActiveNetworkKey(NetworkKey.solana('mainnet'));
      } else if (toChain.family == ChainFamily.evm) {
        widget.blockchain.setActiveChainByChainId(toChain.chainId);
      } else {
        return;
      }
      _afterFlip(_bitcoinChain);
      return;
    }

    if (_isSolanaOrigin && toChain.family == ChainFamily.evm) {
      // Solana → EVM becomes EVM → Solana.
      widget.blockchain.setActiveChainByChainId(toChain.chainId);
      _afterFlip(_solanaChain);
      return;
    }
    if (_isTronOrigin && toChain.family == ChainFamily.evm) {
      widget.blockchain.setActiveChainByChainId(toChain.chainId);
      _afterFlip(_tronChain);
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
    if (toChain.family == ChainFamily.tron) {
      if (_tronAddress == null) {
        ToastUtils.showInfo('This wallet has no TRON address.');
        return;
      }
      final oldOrigin = _isSolanaOrigin
          ? _solanaChain
          : widget.blockchain.activeChain;
      widget.blockchain.setActiveNetworkKey(NetworkKey.tron('mainnet'));
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
      if (_isAssetChainRoute) {
        _syncFromToken();
        _autoPairAssetChainFromTokenIfNeeded();
        _syncAssetChainDestinationCurrency();
      }
    });
    if (_isAssetChainRoute && _assetChainRoutes.isEmpty) {
      unawaited(_loadAssetChainRoutes());
    }
    if (_isAssetChainRoute) {
      unawaited(_loadAssetChainTransfers());
    }
  }

  // ── Execution ───────────────────────────────────────────────────────────

  bool get _hasSufficientBalance {
    final token = _fromToken;
    if (token == null) return false;
    if (_isBitcoinOrigin) {
      try {
        final amount = AmountUtils.parseDecimalToBaseUnits(
          _amountController.text.replaceAll(',', ''),
          8,
        );
        final snapshot = _bitcoinFunding.planner.wallet.cached(
          widget.blockchain.activeWalletAddress,
          BitcoinProductNetwork.mainnet,
        );
        return !_bitcoinBalanceLoading &&
            bitcoinBridgeHasFunds(snapshot, amount);
      } catch (_) {
        return false;
      }
    }
    return _amountValue > 0 && _amountValue <= token.balance;
  }

  String get _bitcoinBalanceText {
    final snapshot = _bitcoinFunding.planner.wallet.cached(
      widget.blockchain.activeWalletAddress,
      BitcoinProductNetwork.mainnet,
    );
    return snapshot == null
        ? '— BTC'
        : '${BitcoinAmountUtils.format(snapshot.totalSats)} BTC';
  }

  String? get _buttonLabel {
    if (_isBridging) return 'Bridging...';
    if (_bridgeActionActive) return 'Preparing bridge...';
    if (_isAssetChainRoute && _assetChainPending.isNotEmpty) {
      return 'Check pending transfer';
    }
    if (_isBitcoinOrigin && _bitcoinBalanceLoading) {
      return 'Checking BTC balance…';
    }
    if (_isBitcoinOrigin && !_bitcoinRecoveryLoaded) {
      return 'BTC balance unavailable';
    }
    if (_amountValue > 0 && !_hasSufficientBalance) {
      return 'Insufficient ${_fromToken?.symbol ?? 'balance'}';
    }
    if (!_isAssetChainRoute &&
        _toCurrency != null &&
        _bridgeCurrencyBlocked(_toCurrency!)) {
      return 'Unverified token blocked';
    }
    return 'Bridge';
  }

  bool get _canBridge {
    if (_bridgeActionActive || _isBridging || _isQuoting) return false;
    if (widget.walletAddress == null || widget.walletAddress!.isEmpty) {
      return false;
    }
    if (_isAssetChainRoute) {
      return _assetChainPending.isEmpty &&
          _assetChainQuote != null &&
          _hasSufficientBalance;
    }
    return _pendingOperation == null &&
        !_bitcoinHasPending &&
        (_toChain?.family != ChainFamily.bitcoin || _bitcoinAllowed) &&
        (!_isBitcoinOrigin ||
            _bitcoinRecoveryLoaded &&
                _bitcoinAllowed &&
                widget.blockchain.activeNetworkKey == 'bitcoin:mainnet') &&
        _quote != null &&
        _hasSufficientBalance &&
        (_toCurrency == null || !_bridgeCurrencyBlocked(_toCurrency!)) &&
        _quote!.canBeginExecution;
  }

  bool _bitcoinDestinationCurrent(BridgeQuote quote) {
    final bitcoin = quote.bitcoinQuote;
    if (bitcoin == null) return true;
    final from = _fromToken;
    if (from == null || from.decimals != bitcoin.originDecimals) return false;
    final currency = from.contractAddress?.isNotEmpty == true
        ? from.contractAddress!
        : _isSolanaOrigin
        ? BridgeService.solanaNativeCurrency
        : BridgeService.nativeCurrency;
    if (_isSolanaOrigin
        ? currency != bitcoin.request.originCurrency
        : currency.toLowerCase() !=
              bitcoin.request.originCurrency.toLowerCase()) {
      return false;
    }
    try {
      if (AmountUtils.parseDecimalToBaseUnits(
            _amountController.text.replaceAll(',', ''),
            from.decimals,
          ) !=
          bitcoin.request.amount) {
        return false;
      }
    } catch (_) {
      return false;
    }
    if (!_bitcoinAllowed ||
        bitcoin.request.bitcoinOrigin ||
        !bitcoin.committed ||
        !DateTime.now().isBefore(bitcoin.approvalExpiresAt) ||
        _toChain?.chainId != bitcoin.request.destinationChainId ||
        _bitcoinReceive?.address != bitcoin.request.recipient) {
      return false;
    }
    if (_isSolanaOrigin) {
      return widget.blockchain.activeNetworkKey == 'solana:mainnet' &&
          widget.walletAddress == bitcoin.request.sender;
    }
    return widget.blockchain.activeFamily == ChainFamily.evm &&
        widget.blockchain.activeChain.chainId ==
            bitcoin.request.originChainId &&
        widget.walletAddress?.toLowerCase() ==
            bitcoin.request.sender.toLowerCase();
  }

  Future<bool> _confirmBitcoinDestination(BridgeQuote quote) async {
    final bitcoin = quote.bitcoinQuote;
    if (bitcoin == null) return true;
    if (!_bitcoinDestinationCurrent(quote)) return false;
    final from = _fromToken!;
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101010),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Confirm bridge',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${AmountUtils.formatBaseUnits(BigInt.parse(quote.amountIn), from.decimals, maxFractionDigits: from.decimals)} ${from.symbol}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Minimum received on Bitcoin Mainnet',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                '${BitcoinAmountUtils.format(bitcoin.minimumAmountOut)} BTC',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 16),
              const Text(
                'Receive address',
                style: TextStyle(color: Colors.white70),
              ),
              SelectableText(
                bitcoin.request.recipient,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'Refund address on the origin network',
                style: TextStyle(color: Colors.white70),
              ),
              SelectableText(
                bitcoin.request.sender,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'Provider: Relay · Approve before ${TimeOfDay.fromDateTime(bitcoin.approvalExpiresAt.toLocal()).format(sheet)}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              const Text(
                'Origin submission and Bitcoin delivery are tracked separately.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(sheet, true),
                child: const Text('Confirm bridge'),
              ),
            ],
          ),
        ),
      ),
    );
    return accepted == true && mounted && _bitcoinDestinationCurrent(quote);
  }

  Future<void> _executeBridge() async {
    if (!_canBridge) return;
    setState(() {
      _bridgeActionActive = true;
      _isBridging = true;
    });
    try {
      await _prepareAndExecuteBridge();
    } finally {
      if (mounted) {
        setState(() {
          _isBridging = false;
          _bridgeActionActive = false;
        });
      }
    }
  }

  Future<void> _prepareAndExecuteBridge() async {
    if (_isAssetChainRoute) {
      final approved = _assetChainQuote;
      if (approved != null) {
        await _executeAssetChainBridge(approved);
      }
      return;
    }
    var quote = _quote;
    final from = _fromToken;
    if (quote == null || from == null || _pendingOperation != null) {
      return;
    }
    if (quote.bitcoinQuote != null && !_bitcoinAllowed) {
      setState(
        () => _quoteError = 'Bitcoin bridging is unavailable right now.',
      );
      return;
    }
    if (_toCurrency != null && _bridgeCurrencyBlocked(_toCurrency!)) {
      setState(() {
        _quoteError =
            'This destination token is not verified. Select a verified token and check its contract address.';
      });
      return;
    }
    if (_isBitcoinOrigin) {
      await _executeBitcoinBridge(quote);
      return;
    }

    final approvalNetwork = widget.blockchain.activeNetworkKey;
    final approvalWallet = widget.walletAddress;
    final approvalIdentity = widget.blockchain.activeWalletAddress;
    final approvalAmount = _amountController.text;
    final approvalDestination = _toChain;
    final approvalCurrency = _toCurrency;
    final approvalSlippage = _slippageBps;
    bool approvalCurrent() =>
        mounted &&
        widget.blockchain.activeNetworkKey == approvalNetwork &&
        widget.walletAddress == approvalWallet &&
        widget.blockchain.activeWalletAddress == approvalIdentity &&
        _amountController.text == approvalAmount &&
        _slippageBps == approvalSlippage &&
        identical(_fromToken, from) &&
        identical(_toChain, approvalDestination) &&
        identical(_toCurrency, approvalCurrency) &&
        RuntimeConfigService.instance.snapshot.allows(RuntimeFeature.bridges);

    // A NEAR Intents preview is deliberately dry. Commit immediately before
    // signing so the one-time deposit address and deadline are fresh.
    if (!quote.committed) {
      final toChain = _toChain;
      final wallet = widget.walletAddress;
      if (toChain == null || wallet == null || wallet.isEmpty) return;
      final isSolanaDestination = toChain.family == ChainFamily.solana;
      final isTronDestination = toChain.family == ChainFamily.tron;
      final recipient = toChain.family == ChainFamily.bitcoin
          ? _bitcoinReceive?.address
          : isSolanaDestination
          ? _solanaAddress
          : isTronDestination
          ? _tronAddress
          : (_isSolanaOrigin || _isTronOrigin ? _evmAddress : wallet);
      if (recipient == null || recipient.isEmpty) return;
      final originCurrency = _isSolanaOrigin
          ? (from.contractAddress?.isNotEmpty == true
                ? from.contractAddress!
                : BridgeService.solanaNativeCurrency)
          : _isTronOrigin
          ? (from.contractAddress?.isNotEmpty == true
                ? from.contractAddress!
                : BridgeService.tronNativeCurrency)
          : (from.contractAddress ?? '');
      final destinationCurrency =
          _toCurrency?.address ??
          (toChain.family == ChainFamily.bitcoin
              ? BridgeService.bitcoinNativeCurrency
              : isSolanaDestination
              ? BridgeService.solanaNativeCurrency
              : isTronDestination
              ? BridgeService.tronNativeCurrency
              : BridgeService.nativeCurrency);
      setState(() => _isBridging = true);
      final committed = await _bridgeService.commitQuote(
        originChainId: quote.originChainId,
        destinationChainId: quote.destinationChainId,
        originCurrency: originCurrency,
        destinationCurrency: destinationCurrency,
        amountWei: quote.amountIn,
        walletAddress: wallet,
        recipientAddress: recipient,
        amountUsd: from.priceUsd > 0 ? _amountValue * from.priceUsd : null,
        slippageBps: _slippageBps,
      );
      if (!approvalCurrent()) return;
      if (committed == null ||
          !committed.committed ||
          committed.steps.isEmpty) {
        setState(() {
          _isBridging = false;
          _quoteError =
              _bridgeService.lastError ??
              'Unable to prepare this bridge safely. Refresh and try again.';
        });
        return;
      }
      if (!committedBridgeQuoteIsFresh(committed, now: DateTime.now())) {
        setState(() {
          _isBridging = false;
          _quoteError =
              'The bridge quote expired before signing. Refresh and try again.';
        });
        return;
      }
      quote = committed;
      setState(() {
        _quote = committed;
        _isBridging = false;
      });
    }

    if (!await _confirmBitcoinDestination(quote)) return;
    if (!mounted || !approvalCurrent()) return;

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
        .where((step) => !step.isSolana && !step.isTron)
        .fold<BigInt>(BigInt.zero, (sum, step) => sum + step.value);
    if (isNative ? totalValue > amountIn : totalValue > BigInt.zero) {
      setState(() {
        _quoteError =
            'Bridge transaction values do not match the quote. Aborting for your safety; please refresh the quote.';
      });
      return;
    }

    setState(() => _isBridging = true);
    var authenticated = false;
    try {
      authenticated =
          await SensitiveAccessGuard.verify(
            context,
            reason: 'Authenticate to confirm this bridge.',
            requireTwoFactor: false,
          ) &&
          approvalCurrent() &&
          committedBridgeQuoteIsFresh(quote, now: DateTime.now());
    } catch (_) {
      if (mounted) {
        setState(
          () => _quoteError = 'Unable to unlock this wallet. Please try again.',
        );
      }
    } finally {
      if (!authenticated && mounted) setState(() => _isBridging = false);
    }
    if (!authenticated || !mounted) return;
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

    EvmSigningAccount? evmAccount;
    EvmChain? latestEvmChain;
    try {
      String? firstTxHash;
      String? latestTxHash;

      for (var stepIndex = 0; stepIndex < quote.steps.length; stepIndex++) {
        if (!_bitcoinDestinationCurrent(quote)) {
          controller.setError(
            'The Bitcoin bridge quote expired or the wallet changed. Refresh before continuing.',
          );
          return;
        }
        final step = quote.steps[stepIndex];
        final isFinalStep = stepIndex == quote.steps.length - 1;
        if (step.isSolanaTransfer) {
          latestEvmChain = null;
          final signature = await widget.walletService.sendSolanaTransaction(
            fromAddress: widget.walletAddress!,
            toAddress: step.solanaTransferTo!,
            amountLamports: step.solanaTransferAmount!,
            tokenMint: step.solanaTokenMint,
          );
          firstTxHash ??= signature;
          latestTxHash = signature;
          if (isFinalStep && quote.requestId.isNotEmpty) {
            await _persistPendingBridge(quote, signature);
          }
          controller.setSwapPending(reference: shortHash(signature));
          continue;
        }
        if (step.isTron) {
          latestEvmChain = null;
          final raw = jsonDecode(step.tronTransactionJson!);
          if (raw is! Map) {
            controller.setError(
              'The TRON bridge transaction could not be prepared.',
            );
            return;
          }
          final transaction = Map<String, dynamic>.from(raw);
          if (transaction['raw_data_hex'] == null &&
              transaction['rawDataHex'] == null) {
            controller.setError(
              'The TRON bridge transaction could not be prepared.',
            );
            return;
          }
          final signed = await widget.walletService.signTronTransactionRaw(
            widget.walletAddress!,
            transaction,
          );
          final hash = await _tronSwapService.broadcastSignedTx(
            signed,
            networkKey: widget.blockchain.activeNetworkKey,
          );
          if (hash == null || hash.isEmpty) {
            controller.setError(
              _tronSwapService.lastError ??
                  'Unable to broadcast the TRON bridge deposit.',
            );
            return;
          }
          firstTxHash ??= hash;
          latestTxHash = hash;
          if (isFinalStep && quote.requestId.isNotEmpty) {
            await _persistPendingBridge(quote, hash);
          }
          controller.setSwapPending(reference: shortHash(hash));
          final confirmation = await _transactionMonitor.waitForConfirmation(
            txHash: hash,
            blockchain: widget.blockchain,
            networkKey: widget.blockchain.activeNetworkKey,
          );
          if (confirmation == TransactionConfirmationStatus.failed) {
            if (isFinalStep) {
              await _bridgeOperationStore.clear(widget.walletAddress!);
              if (mounted) setState(() => _pendingOperation = null);
            }
            controller.setError('The TRON bridge deposit failed on-chain.');
            return;
          }
          if (confirmation == TransactionConfirmationStatus.pending) {
            _schedulePendingObservation();
            controller.setSubmitted(
              reference: shortHash(hash),
              detailsUrl: _originExplorerTxUrl(hash),
            );
            ToastUtils.showInfo(
              'Your TRON bridge is still processing. You can close this screen and track it in Activity.',
            );
            return;
          }
          continue;
        }

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
          latestTxHash = signature;
          if (isFinalStep && quote.requestId.isNotEmpty) {
            await _persistPendingBridge(quote, signature);
          }
          controller.setSwapPending(reference: shortHash(signature));
          continue;
        }

        final matchingChains = widget.blockchain.allChains.where(
          (chain) => chain.chainId == step.chainId,
        );
        if (matchingChains.isEmpty) {
          controller.setError(
            'This transaction network is not supported (${step.chainId}). The transaction was not sent.',
          );
          return;
        }
        final chain = matchingChains.first;
        latestEvmChain = chain;
        final account = evmAccount ??= await widget.walletService
            .getEvmSigningAccount();
        final client = Web3Client(chain.rpcUrl, _httpClientService.client);
        final tx = await EvmBridgeTransactionService.prepare(
          client: client,
          sender: account.address,
          step: step,
          nativeSymbol: chain.symbol,
        );
        final txHash = await EvmTransactionService.broadcastLegacy(
          client: client,
          account: account,
          chainId: step.chainId,
          to: tx.to!,
          data: tx.data,
          valueWei: tx.value!.getInWei,
          gasPriceWei: tx.gasPrice!.getInWei,
          gasLimit: tx.maxGas!,
        );
        firstTxHash ??= txHash;
        latestTxHash = txHash;
        if (isFinalStep && quote.requestId.isNotEmpty) {
          await _persistPendingBridge(quote, txHash);
        }
        controller.setSwapPending(reference: shortHash(txHash));

        // Relay may return an approval followed by a deposit. Waiting for each
        // transaction prevents the next step's gas estimation from running
        // against stale allowance state and also stops on an on-chain revert.
        final confirmation = await _transactionMonitor.waitForConfirmation(
          txHash: txHash,
          blockchain: widget.blockchain,
          evmChain: chain,
        );
        if (confirmation == TransactionConfirmationStatus.failed) {
          if (isFinalStep) {
            await _bridgeOperationStore.clear(widget.walletAddress!);
            if (mounted) setState(() => _pendingOperation = null);
          }
          controller.setError(
            'A bridge transaction was confirmed as failed by the network.',
          );
          return;
        }
        if (confirmation == TransactionConfirmationStatus.pending) {
          _schedulePendingObservation();
          controller.setSubmitted(
            reference: shortHash(txHash),
            detailsUrl: _originExplorerTxUrl(txHash, evmChain: chain),
          );
          ToastUtils.showInfo(
            'Your bridge is still processing. You can close this screen and track it in Activity.',
          );
          return;
        }
      }

      if (latestTxHash != null && quote.requestId.isNotEmpty) {
        await _persistPendingBridge(quote, latestTxHash);
      }

      if (quote.requestId.startsWith('near:') && latestTxHash != null) {
        final submitted = await _bridgeService.submitNearDeposit(
          requestId: quote.requestId,
          txHash: latestTxHash,
        );
        if (!submitted) {
          controller.setError(
            'Your origin deposit was confirmed, but Owllet could not continue delivery. Do not submit it again; check this transfer later.',
          );
          return;
        }
      }

      // Poll briefly after the origin deposit lands, then hand long-running
      // settlement (such as Bitcoin confirmations) off to background tracking
      // so the fullscreen spinner does not remain stuck indefinitely.
      if (quote.requestId.isNotEmpty) {
        var bridgeCompleted = false;
        final pollAttempts = bridgeStatusPollAttempts(quote);
        for (var attempt = 0; attempt < pollAttempts; attempt++) {
          if (attempt > 0) {
            await Future<void>.delayed(const Duration(seconds: 3));
          }
          final status = await _bridgeService.getStatus(
            requestId: quote.requestId,
          );
          if (status == null) continue;
          if (status.isFailure) {
            await _bridgeOperationStore.clear(widget.walletAddress!);
            if (mounted) setState(() => _pendingOperation = null);
            controller.setError(status.userFacingFailureMessage);
            return;
          }
          if (status.isSuccess) {
            final completedOperation = _pendingOperation;
            if (completedOperation != null) {
              _scheduleCompletedBridgeRecording(completedOperation);
            }
            await _bridgeOperationStore.clear(widget.walletAddress!);
            if (mounted) setState(() => _pendingOperation = null);
            bridgeCompleted = true;
            break;
          }
        }
        if (!bridgeCompleted) {
          _schedulePendingObservation();
          controller.setSubmitted(
            reference: latestTxHash == null ? '' : shortHash(latestTxHash),
            detailsUrl: _originExplorerTxUrl(
              latestTxHash,
              evmChain: latestEvmChain,
            ),
          );
          ToastUtils.showInfo(
            'Origin deposit confirmed. Settlement is in progress — track it in Activity.',
          );
          return;
        }
      }

      controller.setSuccess(
        reference: firstTxHash != null ? shortHash(firstTxHash) : null,
        detailsUrl: _originExplorerTxUrl(
          latestTxHash,
          evmChain: latestEvmChain,
        ),
      );

      // The bridge changes the origin balance immediately. Notify the owning
      // swap screen so it can bypass token caches now and perform its existing
      // delayed follow-up refresh while the destination settlement propagates.
      try {
        await widget.onBridgeCompleted?.call();
      } catch (error) {
        debugPrint('Post-bridge wallet refresh failed: $error');
      }

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
      await evmAccount?.close();
      if (mounted) {
        setState(() => _isBridging = false);
      }
    }
  }

  Future<void> _executeBitcoinBridge(BridgeQuote preview) async {
    final identity = widget.blockchain.activeWalletAddress.trim().toLowerCase();
    final refund = _bitcoinReceive;
    final request = preview.bitcoinQuote?.request;
    final text = _amountController.text;
    final destinationCurrency = _toCurrency?.address;
    bool current() =>
        mounted &&
        _bitcoinAllowed &&
        _isBitcoinOrigin &&
        widget.blockchain.activeNetworkKey == 'bitcoin:mainnet' &&
        widget.blockchain.activeWalletAddress.trim().toLowerCase() ==
            identity &&
        _amountController.text == text &&
        _toChain?.chainId == request?.destinationChainId &&
        _toCurrency?.address == destinationCurrency &&
        _bitcoinReceive?.address == refund?.address;
    if (refund == null || request == null || !current()) return;
    setState(() => _isBridging = true);
    try {
      if (AmountUtils.parseDecimalToBaseUnits(text.replaceAll(',', ''), 8) !=
              request.amount ||
          _fromToken?.symbol != 'BTC' ||
          _fromToken?.decimals != 8 ||
          _fromToken?.contractAddress?.isNotEmpty == true) {
        throw StateError('Bitcoin bridge input changed');
      }
      final committed = await _bridgeService.commitQuote(
        originChainId: request.originChainId,
        destinationChainId: request.destinationChainId,
        originCurrency: request.originCurrency,
        destinationCurrency: request.destinationCurrency,
        amountWei: request.amount.toString(),
        walletAddress: request.sender,
        recipientAddress: request.recipient,
        slippageBps: _slippageBps,
        amountUsd: _fromToken!.priceUsd > 0
            ? _amountValue * _fromToken!.priceUsd
            : null,
      );
      if (!current() ||
          committed?.bitcoinQuote == null ||
          !committed!.committed) {
        throw StateError('Bitcoin bridge commitment unavailable');
      }
      final prepared = await _bitcoinFunding.prepare(
        identity,
        committed.bitcoinQuote!,
        refundAddress: refund,
        isCurrent: current,
      );
      if (!mounted || !current()) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (confirmationContext) => BitcoinTransferConfirmationScreen(
            transfer: prepared.transfer,
            bridgeQuote: prepared.quote,
            bridgeDestinationName: _toChain?.name,
            bridgeDestinationSymbol: _toCurrency?.symbol ?? _toChain?.symbol,
            onConfirm: (_) async {
              final result = await _bitcoinFunding.execute(
                prepared,
                isCurrent: current,
                authenticate: () async {
                  await WalletVaultService.lockAll();
                  if (!current() || !confirmationContext.mounted) return false;
                  return await requestWalletUnlock(confirmationContext) &&
                      current();
                },
              );
              if (mounted) {
                setState(() {
                  _bitcoinHasPending = true;
                  _bitcoinRecovery = null;
                  _quote = null;
                });
                unawaited(
                  widget.blockchain
                      .refreshBitcoinAccountAfterTransaction(
                        identity,
                        BitcoinProductNetwork.mainnet,
                        isCurrent: () =>
                            mounted &&
                            widget.blockchain.activeWalletAddress
                                    .trim()
                                    .toLowerCase() ==
                                identity,
                      )
                      .catchError((Object _) {}),
                );
                unawaited(
                  _walletHistoryService
                      .recordBridgeSubmitted(
                        walletAddress: identity,
                        txHash: result.txid,
                        chainId: BridgeService.relayBitcoinChainId,
                        networkName: 'Bitcoin',
                        networkKey: 'bitcoin:mainnet',
                        fromTokenSymbol: 'BTC',
                        fromAmount: BitcoinAmountUtils.format(request.amount),
                        toTokenSymbol:
                            _toCurrency?.symbol ?? _toChain?.symbol ?? 'Token',
                        destinationNetworkName: _toChain?.name ?? 'Destination',
                      )
                      .catchError((Object _) {}),
                );
              }
              if (confirmationContext.mounted) {
                Navigator.of(confirmationContext).pop();
              }
              ToastUtils.showInfo(
                result.status == BitcoinSubmissionStatus.accepted
                    ? 'Bitcoin submitted. Bridge delivery is still processing.'
                    : 'Checking the Bitcoin submission. Do not pay this bridge again.',
              );
              if (mounted) unawaited(_checkBitcoinBridge());
            },
          ),
        ),
      );
    } on BitcoinSplitFundsException {
      if (mounted) {
        setState(
          () => _quoteError =
              'BTC is split across address formats. One format must cover the bridge amount and network fee.',
        );
      }
    } on BitcoinPendingInputsException {
      if (mounted) {
        setState(
          () => _quoteError =
              'Some BTC is reserved for an earlier transaction. Open Send → Review saved attempts to check its status before spending it again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _quoteError =
              'Unable to prepare this Bitcoin bridge. Refresh your BTC balance and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isBridging = false);
    }
  }

  Future<void> _executeAssetChainBridge(
    AssetChainNativeBridgeQuote approved,
  ) async {
    final wallet = widget.walletAddress?.trim();
    if (wallet == null || wallet.isEmpty) return;
    final runtime = RuntimeConfigService.instance.snapshot;
    if (!runtime.allows(RuntimeFeature.bridges) ||
        !runtime.allows(RuntimeFeature.transfers)) {
      if (mounted) {
        setState(
          () => _quoteError = 'Asset Chain bridging is currently unavailable.',
        );
      }
      return;
    }

    final approvalNetwork = widget.blockchain.activeNetworkKey;
    final approvalWallet = widget.walletAddress;
    final approvalAmount = _amountController.text;
    final approvalDestination = _toChain;
    final approvalFrom = _fromToken;
    bool isCurrent() =>
        mounted &&
        widget.blockchain.activeNetworkKey == approvalNetwork &&
        widget.walletAddress == approvalWallet &&
        _amountController.text == approvalAmount &&
        identical(_toChain, approvalDestination) &&
        identical(_fromToken, approvalFrom) &&
        RuntimeConfigService.instance.snapshot.allows(RuntimeFeature.bridges) &&
        RuntimeConfigService.instance.snapshot.allows(RuntimeFeature.transfers);

    var authenticated = false;
    try {
      authenticated =
          await SensitiveAccessGuard.verify(
            context,
            reason: 'Authenticate to confirm this bridge.',
            requireTwoFactor: false,
          ) &&
          isCurrent();
    } catch (_) {
      if (mounted) {
        setState(
          () => _quoteError = 'Unable to unlock this wallet. Please try again.',
        );
      }
    }
    if (!authenticated || !mounted) return;

    final controller = TransactionProgressController(
      flow: TransactionProgressFlow.generic,
    );
    var progressOpen = true;
    unawaited(
      Navigator.of(context)
          .pushNamed(
            '/transaction-processing',
            arguments: TransactionProcessingArguments(controller: controller),
          )
          .whenComplete(() {
            progressOpen = false;
            controller.dispose();
          }),
    );
    controller.setSwapSubmitting();

    try {
      final txHash = await _assetChainBridgeService.send(
        approved,
        wallet,
        isCurrent: isCurrent,
        onStatus: (status) {
          if (!mounted || !progressOpen) return;
          controller.setSwapPending(message: status);
        },
      );
      if (progressOpen) {
        controller.setSuccess(
          reference: shortHash(txHash),
          detailsUrl: _originExplorerTxUrl(
            txHash,
            evmChain: approved.route.sourceChain,
          ),
        );
      }
      if (approved.platformFeeBps > 0) {
        unawaited(
          _bridgeService
              .recordExecutedBridge(
                originChainId: approved.route.sourceChain.chainId,
                destinationChainId: approved.route.destinationChain.chainId,
                walletAddress: wallet,
                sellToken:
                    approved.route.source.token?.symbol ?? _fromToken?.symbol,
                buyToken:
                    approved.route.destination.token?.symbol ??
                    _toCurrency?.symbol,
                amountUsd: approved.amountUsd,
                txHash: txHash,
              )
              .catchError((Object error, StackTrace stackTrace) {
                debugPrint(
                  'Asset Chain bridge completion bookkeeping failed: $error\n$stackTrace',
                );
              }),
        );
      }
      try {
        await widget.onBridgeCompleted?.call();
      } catch (error) {
        debugPrint('Post-bridge wallet refresh failed: $error');
      }
      if (mounted) {
        setState(() {
          _amountController.clear();
          _selectedPercentage = -1;
          _resetQuote();
        });
        unawaited(_loadAssetChainTransfers());
      }
    } catch (error) {
      if (progressOpen) {
        controller.setError(_cleanAssetChainError(error));
      }
      if (mounted) {
        unawaited(_loadAssetChainTransfers());
      }
    }
  }

  Future<void> _claimAssetChainTransfer(
    AssetChainBridgeTransaction transfer,
    AssetChainNativeBridgeRoute route,
  ) async {
    if (_isBridging || _claimingAssetChainTransferId != null) return;
    final wallet = widget.walletAddress?.trim();
    if (wallet == null || wallet.isEmpty) return;
    final runtime = RuntimeConfigService.instance.snapshot;
    if (!runtime.allows(RuntimeFeature.bridges) ||
        !runtime.allows(RuntimeFeature.transfers)) {
      if (mounted) {
        setState(
          () => _quoteError = 'Asset Chain claiming is currently unavailable.',
        );
      }
      return;
    }

    setState(() => _claimingAssetChainTransferId = transfer.id);
    final approvalWallet = widget.walletAddress;
    final approvalNetwork = widget.blockchain.activeNetworkKey;
    bool isCurrent() =>
        mounted &&
        widget.walletAddress == approvalWallet &&
        widget.blockchain.activeNetworkKey == approvalNetwork &&
        RuntimeConfigService.instance.snapshot.allows(RuntimeFeature.bridges) &&
        RuntimeConfigService.instance.snapshot.allows(RuntimeFeature.transfers);

    var authenticated = false;
    try {
      authenticated =
          await SensitiveAccessGuard.verify(
            context,
            reason: 'Authenticate to claim this bridge transfer.',
            requireTwoFactor: false,
          ) &&
          isCurrent();
    } catch (_) {
      if (mounted) {
        setState(
          () => _quoteError = 'Unable to unlock this wallet. Please try again.',
        );
      }
    } finally {
      if (!authenticated && mounted) {
        setState(() => _claimingAssetChainTransferId = null);
      }
    }
    if (!authenticated || !mounted) return;

    final controller = TransactionProgressController(
      flow: TransactionProgressFlow.generic,
    );
    var progressOpen = true;
    unawaited(
      Navigator.of(context)
          .pushNamed(
            '/transaction-processing',
            arguments: TransactionProcessingArguments(controller: controller),
          )
          .whenComplete(() {
            progressOpen = false;
            controller.dispose();
          }),
    );
    controller.setSwapSubmitting();

    try {
      final txHash = await _assetChainBridgeService.claim(
        transfer,
        route,
        wallet,
        isCurrent: isCurrent,
        onStatus: (status) {
          if (!mounted || !progressOpen) return;
          controller.setSwapPending(message: status);
        },
      );
      if (progressOpen) {
        controller.setSuccess(
          reference: shortHash(txHash),
          detailsUrl: _originExplorerTxUrl(
            txHash,
            evmChain: route.destinationChain,
          ),
        );
      }
      try {
        await widget.onBridgeCompleted?.call();
      } catch (error) {
        debugPrint('Post-claim wallet refresh failed: $error');
      }
      if (mounted) {
        unawaited(_loadAssetChainTransfers());
      }
    } catch (error) {
      if (progressOpen) {
        controller.setError(_cleanAssetChainError(error));
      }
      if (mounted) {
        unawaited(_loadAssetChainTransfers());
      }
    } finally {
      if (mounted) {
        setState(() => _claimingAssetChainTransferId = null);
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final from = _fromToken;
    final toChain = _toChain;
    final quote = _quote;
    final acQuote = _assetChainQuote;
    // Family-aware origin display: shows "Solana" + its logo when the
    // active network is Solana, the active EVM chain otherwise.
    final fromChainName = widget.blockchain.activeNetworkName;
    final fromChainLogo = widget.blockchain.activeNetworkLogoUrl;
    final fromTokenIconChainId =
        _isBitcoinOrigin || _isSolanaOrigin || _isTronOrigin
        ? null
        : widget.blockchain.activeChain.chainId;

    final fromUsd = from != null && from.priceUsd > 0
        ? _amountValue * from.priceUsd
        : 0.0;

    String toAmountText = '0.0';
    if (acQuote != null) {
      toAmountText = AmountUtils.formatBaseUnits(
        acQuote.receivedAmount,
        acQuote.route.destination.tokenDecimal,
        maxFractionDigits: 6,
      );
    } else if (quote != null) {
      final outWei = BigInt.tryParse(quote.amountOut) ?? BigInt.zero;
      // Use the selected token's decimals; otherwise the chain's native
      // decimals (SOL uses 9, EVM gas tokens 18).
      final outDecimals =
          quote.bitcoinQuote?.destinationDecimals ??
          _toCurrency?.decimals ??
          (toChain?.family == ChainFamily.bitcoin
              ? 8
              : toChain?.family == ChainFamily.solana
              ? 9
              : toChain?.family == ChainFamily.tron
              ? 6
              : 18);
      toAmountText = AmountUtils.formatBaseUnits(
        outWei,
        outDecimals,
        maxFractionDigits: toChain?.family == ChainFamily.bitcoin ? 8 : 6,
      );
    }
    final double? destinationUsd;
    if (acQuote != null) {
      final sameSymbol =
          from != null &&
          AssetChainNativeBridgeService.normalizedSymbol(from.symbol) ==
              AssetChainNativeBridgeService.normalizedSymbol(
                acQuote.route.symbol,
              );
      destinationUsd = destinationAmountUsd(
        quoteAmountUsd: 0,
        amountText: toAmountText,
        destinationSymbol:
            _toCurrency?.symbol ??
            acQuote.route.destination.token?.symbol ??
            toChain?.symbol ??
            '',
        destinationPriceUsd:
            _toCurrency?.priceUsd ??
            (sameSymbol && from.priceUsd > 0 ? from.priceUsd : null),
      );
    } else if (quote != null) {
      destinationUsd = destinationAmountUsd(
        quoteAmountUsd: quote.amountOutUsd,
        amountText: toAmountText,
        destinationSymbol: _toCurrency?.symbol ?? toChain?.symbol ?? '',
        destinationPriceUsd: _toCurrency?.priceUsd,
      );
    } else {
      destinationUsd = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_bitcoinHasPending || _bitcoinRecovery != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF171717),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(switch (_bitcoinRecovery?.phase) {
                    BitcoinBridgePhase.bitcoinSubmitted =>
                      'Bitcoin submitted · awaiting confirmation',
                    BitcoinBridgePhase.bitcoinConfirmed =>
                      'Bitcoin confirmed · checking bridge delivery',
                    BitcoinBridgePhase.bridgeProcessing => 'Bridge processing',
                    BitcoinBridgePhase.delivered => 'Destination delivered',
                    BitcoinBridgePhase.refundReported =>
                      'Refund reported · verification required. Do not pay again.',
                    BitcoinBridgePhase.refunded =>
                      'Relay reports the refund completed. Check your network balances.',
                    BitcoinBridgePhase.failed =>
                      'Bridge failed · review required. Do not pay again.',
                    BitcoinBridgePhase.reviewRequired =>
                      'Bridge needs review. Your payment remains recorded.',
                    _ =>
                      'Checking an earlier Bitcoin bridge submission. Do not pay again until its status is known.',
                  }, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: _isCheckingBitcoin
                          ? null
                          : _checkBitcoinBridge,
                      child: Text(
                        _isCheckingBitcoin ? 'Checking…' : 'Check status',
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const TransactionsScreen(),
                        ),
                      ),
                      child: const Text('Transaction history'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_pendingOperation != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF171717),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'A bridge is still processing. You can safely leave this screen and check it later.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _isCheckingPending ? null : _checkPendingBridge,
                  child: Text(_isCheckingPending ? 'Checking…' : 'Check'),
                ),
              ],
            ),
          ),
        ],
        if (_isAssetChainRoute ||
            _assetChainPending.isNotEmpty ||
            _assetChainTransfers.isNotEmpty) ...[
          if (_assetChainPending.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF171717),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'An Asset Chain bridge submission is saved. Check status before sending again.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _isRefreshingAssetChain
                        ? null
                        : _loadAssetChainTransfers,
                    child: Text(
                      _isRefreshingAssetChain ? 'Refreshing…' : 'Refresh',
                    ),
                  ),
                ],
              ),
            ),
          for (final transfer in _assetChainTransfers) ...[
            Builder(
              builder: (context) {
                final route = _claimRouteForAssetChain(transfer);
                final amountText = AmountUtils.formatBaseUnits(
                  BigInt.tryParse(transfer.amount) ?? BigInt.zero,
                  route?.source.tokenDecimal ?? 18,
                  maxFractionDigits: 6,
                );
                final hasPendingEntry = _assetChainPending.any(
                  (item) => item['transactionId'] == transfer.id,
                );
                final claimingThis =
                    _claimingAssetChainTransferId == transfer.id;
                final canClaim =
                    route != null &&
                    !_isBridging &&
                    _claimingAssetChainTransferId == null &&
                    !hasPendingEntry;
                final claimLabel = route == null
                    ? 'Route unavailable'
                    : claimingThis
                    ? 'Claiming…'
                    : 'Claim on ${route.destinationChain.name}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171717),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$amountText ${transfer.symbol} · ${route?.sourceChain.name ?? transfer.fromChain} → ${route?.destinationChain.name ?? transfer.toChain}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Awaiting destination claim',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: canClaim
                            ? () => _claimAssetChainTransfer(transfer, route)
                            : null,
                        child: Text(claimLabel),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
        _BridgeCard(
          label: 'BRIDGE FROM',
          chainName: fromChainName,
          chainLogoUrl: fromChainLogo,
          chainId: fromTokenIconChainId,
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
                      from != null && from.priceUsd > 0
                          ? ValueFormatter.formatCurrencyWithGrouping(
                              ValueFormatter.decimalFromNum(fromUsd),
                            )
                          : '—',
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
                    _isBitcoinOrigin
                        ? _bitcoinBalanceText
                        : '${(from?.balance ?? 0).toStringAsFixed(4)} ${from?.symbol ?? ''}',
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
                child: Center(
                  child: FigmaSwapDirectionIcon(
                    color: context.chainTheme.accentColor,
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
          chainId: toChain?.family == ChainFamily.evm ? toChain?.chainId : null,
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
                        color: quote == null && acQuote == null
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
                  ValueFormatter.decimalFromNum(destinationUsd ?? 0),
                ),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF848E9C),
                ),
              ),
            ],
          ),
        ),
        if (quote != null || acQuote != null || _isQuoting) ...[
          const SizedBox(height: 16),
          _BridgeDetailsCard(
            quote: quote,
            assetChainQuote: acQuote,
            isLoading: _isQuoting,
            swapAmountUsd: fromUsd,
          ),
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
        if (!_isAssetChainRoute) ...[
          const SizedBox(height: 16),
          SwapSlippageSection(
            slippageBps: _slippageBps,
            onChanged: (bps) {
              setState(() {
                _slippageBps = bps;
                _resetQuote();
              });
              _requestQuote();
            },
          ),
        ],
        const SizedBox(height: 20),
        if (_isBitcoinOrigin &&
            !_bitcoinRecoveryLoaded &&
            !_bitcoinBalanceLoading)
          TextButton.icon(
            onPressed: _loadBitcoinAddress,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh BTC balance'),
          ),
        SwapPrimaryButton(
          enabled: _canBridge,
          isBusy: _isBridging || _bridgeActionActive,
          onPressed: _executeBridge,
          label: _buttonLabel,
        ),
        const SizedBox(height: 12),
        Text(
          _isAssetChainOrigin && _originTokens.isEmpty
              ? 'RWA and WRWA cannot be bridged. Hold a bridgeable token on ${widget.blockchain.activeChain.name} to bridge.'
              : _isAssetChainRoute
              ? 'You bridge ${_toCurrency?.symbol ?? toChain?.symbol ?? 'the selected token'} to ${toChain?.name ?? 'the destination network'} via Asset Chain Bridge and claim on the destination network.'
              : 'You receive ${_toCurrency?.symbol ?? toChain?.symbol ?? 'the selected token'} on ${toChain?.name ?? 'the destination network'}.',
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
  final int? chainId;
  final VoidCallback? onSelectChain;
  final Widget child;

  const _BridgeCard({
    required this.label,
    required this.chainName,
    required this.chainLogoUrl,
    this.chainId,
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
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFB2B5BD),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ChainPill(
                name: chainName,
                logoUrl: chainLogoUrl,
                chainId: chainId,
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
  final int? chainId;
  final VoidCallback? onTap;

  const _ChainPill({
    required this.name,
    required this.logoUrl,
    this.chainId,
    this.onTap,
  });

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
            _ChainLogoDot(url: logoUrl, chainId: chainId),
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
  final int? chainId;

  const _ChainLogoDot({this.url, this.chainId});

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
    if (trimmed.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          trimmed,
          width: 20,
          height: 20,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      );
    }
    if (chainId != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ChainLogoImage(
          chainId: chainId!,
          logoUrl: trimmed.isEmpty ? null : trimmed,
          width: 20,
          height: 20,
          fit: BoxFit.cover,
          fallback: fallback,
        ),
      );
    }
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
    final chainId = chain?.family == ChainFamily.evm ? chain?.chainId : null;
    final showTokenIcon = currency != null && !currency!.isNative;
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
            if (showTokenIcon)
              TokenIcon(
                tokenSymbol: symbol,
                tokenAddress: currency!.address,
                tokenImageUrl: currency!.logoUri,
                size: 20,
                chainId: chainId,
              )
            else
              _ChainLogoDot(url: logo, chainId: chainId),
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
      _currencies = [...results]
        ..sort((a, b) {
          final aBlocked = _bridgeCurrencyBlocked(a);
          final bBlocked = _bridgeCurrencyBlocked(b);
          final blocked = aBlocked == bBlocked ? 0 : (aBlocked ? 1 : -1);
          return blocked != 0 ? blocked : a.symbol.compareTo(b.symbol);
        });
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
                          final blocked = _bridgeCurrencyBlocked(c);
                          return ListTile(
                            enabled: !blocked,
                            onTap: blocked
                                ? null
                                : () => Navigator.of(ctx).pop(c),
                            leading: c.isNative
                                ? _ChainLogoDot(
                                    url: c.logoUri,
                                    chainId: widget.chainId,
                                  )
                                : TokenIcon(
                                    tokenSymbol: c.symbol,
                                    tokenAddress: c.address,
                                    tokenImageUrl: c.logoUri,
                                    size: 24,
                                    chainId: widget.chainId,
                                  ),
                            title: Text(
                              c.symbol,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              [
                                c.name,
                                c.isNative
                                    ? 'Verified native token'
                                    : blocked
                                    ? 'Unverified · ${TokenTrustUtils.shortenedAddress(c.address)}'
                                    : 'Verified · ${TokenTrustUtils.shortenedAddress(c.address)}',
                              ].join(' · '),
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
                                : Icon(
                                    blocked
                                        ? Icons.warning_amber_rounded
                                        : Icons.verified_rounded,
                                    size: 18,
                                    color: blocked
                                        ? const Color(0xFFEA2A33)
                                        : const Color(0xFF39D98A),
                                  ),
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
    final theme = context.chainTheme;
    final accent = isSelected || alwaysAccent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.accentColor.withValues(alpha: 0.18)
              : const Color(0xFF131313),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: accent
                ? theme.accentColor.withValues(alpha: 0.5)
                : const Color(0x0DFFFFFF),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: accent ? theme.accentColor : const Color(0xFFA1A1A1),
          ),
        ),
      ),
    );
  }
}

/// Fee/details box: platform fee, bridge fee, estimated gas, arrival.
class _BridgeDetailsCard extends StatelessWidget {
  final BridgeQuote? quote;
  final AssetChainNativeBridgeQuote? assetChainQuote;
  final bool isLoading;
  final double swapAmountUsd;

  const _BridgeDetailsCard({
    required this.quote,
    this.assetChainQuote,
    required this.isLoading,
    required this.swapAmountUsd,
  });

  @override
  Widget build(BuildContext context) {
    final q = quote;
    final ac = assetChainQuote;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0x801E2228),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: isLoading && q == null && ac == null
          ? Center(
              child: Text(
                'Fetching quote…',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            )
          : ac != null
          ? Column(
              children: [
                const _DetailRow(label: 'Route', value: 'Asset Chain Bridge'),
                if (ac.platformFeeBps > 0 || (ac.platformFeeUsd ?? 0) > 0)
                  _DetailRow(
                    label: 'Platform Fee',
                    value: formatBridgePlatformFee(
                      swapAmountUsd: swapAmountUsd > 0
                          ? swapAmountUsd
                          : (ac.amountUsd ?? 0),
                      feeUsd: ac.platformFeeUsd,
                      feeBps: ac.platformFeeBps > 0 ? ac.platformFeeBps : null,
                    ),
                  ),
                _DetailRow(
                  label: 'Send Fee',
                  value: '${_feePercentLabel(ac.sendFee, ac.denominator)}%',
                ),
                _DetailRow(
                  label: 'Claim Fee',
                  value: '${_feePercentLabel(ac.receiveFee, ac.denominator)}%',
                ),
                _DetailRow(
                  label: 'Estimated Arrival',
                  value: 'Claim on ${ac.route.destinationChain.name}',
                  isLast: true,
                ),
              ],
            )
          : Column(
              children: [
                if (q?.platformFeeBps != null || q?.platformFeeUsd != null)
                  _DetailRow(
                    label: 'Platform Fee',
                    value: formatBridgePlatformFee(
                      swapAmountUsd: swapAmountUsd,
                      feeUsd: q!.platformFeeUsd,
                      feeBps: q.platformFeeBps,
                    ),
                  ),
                _DetailRow(
                  label: 'Bridge Fee',
                  value: formatBridgeFeeUsd(q?.bridgeFeeUsd),
                ),
                if (hasQuotedOriginNetworkFee(q?.gasFeeUsd))
                  _DetailRow(
                    label: 'Origin Network Fee',
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

  static String _feePercentLabel(BigInt fee, BigInt denominator) {
    final denom = denominator.toDouble();
    if (denom <= 0) return '0.00';
    return (fee.toDouble() / denom * 100).toStringAsFixed(2);
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
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF9CA3AF),
                letterSpacing: 0.24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFE5E2E1),
                letterSpacing: 0.24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChainPickerSheet extends StatefulWidget {
  final List<EvmChain> chains;

  const _ChainPickerSheet({required this.chains});

  @override
  State<_ChainPickerSheet> createState() => _ChainPickerSheetState();
}

class _ChainPickerSheetState extends State<_ChainPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<EvmChain> get _filteredChains {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.chains;
    return widget.chains.where((chain) {
      return chain.name.toLowerCase().contains(q) ||
          chain.symbol.toLowerCase().contains(q) ||
          chain.chainId.toString().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredChains;
    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Text(
                  'Bridge to network',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  key: const ValueKey('bridge-chain-search-field'),
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: 'Search network or symbol',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF848E9C),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: Color(0xFF848E9C),
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            key: const ValueKey('bridge-chain-search-clear'),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: Color(0xFF848E9C),
                            ),
                          ),
                    filled: true,
                    fillColor: const Color(0xFF161616),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF262A30)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF262A30)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF3E4552)),
                    ),
                  ),
                ),
              ),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: Center(
                    child: Text(
                      'No matching networks found.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF848E9C),
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (ctx, index) {
                      final chain = filtered[index];
                      return ListTile(
                        onTap: () => Navigator.of(ctx).pop(chain),
                        leading: _ChainLogoDot(
                          url: chain.logoUrl,
                          chainId: chain.family == ChainFamily.evm
                              ? chain.chainId
                              : null,
                        ),
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
      ),
    );
  }
}

class _AssetChainCurrencyPickerSheet extends StatelessWidget {
  final String chainName;
  final int chainId;
  final List<BridgeCurrency> currencies;

  const _AssetChainCurrencyPickerSheet({
    required this.chainName,
    required this.chainId,
    required this.currencies,
  });

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
                'Receive on $chainName',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            if (currencies.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Text(
                  'No supported Asset Chain bridge tokens found for this route.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF848E9C),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: currencies.length,
                  itemBuilder: (ctx, index) {
                    final c = currencies[index];
                    return ListTile(
                      onTap: () => Navigator.of(ctx).pop(c),
                      leading: c.isNative
                          ? _ChainLogoDot(url: c.logoUri, chainId: chainId)
                          : TokenIcon(
                              tokenSymbol: c.symbol,
                              tokenAddress: c.address,
                              tokenImageUrl: c.logoUri,
                              size: 24,
                              chainId: chainId,
                            ),
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
