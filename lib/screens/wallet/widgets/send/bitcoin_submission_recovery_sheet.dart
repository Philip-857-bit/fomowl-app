import 'package:flutter/material.dart';
import '../../../../constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/bitcoin_account_state.dart';
import '../../../../models/bitcoin_network_data.dart';
import '../../../../services/bitcoin/bitcoin_submission_journal.dart';
import '../../../../services/bitcoin/bitcoin_submission_recovery_service.dart';

class BitcoinSubmissionRecoverySheet extends StatefulWidget {
  final String identity;
  final BitcoinProductNetwork network;
  final BitcoinSubmissionRecoveryService service;
  final Future<bool> Function() authenticate;
  final bool Function() isCurrent;
  const BitcoinSubmissionRecoverySheet({
    super.key,
    required this.identity,
    required this.network,
    required this.service,
    required this.authenticate,
    required this.isCurrent,
  });
  @override
  State<BitcoinSubmissionRecoverySheet> createState() => _RecoverySheetState();
}

class _RecoverySheetState extends State<BitcoinSubmissionRecoverySheet> {
  List<BitcoinPendingSubmission>? _entries;
  final Map<String, BitcoinTransactionStatus> _statuses = {};
  bool _busy = false;
  bool _confirming = false;
  String? _message;
  bool _current() => mounted && widget.isCurrent();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await widget.service.journal.pending(
        widget.identity,
        widget.network,
      );
      if (mounted && widget.isCurrent()) setState(() => _entries = entries);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = AppLocalizations.of(context).bitcoinRecoveryError,
        );
      }
    }
  }

  Future<void> _checkStatus(BitcoinPendingSubmission entry) async {
    if (_busy || _confirming || !widget.isCurrent()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final status = await widget.service.network
          .fetchTransactionStatus(entry.network, entry.txid)
          .timeout(const Duration(seconds: 8));
      if (mounted && widget.isCurrent()) {
        setState(() => _statuses[entry.txid] = status);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = AppLocalizations.of(context).bitcoinRecoveryError,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recover(BitcoinPendingSubmission entry) async {
    if (_busy || _confirming || !widget.isCurrent()) return;
    final l = AppLocalizations.of(context);
    setState(() => _confirming = true);
    var acknowledged = false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(l.bitcoinRecoveryAction),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.bitcoinRecoveryWarning),
              CheckboxListTile(
                key: const Key('bitcoin-recovery-acknowledge'),
                value: acknowledged,
                title: Text(l.bitcoinRecoveryAcknowledge),
                onChanged: (value) =>
                    update(() => acknowledged = value == true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l.closeLabel),
            ),
            FilledButton(
              key: const Key('bitcoin-recovery-proceed'),
              onPressed: acknowledged
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: Text(l.bitcoinRecoveryAction),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (proceed != true || !widget.isCurrent()) {
      setState(() => _busy = false);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.service.recover(
        entry,
        acknowledgedPreBroadcastRejection: acknowledged,
        authenticate: widget.authenticate,
        isCurrent: _current,
      );
      if (!mounted || !widget.isCurrent()) return;
      setState(() => _message = l.bitcoinRecoverySuccess);
      await _load();
    } catch (_) {
      if (mounted) setState(() => _message = l.bitcoinRecoveryError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final allowed =
        widget.service.journal.internalTestnetRecovery &&
        widget.network == BitcoinProductNetwork.testnet4;
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.85,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.bitcoinRecoveryTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              allowed ? l.bitcoinRecoveryWarning : l.bitcoinRecoveryUnavailable,
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _message!,
                  key: const Key('bitcoin-recovery-message'),
                ),
              ),
            Expanded(
              child: _entries == null
                  ? (_message == null
                        ? const Center(child: CircularProgressIndicator())
                        : const SizedBox.shrink())
                  : _entries!.isEmpty
                  ? Center(child: Text(l.bitcoinRecoveryEmpty))
                  : ListView.builder(
                      itemCount: _entries!.length,
                      itemBuilder: (context, index) {
                        final entry = _entries![index];
                        final status = _statuses[entry.txid];
                        return Card(
                          margin: const EdgeInsets.only(top: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.bitcoinTransactionId),
                                SelectableText(
                                  entry.txid,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                ExpansionTile(
                                  title: Text(
                                    '${l.bitcoinReservedInputs}: ${entry.inputs.length}',
                                  ),
                                  children: [
                                    SizedBox(
                                      height: 160,
                                      child: ListView.builder(
                                        itemCount: entry.inputs.length,
                                        itemBuilder: (context, i) => Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: SelectableText(
                                            entry.inputs[i],
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (status != null)
                                  Text(
                                    status.confirmed
                                        ? l.bitcoinConfirmed
                                        : status.found
                                        ? l.transactionSubmittedTitle
                                        : l.transactionSubmissionUnknownTitle,
                                  ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _checkStatus(entry),
                                  child: Text(l.bitcoinRecoveryCheck),
                                ),
                                if (allowed && entry.legacy)
                                  FilledButton(
                                    key: Key('bitcoin-recover-${entry.txid}'),
                                    onPressed: _busy || status?.found == true
                                        ? null
                                        : () => _recover(entry),
                                    child: Text(l.bitcoinRecoveryAction),
                                  ),
                              ],
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
