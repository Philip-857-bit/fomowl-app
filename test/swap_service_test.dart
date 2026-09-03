import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fomowl_wallet/services/cow_limit_order_signing.dart';
import 'package:fomowl_wallet/services/swap_service.dart';
import 'package:fomowl_wallet/services/http_client_service.dart';

class HttpClientServiceMock extends HttpClientService {
  final http.Client _mockClient;
  HttpClientServiceMock(this._mockClient) : super.internal();

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
  group('SwapService quote parsing', () {
    test(
      'accepts valid quote with platformFeeBps and computes percent',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'buyAmount': '1000',
              'allowanceTarget': '0xabc',
              'platformFeeBps': 150, // 1.5% fee
              'tokenMetadata': {
                'buyToken': {'decimals': 6},
              },
            }),
            200,
          );
        });
        final service = SwapService(
          httpClientService: HttpClientServiceMock(mockClient),
        );

        final quote = await service.get0xQuote(
          chainId: 1,
          fromTokenAddress: '0xa0b86991c6218b36c1d19D4a2e9Eb0ce3606eb48',
          toTokenAddress: '0xdac17f958d2ee523a2206206994597C13D831ec7',
          amountWei: '1000',
          buyTokenDecimals: 6,
          isGasless: false,
        );

        expect(quote, isNotNull);
        expect(quote!.amountOutWei, '1000');
        expect(quote.allowanceTarget, '0xabc');
        expect(quote.platformFeeBps, 150);
        expect(quote.platformFeePercent, 1.5);
      },
    );

    test('parses platformFeeUsd from backend quote response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'buyAmount': '1000',
            'allowanceTarget': '0xabc',
            'platformFeeBps': 200,
            'platformFeeUsd': 1.0,
            'tokenMetadata': {
              'buyToken': {'decimals': 6},
            },
          }),
          200,
        );
      });
      final service = SwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final quote = await service.get0xQuote(
        chainId: 56,
        fromTokenAddress: '0x55d398326f99059ff775485246999027b3197955',
        toTokenAddress: '0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d',
        amountWei: '1000',
        buyTokenDecimals: 6,
        isGasless: false,
      );

      expect(quote, isNotNull);
      expect(quote!.platformFeeBps, 200);
      expect(quote.platformFeeUsd, 1.0);
    });

    test(
      'keeps the committed transaction and analytics id on the firm quote',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, endsWith('/api/swap/quote'));
          return http.Response(
            jsonEncode({
              'buyAmount': '2500000',
              'minBuyAmount': '2475000',
              'analyticsEventId': 'evt-firm-quote-1',
              'transaction': {
                'to': '0x1111111111111111111111111111111111111111',
                'data': '0x1234',
                'value': '0',
                'gas': '210000',
                'gasPrice': '3000000000',
              },
              'tokenMetadata': {
                'buyToken': {'decimals': 6},
              },
            }),
            200,
          );
        });
        final service = SwapService(
          httpClientService: HttpClientServiceMock(mockClient),
        );

        final quote = await service.get0xQuote(
          chainId: 56,
          fromTokenAddress: '0x55d398326f99059ff775485246999027b3197955',
          toTokenAddress: '0x0000000000000000000000000000000000000000',
          amountWei: '1000000',
          buyTokenDecimals: 6,
          isGasless: false,
          walletAddress: '0x2222222222222222222222222222222222222222',
          useFirmQuote: true,
        );

        expect(quote, isNotNull);
        expect(quote!.analyticsEventId, 'evt-firm-quote-1');
        expect(quote.minAmountOutWei, '2475000');
        expect(quote.txTo, '0x1111111111111111111111111111111111111111');
        expect(quote.txData, '0x1234');
        expect(quote.txValue, '0');
        expect(quote.txGas, '210000');
        expect(quote.txGasPrice, '3000000000');
      },
    );

    test('preserves detected buy and sell tax metadata', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'liquidityAvailable': true,
            'buyAmount': '1000',
            'tokenMetadata': {
              'buyToken': {
                'decimals': 18,
                'buyTaxBps': '125',
                'sellTaxBps': '0',
              },
              'sellToken': {'buyTaxBps': '0', 'sellTaxBps': '399'},
            },
          }),
          200,
        );
      });
      final service = SwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final quote = await service.get0xQuote(
        chainId: 56,
        fromTokenAddress: '0x72928a49c4e88f382b0b6ff3e561f56dd75485f9',
        toTokenAddress: '',
        amountWei: '10000000000000',
        buyTokenDecimals: 18,
        isGasless: true,
        walletAddress: '0x1111111111111111111111111111111111111111',
      );

      expect(quote, isNotNull);
      expect(quote!.sellTaxBps, 399);
      expect(quote.buyTaxBps, 125);
      expect(quote.taxMetadataAvailable, isTrue);
      expect(quote.hasTransferTax, isTrue);
    });

    test(
      'rejects a 200 response when gasless liquidity is unavailable',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'liquidityAvailable': false, 'zid': '0xroute'}),
            200,
          );
        });
        final service = SwapService(
          httpClientService: HttpClientServiceMock(mockClient),
        );

        final quote = await service.get0xQuote(
          chainId: 56,
          fromTokenAddress: '0x72928a49c4e88f382b0b6ff3e561f56dd75485f9',
          toTokenAddress: '',
          amountWei: '6862706314430',
          buyTokenDecimals: 18,
          isGasless: true,
          walletAddress: '0x1111111111111111111111111111111111111111',
        );

        expect(quote, isNull);
        expect(service.lastError, contains('too low for a gasless route'));
        expect(service.lastError, contains('turn off Gasless'));
      },
    );

    test('isChainSupported returns correct results for gasless vs normal', () {
      final service = SwapService();

      // Chain 1 (Ethereum) supports both
      expect(service.isChainSupported(1, isGasless: true), isTrue);
      expect(service.isChainSupported(1, isGasless: false), isTrue);

      // Chain 56 (BSC) supports normal and gasless
      expect(service.isChainSupported(56, isGasless: false), isTrue);
      expect(service.isChainSupported(56, isGasless: true), isTrue);

      // Robinhood supports both APIs, while Linea is standard-swap only.
      expect(service.isChainSupported(4663, isGasless: false), isTrue);
      expect(service.isChainSupported(4663, isGasless: true), isTrue);
      expect(service.isChainSupported(59144, isGasless: false), isTrue);
      expect(service.isChainSupported(59144, isGasless: true), isFalse);
    });

    test(
      'surfaces provider issue descriptions when buyAmount is empty',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'buyAmount': '0',
              'issues': {
                'balance': {
                  'description': 'Insufficient balance for sell token',
                },
              },
            }),
            200,
          );
        });
        final service = SwapService(
          httpClientService: HttpClientServiceMock(mockClient),
        );

        final quote = await service.get0xQuote(
          chainId: 1,
          fromTokenAddress: '0xa0b86991c6218b36c1d19D4a2e9Eb0ce3606eb48',
          toTokenAddress: '0xdac17f958d2ee523a2206206994597C13D831ec7',
          amountWei: '1000',
          buyTokenDecimals: 6,
          isGasless: false,
        );

        expect(quote, isNull);
        expect(service.lastError, contains('Insufficient balance'));
      },
    );

    test(
      'returns quote even if hasBalanceIssue is true when buyAmount is valid',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'buyAmount': '5000',
              'hasBalanceIssue': true,
              'allowanceTarget': '0xabc',
              'tokenMetadata': {
                'buyToken': {'decimals': 18},
              },
            }),
            200,
          );
        });
        final service = SwapService(
          httpClientService: HttpClientServiceMock(mockClient),
        );

        final quote = await service.get0xQuote(
          chainId: 1,
          fromTokenAddress: '0x123',
          toTokenAddress: '0x456',
          amountWei: '1000',
          buyTokenDecimals: 18,
          isGasless: false,
        );

        expect(quote, isNotNull);
        expect(quote!.hasBalanceIssue, isTrue);
        expect(quote.amountOutWei, '5000');
      },
    );
  });

  group('SwapService limit orders', () {
    test('supports only OpenOcean limit-order chains', () {
      final service = SwapService();

      // Limit orders are backed by OpenOcean, whose supported chain set is a
      // superset of the CoW chains.
      for (final chainId in openOceanSupportedLimitChainIds) {
        expect(service.isLimitChainSupported(chainId), isTrue);
      }
      for (final chainId in cowSupportedLimitChainIds) {
        expect(service.isLimitChainSupported(chainId), isTrue);
      }

      // Chains outside the supported set.
      expect(service.isLimitChainSupported(5), isFalse);
      expect(service.isLimitChainSupported(25), isFalse);
      expect(service.isLimitChainSupported(999999), isFalse);
    });

    test('createLimitOrder prefers canonical orderUid', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 'local-order-1',
            'status': 'open',
            'orderUid': '0xuid123',
            'orderHash': '0xlegacy',
          }),
          200,
        );
      });
      final service = SwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final result = await service.createLimitOrder(
        chainId: 1,
        walletAddress: '0x111111125421ca6dc452d289314280a0f8842a65',
        order: {
          'sellToken': '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
          'buyToken': '0x6b175474e89094c44da98b954eedeac495271d0f',
        },
        signature: '0xsig',
      );

      expect(result, isNotNull);
      expect(result!.orderUid, '0xuid123');
      expect(result.orderHash, '0xuid123');
    });

    test(
      'listLimitOrders falls back to orderHash alias during rollout',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'orders': [
                {
                  'id': 'local-order-2',
                  'walletAddress': '0x111111125421ca6dc452d289314280a0f8842a65',
                  'chainId': 1,
                  'sellToken': '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
                  'buyToken': '0x6b175474e89094c44da98b954eedeac495271d0f',
                  'sellAmount': '1000000',
                  'buyAmount': '998000000000000000',
                  'kind': 'buy',
                  'targetPrice': '998',
                  'expiry': 1700000000,
                  'status': 'open',
                  'orderHash': '0xlegacy-only',
                },
              ],
            }),
            200,
          );
        });
        final service = SwapService(
          httpClientService: HttpClientServiceMock(mockClient),
        );

        final orders = await service.getLimitOrders(
          walletAddress: '0x111111125421ca6dc452d289314280a0f8842a65',
        );

        expect(orders, hasLength(1));
        expect(orders.first.kind, 'buy');
        expect(orders.first.orderUid, '0xlegacy-only');
        expect(orders.first.orderHash, '0xlegacy-only');
      },
    );
  });
}
