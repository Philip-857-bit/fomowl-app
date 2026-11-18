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

  static final BigInt _postApprovalFallbackGasLimit = BigInt.from(264000);
  static final BigInt _erc20TransferGasAdjustment = BigInt.from(25000);
  // Minimal EVM bytecode (`PUSH1 1, PUSH1 0, MSTORE, PUSH1 32, PUSH1 0, RETURN`)
  // returning `true` for ERC-20/NFT allowance & transferFrom checks during simulation.
  static const String _erc20TrueStubBytecode = '0x600160005260206000f3';

  static Future<BurstNetworkFee> estimate(
    Web3Client client,
    BurstExecutionPlan plan, {
    String? rpcUrl,
    List<String> fallbackRpcUrls = const [],
    bool allowBalanceOverride = false,
    String? overrideTokenAddress,
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
    final hasTokenOverride =
        overrideTokenAddress != null && overrideTokenAddress.isNotEmpty;
    if (hasTokenOverride) {
      if (!allowBalanceOverride || rpcUrl == null || rpcUrl.isEmpty) {
        throw const BurstInsufficientNativeBalance();
      }
      gas = await _estimateGasWithBalanceOverride(
        rpcUrl,
        plan,
        fallbackRpcUrls: fallbackRpcUrls,
        overrideTokenAddress: overrideTokenAddress,
        httpClient: httpClient,
      );
      usedBalanceOverride = true;
    } else {
      try {
        gas = await _estimateGas(client, plan);
      } on BurstInsufficientNativeBalance {
        if (!allowBalanceOverride || rpcUrl == null || rpcUrl.isEmpty) {
          rethrow;
        }
        gas = await _estimateGasWithBalanceOverride(
          rpcUrl,
          plan,
          fallbackRpcUrls: fallbackRpcUrls,
          httpClient: httpClient,
        );
        usedBalanceOverride = true;
      }
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
        throw BurstInsufficientNativeBalance(
          estimatedFeeWei: fee.maximumFeeWei,
        );
      }
    }
    return fee;
  }

  /// Estimates combined gas fees across ordered review steps (e.g. approve -> create).
  ///
  /// When a prerequisite `approve` step has not yet executed on-chain,
  /// downstream `create` / `push` simulation reverts on missing allowance; this
  /// simulates the post-approval call using an RPC token state override (falling
  /// back to the live gas price × buffered creation gas if state overrides are
  /// unsupported) so the review sheet shows the complete combined fee upfront.
  static Future<BigInt> estimateReviewSteps(
    Web3Client client,
    List<BurstExecutionPlan> plans, {
    String? rpcUrl,
    List<String> fallbackRpcUrls = const [],
    http.Client? httpClient,
  }) async {
    if (plans.isEmpty) {
      throw const FormatException('The transaction list is unavailable.');
    }
    final totalValue = plans.fold<BigInt>(
      BigInt.zero,
      (sum, plan) => sum + plan.value,
    );
    var totalFee = BigInt.zero;
    var insufficientNative = false;
    var missingOverrideFee = false;
    var hasApproval = false;
    String? approvedTokenAddress;
    for (final plan in plans) {
      if (plan.operation == 'approve') {
        hasApproval = true;
        approvedTokenAddress = plan.to;
      }
      try {
        final fee = await estimate(
          client,
          plan,
          rpcUrl: rpcUrl,
          fallbackRpcUrls: fallbackRpcUrls,
          allowBalanceOverride: true,
          httpClient: httpClient,
        );
        totalFee += fee.maximumFeeWei;
      } on BurstInsufficientNativeBalance catch (error) {
        insufficientNative = true;
        if (error.estimatedFeeWei != null) {
          totalFee += error.estimatedFeeWei!;
        } else if (hasApproval &&
            plan.operation != 'approve' &&
            approvedTokenAddress != null) {
          final stepFee = await _estimatePostApprovalStepFee(
            client,
            plan,
            tokenAddress: approvedTokenAddress,
            rpcUrl: rpcUrl,
            fallbackRpcUrls: fallbackRpcUrls,
            httpClient: httpClient,
          );
          totalFee += stepFee.feeWei;
        } else {
          missingOverrideFee = true;
        }
      } on RPCError {
        if (!hasApproval ||
            plan.operation == 'approve' ||
            approvedTokenAddress == null) {
          rethrow;
        }
        final stepFee = await _estimatePostApprovalStepFee(
          client,
          plan,
          tokenAddress: approvedTokenAddress,
          rpcUrl: rpcUrl,
          fallbackRpcUrls: fallbackRpcUrls,
          httpClient: httpClient,
        );
        totalFee += stepFee.feeWei;
        if (stepFee.insufficientNative) {
          insufficientNative = true;
        }
      }
    }
    if (missingOverrideFee) {
      throw const BurstInsufficientNativeBalance();
    }
    if (insufficientNative) {
      throw BurstInsufficientNativeBalance(estimatedFeeWei: totalFee);
    }
    if (hasApproval) {
      final balance = await client
          .getBalance(EthereumAddress.fromHex(plans.first.wallet))
          .timeout(const Duration(seconds: 15));
      if (balance.getInWei < totalValue + totalFee) {
        throw BurstInsufficientNativeBalance(estimatedFeeWei: totalFee);
      }
    }
    return totalFee;
  }

  static Future<({BigInt feeWei, bool insufficientNative})>
  _estimatePostApprovalStepFee(
    Web3Client client,
    BurstExecutionPlan plan, {
    required String tokenAddress,
    String? rpcUrl,
    List<String> fallbackRpcUrls = const [],
    http.Client? httpClient,
  }) async {
    if (rpcUrl != null && rpcUrl.isNotEmpty) {
      try {
        final fee = await estimate(
          client,
          plan,
          rpcUrl: rpcUrl,
          fallbackRpcUrls: fallbackRpcUrls,
          allowBalanceOverride: true,
          overrideTokenAddress: tokenAddress,
          httpClient: httpClient,
        );
        return (feeWei: fee.maximumFeeWei, insufficientNative: false);
      } on BurstInsufficientNativeBalance catch (error) {
        if (error.estimatedFeeWei != null) {
          return (feeWei: error.estimatedFeeWei!, insufficientNative: true);
        }
      } catch (_) {
        // Fall through to live gas-price fallback below.
      }
    }
    final price = (await client.getGasPrice().timeout(
      const Duration(seconds: 20),
    )).getInWei;
    if (price <= BigInt.zero) {
      throw StateError('The network fee estimate is invalid.');
    }
    return (
      feeWei: price * _postApprovalFallbackGasLimit,
      insufficientNative: false,
    );
  }

  static Future<BigInt> _estimateGasWithBalanceOverride(
    String rpcUrl,
    BurstExecutionPlan plan, {
    List<String> fallbackRpcUrls = const [],
    String? overrideTokenAddress,
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? HttpClientService().client;
    final overrideBalance = plan.value + BigInt.from(10).pow(20);
    final hasTokenOverride =
        overrideTokenAddress != null && overrideTokenAddress.isNotEmpty;
    final stateOverrides = <String, Map<String, String>>{
      plan.wallet: {'balance': '0x${overrideBalance.toRadixString(16)}'},
      if (hasTokenOverride)
        overrideTokenAddress: {'code': _erc20TrueStubBytecode},
    };
    final overridePayload = jsonEncode({
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
        stateOverrides,
      ],
    });
    final candidates = <String>{rpcUrl, ...fallbackRpcUrls};
    for (final url in candidates) {
      final gas = await _postEstimateGas(client, url, overridePayload);
      if (gas != null) {
        return hasTokenOverride ? gas + _erc20TransferGasAdjustment : gas;
      }
    }

    // Some public RPC nodes reject 3rd-argument state overrides; spoofing
    // gasPrice: 0x0 on zero-value calls (e.g. approve) bypasses native-fee
    // checks cleanly on standard Geth/Erigon/Reth endpoints.
    if (plan.value == BigInt.zero && !hasTokenOverride) {
      final zeroGasPricePayload = jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'eth_estimateGas',
        'params': [
          {
            'from': plan.wallet,
            'to': plan.to,
            'value': '0x0',
            'gasPrice': '0x0',
            'data': plan.data,
          },
        ],
      });
      for (final url in candidates) {
        final gas = await _postEstimateGas(client, url, zeroGasPricePayload);
        if (gas != null) {
          return gas;
        }
      }
    }
    throw const BurstInsufficientNativeBalance();
  }

  static Future<BigInt?> _postEstimateGas(
    http.Client client,
    String url,
    String payload,
  ) async {
    if (url.isEmpty) return null;
    try {
      final response = await client
          .post(
            Uri.parse(url),
            headers: const {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['error'] != null) {
        return null;
      }
      final rawHex = decoded['result']?.toString() ?? '';
      if (!rawHex.startsWith('0x') || rawHex.length <= 2) {
        return null;
      }
      final gas = BigInt.tryParse(rawHex.substring(2), radix: 16);
      if (gas != null && gas > BigInt.zero) {
        return gas;
      }
    } catch (_) {
      // Try next candidate or strategy.
    }
    return null;
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
          message.contains('insufficient balance') ||
          message.contains('gas required exceeds allowance') ||
          message.contains('cannot afford')) {
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
