import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

import 'bridge_service.dart';

/// RPC preflight for approved EVM bridge steps; keys and signing stay outside.
class EvmBridgeTransactionService {
  static Future<Transaction> prepare({
    required Web3Client client,
    required EthereumAddress sender,
    required BridgeStepTx step,
    required String nativeSymbol,
  }) async {
    final to = EthereumAddress.fromHex(step.to);
    final data = hexToBytes(step.data.replaceFirst('0x', ''));
    final value = EtherAmount.inWei(step.value);
    final symbol = nativeSymbol.trim().isEmpty
        ? 'the native gas token'
        : nativeSymbol.trim();
    late final List<Object> preflight;
    try {
      preflight = await Future.wait<Object>([
        client.getBalance(sender),
        client.getGasPrice(),
        client.estimateGas(sender: sender, to: to, value: value, data: data),
      ]);
    } catch (error) {
      if (_isGasAllowanceError(error)) {
        throw Exception(
          'Not enough $symbol to cover the bridge network fee. Add more $symbol, then try again.',
        );
      }
      rethrow;
    }
    final nativeBalanceWei = (preflight[0] as EtherAmount).getInWei;
    if (nativeBalanceWei <= step.value) {
      throw Exception(
        'Not enough $symbol to pay the bridge amount and network fee. Add more $symbol, then try again.',
      );
    }

    final gasPrice = preflight[1] as EtherAmount;
    final estimatedGas = preflight[2] as BigInt;
    final bufferedGas = _bufferGasLimit(estimatedGas);
    final gasCostWei = gasPrice.getInWei * bufferedGas;
    final requiredNativeWei = step.value + gasCostWei;

    if (nativeBalanceWei < requiredNativeWei) {
      final missingWei = requiredNativeWei - nativeBalanceWei;
      final missing = EtherAmount.inWei(
        missingWei,
      ).getValueInUnit(EtherUnit.ether).toStringAsFixed(6);
      throw Exception(
        'Not enough $symbol to pay the bridge amount and network fee. Add at least $missing $symbol, then try again.',
      );
    }

    return Transaction(
      to: to,
      data: data,
      value: value,
      gasPrice: gasPrice,
      maxGas: bufferedGas.toInt(),
    );
  }

  static bool _isGasAllowanceError(Object error) {
    final lower = error.toString().toLowerCase();
    return lower.contains('gas required exceeds allowance') ||
        lower.contains('insufficient funds') ||
        lower.contains('insufficient native gas') ||
        lower.contains('cannot afford') ||
        (lower.contains('not enough') && lower.contains('gas'));
  }

  static BigInt _bufferGasLimit(BigInt estimatedGas) {
    final buffered =
        (estimatedGas * BigInt.from(125) + BigInt.from(99)) ~/ BigInt.from(100);
    return buffered > estimatedGas ? buffered : estimatedGas + BigInt.one;
  }
}
