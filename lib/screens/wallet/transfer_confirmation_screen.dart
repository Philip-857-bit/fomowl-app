import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/token.dart';
import '../../services/blockchain_service.dart';
import '../../services/transaction_monitor.dart';
import '../../services/wallet_notification_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/amount_utils.dart';
import '../../utils/app_error_utils.dart';
import '../../utils/value_formatter.dart';
import '../../widgets/wallet_signing_sheet.dart';
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

      double nativePrice = 0;
      if (effectiveCoinId != null && effectiveCoinId.isNotEmpty) {
        final prices = await blockchain.getTokenPrices([effectiveCoinId]);
        nativePrice = prices[effectiveCoinId] ?? 0;
      }

      final gasData = await blockchain.estimateGasFee(
        nativePriceUsd: nativePrice,
      );
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
    return '${value.toStringAsFixed(decimals)} $symbol';
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
              terminalRouteName: '/home',
              clearStackOnTerminalRoute: true,
            ),
          )
          .whenComplete(controller.dispose),
    );
    return controller;
  }

  Future<bool> _requestTransferSignature({
    required BlockchainService blockchain,
    required String toAddress,
    required String amountText,
    required String symbol,
  }) {
    final networkName = blockchain.activeChain.name;
    final gasLabel = _gasEstimationFailed
        ? 'Gas estimate unavailable'
        : '${_gasFeeEth.toStringAsFixed(6)} ${blockchain.activeChain.symbol}';

    return WalletSigningSheet.show(
      context,
      title: 'Sign transfer',
      confirmLabel: 'Sign',
      subtitle:
          'Review the transfer details below. This signature is created locally on this device.',
      note:
          'Only sign if the recipient address and amount are correct. Signed transfers cannot be reversed.',
      fields: [
        WalletSigningField(label: 'From', value: _shortenAddress(_fromAddress)),
        WalletSigningField(label: 'To', value: _shortenAddress(toAddress)),
        WalletSigningField(label: 'Amount', value: '$amountText $symbol'),
        WalletSigningField(label: 'Network', value: networkName),
        WalletSigningField(label: 'Est. gas', value: gasLabel),
      ],
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
    final approved = await _requestTransferSignature(
      blockchain: blockchain,
      toAddress: toAddress,
      amountText: amountText,
      symbol: token?.symbol ?? blockchain.activeChain.symbol,
    );
    if (!approved) {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
      return;
    }

    final progressController = _openProgressFlow();
    progressController.setPreparing();

    try {
      final chain = blockchain.activeChain;
      await blockchain.refreshPricesBeforeConfirmation(
        token == null ? const [] : [token],
      );

      progressController.setSwapSubmitting();

      final isNative =
          token?.contractAddress == null ||
          (token?.contractAddress?.isEmpty ?? true);
      if (isNative && _fromAddress != null) {
        final availableBalance = await blockchain.getNativeBalanceBaseUnits(
          _fromAddress!,
        );
        if (amountInBaseUnits + _gasFeeWei > availableBalance) {
          progressController.setError(
            'Insufficient ${chain.symbol} to cover the transfer amount and gas fee.',
          );
          return;
        }
      }

      final txHash = await _walletService.sendNativeTransaction(
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
        }
        progressController.setSuccess(
          reference: _shortHash(txHash),
          detailsUrl: detailsUrl,
        );
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
        ? '${l.gasFee} (${l.estimationFailed})'
        : '${l.gasFee} (${_formatGasPriceGwei(_gasPriceGwei)} Gwei)';

    final gasValue = _gasEstimationFailed
        ? 'Error'
        : _formatGasFeeNative(_gasFeeEth, blockchain.activeChain.symbol);

    final gasValueUsd = _gasEstimationFailed
        ? ''
        : '~${ValueFormatter.formatUsdValue(ValueFormatter.decimalFromNum(_gasFeeUsd))}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            TransferHeader(onBack: () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
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
                                    color: Colors.white.withValues(alpha: 0.1),
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
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: WarningBanner(message: l.transferWarningMessage),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ConfirmButton(
                isLoading: _isConfirming,
                onPressed: _confirmTransfer,
                label: l.confirmTransfer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
