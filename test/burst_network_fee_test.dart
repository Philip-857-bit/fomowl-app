import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_execution_plan.dart';
import 'package:fomowl_wallet/features/burst/burst_network_fee.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/json_rpc.dart';

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

  test(
    'HTTP 200 with insufficient-funds RPC error reports insufficient native balance',
    () async {
      final transport = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final response = body['method'] == 'eth_estimateGas'
            ? {
                'error': {
                  'code': -32000,
                  'message':
                      'failed with 16777216 gas: insufficient funds for gas * price + value: have 420630739988948 want 515100000000000',
                },
              }
            : {
                'result': body['method'] == 'eth_chainId'
                    ? '0x38'
                    : '0x2faf080',
              };
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': body['id'], ...response}),
          200,
        );
      });
      final client = Web3Client('https://example.test', transport);
      await expectLater(
        BurstNetworkFee.estimate(client, plan),
        throwsA(isA<BurstInsufficientNativeBalance>()),
      );
      client.dispose();
    },
  );

  test(
    'contract revert remains an estimation failure without an invented gas fee',
    () async {
      final transport = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final response = body['method'] == 'eth_estimateGas'
            ? {
                'error': {'code': -32000, 'message': 'execution reverted'},
              }
            : {
                'result': body['method'] == 'eth_chainId'
                    ? '0x38'
                    : '0x2faf080',
              };
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': body['id'], ...response}),
          200,
        );
      });
      final client = Web3Client('https://example.test', transport);
      await expectLater(
        BurstNetworkFee.estimate(client, plan),
        throwsA(isA<RPCError>()),
      );
      client.dispose();
    },
  );

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

  test(
    'balance-override preview estimates fee even when wallet lacks native funds',
    () async {
      final transport = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final method = body['method'] as String;
        final params = body['params'] as List? ?? const [];
        final Map<String, dynamic> response = switch (method) {
          'eth_chainId' => {'result': '0x38'},
          'eth_gasPrice' => {'result': '0x3b9aca00'},
          'eth_getBalance' => {'result': '0x0'},
          'eth_estimateGas' when params.length >= 3 => {'result': '0x186a0'},
          'eth_estimateGas' => {
            'error': {'code': -32000, 'message': 'insufficient funds for gas'},
          },
          _ => {'result': '0x0'},
        };
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': body['id'], ...response}),
          200,
        );
      });
      final client = Web3Client('https://example.test', transport);
      await expectLater(
        BurstNetworkFee.estimate(
          client,
          plan,
          rpcUrl: 'https://example.test',
          allowBalanceOverride: true,
          httpClient: transport,
        ),
        throwsA(
          isA<BurstInsufficientNativeBalance>().having(
            (e) => e.estimatedFeeWei,
            'estimatedFeeWei',
            BigInt.from(120000) * BigInt.from(1000000000),
          ),
        ),
      );
      client.dispose();
    },
  );

  test(
    'BSC gas-required-exceeds-allowance error reports insufficient native balance',
    () async {
      final transport = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final response = body['method'] == 'eth_estimateGas'
            ? {
                'error': {
                  'code': -32000,
                  'message': 'gas required exceeds allowance (0)',
                },
              }
            : {
                'result': body['method'] == 'eth_chainId'
                    ? '0x38'
                    : '0x2faf080',
              };
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': body['id'], ...response}),
          200,
        );
      });
      final client = Web3Client('https://example.test', transport);
      await expectLater(
        BurstNetworkFee.estimate(client, plan),
        throwsA(isA<BurstInsufficientNativeBalance>()),
      );
      client.dispose();
    },
  );

  test(
    'estimateReviewSteps estimates full combined approve and create fee via token state override or fallback',
    () async {
      final approvePlan = BurstExecutionPlan(
        reference: 'ref-approve',
        wallet: '0x1111111111111111111111111111111111111111',
        campaignId: 'campaign',
        operation: 'approve',
        chainId: 56,
        to: '0x3333333333333333333333333333333333333333',
        value: BigInt.zero,
        data: '0x095ea7b3',
      );
      final createPlan = BurstExecutionPlan(
        reference: 'ref-create',
        wallet: '0x1111111111111111111111111111111111111111',
        campaignId: 'campaign',
        operation: 'create',
        chainId: 56,
        to: '0x2222222222222222222222222222222222222222',
        value: BigInt.from(100000000000000),
        data: '0x9ad88796',
      );
      var balanceHex = '0xde0b6b3a7640000'; // 1 BNB
      final transport = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final method = body['method'] as String;
        final params = body['params'] as List? ?? const [];
        if (method == 'eth_chainId') {
          return http.Response(
            jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': '0x38'}),
            200,
          );
        }
        if (method == 'eth_gasPrice') {
          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': body['id'],
              'result': '0x3b9aca00',
            }),
            200,
          );
        }
        if (method == 'eth_getBalance') {
          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': body['id'],
              'result': balanceHex,
            }),
            200,
          );
        }
        if (method == 'eth_estimateGas') {
          final tx = params.first as Map<String, dynamic>;
          final data = tx['data'] as String? ?? '';
          if (data == '0x095ea7b3') {
            return http.Response(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': body['id'],
                'result': '0xc350', // 50,000 gas -> buffered 60,000
              }),
              200,
            );
          }
          if (params.length >= 3) {
            final overrides = params[2] as Map<String, dynamic>;
            if (overrides.containsKey(
              '0x3333333333333333333333333333333333333333',
            )) {
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': body['id'],
                  'result': '0x249f0', // 150,000 + 25,000 -> buffered 210,000
                }),
                200,
              );
            }
          }
          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': body['id'],
              'error': {
                'code': -32000,
                'message':
                    'execution reverted: BEP20: transfer amount exceeds allowance',
              },
            }),
            200,
          );
        }
        throw StateError('Unexpected RPC: $method');
      });
      final client = Web3Client('https://example.test', transport);
      final expectedApproveFee = BigInt.from(60000) * BigInt.from(1000000000);
      final expectedOverrideCreateFee =
          BigInt.from(210000) * BigInt.from(1000000000);
      final expectedFallbackCreateFee =
          BigInt.from(264000) * BigInt.from(1000000000);

      // Without rpcUrl: uses fallback creation gas estimate for full combined fee.
      expect(
        await BurstNetworkFee.estimateReviewSteps(client, [
          approvePlan,
          createPlan,
        ]),
        expectedApproveFee + expectedFallbackCreateFee,
      );

      // With rpcUrl: uses token code override simulation to get combined fee.
      expect(
        await BurstNetworkFee.estimateReviewSteps(
          client,
          [approvePlan, createPlan],
          rpcUrl: 'https://example.test',
          httpClient: transport,
        ),
        expectedApproveFee + expectedOverrideCreateFee,
      );

      // With 0 balance: throws insufficient balance carrying full combined fee.
      balanceHex = '0x0';
      await expectLater(
        BurstNetworkFee.estimateReviewSteps(
          client,
          [approvePlan, createPlan],
          rpcUrl: 'https://example.test',
          httpClient: transport,
        ),
        throwsA(
          isA<BurstInsufficientNativeBalance>().having(
            (e) => e.estimatedFeeWei,
            'estimatedFeeWei',
            expectedApproveFee + expectedOverrideCreateFee,
          ),
        ),
      );
      client.dispose();
    },
  );

  test(
    'estimateReviewSteps preserves combined approve and create fee when create lacks balance & allowance on-chain',
    () async {
      final approvePlan = BurstExecutionPlan(
        reference: 'ref-approve',
        wallet: '0x1111111111111111111111111111111111111111',
        campaignId: 'campaign',
        operation: 'approve',
        chainId: 56,
        to: '0x3333333333333333333333333333333333333333',
        value: BigInt.zero,
        data: '0x095ea7b3',
      );
      final createPlan = BurstExecutionPlan(
        reference: 'ref-create',
        wallet: '0x1111111111111111111111111111111111111111',
        campaignId: 'campaign',
        operation: 'create',
        chainId: 56,
        to: '0x2222222222222222222222222222222222222222',
        value: BigInt.from(100000000000000),
        data: '0x9ad88796',
      );
      final transport = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final method = body['method'] as String;
        final params = body['params'] as List? ?? const [];
        if (method == 'eth_chainId') {
          return http.Response(
            jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': '0x38'}),
            200,
          );
        }
        if (method == 'eth_gasPrice') {
          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': body['id'],
              'result': '0x3b9aca00',
            }),
            200,
          );
        }
        if (method == 'eth_getBalance') {
          return http.Response(
            jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': '0x0'}),
            200,
          );
        }
        if (method == 'eth_estimateGas') {
          final tx = params.first as Map<String, dynamic>;
          final data = tx['data'] as String? ?? '';
          if (data == '0x095ea7b3' && params.length >= 3) {
            return http.Response(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': body['id'],
                'result': '0xc350',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': body['id'],
              'error': {
                'code': -32000,
                'message': 'gas required exceeds allowance (0)',
              },
            }),
            200,
          );
        }
        throw StateError('Unexpected RPC: $method');
      });
      final client = Web3Client('https://example.test', transport);
      final expectedCombinedFee =
          (BigInt.from(60000) + BigInt.from(264000)) * BigInt.from(1000000000);
      await expectLater(
        BurstNetworkFee.estimateReviewSteps(
          client,
          [approvePlan, createPlan],
          rpcUrl: 'https://example.test',
          httpClient: transport,
        ),
        throwsA(
          isA<BurstInsufficientNativeBalance>().having(
            (e) => e.estimatedFeeWei,
            'estimatedFeeWei',
            expectedCombinedFee,
          ),
        ),
      );
      client.dispose();
    },
  );

  test(
    'zero-value approve plan falls back to spoofed zero gasPrice when 3-arg state override is unsupported',
    () async {
      final approvePlan = BurstExecutionPlan(
        reference: 'ref-approve',
        wallet: '0x1111111111111111111111111111111111111111',
        campaignId: 'campaign',
        operation: 'approve',
        chainId: 56,
        to: '0x3333333333333333333333333333333333333333',
        value: BigInt.zero,
        data: '0x095ea7b3',
      );
      final transport = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final method = body['method'] as String;
        final params = body['params'] as List? ?? const [];
        if (method == 'eth_chainId') {
          return http.Response(
            jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': '0x38'}),
            200,
          );
        }
        if (method == 'eth_gasPrice') {
          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': body['id'],
              'result': '0x3b9aca00',
            }),
            200,
          );
        }
        if (method == 'eth_getBalance') {
          return http.Response(
            jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': '0x0'}),
            200,
          );
        }
        if (method == 'eth_estimateGas') {
          final tx = params.first as Map<String, dynamic>;
          if (params.length == 1 && tx['gasPrice'] == '0x0') {
            return http.Response(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': body['id'],
                'result': '0xc350', // 50,000 -> buffered 60,000
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': body['id'],
              'error': {
                'code': -32000,
                'message': 'gas required exceeds allowance (0)',
              },
            }),
            200,
          );
        }
        throw StateError('Unexpected RPC: $method');
      });
      final client = Web3Client('https://example.test', transport);
      await expectLater(
        BurstNetworkFee.estimate(
          client,
          approvePlan,
          rpcUrl: 'https://example.test',
          allowBalanceOverride: true,
          httpClient: transport,
        ),
        throwsA(
          isA<BurstInsufficientNativeBalance>().having(
            (e) => e.estimatedFeeWei,
            'estimatedFeeWei',
            BigInt.from(60000) * BigInt.from(1000000000),
          ),
        ),
      );
      client.dispose();
    },
  );

  test(
    'balance-override preview fails over to fallback RPC when primary rejects state override',
    () async {
      final transport = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final method = body['method'] as String;
        final params = body['params'] as List? ?? const [];
        if (method == 'eth_chainId') {
          return http.Response(
            jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': '0x38'}),
            200,
          );
        }
        if (method == 'eth_gasPrice') {
          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': body['id'],
              'result': '0x3b9aca00',
            }),
            200,
          );
        }
        if (method == 'eth_getBalance') {
          return http.Response(
            jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': '0x0'}),
            200,
          );
        }
        if (method == 'eth_estimateGas' && params.length >= 3) {
          if (request.url.host == 'primary.test') {
            return http.Response(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': body['id'],
                'error': {'code': -32602, 'message': 'invalid params'},
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': body['id'],
              'result': '0x186a0',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': body['id'],
            'error': {'code': -32000, 'message': 'insufficient funds for gas'},
          }),
          200,
        );
      });
      final client = Web3Client('https://primary.test', transport);
      await expectLater(
        BurstNetworkFee.estimate(
          client,
          plan,
          rpcUrl: 'https://primary.test',
          fallbackRpcUrls: const ['https://fallback.test'],
          allowBalanceOverride: true,
          httpClient: transport,
        ),
        throwsA(
          isA<BurstInsufficientNativeBalance>().having(
            (e) => e.estimatedFeeWei,
            'estimatedFeeWei',
            BigInt.from(120000) * BigInt.from(1000000000),
          ),
        ),
      );
      client.dispose();
    },
  );
}
