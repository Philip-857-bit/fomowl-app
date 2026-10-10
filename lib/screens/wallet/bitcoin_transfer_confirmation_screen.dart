import '../../theme/app_chain_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';
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
              (Localizations.of<AppLocalizations>(context, AppLocalizations) ??
                      AppLocalizationsEn())
                  .bitcoinInvalidPlan,
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
        setState(
          () => _error =
              (Localizations.of<AppLocalizations>(context, AppLocalizations) ??
                      AppLocalizationsEn())
                  .bitcoinTransferFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
    final chain = context.chainTheme;
    final actionStyle = FilledButton.styleFrom(
      backgroundColor: chain.accentColor,
      foregroundColor: chain.accentColor.computeLuminance() > 0.35
          ? Colors.black
          : Colors.white,
    );
    final transfer = widget.transfer;
    final plan = transfer.plan;
    if (!_verified) {
      return Scaffold(
        appBar: AppBar(title: Text(l.bitcoinConfirmTransfer)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (_error != null)
                  Text(_error!, key: const Key('bitcoin-confirmation-error'))
                else
                  CircularProgressIndicator(color: chain.accentColor),
                FilledButton(
                  key: const Key('bitcoin-confirm-transfer'),
                  style: actionStyle,
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
      appBar: AppBar(title: Text(l.bitcoinConfirmTransfer)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            detail(
              l.bitcoinAmount,
              '${BitcoinAmountUtils.format(plan.recipientTotalSat)} BTC',
            ),
            detail(l.bitcoinDestination, recipient?.address ?? ''),
            detail(
              'Network',
              transfer.network == BitcoinProductNetwork.mainnet
                  ? 'Bitcoin'
                  : 'Bitcoin Testnet4',
            ),
            detail(l.bitcoinFeeRate, '${plan.feeRateSatVb} sat/vB'),
            detail(
              l.bitcoinNetworkFee,
              '${BitcoinAmountUtils.format(plan.feeSat)} BTC (${plan.feeSat} sats)',
            ),
            detail(l.bitcoinEstimatedVbytes, plan.estimatedVbytes.toString()),
            detail(
              l.bitcoinTotalDebit,
              '${BitcoinAmountUtils.format(plan.recipientTotalSat + plan.feeSat)} BTC',
            ),
            detail(
              l.bitcoinAddressType,
              transfer.purpose == BitcoinPurpose.bip84
                  ? l.bitcoinNativeSegwit
                  : l.bitcoinTaproot,
            ),
            detail('RBF', plan.rbf ? l.bitcoinEnabled : l.bitcoinDisabled),
            if (_error != null)
              Text(_error!, key: const Key('bitcoin-confirmation-error')),
            if (!_verified && _error == null)
              Center(
                child: CircularProgressIndicator(color: chain.accentColor),
              ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('bitcoin-confirm-transfer'),
              style: actionStyle,
              onPressed: _verified && !_busy && widget.onConfirm != null
                  ? _confirm
                  : null,
              child: Text(_busy ? l.bitcoinPreparingTransfer : 'Confirm'),
            ),
          ],
        ),
      ),
    );
  }
}
