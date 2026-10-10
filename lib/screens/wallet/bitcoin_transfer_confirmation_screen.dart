import '../../constants/app_colors.dart';
import '../../models/bitcoin_network_data.dart';
import '../../widgets/advanced_transaction_details.dart';
import 'widgets/transfer_confirmation/amount_summary.dart';
import 'widgets/transfer_confirmation/transfer_header.dart';
import 'widgets/transfer_confirmation/warning_banner.dart';
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

  String _btc(BigInt sats) {
    final parts = BitcoinAmountUtils.format(sats).split('.');
    return '${parts.first}.${(parts.length == 2 ? parts.last : '').padRight(8, '0')} BTC';
  }

  Widget _detail(
    String label,
    String value, {
    String? secondary,
    bool total = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: total ? Colors.white : Colors.white60,
              fontWeight: total ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SelectableText(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: total ? 16 : 14,
                  color: Colors.white,
                  fontWeight: total ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (secondary != null) ...[
                const SizedBox(height: 4),
                Text(
                  secondary,
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
    final chain = context.chainTheme;
    final transfer = widget.transfer;
    final plan = transfer.plan;
    final actionStyle = FilledButton.styleFrom(
      backgroundColor: chain.accentColor,
      foregroundColor: chain.accentColor.computeLuminance() > 0.35
          ? Colors.black
          : Colors.white,
      minimumSize: const Size(double.infinity, 56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    );
    final speed = switch (transfer.requestedFeeTier) {
      BitcoinFeeTier.economy => l.bitcoinEconomy,
      BitcoinFeeTier.normal => l.bitcoinNormal,
      BitcoinFeeTier.priority => l.bitcoinPriority,
    };
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            TransferHeader(
              onBack: () => Navigator.pop(context),
              accentColor: chain.accentColor,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.confirmTransfer,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (!_verified && _error == null)
                          Center(
                            child: CircularProgressIndicator(
                              color: chain.accentColor,
                            ),
                          ),
                        if (_verified) ...[
                          AmountSummary(
                            amountText: _btc(
                              plan.recipientTotalSat,
                            ).replaceFirst(' BTC', ''),
                            symbol: 'BTC',
                            fitAmount: true,
                            title: l.transactionAmountToSend,
                            accentColor: chain.accentColor,
                          ),
                          const SizedBox(height: 28),
                          Text(
                            l.transactionDetails,
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w500,
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                _detail(
                                  l.swapToLabel,
                                  plan.recipients.single.address,
                                ),
                                const Divider(
                                  color: AppColors.divider,
                                  height: 1,
                                ),
                                _detail(
                                  l.network,
                                  transfer.network ==
                                          BitcoinProductNetwork.mainnet
                                      ? 'Bitcoin'
                                      : 'Bitcoin Testnet4',
                                ),
                                const Divider(
                                  color: AppColors.divider,
                                  height: 1,
                                ),
                                _detail(
                                  l.bitcoinNetworkFee,
                                  _btc(plan.feeSat),
                                  secondary: '${plan.feeSat} sats',
                                ),
                                if (transfer.showFeeTier)
                                  _detail(l.bitcoinSpeed, speed),
                                const Divider(
                                  color: AppColors.divider,
                                  height: 1,
                                ),
                                _detail(
                                  l.transactionTotal,
                                  _btc(plan.recipientTotalSat + plan.feeSat),
                                  total: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          AdvancedTransactionDetails(
                            title: l.advancedTransactionDetails,
                            items: [
                              AdvancedTransactionDetail(
                                label: l.bitcoinInputType,
                                value: transfer.purpose == BitcoinPurpose.bip84
                                    ? l.bitcoinNativeSegwit
                                    : l.bitcoinTaproot,
                              ),
                              AdvancedTransactionDetail(
                                label: l.bitcoinFeeRate,
                                value: '${plan.feeRateSatVb} sat/vB',
                              ),
                              AdvancedTransactionDetail(
                                label: l.bitcoinEstimatedSize,
                                value: '${plan.estimatedVbytes} vB',
                              ),
                              AdvancedTransactionDetail(
                                label: l.bitcoinReplaceByFee,
                                value: plan.rbf
                                    ? l.bitcoinEnabled
                                    : l.bitcoinDisabled,
                              ),
                            ],
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            _error!,
                            key: const Key('bitcoin-confirmation-error'),
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: WarningBanner(
                      message: l.transferWarningMessage,
                      accentColor: chain.accentColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                key: const Key('bitcoin-confirm-transfer'),
                style: actionStyle,
                onPressed: _verified && !_busy && widget.onConfirm != null
                    ? _confirm
                    : null,
                child: _busy
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(child: Text(l.bitcoinPreparingTransfer)),
                        ],
                      )
                    : Text(l.confirmTransfer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
