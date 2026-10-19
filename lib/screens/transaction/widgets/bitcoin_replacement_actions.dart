import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/bitcoin_account_state.dart';
import '../../../models/chain.dart';
import '../../../services/bitcoin/bitcoin_broadcast_service.dart';
import '../../../services/bitcoin/bitcoin_rbf_service.dart';
import '../../../services/blockchain_service.dart';
import '../../../services/wallet_vault_service.dart';
import '../../../theme/app_chain_theme.dart';
import '../../../utils/bitcoin_amount_utils.dart';
import '../../../utils/wallet_unlock_navigation.dart';
import 'history_detail_components.dart';

class BitcoinReplacementActions extends StatefulWidget {
  final String walletIdentity;
  final BitcoinProductNetwork network;
  final String txid;
  final BitcoinRbfService? service;
  final bool Function()? isCurrent;
  final Future<bool> Function(BuildContext)? authenticate;
  final Future<void> Function(
    BitcoinPreparedReplacement,
    BitcoinBroadcastOutcome,
  )?
  onSubmitted;
  const BitcoinReplacementActions({
    super.key,
    required this.walletIdentity,
    required this.network,
    required this.txid,
    this.service,
    this.isCurrent,
    this.authenticate,
    this.onSubmitted,
  });
  @override
  State<BitcoinReplacementActions> createState() =>
      _BitcoinReplacementActionsState();
}

