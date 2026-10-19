import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web3dart/web3dart.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chain.dart';
import '../../models/evm_outbound_transaction.dart';
import '../../models/non_evm_receipt_facts.dart';
import '../../services/non_evm_receipt_service.dart';
import '../../services/wallet_history_service.dart';
import '../../services/wallet_service.dart';
import '../../theme/app_chain_theme.dart';
import '../../utils/amount_utils.dart';
import '../../widgets/advanced_transaction_details.dart';
import '../../widgets/transaction_protocol_details.dart';
import 'widgets/evm_replacement_actions.dart';
import 'widgets/history_detail_components.dart';

/// Shared presentation with separate, read-only receipt paths for each family.
class HistoryTransactionDetailsSheet extends StatefulWidget {
  const HistoryTransactionDetailsSheet({
    super.key,
    required this.entry,
    required this.chain,
    required this.explorerUrl,
    required this.walletService,
    required this.titleText,
    required this.messageText,
    required this.amountText,
    required this.timestampText,
    required this.networkText,
    required this.onOpenExplorer,
    this.receiptService,
  });
  final WalletHistoryEntry entry;
  final EvmChain? chain;
  final String? explorerUrl;
  final WalletService walletService;
  final String titleText, messageText, amountText, timestampText, networkText;
  final Future<void> Function(String url) onOpenExplorer;
  final NonEvmReceiptService? receiptService;
  @override
  State<HistoryTransactionDetailsSheet> createState() =>
      _HistoryTransactionDetailsSheetState();
}

