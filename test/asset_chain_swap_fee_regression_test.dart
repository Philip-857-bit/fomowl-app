import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web3dart/web3dart.dart';
import 'package:fomowl_wallet/services/blockchain/asset_chain_swap_service.dart';

void main() {
  const owner = '0x1111111111111111111111111111111111111111';
  const token = '0x2222222222222222222222222222222222222222';
  const pool = '0x3333333333333333333333333333333333333333';
  AssetChainSwapService service({
    bool allowance = true,
    bool estimateFails = false,
  }) {
    return AssetChainSwapService(
      web3Client: Web3Client(
        'https://rpc.offline.test',
        MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final params = body['params'] as List<dynamic>;
          Object result;
          switch (body['method']) {
            case 'eth_gasPrice':
              result = '0x3d187120';
              break;
            case 'eth_estimateGas':
              final tx = params.first as Map<String, dynamic>;
              expect(tx['from'].toString().toLowerCase(), owner);
              expect(
                tx['to'].toString().toLowerCase(),
                AssetChainSwapService.mainnetRouterAddress,
              );
              expect(tx['data'], startsWith('0x'));
              if (estimateFails) {
                return http.Response(
                  jsonEncode({
                    'jsonrpc': '2.0',
                    'id': body['id'],
                    'error': {'code': 3, 'message': 'execution reverted'},
                  }),
                  200,
                );
              }
              result = '0x186a0';
              break; // independently fixed 100,000 gas
            case 'eth_call':
              final tx = params.first as Map<String, dynamic>;
              final data = tx['data'] as String;
              if (data.startsWith('0x1698ee82')) {
                result = '0x${pool.substring(2).padLeft(64, '0')}';
              } else if (data.startsWith('0xc6a5026a')) {
                result =
                    '0x${BigInt.from(2000000).toRadixString(16).padLeft(64, '0')}';
              } else if (data.startsWith('0xdd62ed3e')) {
                result =
                    '0x${(allowance ? BigInt.from(1000000) : BigInt.zero).toRadixString(16).padLeft(64, '0')}';
              } else {
                throw StateError('Unexpected call: $data');
              }
              break;
            default:
              throw StateError('Unexpected RPC ${body['method']}');
          }
          return http.Response(
            jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
            200,
          );
        }),
      ),
    );
  }

  test(
    'native firm quote uses current gas price and estimates actual calldata',
    () async {
      final quote = await service().getQuote(
        chainId: 42420,
        fromTokenAddress: '',
        toTokenAddress: token,
        amountInWei: '1000000',
        walletAddress: owner,
        useFirmQuote: true,
      );
      expect(quote, isNotNull);
      expect(quote!.txGasPrice, '1025012000');
      expect(quote.txGas, '120000');
      expect(quote.networkFeeNative, closeTo(0.00012300144, 1e-15));
    },
  );
  test(
    'insufficient allowance produces approval-only quote, not executable calldata',
    () async {
      final quote = await service(allowance: false).getQuote(
        chainId: 42420,
        fromTokenAddress: token,
        toTokenAddress: '',
        amountInWei: '1000000',
        walletAddress: owner,
        useFirmQuote: true,
      );
      expect(quote, isNotNull);
      expect(quote!.needsAllowance, isTrue);
      expect(quote.txTo, isNull);
      expect(quote.txGas, isNull);
      expect(quote.networkFeeNative, 0);
    },
  );
  test('failed actual transaction estimate refuses firm quote', () async {
    final sut = service(estimateFails: true);
    final quote = await sut.getQuote(
      chainId: 42420,
      fromTokenAddress: '',
      toTokenAddress: token,
      amountInWei: '1000000',
      walletAddress: owner,
      useFirmQuote: true,
    );
    expect(quote, isNull);
    expect(sut.lastError, contains('estimate'));
  });
  test(
    'preview without sender does not produce a zero-recipient transaction',
    () async {
      final quote = await service().getQuote(
        chainId: 42420,
        fromTokenAddress: '',
        toTokenAddress: token,
        amountInWei: '1000000',
      );
      expect(quote, isNotNull);
      expect(quote!.txTo, isNull);
      expect(quote.txGasPrice, isNull);
      expect(quote.networkFeeNative, 0);
    },
  );
}
