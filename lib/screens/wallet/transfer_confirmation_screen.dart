import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/token.dart';
import '../../services/blockchain_service.dart';
import '../../services/currency_controller.dart';
import '../../services/wallet_history_service.dart';
import '../../services/transaction_monitor.dart';
import '../../services/wallet_notification_service.dart';
import '../../models/chain.dart';
import '../../services/wallet_service.dart';
import '../../utils/amount_utils.dart';
import '../../utils/app_error_utils.dart';
import '../../utils/value_formatter.dart';
import '../../widgets/entrance_motion.dart';
import '../transaction/transaction_processing_screen.dart';
import 'widgets/transfer_confirmation/amount_summary.dart';
import 'widgets/transfer_confirmation/confirm_button.dart';
import 'widgets/transfer_confirmation/transaction_details_card.dart';
import 'widgets/transfer_confirmation/transfer_header.dart';
import 'widgets/transfer_confirmation/warning_banner.dart';

/// Transfer Confirmation Screen
/// Shows transaction details and fee breakdown before confirming
class TransferConfirmationScreen extends StatefulWidget {
  const TransferConfirmationScreen({super.key});

  @override
  State<TransferConfirmationScreen> createState() =>
      _TransferConfirmationScreenState();
}

class _TransferConfirmationScreenState
    extends State<TransferConfirmationScreen> {
  static final BigInt _solanaTransferFeeLamports = BigInt.from(5000);

  final WalletService _walletService = WalletService();
  final TransactionMonitor _transactionMonitor = TransactionMonitor();
  final WalletNotificationService _walletNotificationService =
      WalletNotificationService();
  final WalletHistoryService _walletHistoryService = WalletHistoryService();
  Map<String, dynamic>? _args;
  String? _fromAddress;
  bool _isConfirming = false;

  double _gasPriceGwei = 0;
  double _gasFeeEth = 0;
  double _gasFeeUsd = 0;
  BigInt _gasFeeWei = BigInt.zero;
  bool _isLoadingGas = true;
  bool _gasEstimationFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _args ??= _routeArgumentsAsMap(ModalRoute.of(context)?.settings.arguments);
    if (_fromAddress == null) {
      _loadFromAddress();
    }
  }

  Map<String, dynamic>? _routeArgumentsAsMap(dynamic arguments) {
    if (arguments is Map<String, dynamic>) {
      return arguments;
    }
    if (arguments is Map) {
      return arguments.map((key, value) => MapEntry('$key', value));
    }
    if (arguments is String && arguments.isNotEmpty) {
      try {
        final decoded = jsonDecode(arguments);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry('$key', value));
        }
      } catch (_) {}
    }
    return null;
  }

  double _tokenUsdPrice(BlockchainService blockchain, Token? token) {
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

  String _transferNetworkKey(BlockchainService blockchain) {
    final argKey = _args?['networkKey']?.toString().trim();
    if (argKey != null && argKey.isNotEmpty) {
      return argKey;
    }
    final token = _args?['token'] as Token?;
    final tokenKey = token?.networkKey?.trim();
    if (tokenKey != null && tokenKey.isNotEmpty) {
      return tokenKey;
    }
    return blockchain.activeNetworkKey;
  }

  ChainFamily _transferFamily(BlockchainService blockchain) {
    return NetworkKey.familyOf(_transferNetworkKey(blockchain));
  }

  int? _argChainId() {
    final value = _args?['chainId'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  EvmChain _evmChainForTransfer(
    BlockchainService blockchain,
    String networkKey,
  ) {
    final chainId =
        NetworkKey.evmChainIdOf(networkKey) ??
        _argChainId() ??
        blockchain.activeChain.chainId;
    return blockchain.allChains.firstWhere(
      (chain) => chain.chainId == chainId,
      orElse: () => blockchain.activeChain,
    );
  }

  String _networkNameForTransfer(BlockchainService blockchain) {
    final argNetwork = _args?['network']?.toString().trim();
    if (argNetwork != null && argNetwork.isNotEmpty) {
      return argNetwork;
    }
    final networkKey = _transferNetworkKey(blockchain);
    return switch (NetworkKey.familyOf(networkKey)) {
      ChainFamily.solana => 'Solana',
      ChainFamily.tron => 'TRON',
      ChainFamily.evm => _evmChainForTransfer(blockchain, networkKey).name,
    };
  }

  String _nativeSymbolForTransfer(BlockchainService blockchain) {
    final argSymbol = _args?['networkSymbol']?.toString().trim();
    if (argSymbol != null && argSymbol.isNotEmpty) {
      return argSymbol;
    }
    final networkKey = _transferNetworkKey(blockchain);
    return switch (NetworkKey.familyOf(networkKey)) {
      ChainFamily.solana => 'SOL',
      ChainFamily.tron => 'TRX',
      ChainFamily.evm => _evmChainForTransfer(blockchain, networkKey).symbol,
    };
  }

  int? _tokenIconChainIdForTransfer(BlockchainService blockchain) {
    final networkKey = _transferNetworkKey(blockchain);
    if (NetworkKey.familyOf(networkKey) != ChainFamily.evm) {
      return null;
    }
    return _evmChainForTransfer(blockchain, networkKey).chainId;
  }

  Future<void> _loadFromAddress() async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final family = _transferFamily(blockchain);
    final address = await _walletService.getWalletAddressForFamily(family);
    if (mounted) {
      setState(() => _fromAddress = address);
    }
    _fetchGasEstimate();
  }

  Future<void> _fetchGasEstimate() async {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final networkKey = _transferNetworkKey(blockchain);
      final activeFamily = NetworkKey.familyOf(networkKey);

      if (activeFamily != ChainFamily.evm) {
        final estimatedFeeBaseUnits = _estimatedNonEvmFeeBaseUnits(
          activeFamily,
        );
        final nativeDecimals = _nativeDecimalsForFamily(activeFamily);
        final estimatedFeeNative = _baseUnitsToDouble(
          estimatedFeeBaseUnits,
          nativeDecimals,
        );
        double estimatedFeeUsd = 0;
        final coinId = _nativeCoinGeckoIdForTransfer(blockchain, activeFamily);
        if (estimatedFeeNative > 0 && coinId != null && coinId.isNotEmpty) {
          try {
            final prices = await blockchain.getTokenPrices([coinId]);
            estimatedFeeUsd = estimatedFeeNative * (prices[coinId] ?? 0);
          } catch (_) {
            estimatedFeeUsd = 0;
          }
        }
        if (mounted) {
          setState(() {
            _gasPriceGwei = 0;
            _gasFeeEth = estimatedFeeNative;
            _gasFeeUsd = estimatedFeeUsd;
            _gasFeeWei = estimatedFeeBaseUnits;
            _isLoadingGas = false;
            _gasEstimationFailed = false;
          });
        }
        return;
      }

      final evmChain = _evmChainForTransfer(blockchain, networkKey);
      final effectiveCoinId = evmChain.coinGeckoId;
      final token = _args?['token'] as Token?;
      final toAddress = _args?['toAddress'] as String? ?? '';
      final amountInBaseUnits =
          _args?['amountBaseUnits'] as BigInt? ?? BigInt.zero;

      double nativePrice = 0;
      if (effectiveCoinId != null && effectiveCoinId.isNotEmpty) {
        final prices = await blockchain.getTokenPrices([effectiveCoinId]);
        nativePrice = prices[effectiveCoinId] ?? 0;
      }

      final gasData =
          _fromAddress != null &&
              _fromAddress!.isNotEmpty &&
              toAddress.isNotEmpty &&
              amountInBaseUnits > BigInt.zero
          ? await _walletService.estimateTransferFee(
              fromAddress: _fromAddress!,
              toAddress: toAddress,
              amountInBaseUnits: amountInBaseUnits,
              rpcUrl: evmChain.rpcUrl,
              tokenAddress: token?.contractAddress?.isNotEmpty == true
                  ? token!.contractAddress
                  : null,
              nativePriceUsd: nativePrice,
            )
          : await blockchain.estimateGasFee(nativePriceUsd: nativePrice);
      if (mounted) {
        setState(() {
          _gasPriceGwei = gasData['gasGwei'] ?? 20;
          _gasFeeEth = gasData['totalFeeEth'] ?? 0;
          _gasFeeUsd = gasData['totalFeeUsd'] ?? 0;
          _gasFeeWei = gasData['totalFeeWei'] as BigInt? ?? BigInt.zero;
          _isLoadingGas = false;
          _gasEstimationFailed = false;
        });
      }
    } catch (e) {
      debugPrint('Gas estimation failed: $e');
      if (mounted) {
        setState(() {
          _isLoadingGas = false;
          _gasEstimationFailed = true;
        });
      }
    }
  }

  String _shortenAddress(String? address) {
    if (address == null || address.length < 10) {
      return address ?? '--';
    }
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _shortHash(String hash) {
    if (hash.length <= 10) {
      return hash;
    }
    return '${hash.substring(0, 6)}...${hash.substring(hash.length - 4)}';
  }

  String _formatGasPriceGwei(double value) {
    if (value >= 10) {
      return value.toStringAsFixed(1);
    }
    if (value >= 1) {
      return value.toStringAsFixed(2);
    }
    if (value >= 0.01) {
      return value.toStringAsFixed(4);
    }
    return value.toStringAsFixed(6);
  }

  String _formatGasFeeNative(double value, String symbol) {
    final decimals = value >= 0.01
        ? 6
        : value >= 0.0001
        ? 8
        : 10;
    final formatted = value
        .toStringAsFixed(decimals)
        .replaceFirst(RegExp(r'0+$'), '');
    final normalized = formatted.endsWith('.')
        ? formatted.substring(0, formatted.length - 1)
        : formatted;
    return '$normalized $symbol';
  }

  BigInt _estimatedNonEvmFeeBaseUnits(ChainFamily family) {
    return switch (family) {
      ChainFamily.solana => _solanaTransferFeeLamports,
      ChainFamily.tron => BigInt.zero,
      ChainFamily.evm => BigInt.zero,
    };
  }

  int _nativeDecimalsForFamily(ChainFamily family) {
    return switch (family) {
      ChainFamily.solana => 9,
      ChainFamily.tron => 6,
      ChainFamily.evm => 18,
    };
  }

  double _baseUnitsToDouble(BigInt value, int decimals) {
    return double.tryParse(
          AmountUtils.formatBaseUnits(
            value,
            decimals,
            maxFractionDigits: decimals,
          ),
        ) ??
        0;
  }

  String? _nativeCoinGeckoIdForTransfer(
    BlockchainService blockchain,
    ChainFamily family,
  ) {
    return switch (family) {
      ChainFamily.solana => 'solana',
      ChainFamily.tron => 'tron',
      ChainFamily.evm => blockchain.activeNetworkCoinGeckoId,
    };
  }

  String _formatNonEvmNetworkFeeValue(ChainFamily family, String nativeSymbol) {
    if (_gasFeeWei > BigInt.zero) {
      final decimals = _nativeDecimalsForFamily(family);
      return '≈ ${AmountUtils.formatBaseUnits(_gasFeeWei, decimals, maxFractionDigits: decimals)} $nativeSymbol';
    }
    return 'Calculated by network';
  }

  BigInt? _nativeBalanceBaseUnits(
    BlockchainService blockchain,
    ChainFamily family, {
    Token? nativeToken,
  }) {
    final decimals = _nativeDecimalsForFamily(family);
    Token? candidate;
    if (nativeToken != null &&
        (nativeToken.contractAddress == null ||
            nativeToken.contractAddress!.isEmpty)) {
      candidate = nativeToken;
    } else {
      for (final token in blockchain.tokens) {
        if (token.contractAddress == null || token.contractAddress!.isEmpty) {
          candidate = token;
          break;
        }
      }
    }
    if (candidate == null) return null;
    try {
      return AmountUtils.parseDecimalToBaseUnits(
        candidate.balance.toStringAsFixed(decimals),
        decimals,
      );
    } catch (_) {
      return null;
    }
  }

  String? _transactionDetailsUrl(String hash, BlockchainService blockchain) {
    final networkKey = _transferNetworkKey(blockchain);
    final family = NetworkKey.familyOf(networkKey);

    switch (family) {
      case ChainFamily.solana:
        // Solana signatures are 87-88 base58 chars.
        if (!RegExp(r'^[1-9A-HJ-NP-Za-km-z]{80,90}$').hasMatch(hash)) {
          return null;
        }
        final solanaExplorer = networkKey == 'solana:mainnet'
            ? 'https://explorer.solana.com'
            : 'https://explorer.solana.com/?cluster=devnet';
        return '$solanaExplorer/tx/$hash';

      case ChainFamily.tron:
        // Tron txids are 64 hex chars without 0x prefix.
        if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash)) return null;
        return 'https://tronscan.org/#/transaction/$hash';

      case ChainFamily.evm:
        if (!RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(hash)) return null;
        final explorerUrl = _evmChainForTransfer(
          blockchain,
          networkKey,
        ).explorerUrl?.trim();
        if (explorerUrl == null || explorerUrl.isEmpty) return null;
        final normalized = explorerUrl.endsWith('/')
            ? explorerUrl.substring(0, explorerUrl.length - 1)
            : explorerUrl;
        return '$normalized/tx/$hash';
    }
  }

  TransactionProgressController _openProgressFlow() {
    final controller = TransactionProgressController(
      flow: TransactionProgressFlow.transfer,
    );
    unawaited(
      Navigator.of(context)
          .pushNamed(
            '/transaction-processing',
            arguments: TransactionProcessingArguments(
              controller: controller,
              terminalRouteName: '/shell',
              clearStackOnTerminalRoute: true,
            ),
          )
          .whenComplete(controller.dispose),
    );
    return controller;
  }

  Future<void> _refreshWalletStateAfterTransfer({
    required BlockchainService blockchain,
    required ChainFamily family,
    required int? chainId,
  }) async {
    final walletAddress = _fromAddress;
    if (walletAddress == null || walletAddress.isEmpty) return;

    // For non-EVM families chainId is irrelevant — pass null so
    // fetchWalletTokens uses activeNetworkKey to hit the correct cache bucket.
    final effectiveChainId = family == ChainFamily.evm ? chainId : null;
    await blockchain.refreshWalletTokens(
      walletAddress,
      chainId: effectiveChainId,
    );
    unawaited(
      Future<void>.delayed(const Duration(seconds: 3), () async {
        try {
          await blockchain.refreshWalletTokens(
            walletAddress,
            chainId: effectiveChainId,
          );
        } catch (_) {}
      }),
    );
  }

  Future<void> _confirmTransfer() async {
    if (_isConfirming) {
      return;
    }
    setState(() => _isConfirming = true);

    final toAddress = _args?['toAddress'] as String? ?? '';
    final amountInBaseUnits =
        _args?['amountBaseUnits'] as BigInt? ?? BigInt.zero;
    final amountText = _args?['amount'] as String? ?? '0';
    final token = _args?['token'] as Token?;
    final blockchain = Provider.of<BlockchainService>(context, listen: false);

    final progressController = _openProgressFlow();
    progressController.setPreparing();

    try {
      final transferNetworkKey = _transferNetworkKey(blockchain);
      final activeFamily = NetworkKey.familyOf(transferNetworkKey);
      final evmChain = activeFamily == ChainFamily.evm
          ? _evmChainForTransfer(blockchain, transferNetworkKey)
          : null;
      final nativeSymbol = _nativeSymbolForTransfer(blockchain);
      final networkName = _networkNameForTransfer(blockchain);
      progressController.setSwapSubmitting();

      final isNative =
          token?.contractAddress == null ||
          (token?.contractAddress?.isEmpty ?? true);

      if (_fromAddress == null || _fromAddress!.isEmpty) {
        progressController.setError(
          'This wallet does not have an address for $networkName.',
        );
        return;
      }

      // EVM balance/gas checks only apply to EVM families.
      if (activeFamily == ChainFamily.evm && _fromAddress != null) {
        final availableBalance = await blockchain.getNativeBalanceBaseUnits(
          _fromAddress!,
        );
        if (isNative && amountInBaseUnits + _gasFeeWei > availableBalance) {
          progressController.setError(
            'Insufficient $nativeSymbol to cover the transfer amount and network fee.',
          );
          return;
        }
        if (!isNative && _gasFeeWei > availableBalance) {
          progressController.setError(
            'Insufficient $nativeSymbol to cover the network fee for this token transfer.',
          );
          return;
        }
      }
      if (activeFamily == ChainFamily.solana && _gasFeeWei > BigInt.zero) {
        final nativeBalance = _nativeBalanceBaseUnits(
          blockchain,
          activeFamily,
          nativeToken: isNative ? token : null,
        );
        if (nativeBalance != null &&
            isNative &&
            amountInBaseUnits + _gasFeeWei > nativeBalance) {
          progressController.setError(
            'Insufficient $nativeSymbol to cover the transfer amount and network fee.',
          );
          return;
        }
        if (nativeBalance != null && !isNative && _gasFeeWei > nativeBalance) {
          progressController.setError(
            'Insufficient $nativeSymbol to cover the network fee for this token transfer.',
          );
          return;
        }
      }

      String txHash;
      if (activeFamily == ChainFamily.solana) {
        txHash = await _walletService.sendSolanaTransaction(
          fromAddress: _fromAddress!,
          toAddress: toAddress,
          amountLamports: amountInBaseUnits,
          tokenMint: isNative ? null : token?.contractAddress,
        );
      } else if (activeFamily == ChainFamily.tron) {
        txHash = await _walletService.sendTronTransaction(
          fromAddress: _fromAddress!,
          toAddress: toAddress,
          amount: amountInBaseUnits,
          tokenContract: isNative ? null : token?.contractAddress,
        );
      } else {
        txHash = isNative
            ? await _walletService.sendNativeTransaction(
                toAddress: toAddress,
                amountInBaseUnits: amountInBaseUnits,
                rpcUrl: evmChain!.rpcUrl,
                chainId: evmChain.chainId,
              )
            : await _walletService.sendTokenTransaction(
                tokenAddress: token!.contractAddress!,
                toAddress: toAddress,
                amountInBaseUnits: amountInBaseUnits,
                rpcUrl: evmChain!.rpcUrl,
                chainId: evmChain.chainId,
              );
      }

      final detailsUrl = _transactionDetailsUrl(txHash, blockchain);
      progressController.setSwapPending(
        reference: _shortHash(txHash),
        detailsUrl: detailsUrl,
      );

      final confirmed = await _transactionMonitor.waitForConfirmation(
        txHash: txHash,
        blockchain: blockchain,
        networkKey: transferNetworkKey,
        evmChain: evmChain,
      );
      if (!mounted) {
        return;
      }

      if (confirmed) {
        progressController.setSuccess(
          reference: _shortHash(txHash),
          detailsUrl: detailsUrl,
        );
        unawaited(
          _refreshWalletStateAfterTransfer(
            blockchain: blockchain,
            family: activeFamily,
            chainId: evmChain?.chainId,
          ),
        );
        if (_fromAddress != null && token != null) {
          // For non-EVM families use 0 as a sentinel chainId and rely on
          // networkKey for chain identification in history/notification services.
          final effectiveChainId = activeFamily == ChainFamily.evm
              ? evmChain!.chainId
              : 0;
          unawaited(
            _walletNotificationService.notifySendConfirmed(
              walletAddress: _fromAddress!,
              chainId: effectiveChainId,
              txHash: txHash,
              amountText: amountText,
              tokenSymbol: token.symbol,
              toAddress: toAddress,
              networkName: networkName,
            ),
          );
          unawaited(
            _walletHistoryService.recordSendConfirmed(
              walletAddress: _fromAddress!,
              txHash: txHash,
              chainId: effectiveChainId,
              networkName: networkName,
              tokenName: token.name,
              tokenSymbol: token.symbol,
              amountText: amountText,
              toAddress: toAddress,
              networkKey: transferNetworkKey,
            ),
          );
        }
      } else {
        progressController.setError(
          AppLocalizations.of(context).transactionPendingConfirmation,
          reference: _shortHash(txHash),
          detailsUrl: detailsUrl,
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      final l = AppLocalizations.of(context);
      progressController.setError(
        AppErrorUtils.userMessage(e, fallback: l.transactionFailed),
      );
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.select<CurrencyController, String>(
      (controller) => controller.currencyCode,
    );
    final token = _args?['token'] as Token?;
    final toAddress = _args?['toAddress'] as String? ?? '';
    final amountText = _args?['amount'] as String? ?? '0';
    final amountInBaseUnits =
        _args?['amountBaseUnits'] as BigInt? ?? BigInt.zero;
    final blockchain = Provider.of<BlockchainService>(context);
    final l = AppLocalizations.of(context);
    final transferFamily = _transferFamily(blockchain);
    final network = _networkNameForTransfer(blockchain);
    final nativeSymbol = _nativeSymbolForTransfer(blockchain);
    final symbol = token?.symbol ?? nativeSymbol;

    final isNative =
        token?.contractAddress == null ||
        (token?.contractAddress?.isEmpty ?? true);
    final parsedAmount = AmountUtils.formatBaseUnits(
      amountInBaseUnits,
      token?.decimals ?? 18,
    );
    final tokenUsdPrice = _tokenUsdPrice(blockchain, token);
    final amountValueText = tokenUsdPrice > 0
        ? ValueFormatter.formatCurrencyWithGrouping(
            ValueFormatter.decimalFromNum(
              (double.tryParse(parsedAmount) ?? 0.0) * tokenUsdPrice,
            ),
          )
        : '';
    final tokenRateText = tokenUsdPrice > 0 && symbol.isNotEmpty
        ? '1 ${ValueFormatter.currencyCode} -> ${ValueFormatter.formatTokenRateAmount(ValueFormatter.doubleFromDecimal(ValueFormatter.convertToUsdDecimal(Decimal.one)) / tokenUsdPrice)} $symbol'
        : '';
    final amountSubtitle = [
      if (amountValueText.isNotEmpty) amountValueText,
      if (tokenRateText.isNotEmpty) tokenRateText,
    ].join(' • ');
    final maxTotalDisplay = isNative
        ? '${AmountUtils.formatBaseUnits(amountInBaseUnits + _gasFeeWei, token?.decimals ?? 18)} $symbol'
        : '$amountText $symbol';

    final isEvmTransfer = transferFamily == ChainFamily.evm;
    final gasLabel = !isEvmTransfer
        ? l.networkFeeLabel
        : _gasEstimationFailed
        ? '${l.networkFeeLabel} (${l.estimationFailed})'
        : '${l.networkFeeLabel} (${_formatGasPriceGwei(_gasPriceGwei)} Gwei)';

    final gasValue = !isEvmTransfer
        ? _formatNonEvmNetworkFeeValue(transferFamily, nativeSymbol)
        : _gasEstimationFailed
        ? 'Error'
        : _formatGasFeeNative(_gasFeeEth, nativeSymbol);

    final gasValueUsd = _gasEstimationFailed || _gasFeeUsd <= 0
        ? ''
        : ValueFormatter.formatUsdValueOrLessThanCent(
            ValueFormatter.decimalFromNum(_gasFeeUsd),
          );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            EntranceMotion(
              beginOffset: const Offset(0, -0.04),
              child: TransferHeader(onBack: () => Navigator.pop(context)),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    EntranceMotion(
                      delay: const Duration(milliseconds: 70),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  l.confirmTransfer,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            AmountSummary(
                              amountText: parsedAmount,
                              symbol: symbol,
                              subtitle: amountSubtitle,
                            ),
                            const SizedBox(height: 28),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                l.transactionDetails,
                                style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TransactionDetailsCard(
                              fromAddress: _shortenAddress(_fromAddress),
                              toAddress: _shortenAddress(toAddress),
                              network: network,
                              token: token,
                              chainId: _tokenIconChainIdForTransfer(blockchain),
                              isLoadingGas: _isLoadingGas,
                              gasEstimationFailed: _gasEstimationFailed,
                              gasLabel: gasLabel,
                              gasValue: gasValue,
                              gasValueUsd: gasValueUsd,
                              totalLabel: isNative ? l.maxTotal : l.amount,
                              maxTotalDisplay: maxTotalDisplay,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    EntranceMotion(
                      delay: const Duration(milliseconds: 140),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: WarningBanner(message: l.transferWarningMessage),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            EntranceMotion(
              delay: const Duration(milliseconds: 210),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConfirmButton(
                  isLoading: _isConfirming,
                  onPressed: _confirmTransfer,
                  label: l.confirmTransfer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