class _BitcoinReplacementActionsState extends State<BitcoinReplacementActions> {
  late final BitcoinRbfService _service = widget.service ?? BitcoinRbfService();
  bool _available = false;
  bool _busy = false;
  bool _reviewing = false;
  bool _checking = false;
  int _generation = 0;
  String? _message;
  Timer? _timer;
  bool current() {
    if (!mounted) return false;
    if (widget.isCurrent != null) return widget.isCurrent!();
    final chain = context.read<BlockchainService>();
    return chain.activeFamily == ChainFamily.bitcoin &&
        chain.activeNetworkKey == widget.network.networkKey &&
        chain.activeWalletAddress.trim().toLowerCase() ==
            widget.walletIdentity.trim().toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    unawaited(refresh());
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_busy) unawaited(refresh());
    });
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (_checking || _busy || !current()) return;
    _checking = true;
    final generation = _generation;
    try {
      final result = await _service.available(
        widget.walletIdentity,
        widget.network,
        widget.txid,
        isCurrent: current,
      );
      if (current() && generation == _generation) {
        setState(() => _available = result);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _available = false);
      }
    } finally {
      _checking = false;
    }
  }

  String fee(BigInt sats) =>
      '${BitcoinAmountUtils.format(sats)} BTC ($sats sats)';
  ButtonStyle confirmationStyle() {
    final accent = context.chainTheme.accentColor;
    return FilledButton.styleFrom(
      backgroundColor: accent,
      foregroundColor: accent.computeLuminance() > 0.35
          ? Colors.black
          : Colors.white,
    );
  }

  Future<BigInt?> chooseRate() async {
    final candidates = await _service.journal.pending(
      widget.walletIdentity,
      widget.network,
    );
    final original = candidates
        .where((entry) => entry.txid == widget.txid && entry.active)
        .single;
    final oldRate = original.transaction!.plan.feeRateSatVb;
    final rates = await _service.network.fetchFeeRates(widget.network);
    if (!mounted || !current()) return null;
    final normalRate = BigInt.from(rates.normal);
    final suggested = normalRate > oldRate ? normalRate : oldRate + BigInt.one;
    return showDialog<BigInt>(
      context: context,
      builder: (_) => _BitcoinFeeRateDialog(
        oldRate: oldRate,
        suggested: suggested,
        confirmationStyle: confirmationStyle(),
      ),
    );
  }

  Future<void> replace() async {
    if (_busy || !current()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final l = AppLocalizations.of(context);
    var authenticationCancelled = false;
    try {
      setState(() => _reviewing = true);
      final rate = await chooseRate();
      if (!mounted || rate == null || !current()) return;
      setState(() => _reviewing = false);
      final prepared = await _service.prepare(
        widget.walletIdentity,
        widget.network,
        widget.txid,
        rate,
        isCurrent: current,
      );
      if (!mounted || !current()) return;
      setState(() => _reviewing = true);
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF14161A),
          title: Text(l.bitcoinSpeedUp),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HistoryDetailRow(
                  label: l.network,
                  value: widget.network == BitcoinProductNetwork.mainnet
                      ? 'Bitcoin'
                      : 'Bitcoin Testnet4',
                ),
                HistoryDetailRow(
                  label: l.historyToLabel,
                  value: prepared.transfer.plan.recipients
                      .map((recipient) => recipient.address)
                      .join('\n'),
                  monospace: true,
                ),
                HistoryDetailRow(
                  label: l.amount,
                  value:
                      '${BitcoinAmountUtils.format(prepared.transfer.plan.recipientTotalSat)} BTC',
                ),
                HistoryDetailRow(
                  label: l.bitcoinRbfOriginalFee,
                  value: fee(prepared.originalFeeSat),
                ),
                HistoryDetailRow(
                  label: l.bitcoinRbfReplacementFee,
                  value: fee(prepared.replacementFeeSat),
                ),
                HistoryDetailRow(
                  label: l.bitcoinRbfAdditionalFee,
                  value: fee(prepared.additionalFeeSat),
                ),
                HistoryDetailRow(
                  label: l.bitcoinRbfNewRate,
                  value: '${prepared.transfer.plan.feeRateSatVb} sat/vB',
                ),
                const SizedBox(height: 12),
                Text(l.bitcoinRbfWarning),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              key: const Key('bitcoin-rbf-approve'),
              style: confirmationStyle(),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l.confirmTransfer),
            ),
          ],
        ),
      );
      if (approved != true || !current()) return;
      setState(() => _reviewing = false);
      final outcome = await _service.submit(
        prepared,
        authenticate: () async {
          await WalletVaultService.lockAll();
          if (!mounted || !current()) return false;
          final unlocked =
              await (widget.authenticate?.call(context) ??
                  requestWalletUnlock(context));
          authenticationCancelled = unlocked != true;
          return unlocked == true && current();
        },
        isCurrent: current,
      );
      if (!mounted || !current()) return;
      setState(() {
        _available = false;
        _message = outcome.status == BitcoinSubmissionStatus.accepted
            ? l.bitcoinRbfSubmitted
            : l.bitcoinRbfUnknown;
      });
      await widget.onSubmitted?.call(prepared, outcome);
    } catch (_) {
      if (mounted && !authenticationCancelled) {
        setState(() => _message = l.bitcoinRbfUnavailable);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _reviewing = false;
        });
        unawaited(refresh());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (widget.isCurrent == null) {
      context.select<BlockchainService, String>(
        (chain) => '${chain.activeNetworkKey}|${chain.activeWalletAddress}',
      );
    }
    if (!current() || (!_available && _message == null)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          if (_available)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('bitcoin-speed-up'),
                onPressed: _busy ? null : replace,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.chainTheme.accentColor,
                ),
                child: Text(l.bitcoinSpeedUp),
              ),
            ),
          if (_busy && !_reviewing)
            Padding(
              padding: const EdgeInsets.all(12),
              child: CircularProgressIndicator(
                key: const Key('bitcoin-rbf-progress'),
                color: context.chainTheme.accentColor,
              ),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _message!,
                key: const Key('bitcoin-rbf-result'),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }
}

class _BitcoinFeeRateDialog extends StatefulWidget {
  final BigInt oldRate;
  final BigInt suggested;
  final ButtonStyle confirmationStyle;
  const _BitcoinFeeRateDialog({
    required this.oldRate,
    required this.suggested,
    required this.confirmationStyle,
  });
  @override
  State<_BitcoinFeeRateDialog> createState() => _BitcoinFeeRateDialogState();
}

class _BitcoinFeeRateDialogState extends State<_BitcoinFeeRateDialog> {
  late final TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.suggested.toString());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final value = RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(controller.text)
        ? BigInt.tryParse(controller.text)
        : null;
    final valid =
        value != null && value > widget.oldRate && value.bitLength <= 64;
    return AlertDialog(
      backgroundColor: const Color(0xFF14161A),
      title: Text(l.bitcoinSpeedUp),
      content: TextField(
        key: const Key('bitcoin-rbf-rate'),
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: l.bitcoinFeeRate,
          suffixText: 'sat/vB',
          errorText: valid ? null : l.bitcoinRbfHigherFee,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const Key('bitcoin-rbf-prepare'),
          style: widget.confirmationStyle,
          onPressed: valid ? () => Navigator.pop(context, value) : null,
          child: Text(l.continue_),
        ),
      ],
    );
  }
}
