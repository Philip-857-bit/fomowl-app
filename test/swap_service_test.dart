import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fomowl_wallet/services/swap_service.dart';

void main() {
  group('SwapService quote parsing', () {
    test('accepts valid quote with platformFeeBps and computes percent', () async {
      final service = SwapService(
        httpClient: MockClient((request) async {
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
        }),
      );

      final quote = await service.get0xQuote(
        chainId: 1,
        fromTokenAddress: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
        toTokenAddress: '0xdac17f958d2ee523a2206206994597c13d831ec7',
        amountWei: '1000',
        buyTokenDecimals: 6,
        isGasless: false,
      );

      expect(quote, isNotNull);
      expect(quote!.amountOutWei, '1000');
      expect(quote.allowanceTarget, '0xabc');
      expect(quote.platformFeeBps, 150);
      expect(quote.platformFeePercent, 1.5);
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
        final service = SwapService(
          httpClient: MockClient((request) async {
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
          }),
        );

        final quote = await service.get0xQuote(
          chainId: 1,
          fromTokenAddress: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
          toTokenAddress: '0xdac17f958d2ee523a2206206994597c13d831ec7',
          amountWei: '1000',
          buyTokenDecimals: 6,
          isGasless: false,
        );

        expect(quote, isNull);
        expect(service.lastError, contains('Insufficient balance'));
      },
    );
  });
}
