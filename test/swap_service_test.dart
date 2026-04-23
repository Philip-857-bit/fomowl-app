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

    test('isChainSupported returns correct results for gasless vs normal', () {
      final service = SwapService();

      // Chain 1 (Ethereum) supports both
      expect(service.isChainSupported(1, isGasless: true), isTrue);
      expect(service.isChainSupported(1, isGasless: false), isTrue);

      // Chain 56 (BSC) supports normal and gasless
      expect(service.isChainSupported(56, isGasless: false), isTrue);
      expect(service.isChainSupported(56, isGasless: true), isTrue);
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
    test('supports only CoW limit-order chains', () {
      final service = SwapService();

      for (final chainId in cowSupportedLimitChainIds) {
        expect(service.isLimitChainSupported(chainId), isTrue);
      }

      expect(service.isLimitChainSupported(10), isFalse);
      expect(service.isLimitChainSupported(250), isFalse);
      expect(service.isLimitChainSupported(324), isFalse);
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