class _HistoryTransactionDetailsSheetState
    extends State<HistoryTransactionDetailsSheet> {
  Future<TransactionReceipt?>? _evmReceipt;
  Future<EvmOutboundTransaction?>? _outbound;
  Future<NonEvmReceiptFacts>? _nativeReceipt;
  String get _hash => widget.entry.txHash?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  @override
  void didUpdateWidget(covariant HistoryTransactionDetailsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.txHash != widget.entry.txHash ||
        oldWidget.entry.walletAddress != widget.entry.walletAddress ||
        oldWidget.entry.networkKey != widget.entry.networkKey ||
        oldWidget.chain?.chainId != widget.chain?.chainId ||
        oldWidget.chain?.rpcUrl != widget.chain?.rpcUrl ||
        !identical(oldWidget.walletService, widget.walletService) ||
        !identical(oldWidget.receiptService, widget.receiptService)) {
      _loadReceipts();
    }
  }

  void _loadReceipts() {
    _evmReceipt = null;
    _outbound = null;
    _nativeReceipt = null;
    final key = widget.entry.networkKey?.trim() ?? '';
    if ((key.isEmpty || key.startsWith('evm:')) &&
        widget.chain != null &&
        widget.chain!.rpcUrl.trim().isNotEmpty &&
        (widget.entry.chainId == null ||
            widget.entry.chainId == widget.chain!.chainId) &&
        (key.isEmpty ||
            NetworkKey.evmChainIdOf(key) == widget.chain!.chainId) &&
        RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(_hash)) {
      _evmReceipt = widget.walletService
          .getTransactionReceipt(txHash: _hash, rpcUrl: widget.chain!.rpcUrl)
          .timeout(const Duration(seconds: 10));
      _outbound = _loadOutbound();
    } else if (key.startsWith('solana:') || key.startsWith('tron:')) {
      _nativeReceipt = (widget.receiptService ?? NonEvmReceiptService()).fetch(
        networkKey: key,
        transactionHash: _hash,
      );
    }
  }

  Future<EvmOutboundTransaction?> _loadOutbound() async {
    try {
      final record =
          (await widget.walletService.evmOutbound
                  .snapshot(
                    widget.entry.walletAddress,
                    widget.chain!.chainId,
                    _hash,
                  )
                  .timeout(const Duration(seconds: 2)))
              ?.transaction;
      if (record?.fields.sender ==
          widget.entry.walletAddress.trim().toLowerCase()) {
        return record;
      }
    } catch (_) {
      // Optional public metadata cannot suppress the chain receipt.
    }
    return null;
  }

  Widget _status(AppLocalizations l, bool? success, {bool pending = false}) =>
      HistoryDetailRow(
        label: l.historyStatusLabel,
        value: pending
            ? l.pendingLabel
            : success == null
            ? l.transactionUnavailable
            : success
            ? l.confirmedLabel
            : l.failedLabel,
        valueColor: success == true
            ? AppColors.success
            : success == false
            ? AppColors.accentRed
            : Colors.white70,
      );

  Widget _evm(AppLocalizations l) => FutureBuilder<EvmOutboundTransaction?>(
    future: _outbound,
    builder: (context, record) => FutureBuilder<TransactionReceipt?>(
      future: _evmReceipt,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return HistoryInfoBanner(
            message: l.historyLoadingReceipt,
            loading: true,
          );
        }
        final receipt = snapshot.data;
        if (snapshot.hasError ||
            receipt != null &&
                !TransactionProtocolDetails.matchesReceipt(receipt, _hash)) {
          return HistoryInfoBanner(message: l.historyReceiptLoadError);
        }
        final fee = receipt == null
            ? null
            : TransactionProtocolDetails.executionFee(receipt);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HistoryDetailSection(
              children: [
                _status(
                  l,
                  receipt?.status,
                  pending: receipt == null || receipt.blockNumber.isPending,
                ),
                if (receipt?.from != null)
                  HistoryDetailRow(
                    label: l.historyFromLabel,
                    value: receipt!.from!.hexEip55,
                    monospace: true,
                  ),
                if (receipt?.to != null)
                  HistoryDetailRow(
                    label: l.historyToLabel,
                    value: receipt!.to!.hexEip55,
                    monospace: true,
                  ),
                if (fee != null)
                  HistoryDetailRow(
                    label: l.transactionExecutionFee,
                    value:
                        '${AmountUtils.formatBaseUnits(fee, 18, maxFractionDigits: 18)} ${widget.chain!.symbol}',
                  ),
              ],
            ),
            const SizedBox(height: 14),
            AdvancedTransactionDetails(
              key: ValueKey('receipt-advanced-$_hash'),
              title: l.advancedTransactionDetails,
              items: TransactionProtocolDetails.evmReceipt(
                l,
                expectedHash: _hash,
                chainId: widget.chain!.chainId,
                nativeSymbol: widget.chain!.symbol,
                outbound: record.data,
                receipt: receipt,
              ),
            ),
            if (receipt == null) ...[
              const SizedBox(height: 14),
              HistoryInfoBanner(message: l.historyReceiptPending),
              if (!widget.entry.isIncoming)
                EvmReplacementActions(
                  wallet: widget.walletService,
                  chain: widget.chain!,
                  sender: widget.entry.walletAddress,
                  hash: _hash,
                  onSubmitted: (_) async {},
                ),
            ],
          ],
        );
      },
    ),
  );

  Widget _nonEvm(AppLocalizations l) => FutureBuilder<NonEvmReceiptFacts>(
    future: _nativeReceipt,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return HistoryInfoBanner(
          message: l.historyLoadingReceipt,
          loading: true,
        );
      }
      final facts = snapshot.data;
      if (snapshot.hasError || facts == null) {
        return HistoryInfoBanner(message: l.historyReceiptLoadError);
      }
      final solana = facts.networkKey.startsWith('solana:');
      final fee = facts.feeBaseUnits;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HistoryDetailSection(
            children: [
              _status(l, facts.success, pending: facts.pending),
              HistoryDetailRow(
                label: l.networkFeeLabel,
                value: fee == null
                    ? l.transactionUnavailable
                    : '${AmountUtils.formatBaseUnits(fee, solana ? 9 : 6, maxFractionDigits: solana ? 9 : 6)} ${solana ? 'SOL' : 'TRX'}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          AdvancedTransactionDetails(
            key: ValueKey('receipt-advanced-$_hash'),
            title: l.advancedTransactionDetails,
            items: TransactionProtocolDetails.nonEvmReceipt(l, facts),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accent = context.chainTheme.accentColor;
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.transactionDetails,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.titleText,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.messageText,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: 18),
                    HistoryDetailSection(
                      children: [
                        if (widget.amountText.isNotEmpty)
                          HistoryDetailRow(
                            label: l.amount,
                            value: widget.amountText,
                          ),
                        HistoryDetailRow(
                          label: l.network,
                          value: widget.networkText,
                        ),
                        HistoryDetailRow(
                          label: l.historyTimestampLabel,
                          value: widget.timestampText,
                        ),
                        if (widget.entry.tokenName?.trim().isNotEmpty == true)
                          HistoryDetailRow(
                            label: l.tokenLabel,
                            value:
                                '${widget.entry.tokenName} (${widget.entry.tokenSymbol ?? '-'})',
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_evmReceipt != null)
                      _evm(l)
                    else if (_nativeReceipt != null)
                      _nonEvm(l)
                    else
                      HistoryInfoBanner(message: l.historyReceiptUnavailable),
                    if (widget.explorerUrl?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () =>
                            widget.onOpenExplorer(widget.explorerUrl!),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: accent.computeLuminance() > 0.35
                              ? Colors.black
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(l.viewOnExplorer),
                      ),
                    ],
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
