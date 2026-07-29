import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fomowl_wallet/services/bridge_service.dart';
import 'package:fomowl_wallet/services/http_client_service.dart';

class _HttpClientServiceMock extends HttpClientService {
  _HttpClientServiceMock(this._mockClient) : super.internal();

  final http.Client _mockClient;

  @override
  http.Client get client => _mockClient;

  @override
  Future<http.Response> sendWithRetry(
    Future<http.Response> Function() request, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
    bool Function(http.Response)? retryIf,
    bool retryOnException = true,
  }) {
    return request();
  }
}

void main() {
  test('maps an amount-too-low quote error to actionable bridge guidance', () {
    const body =
        '{"code":"AMOUNT_TOO_LOW","message":"Amount is too low for this route."}';

    expect(
      BridgeService.quoteErrorMessage(body),
      'Amount is too low for this bridge. Increase the amount and try again.',
    );
  });

  test('does not expose malformed provider responses', () {
    expect(
      BridgeService.quoteErrorMessage('<html>provider failure</html>'),
      'Unable to fetch a bridge quote right now.',
    );
  });

  test('passes selected slippage to the Relay quote endpoint', () async {
    Uri? requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        '{"code":"ROUTE_UNAVAILABLE","message":"No route."}',
        400,
      );
    });
    final service = BridgeService(
      httpClientService: _HttpClientServiceMock(client),
    );

    await service.getQuote(
      originChainId: 56,
      destinationChainId: 56,
      originCurrency: '0x1111111111111111111111111111111111111111',
      destinationCurrency: BridgeService.nativeCurrency,
      amountWei: '1000000000',
      walletAddress: '0x2222222222222222222222222222222222222222',
      slippageBps: 550,
    );

    expect(requestedUri?.queryParameters['slippageBps'], '550');
  });

  test('parseSteps preserves an EVM approval and deposit in order', () {
    final steps = BridgeService.parseSteps([
      {
        'id': 'approve',
        'description': 'Approve token',
        'items': [
          {
            'data': {
              'to': '0x1111111111111111111111111111111111111111',
              'data': '0x095ea7b3',
              'value': '0',
              'chainId': 137,
              'maxFeePerGas': '0x64',
              'maxPriorityFeePerGas': '10',
            },
          },
        ],
      },
      {
        'id': 'deposit',
        'description': 'Deposit token',
        'items': [
          {
            'data': {
              'to': '0x2222222222222222222222222222222222222222',
              'data': '0xabcdef',
              'value': '0',
              'chainId': 137,
            },
          },
        ],
      },
    ]);

    expect(steps, hasLength(2));
    expect(steps.map((step) => step.stepId), ['approve', 'deposit']);
    expect(steps.every((step) => step.chainId == 137), isTrue);
    expect(steps.first.maxFeePerGas, BigInt.from(100));
    expect(steps.first.maxPriorityFeePerGas, BigInt.from(10));
    expect(steps.every((step) => !step.isSolana), isTrue);
  });
}
