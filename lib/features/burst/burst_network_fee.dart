import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart';
import 'package:web3dart/json_rpc.dart';
import 'package:web3dart/web3dart.dart';

import '../../services/http_client_service.dart';
import 'burst_execution_plan.dart';

/// The RPC could not simulate the transaction with this wallet's native balance,
/// or the wallet's native balance is below the estimated total cost.
class BurstInsufficientNativeBalance implements Exception {
  const BurstInsufficientNativeBalance({this.estimatedFeeWei});

  final BigInt? estimatedFeeWei;

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
    BurstExecutionPlan plan, {
    String? rpcUrl,
    bool allowBalanceOverride = false,
    http.Client? httpClient,
  }) async {
    final rpcChain = await client.getChainId().timeout(
      const Duration(seconds: 15),
    );
    if (rpcChain != BigInt.from(plan.chainId)) {
      throw StateError('The network RPC returned the wrong chain.');
    }
    final priceFuture = client.getGasPrice().timeout(
      const Duration(seconds: 20),
    );
    var usedBalanceOverride = false;
    late final BigInt gas;
    try {
      gas = await _estimateGas(client, plan);
    } on BurstInsufficientNativeBalance {
      if (!allowBalanceOverride || rpcUrl == null || rpcUrl.isEmpty) {
        rethrow;
      }
      gas = await _estimateGasWithBalanceOverride(
        rpcUrl,
        plan,
        httpClient: httpClient,
      );
      usedBalanceOverride = true;
    }
    final price = (await priceFuture).getInWei;
    if (price <= BigInt.zero || gas <= BigInt.zero || gas.bitLength > 52) {
      throw StateError('The network fee estimate is invalid.');
    }
    // Match the actual submitted gas limit to the reviewed buffered estimate.
    final buffered =
        (gas * BigInt.from(120) + BigInt.from(99)) ~/ BigInt.from(100);
    if (buffered.bitLength > 52) {
      throw StateError('The network fee estimate is invalid.');
    }
    final fee = BurstNetworkFee(gasLimit: buffered.toInt(), gasPriceWei: price);
    if (usedBalanceOverride) {
      final balance = await client
          .getBalance(EthereumAddress.fromHex(plan.wallet))
          .timeout(const Duration(seconds: 15));
      if (balance.getInWei < plan.value + fee.maximumFeeWei) {
        throw BurstInsufficientNativeBalance(estimatedFeeWei: fee.maximumFeeWei);
      }
    }
    return fee;
  }

  static Future<BigInt> _estimateGasWithBalanceOverride(
    String rpcUrl,
    BurstExecutionPlan plan, {
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? HttpClientService().client;
    try {
      // Simulate with an ample native balance so RPCs still validate the contract
      // call and return an accurate gas estimate for ERC-20/native Bursts.
      final overrideBalance = plan.value + BigInt.from(10).pow(20);
      final response = await client
          .post(
            Uri.parse(rpcUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'id': 1,
              'method': 'eth_estimateGas',
              'params': [
                {
                  'from': plan.wallet,
                  'to': plan.to,
                  'value': '0x${plan.value.toRadixString(16)}',
                  'data': plan.data,
                },
                'latest',
                {
                  plan.wallet: {
                    'balance': '0x${overrideBalance.toRadixString(16)}',
                  },
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const BurstInsufficientNativeBalance();
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['error'] != null) {
        throw const BurstInsufficientNativeBalance();
      }
      final rawHex = decoded['result']?.toString() ?? '';
      if (!rawHex.startsWith('0x') || rawHex.length <= 2) {
        throw const BurstInsufficientNativeBalance();
      }
      final gas = BigInt.tryParse(rawHex.substring(2), radix: 16);
      if (gas == null || gas <= BigInt.zero) {
        throw const BurstInsufficientNativeBalance();
      }
      return gas;
    } on BurstInsufficientNativeBalance {
      rethrow;
    } catch (_) {
      throw const BurstInsufficientNativeBalance();
    }
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
