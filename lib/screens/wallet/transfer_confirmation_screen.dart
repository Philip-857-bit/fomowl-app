import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/token.dart';
import '../../services/blockchain_service.dart';
import '../../services/wallet_history_service.dart';
import '../../services/transaction_monitor.dart';
import '../../services/wallet_notification_service.dart';
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

  Future<void> _loadFromAddress() async {
    final address = await _walletService.getCurrentWalletAddress();
    if (mounted) {
      setState(() => _fromAddress = address);
    }
    _fetchGasEstimate();
  }

  Future<void> _fetchGasEstimate() async {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final effectiveCoinId = blockchain.activeChain.coinGeckoId;
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
              rpcUrl: blockchain.activeChain.rpcUrl,
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

  String? _transactionDetailsUrl(String hash, BlockchainService blockchain) {
    if (!RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(hash)) {
      return null;
    }
    final explorerUrl = blockchain.activeChain.explorerUrl?.trim();
    if (explorerUrl == null || explorerUrl.isEmpty) {
      return null;
    }
    final normalized = explorerUrl.endsWith('/')
        ? explorerUrl.substring(0, explorerUrl.length - 1)
        : explorerUrl;
    return '$normalized/tx/$hash';
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
    required int chainId,
  }) async {
    final walletAddress = _fromAddress;
    if (walletAddress == null || walletAddress.isEmpty) {
      return;
    }

    await blockchain.refreshWalletTokens(walletAddress, chainId: chainId);
    unawaited(
      Future<void>.delayed(const Duration(seconds: 3), () async {
        try {
          await blockchain.refreshWalletTokens(walletAddress, chainId: chainId);
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
      final chain = blockchain.activeChain;
      progressController.setSwapSubmitting();

      final isNative =
          token?.contractAddress == null ||
          (token?.contractAddress?.isEmpty ?? true);
      if (_fromAddress != null) {
        final availableBalance = await blockchain.getNativeBalanceBaseUnits(
          _fromAddress!,
        );
        if (isNative && amountInBaseUnits + _gasFeeWei > availableBalance) {
          progressController.setError(
            'Insufficient ${chain.symbol} to cover the transfer amount and gas fee.',
          );
          return;
        }
        if (!isNative && _gasFeeWei > availableBalance) {
          progressController.setError(
            'Insufficient ${chain.symbol} to cover the network gas fee for this token transfer.',
          );
          return;
        }
      }

      final txHash = isNative
          ? await _walletService.sendNativeTransaction(
              toAddress: toAddress,
              amountInBaseUnits: amountInBaseUnits,
              rpcUrl: chain.rpcUrl,
              chainId: chain.chainId,
            )
          : await _walletService.sendTokenTransaction(
              tokenAddress: token!.contractAddress!,
              toAddress: toAddress,
              amountInBaseUnits: amountInBaseUnits,
              rpcUrl: chain.rpcUrl,
              chainId: chain.chainId,
            );

      final detailsUrl = _transactionDetailsUrl(txHash, blockchain);
      progressController.setSwapPending(
        reference: _shortHash(txHash),
        detailsUrl: detailsUrl,
      );

      final confirmed = await _transactionMonitor.waitForConfirmation(
        txHash: txHash,
        blockchain: blockchain,
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
            chainId: chain.chainId,
          ),
        );
        if (_fromAddress != null && token != null) {
          unawaited(
            _walletNotificationService.notifySendConfirmed(
              walletAddress: _fromAddress!,
              amountText: amountText,
              tokenSymbol: token.symbol,
              toAddress: toAddress,
              networkName: chain.name,
            ),
          );
          unawaited(
            _walletHistoryService.recordSendConfirmed(
              walletAddress: _fromAddress!,
              txHash: txHash,
              chainId: chain.chainId,
              networkName: chain.name,
              tokenName: token.name,
              tokenSymbol: token.symbol,
              amountText: amountText,
              toAddress: toAddress,
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
    final token = _args?['token'] as Token?;
    final toAddress = _args?['toAddress'] as String? ?? '';
    final amountText = _args?['amount'] as String? ?? '0';
    final amountInBaseUnits =
        _args?['amountBaseUnits'] as BigInt? ?? BigInt.zero;
    final network = _args?['network'] as String? ?? 'Ethereum';
    final symbol = token?.symbol ?? 'ETH';
    final blockchain = Provider.of<BlockchainService>(context);
    final l = AppLocalizations.of(context);

    final isNative =
        token?.contractAddress == null ||
        (token?.contractAddress?.isEmpty ?? true);
    final parsedAmount = AmountUtils.formatBaseUnits(
      amountInBaseUnits,
      token?.decimals ?? 18,
    );
    final maxTotalDisplay = isNative
        ? '${AmountUtils.formatBaseUnits(amountInBaseUnits + _gasFeeWei, token?.decimals ?? 18)} $symbol'
        : '$amountText $symbol';

    final gasLabel = _gasEstimationFailed
        ? '${l.networkFeeLabel} (${l.estimationFailed})'
        : '${l.networkFeeLabel} (${_formatGasPriceGwei(_gasPriceGwei)} Gwei)';

    final gasValue = _gasEstimationFailed
        ? 'Error'
        : _formatGasFeeNative(_gasFeeEth, blockchain.activeChain.symbol);

    final gasValueUsd = _gasEstimationFailed
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
                              chainId: blockchain.activeChain.chainId,
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
