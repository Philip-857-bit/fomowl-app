import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web3dart/web3dart.dart';

import 'package:fomowl_wallet/services/bridge_service.dart';
import 'package:fomowl_wallet/services/evm_bridge_transaction_service.dart';

void main() {
  final sender = EthereumAddress.fromHex(
    '0x4444444444444444444444444444444444444444',
  );
  final step = BridgeStepTx(
    stepId: 'deposit',
    description: 'Deposit',
    to: '0x3333333333333333333333333333333333333333',
    data: '0x1234',
    value: BigInt.from(1000),
    chainId: 1,
  );

  Web3Client client({required String balance, bool gasError = false}) =>
      Web3Client(
        'https://rpc.invalid',
        MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final Object result;
          switch (body['method']) {
            case 'eth_getBalance':
              result = balance;
            case 'eth_gasPrice':
              result = '0x3b9aca00';
            case 'eth_estimateGas':
              final tx = (body['params'] as List).first as Map;
              expect(tx['from'], sender.hex);
              expect(tx['to'], step.to);
              expect(tx['value'], '0x3e8');
              expect(tx['data'], step.data);
              if (gasError) {
                return http.Response(
                  jsonEncode({
                    'jsonrpc': '2.0',
                    'id': body['id'],
                    'error': {
                      'code': -32000,
                      'message': 'insufficient funds for gas',
                    },
                  }),
                  200,
                );
              }
              result = '0xc350';
            default:
              throw StateError('Preflight must not sign/broadcast');
          }
          return http.Response(
            jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
            200,
          );
        }),
      );

  test(
    'bridge preflight preserves calldata, value and 25% gas buffer',
    () async {
      final rpc = client(balance: '0xde0b6b3a7640000');
      addTearDown(rpc.dispose);
      final tx = await EvmBridgeTransactionService.prepare(
        client: rpc,
        sender: sender,
        step: step,
        nativeSymbol: 'ETH',
      );
      expect(tx.to?.hex, step.to);
      expect(tx.value?.getInWei, step.value);
      expect(tx.data, [0x12, 0x34]);
      expect(tx.gasPrice?.getInWei, BigInt.from(1000000000));
      expect(tx.maxGas, 62500);
    },
  );

  for (final balance in ['0x0', '0x3e9']) {
    test('bridge balance $balance cannot cover amount plus fees', () async {
      final rpc = client(balance: balance);
      addTearDown(rpc.dispose);
      await expectLater(
        EvmBridgeTransactionService.prepare(
          client: rpc,
          sender: sender,
          step: step,
          nativeSymbol: 'ETH',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Not enough ETH'),
          ),
        ),
      );
    });
  }

  test('bridge gas allowance failures retain actionable guidance', () async {
    final rpc = client(balance: '0xde0b6b3a7640000', gasError: true);
    addTearDown(rpc.dispose);
    await expectLater(
      EvmBridgeTransactionService.prepare(
        client: rpc,
        sender: sender,
        step: step,
        nativeSymbol: 'ETH',
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('cover the bridge network fee'),
        ),
      ),
    );
  });
}
