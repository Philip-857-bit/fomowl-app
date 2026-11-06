import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_execution_plan.dart';
import 'package:fomowl_wallet/features/burst/burst_network_fee.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web3dart/web3dart.dart';

void main() {
  final plan = BurstExecutionPlan(
    reference: 'ref',
    wallet: '0x1111111111111111111111111111111111111111',
    campaignId: 'campaign',
    operation: 'create',
    chainId: 56,
    to: '0x2222222222222222222222222222222222222222',
    value: BigInt.zero,
    data: '0xa4be8afd',
  );
  test('estimates buffered fee using the selected chain RPC', () async {
    final transport = MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      final result = switch (body['method']) {
        'eth_chainId' => '0x38',
        'eth_gasPrice' => '0x3b9aca00',
        'eth_estimateGas' => '0x5208',
        _ => throw StateError('Unexpected RPC'),
      };
      return http.Response(
        jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
        200,
      );
    });
    final client = Web3Client('https://example.test', transport);
    final fee = await BurstNetworkFee.estimate(client, plan);
    expect(fee.gasLimit, 25200);
    expect(fee.maximumFeeWei, BigInt.from(25200) * BigInt.from(1000000000));
    client.dispose();
  });

  test('rejects an RPC connected to the wrong chain', () async {
    final transport = MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      return http.Response(
        jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': '0x1'}),
        200,
      );
    });
    final client = Web3Client('https://example.test', transport);
    await expectLater(BurstNetworkFee.estimate(client, plan), throwsStateError);
    client.dispose();
  });

  test('recovery verifies sender, destination, value and calldata', () async {
    final hash = '0x${'ab' * 32}';
    var sender = plan.wallet;
    final transport = MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      final result = body['method'] == 'eth_chainId'
          ? '0x38'
          : {
              'hash': hash,
              'from': sender,
              'to': plan.to,
              'value': '0x0',
              'input': plan.data,
              'gas': '0x5208',
              'gasPrice': '0x3b9aca00',
              'nonce': '0x1',
              'v': '0x1b',
              'r': '0x1',
              's': '0x1',
            };
      return http.Response(
        jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
        200,
      );
    });
    final client = Web3Client('https://example.test', transport);
    expect(
      await BurstNetworkFee.matchesTransaction(client, plan, hash),
      isTrue,
    );
    sender = '0x3333333333333333333333333333333333333333';
    expect(
      await BurstNetworkFee.matchesTransaction(client, plan, hash),
      isFalse,
    );
    client.dispose();
  });
}
