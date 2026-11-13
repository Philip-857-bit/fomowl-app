import 'package:web3dart/crypto.dart';
import 'package:web3dart/json_rpc.dart';
import 'package:web3dart/web3dart.dart';

import 'burst_execution_plan.dart';

/// The RPC could not simulate the transaction with this wallet's native balance.
/// No gas limit or fee is inferred from the failed simulation.
class BurstInsufficientNativeBalance implements Exception {
  const BurstInsufficientNativeBalance();

  String messageFor(String symbol) =>
      'Insufficient $symbol to cover the Burst amount and fees. Add $symbol and retry.';

  @override
  String toString() =>
      'Insufficient native balance to cover the Burst amount and fees.';
}

class BurstNetworkFee {
  const BurstNetworkFee({required this.gasLimit, required this.gasPriceWei});
  final int gasLimit;
  final BigInt gasPriceWei;
  BigInt get maximumFeeWei => BigInt.from(gasLimit) * gasPriceWei;

  static Future<BurstNetworkFee> estimate(
    Web3Client client,
    BurstExecutionPlan plan,
  ) async {
    final rpcChain = await client.getChainId().timeout(
      const Duration(seconds: 15),
    );
    if (rpcChain != BigInt.from(plan.chainId)) {
      throw StateError('The network RPC returned the wrong chain.');
    }
    final results = await Future.wait<Object>([
      client.getGasPrice(),
      _estimateGas(client, plan),
    ]).timeout(const Duration(seconds: 20));
    final price = (results[0] as EtherAmount).getInWei;
    final gas = results[1] as BigInt;
    if (price <= BigInt.zero || gas <= BigInt.zero || gas.bitLength > 52) {
      throw StateError('The network fee estimate is invalid.');
    }
    // Match the actual submitted gas limit to the reviewed buffered estimate.
    final buffered =
        (gas * BigInt.from(120) + BigInt.from(99)) ~/ BigInt.from(100);
    if (buffered.bitLength > 52) {
      throw StateError('The network fee estimate is invalid.');
    }
    return BurstNetworkFee(gasLimit: buffered.toInt(), gasPriceWei: price);
  }

  static Future<BigInt> _estimateGas(
    Web3Client client,
    BurstExecutionPlan plan,
  ) async {
    try {
      return await client.estimateGas(
        sender: EthereumAddress.fromHex(plan.wallet),
        to: EthereumAddress.fromHex(plan.to),
        value: EtherAmount.inWei(plan.value),
        data: hexToBytes(plan.data.substring(2)),
      );
    } on RPCError catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('insufficient funds') ||
          message.contains('insufficient balance')) {
        throw const BurstInsufficientNativeBalance();
      }
      rethrow;
    }
  }

  static Future<bool> matchesTransaction(
    Web3Client client,
    BurstExecutionPlan plan,
    String hash,
  ) async {
    if (await client.getChainId().timeout(const Duration(seconds: 15)) !=
        BigInt.from(plan.chainId)) {
      return false;
    }
    final transaction = await client
        .getTransactionByHash(hash)
        .timeout(const Duration(seconds: 15));
    if (transaction == null) return false;
    return transaction.hash.toLowerCase() == hash.toLowerCase() &&
        transaction.from.hex.toLowerCase() == plan.wallet &&
        transaction.to?.hex.toLowerCase() == plan.to &&
        transaction.value.getInWei == plan.value &&
        '0x${bytesToHex(transaction.input)}'.toLowerCase() == plan.data;
  }
}
