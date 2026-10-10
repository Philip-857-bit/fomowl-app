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
  @override
  void initState() {
    super.initState();
    try {
      _txid = bitcoinTxid(widget.entry.txHash);
      _status =
          (widget.api ??
                  BitcoinNetworkService(timeout: const Duration(seconds: 8)))
              .fetchTransactionStatus(widget.network, _txid!);
    } on FormatException {
      // Invalid local metadata must not produce a receipt/RPC fallback.
    }
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
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            Widget detail(String label, String text) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  SelectableText(text),
                ],
              ),
            );
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  l.bitcoinTransaction,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: chainTheme.accentColor,
                  ),
                ),
                detail(
                  l.bitcoinStatus,
                  confirmations >= 1 ? l.bitcoinConfirmed : l.bitcoinPending,
                ),
                detail(l.bitcoinConfirmations, confirmations.toString()),
                detail(l.bitcoinBlockHeight, blockHeight?.toString() ?? '-'),
                detail(l.bitcoinTransactionId, _txid ?? '-'),
                detail(
                  widget.entry.bitcoin == null
                      ? l.bitcoinAmount
                      : l.bitcoinWalletChange,
                  '${_amount()} BTC',
                ),
                detail(
                  l.bitcoinNetworkFee,
                  known == null
                      ? '-'
                      : '${BitcoinAmountUtils.format(known.feeSats)} BTC (${known.feeSats} sats)',
                ),
                detail('Network', chain.name),
                detail(
                  l.bitcoinTimestamp,
                  timestamp == null
                      ? l.bitcoinPending
                      : DateTime.fromMillisecondsSinceEpoch(
                          timestamp * 1000,
                          isUtc: true,
                        ).toLocal().toString(),
                ),
                if (snapshot.hasError) Text(l.bitcoinStatusUnavailable),
                if (_txid != null)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: chainTheme.accentColor,
                    ),
                    onPressed: () =>
                        widget.onOpenExplorer('${chain.explorerUrl}/tx/$_txid'),
                    child: Text(l.bitcoinViewExplorer),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
