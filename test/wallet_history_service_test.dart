import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fomowl_wallet/services/http_client_service.dart';
import 'package:fomowl_wallet/services/wallet_history_service.dart';

class _FakeHttpClientService extends HttpClientService {
  _FakeHttpClientService(this._testClient) : super.internal();

  final http.Client _testClient;

  @override
  http.Client get client => _testClient;
}

void main() {
  test(
    'confirmed send includes token address for server-side pricing',
    () async {
      Map<String, dynamic>? recordedPayload;
      final client = MockClient((request) async {
        recordedPayload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"success":true}', 201);
      });
      final service = WalletHistoryService(
        httpClientService: _FakeHttpClientService(client),
      );

      await service.recordSendConfirmed(
        walletAddress: '0x1111111111111111111111111111111111111111',
        txHash: '0xabc',
        chainId: 56,
        networkName: 'BNB Smart Chain',
        tokenName: 'USD Coin',
        tokenSymbol: 'USDC',
        amountText: '25',
        toAddress: '0x2222222222222222222222222222222222222222',
        tokenAddress: ' 0x3333333333333333333333333333333333333333 ',
        networkKey: 'evm:56',
      );

      expect(
        recordedPayload?['tokenAddress'],
        '0x3333333333333333333333333333333333333333',
      );
    },
  );
}
