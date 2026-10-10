import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import 'widgets/history_detail_components.dart';
import '../../theme/app_chain_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_network_data.dart';
import '../../services/bitcoin/bitcoin_network_service.dart';
import '../../services/blockchain/bitcoin_catalog.dart';
import '../../services/wallet_history_service.dart';
import '../../utils/bitcoin_amount_utils.dart';

class BitcoinTransactionDetailsSheet extends StatefulWidget {
  final WalletHistoryEntry entry;
  final BitcoinProductNetwork network;
  final BitcoinNetworkApi? api;
  final Future<void> Function(String url) onOpenExplorer;
  const BitcoinTransactionDetailsSheet({
    super.key,
    required this.entry,
    required this.network,
    required this.onOpenExplorer,
    this.api,
  });
  @override
  State<BitcoinTransactionDetailsSheet> createState() =>
      _BitcoinTransactionDetailsSheetState();
}

class _BitcoinTransactionDetailsSheetState
    extends State<BitcoinTransactionDetailsSheet> {
  Future<BitcoinTransactionStatus>? _status;
  String? _txid;
  Timer? _refreshTimer;
  bool _fetching = false;
  late final BitcoinNetworkApi _api =
      widget.api ?? BitcoinNetworkService(timeout: const Duration(seconds: 8));
  @override
  void initState() {
    super.initState();
    try {
      _txid = bitcoinTxid(widget.entry.txHash);
      _status = _fetchStatus();
      _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted && !_fetching) {
          final next = _fetchStatus();
          setState(() {
            _status = next;
          });
        }
      });
    } on FormatException {
      // Invalid local metadata must not produce a receipt/RPC fallback.
    }
  }

  Future<BitcoinTransactionStatus> _fetchStatus() async {
    _fetching = true;
    try {
      final status = await _api
          .fetchTransactionStatus(widget.network, _txid!)
          .timeout(const Duration(seconds: 8));
      if (status.confirmed && status.confirmations >= 1) {
        _refreshTimer?.cancel();
      }
      return status;
    } finally {
      _fetching = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _amount() {
    final exact = widget.entry.bitcoin?.deltaSats.abs();
    if (exact != null) return BitcoinAmountUtils.format(exact);
    return BitcoinAmountUtils.formatLegacyDisplay(widget.entry.amount);
  }

  @override
  Widget build(BuildContext context) {
    final chainTheme = context.chainTheme;
    final l =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
    final known = widget.entry.bitcoin?.transaction;
    final chain = widget.network == BitcoinProductNetwork.mainnet
        ? BitcoinCatalog.mainnet
        : BitcoinCatalog.testnet4;
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
              child: FutureBuilder<BitcoinTransactionStatus>(
                future: _status,
                builder: (context, snapshot) {
                  final current = snapshot.data;
                  final confirmations =
                      current?.confirmations ?? known?.confirmations ?? 0;
                  final blockHeight = current != null
                      ? current.blockHeight
                      : known?.blockHeight;
                  final timestamp = current != null
                      ? current.timestamp
                      : known?.timestamp;
                  final submitted = current?.found ?? known != null;
                  Widget detail(
                    String label,
                    String text, {
                    Color? color,
                    bool monospace = false,
                  }) => HistoryDetailRow(
                    label: label,
                    value: text,
                    valueColor: color,
                    monospace: monospace,
                  );
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      Text(
                        l.bitcoinTransaction,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 18),
                      HistoryDetailSection(
                        children: [
                          detail(
                            widget.entry.bitcoin == null
                                ? l.bitcoinAmount
                                : l.bitcoinWalletChange,
                            '${_amount()} BTC',
                          ),
                          detail(l.network, chain.name),
                          detail(
                            l.bitcoinStatus,
                            confirmations >= 1
                                ? l.bitcoinConfirmed
                                : submitted
                                ? l.transactionSubmittedTitle
                                : l.bitcoinPending,
                            color: confirmations >= 1
                                ? AppColors.success
                                : chainTheme.accentColor,
                          ),
                          detail(
                            l.bitcoinConfirmations,
                            confirmations.toString(),
                          ),
                          detail(
                            l.bitcoinBlockHeight,
                            blockHeight?.toString() ?? '-',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      HistoryDetailSection(
                        children: [
                          detail(
                            l.bitcoinTransactionId,
                            _txid ?? '-',
                            monospace: true,
                          ),
                          detail(
                            l.bitcoinNetworkFee,
                            known == null
                                ? '-'
                                : '${BitcoinAmountUtils.format(known.feeSats)} BTC (${known.feeSats} sats)',
                          ),
                          detail(
                            l.bitcoinTimestamp,
                            timestamp == null
                                ? l.bitcoinPending
                                : DateTime.fromMillisecondsSinceEpoch(
                                    timestamp * 1000,
                                    isUtc: true,
                                  ).toLocal().toString(),
                          ),
                        ],
                      ),
                      if (snapshot.hasError) ...[
                        const SizedBox(height: 14),
                        HistoryInfoBanner(message: l.bitcoinStatusUnavailable),
                      ],
                      if (_txid != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: chainTheme.accentColor,
                              foregroundColor:
                                  chainTheme.accentColor.computeLuminance() >
                                      0.35
                                  ? Colors.black
                                  : Colors.white,
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => widget.onOpenExplorer(
                              '${chain.explorerUrl}/tx/$_txid',
                            ),
                            child: Text(l.bitcoinViewExplorer),
                          ),
                        ),
                    ],
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
