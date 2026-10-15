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
  test('Bitcoin bridge requests use the strict dedicated route', () async {
    Uri? requested;
    final service = BridgeService(
      httpClientService: _HttpClientServiceMock(
        MockClient((request) async {
          requested = request.url;
          return http.Response('{"message":"No route available."}', 409);
        }),
      ),
    );
    await service.getQuote(
      originChainId: BridgeService.relayBitcoinChainId,
      destinationChainId: 8453,
      originCurrency: BridgeService.bitcoinNativeCurrency,
      destinationCurrency: BridgeService.nativeCurrency,
      amountWei: '100000',
      walletAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      recipientAddress: '0x03508bb71268bba25ecacc8f620e01866650532c',
      commit: true,
    );
    expect(requested?.path, endsWith('/api/swap/cross-chain/bitcoin/quote'));
    expect(requested?.queryParameters['amount'], '100000');
    expect(requested?.queryParameters['commit'], 'true');
  });
  test(
    'Bitcoin cannot fall through to the ordinary same-chain swap endpoint',
    () async {
      var called = false;
      final service = BridgeService(
        httpClientService: _HttpClientServiceMock(
          MockClient((request) async {
            called = true;
            return http.Response('{}', 200);
          }),
        ),
      );
      final quote = await service.getQuote(
        originChainId: BridgeService.relayBitcoinChainId,
        destinationChainId: BridgeService.relayBitcoinChainId,
        originCurrency: BridgeService.bitcoinNativeCurrency,
        destinationCurrency: BridgeService.bitcoinNativeCurrency,
        amountWei: '100000',
        walletAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      );
      expect(quote, isNull);
      expect(called, isFalse);
    },
  );
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
      'Unable to fetch a bridge route right now.',
    );
  });

  test('does not expose internal routing language in quote errors', () {
    expect(
      BridgeService.quoteErrorMessage(
        '{"message":"Relay provider route failed"}',
      ),
      'Unable to fetch a bridge route right now.',
    );
  });

  test('uses swap wording for a same-chain route failure', () {
    expect(
      BridgeService.quoteErrorMessage(
        '{"code":"ROUTE_UNAVAILABLE","message":"No bridge route is available."}',
        isSameChain: true,
      ),
      'Unable to fetch a swap route right now.',
    );
  });

  test('shows the user the slippage needed for a taxed token', () {
    expect(
      BridgeService.quoteErrorMessage(
        '{"code":"SLIPPAGE_TOO_LOW","suggestedSlippageBps":800}',
        isSameChain: true,
      ),
      'This token needs at least 8.00% slippage to account for its transfer fee. Increase slippage and request a new quote.',
    );
  });

  test('reads destination currency USD metadata', () {
    final currency = BridgeCurrency.fromJson({
      'chainId': 1,
      'address': '0xbtc',
      'symbol': 'WBTC',
      'name': 'Wrapped Bitcoin',
      'decimals': 8,
      'metadata': {'priceUsd': '65000.25'},
    });

    expect(currency.priceUsd, 65000.25);
  });

  test(
    'routes same-chain EVM quotes through the 0x-first swap endpoint',
    () async {
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
      expect(requestedUri?.path, endsWith('/api/swap/quote'));
      expect(requestedUri?.queryParameters['chainId'], '56');
      expect(requestedUri?.queryParameters['src'], startsWith('0x1111'));
      expect(
        requestedUri?.queryParameters.containsKey('originChainId'),
        isFalse,
      );
    },
  );

  test('turns a same-chain 0x quote into approval and swap steps', () async {
    final client = MockClient(
      (_) async => http.Response(
        '''{"buyAmount":"900000","minBuyAmount":"890000","needsAllowance":true,"allowanceSpender":"0x3333333333333333333333333333333333333333","platformFeeBps":1000,"platformFeeUsd":1.0,"networkFeeUsd":0.02,"transaction":{"to":"0x4444444444444444444444444444444444444444","data":"0xabcdef","value":"0","gas":"250000","gasPrice":"1000000000"}}''',
        200,
      ),
    );
    final service = BridgeService(
      httpClientService: _HttpClientServiceMock(client),
    );

    final quote = await service.getQuote(
      originChainId: 56,
      destinationChainId: 56,
      originCurrency: '0x1111111111111111111111111111111111111111',
      destinationCurrency: BridgeService.nativeCurrency,
      amountWei: '1000000',
      walletAddress: '0x2222222222222222222222222222222222222222',
      slippageBps: 50,
    );

    expect(quote, isNotNull);
    expect(quote!.routeProviderLabel, '0x');
    expect(quote.steps, hasLength(2));
    expect(quote.steps.first.to, '0x1111111111111111111111111111111111111111');
    expect(quote.steps.first.data, startsWith('0x095ea7b3'));
    expect(quote.steps.last.to, '0x4444444444444444444444444444444444444444');
    expect(quote.requestId, isEmpty);
  });

  test(
    'does not send a same-chain TRON route to the EVM swap endpoint',
    () async {
      Uri? requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response('{"code":"ROUTE_UNAVAILABLE"}', 400);
      });
      final service = BridgeService(
        httpClientService: _HttpClientServiceMock(client),
      );

      await service.getQuote(
        originChainId: BridgeService.tronBridgeChainId,
        destinationChainId: BridgeService.tronBridgeChainId,
        originCurrency: BridgeService.tronNativeCurrency,
        destinationCurrency: BridgeService.tronNativeCurrency,
        amountWei: '1000000',
        walletAddress: 'TWallet',
      );

      expect(requestedUri?.path, endsWith('/api/swap/cross-chain/quote'));
    },
  );

  test('parses actionable slippage refund guidance', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"status":"refund","inTxHashes":["0xorigin"],"txHashes":["0xrefund"],"failureCode":"SLIPPAGE_EXCEEDED","failureMessage":"The destination price moved beyond the allowed slippage, so this bridge could not complete.","suggestedAction":"Your funds were returned on the origin network. Refresh your balances, then request a new quote and try again."}',
        200,
      ),
    );
    final service = BridgeService(
      httpClientService: _HttpClientServiceMock(client),
    );

    final status = await service.getStatus(requestId: '0xrequest');

    expect(status, isNotNull);
    expect(status!.isFailure, isTrue);
    expect(status.isRefunded, isTrue);
    expect(status.failureCode, 'SLIPPAGE_EXCEEDED');
    expect(status.txHashes, ['0xrefund', '0xorigin']);
    expect(status.userFacingFailureMessage, contains('allowed slippage'));
    expect(status.userFacingFailureMessage, contains('What you can do:'));
    expect(status.userFacingFailureMessage, contains('request a new quote'));
    expect(
      status.userFacingFailureMessage.toLowerCase(),
      isNot(contains('relay')),
    );
  });

  test('refund without details still gives a safe recovery action', () {
    const status = BridgeStatus(status: 'refund', txHashes: []);

    expect(status.userFacingFailureMessage, contains('funds were returned'));
    expect(status.userFacingFailureMessage, contains('Refresh your balance'));
    expect(status.userFacingFailureMessage, isNot(contains('Do not submit')));
  });

  test(
    'accepts a dry TRON preview and commits only on explicit request',
    () async {
      final requestedUris = <Uri>[];
      final client = MockClient((request) async {
        requestedUris.add(request.url);
        final committed = request.url.queryParameters['commit'] == 'true';
        return http.Response(
          '''{"originChainId":728126428,"destinationChainId":1399811149,"amountIn":"1000000","amountOut":"900000","feeUsd":0,"gasFeeUsd":0,"requestId":"${committed ? 'near:TDeposit' : ''}","steps":${committed ? '[{"id":"deposit","description":"Deposit","items":[{"data":{"chainType":"tvm","chainId":728126428,"depositAddress":"TDeposit","transaction":{"raw_data_hex":"deadbeef"}}}]}]' : '[]'},"extra":{"committed":$committed,"deadline":"2099-01-01T00:00:00Z"}}''',
          200,
        );
      });
      final service = BridgeService(
        httpClientService: _HttpClientServiceMock(client),
      );

      final preview = await service.getQuote(
        originChainId: BridgeService.tronBridgeChainId,
        destinationChainId: BridgeService.relaySolanaChainId,
        originCurrency: BridgeService.tronNativeCurrency,
        destinationCurrency: BridgeService.solanaNativeCurrency,
        amountWei: '1000000',
        walletAddress: 'TWallet',
      );
      final committed = await service.commitQuote(
        originChainId: BridgeService.tronBridgeChainId,
        destinationChainId: BridgeService.relaySolanaChainId,
        originCurrency: BridgeService.tronNativeCurrency,
        destinationCurrency: BridgeService.solanaNativeCurrency,
        amountWei: '1000000',
        walletAddress: 'TWallet',
      );

      expect(preview, isNotNull);
      expect(preview!.committed, isFalse);
      expect(preview.steps, isEmpty);
      expect(preview.canBeginExecution, isTrue);
      expect(committed, isNotNull);
      expect(committed!.committed, isTrue);
      expect(committed.steps.single.isTron, isTrue);
      expect(
        requestedUris.first.queryParameters.containsKey('commit'),
        isFalse,
      );
      expect(requestedUris.last.queryParameters['commit'], 'true');
    },
  );

  test('accepts flattened NEAR Intents preview metadata', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"originChainId":728126428,"destinationChainId":1,"amountIn":"1000000000","amountOut":"170192993473152434","amountOutUsd":32.91,"feeUsd":0,"requestId":"","steps":[],"provider":"near_intents","committed":false,"deadline":"2099-01-01T00:00:00Z"}',
        200,
      ),
    );
    final service = BridgeService(
      httpClientService: _HttpClientServiceMock(client),
    );

    final preview = await service.getQuote(
      originChainId: BridgeService.tronBridgeChainId,
      destinationChainId: 1,
      originCurrency: BridgeService.tronNativeCurrency,
      destinationCurrency: BridgeService.nativeCurrency,
      amountWei: '1000000000',
      walletAddress: 'TWallet',
    );

    expect(preview, isNotNull);
    expect(preview!.committed, isFalse);
    expect(preview.canBeginExecution, isTrue);
    expect(preview.routeProviderLabel, 'NEAR Intents');
    expect(preview.amountOutUsd, 32.91);
    expect(preview.bridgeFeeUsd, 0);
    expect(preview.gasFeeUsd, isNull);
  });

  test('prefers protocolUsed and reads a nested provider safely', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"amountOut":"900000","protocolUsed":"relay","provider":{"name":"ignored"},"details":{"currencyOut":{"amountUsd":"0.89"}},"feeUsd":0.15,"gasFeeUsd":0.02,"effectiveSlippageBps":800,"steps":[],"committed":false}',
        200,
      ),
    );
    final service = BridgeService(
      httpClientService: _HttpClientServiceMock(client),
    );

    final preview = await service.getQuote(
      originChainId: 1,
      destinationChainId: 8453,
      originCurrency: BridgeService.nativeCurrency,
      destinationCurrency: BridgeService.nativeCurrency,
      amountWei: '1000000',
      walletAddress: '0x2222222222222222222222222222222222222222',
    );

    expect(preview?.routeProviderLabel, 'Relay');
    expect(preview?.amountOutUsd, 0.89);
    expect(preview?.bridgeFeeUsd, 0.15);
    expect(preview?.gasFeeUsd, 0.02);
    expect(preview?.effectiveSlippageBps, 800);
  });

  test('preserves an omitted bridge fee as null', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"amountOut":"900000","provider":"relay","steps":[],"committed":false}',
        200,
      ),
    );
    final service = BridgeService(
      httpClientService: _HttpClientServiceMock(client),
    );

    final preview = await service.getQuote(
      originChainId: 1,
      destinationChainId: 8453,
      originCurrency: BridgeService.nativeCurrency,
      destinationCurrency: BridgeService.nativeCurrency,
      amountWei: '1000000',
      walletAddress: '0x2222222222222222222222222222222222222222',
    );

    expect(preview?.bridgeFeeUsd, isNull);
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

  test('parseSteps recognizes a signable TRON deposit transaction', () {
    final steps = BridgeService.parseSteps([
      {
        'id': 'near_intents_deposit',
        'description': 'Deposit to NEAR Intents',
        'items': [
          {
            'data': {
              'chainType': 'tvm',
              'chainId': BridgeService.tronBridgeChainId,
              'depositAddress': 'TDepositAddress',
              'transaction': {
                'txID': 'abc123',
                'raw_data_hex': 'deadbeef',
                'raw_data': {'contract': []},
              },
            },
          },
        ],
      },
    ]);

    expect(steps, hasLength(1));
    expect(steps.single.isTron, isTrue);
    expect(steps.single.isSolana, isFalse);
    expect(steps.single.chainId, BridgeService.tronBridgeChainId);
    expect(steps.single.to, 'TDepositAddress');
    expect(steps.single.tronTransactionJson, contains('raw_data_hex'));
  });

  test('parseSteps recognizes a wallet-native Solana deposit transfer', () {
    final steps = BridgeService.parseSteps([
      {
        'id': 'near_intents_deposit',
        'description': 'Deposit to NEAR Intents',
        'items': [
          {
            'data': {
              'chainType': 'solana-transfer',
              'chainId': BridgeService.relaySolanaChainId,
              'to': 'Deposit111111111111111111111111111111111',
              'amount': '1234567',
              'tokenMint': 'Mint111111111111111111111111111111111111',
            },
          },
        ],
      },
    ]);

    expect(steps, hasLength(1));
    expect(steps.single.isSolanaTransfer, isTrue);
    expect(steps.single.solanaTransferAmount, BigInt.from(1234567));
    expect(steps.single.solanaTokenMint, startsWith('Mint'));
  });

  test('submits a confirmed NEAR Intents origin transaction', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('{"submitted":true}', 202);
    });
    final service = BridgeService(
      httpClientService: _HttpClientServiceMock(client),
    );

    final submitted = await service.submitNearDeposit(
      requestId: 'near:TDepositAddress',
      txHash: 'abc123',
    );

    expect(submitted, isTrue);
    expect(captured.method, 'POST');
    expect(captured.url.path, contains('/cross-chain/near-deposit'));
    expect(captured.body, contains('TDepositAddress'));
    expect(captured.body, contains('abc123'));
  });
}
