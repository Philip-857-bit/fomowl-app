import 'dart:typed_data';
import 'package:web3dart/json_rpc.dart';
import '../models/evm_fee_quote.dart';

typedef EvmFeeRpc =
    Future<Object?> Function(String method, List<dynamic> params);

/// Host-side fee observations and estimation only. Rust remains the signer.
/// Unsupported optional fee RPCs fall back to other validated observations;
/// transport errors and malformed responses never invent fees or chain support.
class EvmFeeService {
  final EvmFeeRpc rpc;
  final Object rpcScope;
  final DateTime Function() now;
  final Duration timeout;
  EvmFeeService({
    required this.rpc,
    required this.rpcScope,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 12),
  }) : now = now ?? DateTime.now {
    if (timeout <= Duration.zero || timeout > const Duration(seconds: 30)) {
      throw const EvmFeeQuoteException('Invalid fee request timeout');
    }
  }
  static final _quantity = RegExp(r'^0x(?:0|[1-9a-fA-F][0-9a-fA-F]*)$');
  static final _unsupported = Object();
  static BigInt quantity(Object? value, {int bits = 128}) {
    if (value is! String ||
        value.length > 2 + (bits + 3) ~/ 4 ||
        !_quantity.hasMatch(value)) {
      throw const EvmFeeQuoteException('Invalid network fee response');
    }
    final parsed = BigInt.parse(value.substring(2), radix: 16);
    if (parsed.bitLength > bits) {
      throw const EvmFeeQuoteException('Invalid network fee response');
    }
    return parsed;
  }

  Future<Object?> _call(String method, List<dynamic> args) =>
      rpc(method, args).timeout(timeout);
  Future<Object?> _optional(String method, List<dynamic> args) async {
    try {
      return await _call(method, args);
    } on RPCError catch (error) {
      if (error.errorCode == -32601 || error.errorCode == -32004) {
        return _unsupported;
      }
      rethrow;
    }
  }

  Future<EvmFeeQuotes> quote({
    required int chainId,
    required String sender,
    required String destination,
    required BigInt valueWei,
    required Uint8List data,
  }) async {
    final started = now().toUtc();
    final intent = EvmFeeIntent(
      chainId: chainId,
      sender: sender,
      destination: destination,
      valueWei: valueWei,
      data: data,
      rpcScope: rpcScope,
    );
    try {
      final observations = await Future.wait<Object?>([
        _call('eth_chainId', []),
        _call('eth_getBlockByNumber', ['latest', false]),
        _call('eth_gasPrice', []),
        _call('eth_estimateGas', [
          {
            'from': intent.sender,
            'to': intent.destination,
            'value': '0x${valueWei.toRadixString(16)}',
            if (data.isNotEmpty) 'data': '0x${intent.dataHex}',
          },
        ]),
      ]);
      if (quantity(observations[0], bits: 63) != BigInt.from(chainId)) {
        throw const EvmFeeQuoteException(
          'Fee provider does not match the selected network',
        );
      }
      final block = observations[1];
      if (block is! Map<String, dynamic>) {
        throw const EvmFeeQuoteException('Invalid network block response');
      }
      quantity(block['number'], bits: 63);
      final blockGasLimit = quantity(block['gasLimit'], bits: 63);
      if (blockGasLimit == BigInt.zero) {
        throw const EvmFeeQuoteException('Invalid network block response');
      }
      final base = block.containsKey('baseFeePerGas')
          ? quantity(block['baseFeePerGas'])
          : null;
      final gasPrice = quantity(observations[2]);
      final rawGas = quantity(observations[3], bits: 63);
      if (rawGas == BigInt.zero || rawGas > blockGasLimit) {
        throw const EvmFeeQuoteException('Invalid network gas estimate');
      }
      final requestedBuffer =
          (rawGas * BigInt.from(110) + BigInt.from(99)) ~/ BigInt.from(100);
      final buffered = requestedBuffer > blockGasLimit
          ? blockGasLimit
          : requestedBuffer;
      if (buffered.bitLength > 63) {
        throw const EvmFeeQuoteException('Invalid network gas estimate');
      }
      final history = await _optional('eth_feeHistory', [
        '0x5',
        'latest',
        [10, 50, 90],
      ]);
      List<BigInt>? rewards;
      if (!identical(history, _unsupported)) {
        rewards = _rewards(history, base != null);
      }
      BigInt? suggestedTip;
      final needsSuggestion =
          base != null &&
          (rewards == null || rewards[EvmFeeTier.normal.index] == BigInt.zero);
      if (base != null && needsSuggestion) {
        final tip = await _optional('eth_maxPriorityFeePerGas', []);
        final observedTip = identical(tip, _unsupported)
            ? BigInt.zero
            : quantity(tip);
        final gasPriceTip = gasPrice > base ? gasPrice - base : BigInt.zero;
        suggestedTip = observedTip > gasPriceTip ? observedTip : gasPriceTip;
      }
      final values = <EvmFeeTier, EvmFeeQuote>{};
      for (final tier in EvmFeeTier.values) {
        if (base == null) {
          final observed = rewards?[tier.index] ?? gasPrice;
          final price = observed > gasPrice ? observed : gasPrice;
          values[tier] = EvmFeeQuote(
            intent: intent,
            tier: tier,
            type: EvmTransactionType.legacy,
            gasLimit: buffered.toInt(),
            gasPriceWei: price,
            quotedAt: started,
          );
        } else {
          final observed = rewards?[tier.index] ?? BigInt.zero;
          final tip = needsSuggestion && suggestedTip! > observed
              ? suggestedTip
              : observed;
          values[tier] = EvmFeeQuote(
            intent: intent,
            tier: tier,
            type: EvmTransactionType.dynamicFee,
            gasLimit: buffered.toInt(),
            baseFeePerGasWei: base,
            maxPriorityFeePerGasWei: tip,
            maxFeePerGasWei: base * BigInt.two + tip,
            quotedAt: started,
          );
        }
      }
      final result = EvmFeeQuotes(values);
      result.forTier(EvmFeeTier.normal).requireFresh(now());
      return result;
    } on EvmFeeQuoteException {
      rethrow;
    } on RPCError catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('insufficient funds') ||
          message.contains('insufficient balance') ||
          message.contains('gas required exceeds allowance')) {
        throw const EvmFeeQuoteException(
          'Insufficient balance to estimate this transfer',
        );
      }
      throw const EvmFeeQuoteException('Unable to obtain network fees');
    } catch (_) {
      throw const EvmFeeQuoteException('Unable to obtain network fees');
    }
  }

  List<BigInt>? _rewards(Object? value, bool dynamicFee) {
    if (value is! Map<String, dynamic>) {
      throw const EvmFeeQuoteException('Invalid fee history');
    }
    quantity(value['oldestBlock'], bits: 63);
    final bases = value['baseFeePerGas'];
    final rows = value['reward'];
    if (bases is! List ||
        bases.isEmpty ||
        bases.length > 6 ||
        rows is! List ||
        rows.length > 5 ||
        bases.length != rows.length + 1) {
      throw const EvmFeeQuoteException('Invalid fee history');
    }
    for (final base in bases) {
      if (!dynamicFee && quantity(base) != BigInt.zero) {
        throw const EvmFeeQuoteException('Inconsistent network fee capability');
      }
      quantity(base);
    }
    if (rows.isEmpty) return null;
    final columns = List.generate(3, (_) => <BigInt>[]);
    for (final row in rows) {
      if (row is! List || row.length != 3) {
        throw const EvmFeeQuoteException('Invalid fee rewards');
      }
      final fees = row.map(quantity).toList();
      if (fees[0] > fees[1] || fees[1] > fees[2]) {
        throw const EvmFeeQuoteException('Invalid fee rewards');
      }
      for (var column = 0; column < 3; column++) {
        columns[column].add(fees[column]);
      }
    }
    return columns.map((column) {
      column.sort();
      return column[column.length ~/ 2];
    }).toList();
  }
}
