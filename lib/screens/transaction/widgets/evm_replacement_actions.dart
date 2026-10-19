import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/chain.dart';
import '../../../models/evm_outbound_transaction.dart';
import '../../../models/evm_fee_quote.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/blockchain_service.dart';
import '../../../services/wallet_service.dart';
import '../../../services/wallet_vault_service.dart';
import '../../../services/evm_replacement_service.dart';
import '../../../theme/app_chain_theme.dart';
import '../../../utils/amount_utils.dart';
import '../../../utils/wallet_unlock_navigation.dart';
import 'history_detail_components.dart';

class EvmReplacementActions extends StatefulWidget {
  final WalletService wallet;
  final EvmChain chain;
  final String sender;
  final String hash;
  final EvmReplacementService? service;
  final bool Function()? isCurrent;
  final Future<bool> Function(BuildContext)? authenticate;
  final Future<void> Function(String hash)? onSubmitted;
  const EvmReplacementActions({
    super.key,
    required this.wallet,
    required this.chain,
    required this.sender,
    required this.hash,
    this.service,
    this.isCurrent,
    this.authenticate,
    this.onSubmitted,
  });
  @override
  State<EvmReplacementActions> createState() => _EvmReplacementActionsState();
}

class _EvmReplacementActionsState extends State<EvmReplacementActions> {
  late final EvmReplacementService service =
      widget.service ?? widget.wallet.evmReplacements(widget.chain.rpcUrl);
  EvmReplacementAvailability? availability;
  bool busy = false;
  bool reviewing = false;
  bool checking = false;
  int generation = 0;
  String? message;
  Timer? timer;
  bool current() {
    if (!mounted) return false;
    if (widget.isCurrent != null) return widget.isCurrent!();
    final chain = context.read<BlockchainService>();
    return chain.activeNetworkKey == widget.chain.networkKey &&
        chain.activeWalletAddress.toLowerCase() == widget.sender.toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    unawaited(refresh());
    timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!busy) unawaited(refresh());
    });
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (checking || !current()) return;
    checking = true;
    final epoch = generation;
    try {
      final next = await service.availability(
        widget.sender,
        widget.chain.chainId,
        widget.hash,
        isCurrent: current,
      );
      if (current() && epoch == generation) setState(() => availability = next);
    } finally {
      checking = false;
    }
  }

  String fee(BigInt wei) =>
      '${AmountUtils.formatBaseUnits(wei, 18, maxFractionDigits: 18)} ${widget.chain.symbol}';
  Future<void> replace(EvmReplacementKind kind) async {
    if (busy || !current()) return;
    setState(() {
      busy = true;
      message = null;
    });
    final l = AppLocalizations.of(context);
    try {
      final prepared = await service.prepare(
        widget.sender,
        widget.chain.chainId,
        widget.hash,
        kind,
        isCurrent: current,
      );
      if (!mounted || !current()) return;
      setState(() => reviewing = true);
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF14161A),
          title: Text(
            kind == EvmReplacementKind.cancel
                ? l.evmCancelTransaction
                : l.evmSpeedUp,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HistoryDetailRow(label: l.network, value: widget.chain.name),
                HistoryDetailRow(
                  label: l.historyTransactionHashLabel,
                  value: prepared.original.hash,
                  monospace: true,
                ),
                HistoryDetailRow(
                  label: l.historyToLabel,
                  value: prepared.fields.destination,
                  monospace: true,
                ),
                if (prepared.fields.dataHex == '0x')
                  HistoryDetailRow(
                    label: l.amount,
                    value: fee(prepared.fields.valueWei),
                  ),
                HistoryDetailRow(
                  label: l.evmOldFee,
                  value: fee(prepared.oldEstimatedFeeWei),
                ),
                HistoryDetailRow(
                  label: l.evmNewFee,
                  value: fee(prepared.newEstimatedFeeWei),
                ),
                HistoryDetailRow(
                  label: l.evmAdditionalFee,
                  value: fee(prepared.additionalEstimatedFeeWei),
                ),
                HistoryDetailRow(
                  label: l.evmMaximumFee,
                  value: fee(prepared.maximumFeeWei),
                ),
                const SizedBox(height: 12),
                Text(
                  kind == EvmReplacementKind.cancel
                      ? l.evmCancelWarning
                      : l.evmSpeedUpWarning,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              key: const Key('evm-approve-replacement'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l.confirmTransfer),
            ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() => reviewing = false);
      if (approved != true || !current()) return;
      await WalletVaultService.lockAll();
      if (!mounted || !current()) return;
      final unlocked =
          await (widget.authenticate?.call(context) ??
              requestWalletUnlock(context));
      if (!mounted || unlocked != true || !current()) return;
      final hash = await service.submit(prepared, isCurrent: current);
      if (!mounted || !current()) return;
      setState(() {
        availability = const EvmReplacementAvailability(
          pending: false,
          canCancel: false,
        );
        message = l.evmReplacementSubmitted;
      });
      await widget.onSubmitted?.call(hash);
    } catch (error) {
      if (mounted) {
        setState(
          () => message = error is EvmFeeQuoteException
              ? l.evmFeeQuoteUpdated
              : l.evmReplacementCheckOutcome,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          reviewing = false;
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
    if (!current() || (availability?.pending != true && message == null)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          if (availability?.pending == true)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('evm-speed-up'),
                    onPressed: busy
                        ? null
                        : () => replace(EvmReplacementKind.speedUp),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.chainTheme.accentColor,
                    ),
                    child: Text(l.evmSpeedUp),
                  ),
                ),
                if (availability?.canCancel == true) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('evm-cancel-transaction'),
                      onPressed: busy
                          ? null
                          : () => replace(EvmReplacementKind.cancel),
                      child: Text(l.evmCancelTransaction),
                    ),
                  ),
                ],
              ],
            ),
          if (busy && !reviewing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                message!,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }
}
