import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
}
