import 'package:hex/hex.dart';
import 'package:web3dart/web3dart.dart';
import '../l10n/app_localizations.dart';
import '../models/evm_fee_quote.dart';
import '../models/evm_outbound_transaction.dart';
import '../models/non_evm_receipt_facts.dart';
import '../utils/amount_utils.dart';
import 'advanced_transaction_details.dart';

/// Explicit public-field adapters. The expandable widget remains chain-agnostic.
class TransactionProtocolDetails {
  static String _gwei(BigInt value) =>
      '${AmountUtils.formatBaseUnits(value, 9, maxFractionDigits: 9)} Gwei';

  static List<AdvancedTransactionDetail> evmQuote(
    AppLocalizations l,
    EvmFeeQuote quote,
  ) => [
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
  ];

  static bool matchesReceipt(TransactionReceipt receipt, String expectedHash) =>
      RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(expectedHash) &&
      '0x${HEX.encode(receipt.transactionHash)}' == expectedHash.toLowerCase();

  static BigInt? executionFee(TransactionReceipt receipt) {
    final used = receipt.gasUsed;
    final price = receipt.effectiveGasPrice?.getInWei;
    if (receipt.blockNumber.isPending ||
        receipt.status == null ||
        used == null ||
        price == null ||
        used.isNegative ||
        price.isNegative) {
      return null;
    }
    // Execution cost only; separate rollup data fees are not inferred.
    return used * price;
  }

  static List<AdvancedTransactionDetail> evmReceipt(
    AppLocalizations l, {
    required String expectedHash,
    required int chainId,
    required String nativeSymbol,
    EvmOutboundTransaction? outbound,
    TransactionReceipt? receipt,
  }) {
    final record =
        outbound?.hash == expectedHash.toLowerCase() &&
            outbound?.fields.chainId == chainId
        ? outbound
        : null;
    final actual = receipt != null && matchesReceipt(receipt, expectedHash)
        ? receipt
        : null;
    final fields = record?.fields;
    final fee = actual == null ? null : executionFee(actual);
    return [
      AdvancedTransactionDetail(
        label: l.historyTransactionHashLabel,
        value: expectedHash,
        selectable: true,
      ),
      if (fields != null) ...[
        AdvancedTransactionDetail(
          label: l.evmTransactionType,
          value: fields.type == EvmTransactionType.dynamicFee
              ? l.evmDynamicTransaction
              : l.evmLegacyTransaction,
        ),
        AdvancedTransactionDetail(
          label: l.evmGasLimit,
          value: fields.gasLimit.toString(),
        ),
        AdvancedTransactionDetail(
          label: l.transactionNonce,
          value: fields.nonce.toString(),
        ),
        if (fields.gasPriceWei != null)
          AdvancedTransactionDetail(
            label: l.evmGasPrice,
            value: _gwei(fields.gasPriceWei!),
          )
        else ...[
          AdvancedTransactionDetail(
            label: l.evmPriorityFee,
            value: _gwei(fields.maxPriorityFeePerGasWei!),
          ),
          AdvancedTransactionDetail(
            label: l.evmMaxFee,
            value: _gwei(fields.maxFeePerGasWei!),
          ),
        ],
      ],
      if (actual != null) ...[
        if (!actual.blockNumber.isPending)
          AdvancedTransactionDetail(
            label: l.historyBlockNumberLabel,
            value: actual.blockNumber.blockNum.toString(),
          ),
        if (actual.gasUsed != null && !actual.gasUsed!.isNegative)
          AdvancedTransactionDetail(
            label: l.historyGasUsedLabel,
            value: actual.gasUsed.toString(),
          ),
        if (actual.effectiveGasPrice != null &&
            !actual.effectiveGasPrice!.getInWei.isNegative)
          AdvancedTransactionDetail(
            label: l.historyGasPriceLabel,
            value: _gwei(actual.effectiveGasPrice!.getInWei),
          ),
        if (fee != null)
          AdvancedTransactionDetail(
            label: l.transactionExecutionFee,
            value:
                '${AmountUtils.formatBaseUnits(fee, 18, maxFractionDigits: 18)} $nativeSymbol',
          ),
      ],
    ];
  }

  static List<AdvancedTransactionDetail> nonEvmReceipt(
    AppLocalizations l,
    NonEvmReceiptFacts facts,
  ) => [
    AdvancedTransactionDetail(
      label: l.historyTransactionHashLabel,
      value: facts.transactionHash,
      selectable: true,
    ),
    if (facts.blockHeight != null)
      AdvancedTransactionDetail(
        label: facts.networkKey.startsWith('solana:')
            ? l.transactionSlot
            : l.historyBlockNumberLabel,
        value: facts.blockHeight.toString(),
      ),
    if (facts.computeUnitsConsumed != null)
      AdvancedTransactionDetail(
        label: l.transactionComputeUnits,
        value: facts.computeUnitsConsumed.toString(),
      ),
    if (facts.priorityFeeLamports != null)
      AdvancedTransactionDetail(
        label: l.evmPriorityFee,
        value:
            '${AmountUtils.formatBaseUnits(facts.priorityFeeLamports!, 9, maxFractionDigits: 9)} SOL',
      ),
    if (facts.energyUsed != null)
      AdvancedTransactionDetail(
        label: l.transactionEnergyUsed,
        value: facts.energyUsed.toString(),
      ),
    if (facts.bandwidthUsed != null)
      AdvancedTransactionDetail(
        label: l.transactionBandwidthUsed,
        value: facts.bandwidthUsed.toString(),
      ),
    if (facts.energyFeeSun != null)
      AdvancedTransactionDetail(
        label: l.transactionEnergyFee,
        value:
            '${AmountUtils.formatBaseUnits(facts.energyFeeSun!, 6, maxFractionDigits: 6)} TRX',
      ),
    if (facts.bandwidthFeeSun != null)
      AdvancedTransactionDetail(
        label: l.transactionBandwidthFee,
        value:
            '${AmountUtils.formatBaseUnits(facts.bandwidthFeeSun!, 6, maxFractionDigits: 6)} TRX',
      ),
    if (facts.feeLimitSun != null)
      AdvancedTransactionDetail(
        label: l.transactionEnergyFeeLimit,
        value:
            '${AmountUtils.formatBaseUnits(facts.feeLimitSun!, 6, maxFractionDigits: 6)} TRX',
      ),
  ];
}
