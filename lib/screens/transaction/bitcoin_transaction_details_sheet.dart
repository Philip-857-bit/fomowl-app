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
                  'Bitcoin transaction',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                detail('Status', confirmations >= 1 ? 'Confirmed' : 'Pending'),
                detail('Confirmations', confirmations.toString()),
                detail('Block height', blockHeight?.toString() ?? '-'),
                detail('Transaction ID', _txid ?? '-'),
                detail(
                  widget.entry.bitcoin == null ? 'Amount' : 'Wallet change',
                  '${_amount()} BTC',
                ),
                detail(
                  'Network fee',
                  known == null
                      ? '-'
                      : '${BitcoinAmountUtils.format(known.feeSats)} BTC (${known.feeSats} sats)',
                ),
                detail('Network', chain.name),
                detail(
                  'Timestamp',
                  timestamp == null
                      ? 'Pending'
                      : DateTime.fromMillisecondsSinceEpoch(
                          timestamp * 1000,
                          isUtc: true,
                        ).toLocal().toString(),
                ),
                if (snapshot.hasError)
                  const Text('Latest transaction status is unavailable.'),
                if (_txid != null)
                  TextButton(
                    onPressed: () =>
                        widget.onOpenExplorer('${chain.explorerUrl}/tx/$_txid'),
                    child: const Text('View in explorer'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
