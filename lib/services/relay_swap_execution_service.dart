import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

import 'blockchain_service.dart';
import 'bridge_service.dart';
import 'http_client_service.dart';
import 'rpc_service.dart';
import 'wallet_service.dart';

class RelaySwapExecutionResult {
  final bool success;
  final String? transactionHash;
  final String? error;

  const RelaySwapExecutionResult({
    required this.success,
    this.transactionHash,
    this.error,
  });
}

const _relayDiffErrorSelector = '0dd10eb1';

/// Converts Relay execution failures into stable, actionable guidance without
/// exposing raw RPC or calldata details to the user.
String relaySwapExecutionErrorMessage(Object error) {
  final lower = error.toString().toLowerCase();
  if (lower.contains('differror') || lower.contains(_relayDiffErrorSelector)) {
    return 'This token may charge a transfer fee that exceeds the current '
        'slippage tolerance. Increase slippage and try again.';
  }
  return 'Relay swap failed. Please try again.';
}

/// Executes a Relay quote whose origin and destination are the active EVM
/// chain. Keys never leave [WalletService]; every Relay transaction is signed
/// locally and must match the quoted chain and native-value bounds.
class RelaySwapExecutionService {
  RelaySwapExecutionService({
    BridgeService? bridgeService,
    RpcService? rpcService,
    HttpClientService? httpClientService,
  }) : _bridgeService = bridgeService ?? BridgeService(),
       _http = httpClientService ?? HttpClientService();

  final BridgeService _bridgeService;
  final HttpClientService _http;

  Future<RelaySwapExecutionResult> execute({
    required BridgeQuote quote,
    required BlockchainService blockchain,
    required WalletService walletService,
    required bool isNativeInput,
  }) async {
    final chainId = blockchain.activeChain.chainId;
    if (quote.originChainId != chainId || quote.destinationChainId != chainId) {
      return const RelaySwapExecutionResult(
        success: false,
        error: 'Relay returned a route for a different network.',
      );
    }
    if (quote.steps.isEmpty ||
        quote.steps.any((step) => step.isSolana || step.chainId != chainId)) {
      return const RelaySwapExecutionResult(
        success: false,
        error: 'Relay returned an unsupported transaction plan.',
      );
    }

    final amountIn = BigInt.tryParse(quote.amountIn) ?? BigInt.zero;
    final totalValue = quote.steps.fold<BigInt>(
      BigInt.zero,
      (sum, step) => sum + step.value,
    );
    if (isNativeInput ? totalValue > amountIn : totalValue > BigInt.zero) {
      return const RelaySwapExecutionResult(
        success: false,
        error: 'Relay transaction values do not match the quote.',
      );
    }

    try {
      final credentials = await walletService.getCredentials();
      final client = Web3Client(blockchain.activeChain.rpcUrl, _http.client);
      String? firstHash;

      for (final step in quote.steps) {
        final to = EthereumAddress.fromHex(step.to);
        final data = hexToBytes(step.data.replaceFirst('0x', ''));
        final value = EtherAmount.inWei(step.value);
        final preflight = await Future.wait<Object>([
          client.getGasPrice(),
          client.estimateGas(
            sender: credentials.address,
            to: to,
            value: value,
            data: data,
          ),
          client.getBalance(credentials.address),
        ]);
        final gasPrice = preflight[0] as EtherAmount;
        final estimated = preflight[1] as BigInt;
        final bufferedGas =
            (estimated * BigInt.from(125) + BigInt.from(99)) ~/
            BigInt.from(100);
        final balance = (preflight[2] as EtherAmount).getInWei;
        if (balance < step.value + gasPrice.getInWei * bufferedGas) {
          return RelaySwapExecutionResult(
            success: false,
            error:
                'Not enough ${blockchain.activeChain.symbol} for the swap and network fee.',
          );
        }
        final hash = await client.sendTransaction(
          credentials,
          Transaction(
            to: to,
            data: data,
            value: value,
            gasPrice: gasPrice,
            maxGas: bufferedGas.toInt(),
          ),
          chainId: chainId,
          fetchChainIdFromNetworkId: false,
        );
        firstHash ??= hash;
      }

      if (quote.requestId.isNotEmpty) {
        for (var attempt = 0; attempt < 45; attempt++) {
          if (attempt > 0) {
            await Future<void>.delayed(const Duration(seconds: 4));
          }
          final status = await _bridgeService.getStatus(
            requestId: quote.requestId,
          );
          if (status == null) continue;
          if (status.isFailure) {
            return RelaySwapExecutionResult(
              success: false,
              transactionHash: firstHash,
              error: 'Relay reported that the swap failed or was refunded.',
            );
          }
          if (status.isSuccess) break;
        }
      }
      return RelaySwapExecutionResult(
        success: true,
        transactionHash: firstHash,
      );
    } catch (error) {
      return RelaySwapExecutionResult(
        success: false,
        error: relaySwapExecutionErrorMessage(error),
      );
    }
  }
}
