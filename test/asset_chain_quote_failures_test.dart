import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fomowl_wallet/services/swap_service.dart';
import 'package:fomowl_wallet/services/http_client_service.dart';
import 'package:fomowl_wallet/utils/swap_quote_error_messages.dart';

class _Http extends HttpClientService {
  _Http(this.transport) : super.internal();
  final http.Client transport;
  int? retryLimit;
  @override
  http.Client get client => transport;
  @override
  Future<http.Response> sendWithRetry(
    Future<http.Response> Function() request, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
    bool Function(http.Response)? retryIf,
    bool retryOnException = true,
  }) {
    retryLimit = maxRetries;
    return super.sendWithRetry(
      request,
      maxRetries: maxRetries,
      delay: Duration.zero,
      retryIf: retryIf,
      retryOnException: retryOnException,
    );
  }
}

Future<SwapQuote?> _quote(SwapService service) => service.get0xQuote(
  chainId: 42420,
  fromTokenAddress: '',
  toTokenAddress: '0x26e490d30e73c36800788dc6d6315946c4bbea24',
  amountWei: '100000000000000000000',
  buyTokenDecimals: 18,
  isGasless: false,
);

void main() {
  test('transport errors do not start an unbounded local scan', () async {
    final client = MockClient(
      (_) async => throw http.ClientException('Connection closed'),
    );
    final service = SwapService(httpClientService: _Http(client));
    expect(await _quote(service), isNull);
    expect(service.lastError, contains('temporarily unavailable'));
    client.close();
  });
  for (final body in [
    '{}',
    '[]',
    'invalid json',
    '{"buyAmount":"0"}',
    '{"buyAmount":"1","usedFallback":true}',
  ]) {
    test(
      'invalid successful Asset Chain quote is identified as incomplete: $body',
      () async {
        final client = MockClient((_) async => http.Response(body, 200));
        final service = SwapService(httpClientService: _Http(client));
        expect(await _quote(service), isNull);
        expect(service.lastError, swapQuoteIncompleteMessage);
        client.close();
      },
    );
  }
  test(
    'the staging 400 preserves its cause without repeating the pool scan',
    () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response(
          '{"error":"Insufficient liquidity","message":"No liquidity pool"}',
          400,
        );
      });
      final service = SwapService(httpClientService: _Http(client));
      expect(await _quote(service), isNull);
      expect(service.lastError, swapRouteUnavailableMessage);
      expect(requests, 1);
      client.close();
    },
  );
  test(
    'RPC unavailable response has a single bounded request, no repeated direct scans',
    () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response(
          '{"error":"Asset Chain RPC unavailable","message":"Asset Chain is temporarily unavailable. Please try again shortly."}',
          503,
        );
      });
      final transport = _Http(client);
      final service = SwapService(httpClientService: transport);
      expect(await _quote(service), isNull);
      expect(requests, 1);
      expect(transport.retryLimit, 1);
      expect(service.lastError, contains('temporarily unavailable'));
      client.close();
    },
  );
  test('timing out a quote never starts background retry requests', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return http.Response('{"buyAmount":"1000000"}', 200);
    });
    final service = SwapService(
      httpClientService: _Http(client),
      assetChainRequestTimeout: const Duration(milliseconds: 10),
    );
    expect(await _quote(service), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(requests, 1);
    expect(service.lastError, contains('temporarily unavailable'));
    client.close();
  });
  test('a price quote does not require a funded wallet or a taker', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters.containsKey('taker'), isFalse);
      return http.Response(
        '{"buyAmount":"1000000","minBuyAmount":"990000","networkFeeUnavailable":true}',
        200,
      );
    });
    final service = SwapService(httpClientService: _Http(client));
    expect(await _quote(service), isNotNull);
    client.close();
  });
}
