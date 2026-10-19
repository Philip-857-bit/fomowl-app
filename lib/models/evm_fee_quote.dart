import 'dart:typed_data';
import 'package:hex/hex.dart';

enum EvmFeeTier { economy, normal, priority }

enum EvmTransactionType { legacy, dynamicFee }

class EvmFeeQuoteException implements Exception {
  final String message;
  const EvmFeeQuoteException(this.message);
  @override
  String toString() => message;
}

/// An immutable public transaction intent. It contains no signing material.
class EvmFeeIntent {
  final int chainId;
  final String sender;
  final String destination;
  final BigInt valueWei;
  final String dataHex;
  final Object _rpcScope;
  EvmFeeIntent({
    required this.chainId,
    required String sender,
    required String destination,
    required this.valueWei,
    required Uint8List data,
    required Object rpcScope,
  }) : sender = sender.toLowerCase(),
       destination = destination.toLowerCase(),
       dataHex = HEX.encode(data),
       _rpcScope = rpcScope {
    final address = RegExp(r'^0x[0-9a-f]{40}$');
    if (chainId <= 0 ||
        !address.hasMatch(this.sender) ||
        !address.hasMatch(this.destination) ||
        valueWei < BigInt.zero ||
        valueWei.bitLength > 256 ||
        data.length > 1024 * 1024) {
      throw const EvmFeeQuoteException('Invalid EVM fee quote intent');
    }
  }
  bool matches({
    required int chainId,
    required String sender,
    required String destination,
    required BigInt valueWei,
    required Uint8List data,
    required Object rpcScope,
  }) =>
      this.chainId == chainId &&
      this.sender == sender.toLowerCase() &&
      this.destination == destination.toLowerCase() &&
      this.valueWei == valueWei &&
      dataHex == HEX.encode(data) &&
      identical(_rpcScope, rpcScope);
  @override
  String toString() => 'EvmFeeIntent(chainId: $chainId)';
}

/// Integer-wei execution-gas fees. The maximum covers this transaction's gas
/// fields, not separate rollup data fees charged outside those fields. It does
/// not claim every gas unit or the whole max fee will be spent.
class EvmFeeQuote {
  final EvmFeeIntent intent;
  final EvmFeeTier tier;
  final EvmTransactionType type;
  final int gasLimit;
  final BigInt? gasPriceWei;
  final BigInt? baseFeePerGasWei;
  final BigInt? maxPriorityFeePerGasWei;
  final BigInt? maxFeePerGasWei;
  final DateTime quotedAt;
  EvmFeeQuote({
    required this.intent,
    required this.tier,
    required this.type,
    required this.gasLimit,
    required DateTime quotedAt,
    this.gasPriceWei,
    this.baseFeePerGasWei,
    this.maxPriorityFeePerGasWei,
    this.maxFeePerGasWei,
  }) : quotedAt = quotedAt.toUtc() {
    final fees = [
      gasPriceWei,
      baseFeePerGasWei,
      maxPriorityFeePerGasWei,
      maxFeePerGasWei,
    ];
    if (gasLimit <= 0 ||
        gasLimit.bitLength > 63 ||
        fees.any(
          (fee) => fee != null && (fee < BigInt.zero || fee.bitLength > 128),
        ) ||
        (type == EvmTransactionType.legacy
            ? gasPriceWei == null || fees.skip(1).any((fee) => fee != null)
            : gasPriceWei != null ||
                  baseFeePerGasWei == null ||
                  maxPriorityFeePerGasWei == null ||
                  maxFeePerGasWei == null ||
                  maxPriorityFeePerGasWei! > maxFeePerGasWei! ||
                  baseFeePerGasWei! + maxPriorityFeePerGasWei! >
                      maxFeePerGasWei!)) {
      throw const EvmFeeQuoteException('Invalid EVM fee policy');
    }
  }
  BigInt get effectivePriceWei =>
      gasPriceWei ?? baseFeePerGasWei! + maxPriorityFeePerGasWei!;
  BigInt get estimatedTotalFeeWei => BigInt.from(gasLimit) * effectivePriceWei;
  BigInt get maximumTotalFeeWei =>
      BigInt.from(gasLimit) * (gasPriceWei ?? maxFeePerGasWei!);
  bool isFresh(
    DateTime now, {
    Duration maximumAge = const Duration(seconds: 30),
  }) {
    final age = now.toUtc().difference(quotedAt);
    return !age.isNegative && age < maximumAge;
  }

  void requireFresh(DateTime now) {
    if (!isFresh(now)) {
      throw const EvmFeeQuoteException(
        'Network fees expired. Review a fresh quote before signing.',
      );
    }
  }

  @override
  String toString() => 'EvmFeeQuote(type: ${type.name}, tier: ${tier.name})';
}

class EvmFeeQuotes {
  final Map<EvmFeeTier, EvmFeeQuote> tiers;
  EvmFeeQuotes(Map<EvmFeeTier, EvmFeeQuote> values)
    : tiers = Map.unmodifiable(values) {
    if (values.length != EvmFeeTier.values.length ||
        EvmFeeTier.values.any((tier) => values[tier]?.tier != tier)) {
      throw const EvmFeeQuoteException('Incomplete EVM fee tiers');
    }
    final first = values[EvmFeeTier.normal]!;
    if (values.values.any(
      (quote) =>
          !identical(quote.intent, first.intent) ||
          quote.type != first.type ||
          quote.gasLimit != first.gasLimit ||
          quote.quotedAt != first.quotedAt,
    )) {
      throw const EvmFeeQuoteException('Inconsistent EVM fee tiers');
    }
  }
  EvmFeeQuote forTier(EvmFeeTier tier) => tiers[tier]!;
  bool get hasDistinctTiers =>
      tiers.values.map((q) => q.effectivePriceWei).toSet().length > 1;
}
