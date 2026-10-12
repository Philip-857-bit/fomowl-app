import 'package:flutter/material.dart';
import '../../../../models/evm_fee_quote.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_chain_theme.dart';
import '../../../../utils/amount_utils.dart';
import '../../../../widgets/advanced_transaction_details.dart';

String evmFeeTierLabel(AppLocalizations l, EvmFeeTier tier) => switch (tier) {
  EvmFeeTier.economy => l.transactionEconomy,
  EvmFeeTier.normal => l.transactionNormal,
  EvmFeeTier.priority => l.transactionPriority,
};

class EvmFeeOptions extends StatelessWidget {
  final EvmFeeQuotes quotes;
  final EvmFeeTier selected;
  final ValueChanged<EvmFeeTier> onChanged;
  final bool enabled;
  const EvmFeeOptions({
    super.key,
    required this.quotes,
    this.selected = EvmFeeTier.normal,
    required this.onChanged,
    this.enabled = true,
  });
  String _gwei(BigInt value) =>
      '${AmountUtils.formatBaseUnits(value, 9, maxFractionDigits: 9)} Gwei';
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final quote = quotes.forTier(selected);
    final accent = context.chainTheme.accentColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quotes.hasDistinctTiers
                    ? l.transactionNetworkSpeed
                    : l.networkFeeLabel,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 10),
              if (quotes.hasDistinctTiers)
                Row(
                  children: [
                    for (final tier in EvmFeeTier.values)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: OutlinedButton(
                            key: Key('evm-fee-tier-${tier.name}'),
                            onPressed: enabled ? () => onChanged(tier) : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: tier == selected
                                  ? accent
                                  : Colors.white70,
                              backgroundColor: tier == selected
                                  ? accent.withValues(alpha: 0.12)
                                  : null,
                              side: BorderSide(
                                color: tier == selected
                                    ? accent
                                    : Colors.white24,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 10,
                              ),
                            ),
                            child: Text(
                              evmFeeTierLabel(l, tier),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              else
                Text(
                  l.transactionEqualFeeTiers,
                  key: const Key('evm-fee-tiers-equal'),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AdvancedTransactionDetails(
          title: l.advancedTransactionDetails,
          items: [
            AdvancedTransactionDetail(
              label: l.evmTransactionType,
              value: quote.type == EvmTransactionType.dynamicFee
                  ? l.evmDynamicTransaction
                  : l.evmLegacyTransaction,
            ),
            AdvancedTransactionDetail(
              label: l.evmGasLimit,
              value: quote.gasLimit.toString(),
            ),
            if (quote.type == EvmTransactionType.legacy)
              AdvancedTransactionDetail(
                label: l.evmGasPrice,
                value: _gwei(quote.gasPriceWei!),
              )
            else ...[
              AdvancedTransactionDetail(
                label: l.evmBaseFee,
                value: _gwei(quote.baseFeePerGasWei!),
              ),
              AdvancedTransactionDetail(
                label: l.evmPriorityFee,
                value: _gwei(quote.maxPriorityFeePerGasWei!),
              ),
              AdvancedTransactionDetail(
                label: l.evmMaxFee,
                value: _gwei(quote.maxFeePerGasWei!),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
