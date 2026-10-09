import 'package:flutter/material.dart';
import '../../models/bitcoin_account_state.dart';
import '../../services/bitcoin/bitcoin_native_crypto.dart';
import '../../services/bitcoin/bitcoin_send_service.dart';
import '../../src/rust/api/bitcoin_transaction.dart';
import '../../utils/bitcoin_amount_utils.dart';

/// Displays and approves one immutable SDK plan. It never estimates EVM gas.
class BitcoinTransferConfirmationScreen extends StatefulWidget {
  final BitcoinPreparedTransfer transfer;
  final Future<void> Function(BitcoinPreparedTransfer)? onConfirm;
  const BitcoinTransferConfirmationScreen({
    super.key,
    required this.transfer,
    this.onConfirm,
  });
  @override
  State<BitcoinTransferConfirmationScreen> createState() =>
      _BitcoinTransferConfirmationScreenState();
}

class _BitcoinTransferConfirmationScreenState
    extends State<BitcoinTransferConfirmationScreen> {
  bool _verified = false;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _validate();
  }

  Future<void> _validate() async {
    try {
      final transfer = widget.transfer;
      final account = NativeBitcoinCrypto.metadata(transfer.plan.account);
      if (account.network != transfer.network ||
          account.purpose != transfer.purpose ||
          transfer.plan.recipients.length != 1) {
        throw StateError('Bitcoin confirmation identity mismatch');
      }
      await validateBitcoinTransferPlan(plan: transfer.plan);
      if (mounted) setState(() => _verified = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'This Bitcoin plan is invalid. Return to Send and prepare it again.',
        );
      }
    }
  }

  Future<void> _confirm() async {
    if (!_verified || _busy || widget.onConfirm == null) return;
    setState(() => _busy = true);
    try {
      await widget.onConfirm!(widget.transfer);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Bitcoin transfer could not be completed.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transfer = widget.transfer;
    final plan = transfer.plan;
    if (!_verified) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirm Bitcoin transfer')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (_error != null)
                  Text(_error!, key: const Key('bitcoin-confirmation-error'))
                else
                  const CircularProgressIndicator(),
                const FilledButton(
                  key: Key('bitcoin-confirm-transfer'),
                  onPressed: null,
                  child: Text('Confirm'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final recipient = plan.recipients.singleOrNull;
    Widget detail(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          SelectableText(value),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Bitcoin transfer')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            detail(
              'Amount',
              '${BitcoinAmountUtils.format(plan.recipientTotalSat)} BTC',
            ),
            detail('Destination', recipient?.address ?? ''),
            detail(
              'Network',
              transfer.network == BitcoinProductNetwork.mainnet
                  ? 'Bitcoin'
                  : 'Bitcoin Testnet4',
            ),
            detail('Fee rate', '${plan.feeRateSatVb} sat/vB'),
            detail(
              'Network fee',
              '${BitcoinAmountUtils.format(plan.feeSat)} BTC (${plan.feeSat} sats)',
            ),
            detail('Estimated vbytes', plan.estimatedVbytes.toString()),
            detail(
              'Total debit',
              '${BitcoinAmountUtils.format(plan.recipientTotalSat + plan.feeSat)} BTC',
            ),
            detail(
              'Address type',
              transfer.purpose == BitcoinPurpose.bip84
                  ? 'Native SegWit'
                  : 'Taproot',
            ),
            detail('RBF', plan.rbf ? 'Enabled' : 'Disabled'),
            if (_error != null)
              Text(_error!, key: const Key('bitcoin-confirmation-error')),
            if (!_verified && _error == null)
              const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('bitcoin-confirm-transfer'),
              onPressed: _verified && !_busy && widget.onConfirm != null
                  ? _confirm
                  : null,
              child: Text(_busy ? 'Preparing transfer…' : 'Confirm'),
            ),
          ],
        ),
      ),
    );
  }
}
