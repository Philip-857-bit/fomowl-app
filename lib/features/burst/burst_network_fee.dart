import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

import 'burst_execution_plan.dart';

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
      client.estimateGas(
        sender: EthereumAddress.fromHex(plan.wallet),
        to: EthereumAddress.fromHex(plan.to),
        value: EtherAmount.inWei(plan.value),
        data: hexToBytes(plan.data.substring(2)),
      ),
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
