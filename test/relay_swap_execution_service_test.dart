import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web3dart/web3dart.dart';

import 'package:fomowl_wallet/services/relay_swap_execution_service.dart';
import 'package:fomowl_wallet/services/bridge_service.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/evm_transaction_service.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';

class _Wallet extends WalletService {
  final List<Map<String, Object?>> requests = [];
  @override
  Future<String?> getCurrentWalletAddress() async =>
      '0x4444444444444444444444444444444444444444';
  @override
  Future<String> sendRawTransactionRequest({
    required String rpcUrl,
    required int chainId,
    String? expectedFromAddress,
    String? toAddress,
    BigInt? valueInWei,
    String? dataHex,
    BigInt? gasPriceWei,
    BigInt? maxFeePerGasWei,
    BigInt? maxPriorityFeePerGasWei,
    int? gasLimit,
    int? nonce,
    Future<void> Function(EvmSignedTransaction transaction)? beforeBroadcast,
    Future<void> Function()? abortedBeforeBroadcast,
    void Function()? validateBeforeSigning,
  }) async {
    requests.add({
      'chain': chainId,
      'to': toAddress,
      'value': valueInWei,
      'data': dataHex,
      'gasPrice': gasPriceWei,
      'gasLimit': gasLimit,
    });
    return '0xhash${requests.length}';
  }
}

BridgeQuote _quote({int chain = 1, BigInt? value}) => BridgeQuote(
  originChainId: chain,
  destinationChainId: chain,
  amountIn: '1000',
  amountOut: '1000',
  amountOutUsd: 1,
  bridgeFeeUsd: null,
  gasFeeUsd: null,
  routeProvider: 'relay',
  platformFeeBps: null,
  platformFeeUsd: null,
  effectiveSlippageBps: null,
  timeEstimateSeconds: null,
  requestId: '',
  committed: true,
  deadline: null,
  steps: [
    for (final id in ['approval', 'deposit'])
      BridgeStepTx(
        stepId: id,
        description: id,
        to: '0x3333333333333333333333333333333333333333',
        data: '0x1234',
        value: value ?? BigInt.zero,
        chainId: chain,
      ),
  ],
);

Web3Client _client({bool sufficientBalance = true}) => Web3Client(
  'https://rpc.invalid',
  MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final method = body['method'];
    final Object result;
    switch (method) {
      case 'eth_gasPrice':
        result = '0x3b9aca00';
      case 'eth_estimateGas':
        final tx = (body['params'] as List).first as Map;
        expect(tx['from'], '0x4444444444444444444444444444444444444444');
        expect(tx['data'], '0x1234');
        result = '0xc350';
      case 'eth_getBalance':
        result = sufficientBalance ? '0xde0b6b3a7640000' : '0x0';
      default:
        throw StateError('Unexpected RPC: $method');
    }
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
      200,
      headers: {'content-type': 'application/json'},
    );
  }),
);

void main() {
  for (final sufficient in [true, false]) {
    test(
      'Relay preserves sequential Rust requests and balance guard ($sufficient)',
      () async {
        final blockchain = BlockchainService();
        addTearDown(blockchain.dispose);
        final wallet = _Wallet();
        final client = _client(sufficientBalance: sufficient);
        addTearDown(client.dispose);
        final result =
            await RelaySwapExecutionService(
              web3ClientFactory: (_) => client,
            ).execute(
              quote: _quote(),
              blockchain: blockchain,
              walletService: wallet,
              isNativeInput: false,
            );
        expect(result.success, sufficient);
        if (sufficient) {
          expect(result.transactionHash, '0xhash1');
          expect(wallet.requests, hasLength(2));
          for (final tx in wallet.requests) {
            expect(tx, {
              'chain': 1,
              'to': '0x3333333333333333333333333333333333333333',
              'value': BigInt.zero,
              'data': '0x1234',
              'gasPrice': BigInt.from(1000000000),
              'gasLimit': 62500,
            });
          }
        } else {
          expect(wallet.requests, isEmpty);
          expect(result.error, contains('Not enough'));
        }
      },
    );
  }

  test('Relay network and value guards reject plans before signing', () async {
    final blockchain = BlockchainService();
    addTearDown(blockchain.dispose);
    final wallet = _Wallet();
    final service = RelaySwapExecutionService(
      web3ClientFactory: (_) => throw StateError('No RPC expected'),
    );
    for (final quote in [_quote(chain: 56), _quote(value: BigInt.one)]) {
      final result = await service.execute(
        quote: quote,
        blockchain: blockchain,
        walletService: wallet,
        isNativeInput: false,
      );
      expect(result.success, isFalse);
      expect(wallet.requests, isEmpty);
    }
  });

  test('maps Relay DiffError reverts to transfer-fee guidance', () {
    const raw =
        'RPCError: execution reverted: '
        '0x9eea691b00000000000000000000000000000000000000000000000000000000'
        '0dd10eb100000000000000000000000000000000000000000000000000000000';

    expect(
      relaySwapExecutionErrorMessage(raw),
      'This token may charge a transfer fee that exceeds the current '
      'slippage tolerance. Increase slippage and try again.',
    );
  });

  test('keeps unrelated Relay execution failures generic', () {
    expect(
      relaySwapExecutionErrorMessage('RPC connection closed'),
      'Relay swap failed. Please try again.',
    );
  });
}
