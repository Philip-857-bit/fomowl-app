import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/token.dart';
import '../../services/blockchain_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/amount_utils.dart';
import '../../utils/app_error_utils.dart';
import '../../utils/toast_utils.dart';
import '../../utils/value_formatter.dart';
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
    if (_fromAddress == null) _loadFromAddress();
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
    if (mounted) setState(() => _fromAddress = address);
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
    if (address == null || address.length < 10) return address ?? '--';
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  Future<void> _confirmTransfer() async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);

    final toAddress = _args?['toAddress'] as String? ?? '';
    final amountInBaseUnits =
        _args?['amountBaseUnits'] as BigInt? ?? BigInt.zero;

    try {
      // Refresh selected token price right before confirmation for accuracy
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final chain = blockchain.activeChain;
      final token = _args?['token'] as Token?;
      await blockchain.refreshPricesBeforeConfirmation(
        token == null ? const [] : [token],
      );

      final txHash = await _walletService.sendNativeTransaction(
        toAddress: toAddress,
        amountInBaseUnits: amountInBaseUnits,
        rpcUrl: chain.rpcUrl,
        chainId: chain.chainId,
      );

      if (mounted) {
        ToastUtils.showSuccess(
          '${AppLocalizations.of(context).transactionBroadcast}. Tx: ${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 6)}',
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (route) => false,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context);
        ToastUtils.showError(
          AppErrorUtils.userMessage(e, fallback: l.transactionFailed),
        );
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

    final isNative = token?.contractAddress == null;
    final parsedAmount = AmountUtils.formatBaseUnits(
      amountInBaseUnits,
      token?.decimals ?? 18,
    );
    final maxTotalDisplay = isNative
        ? '${AmountUtils.formatBaseUnits(amountInBaseUnits + _gasFeeWei, token?.decimals ?? 18)} $symbol'
        : '$amountText $symbol';

    final gasLabel = _gasEstimationFailed
        ? '${l.gasFee} (${l.estimationFailed})'
        : '${l.gasFee} (${_gasPriceGwei.toStringAsFixed(1)} Gwei)';

    final gasValue = _gasEstimationFailed
        ? 'Error'
        : '${_gasFeeEth.toStringAsFixed(6)} ${blockchain.activeChain.symbol}';

    final gasValueUsd = _gasEstimationFailed
        ? ''
        : '≈${ValueFormatter.formatUsdValue(ValueFormatter.decimalFromNum(_gasFeeUsd))}';

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
