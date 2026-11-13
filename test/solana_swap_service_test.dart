import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fomowl_wallet/services/solana_swap_service.dart';
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
  group('SolanaSwapService.getQuote', () {
    test('parses valid quote with swapTransaction field', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['sellAmountUsd'], isNull);
        return http.Response(
          jsonEncode({
            'swapTransaction': 'base64txhere==',
            'requestId': 'req-001',
            'outAmount': '1000000000',
            'toDecimals': 9,
            'networkFeeUsd': 0.001,
            'platformFeeUsd': 0.05,
            'platformFeeBps': 50,
          }),
          200,
        );
      });
      final service = SolanaSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final quote = await service.getQuote(
        fromMint: 'So11111111111111111111111111111111111111112',
        toMint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
        amountLamports: '1000000000',
        walletAddress: 'SoLWaLLetAddresS',
      );

      expect(quote, isNotNull);
      expect(quote!.swapTransaction, 'base64txhere==');
      expect(quote.requestId, 'req-001');
      expect(quote.amountOutRaw, '1000000000');
      expect(quote.platformFeeBps, 50);
      expect(quote.platformFeePercent, 0.5);
      expect(quote.networkFeeUsd, 0.001);
      expect(quote.platformFeeUsd, 0.05);
    });

    test('sends sellAmountUsd hint when available', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['sellAmountUsd'], '100.25');
        return http.Response(
          jsonEncode({
            'swapTransaction': 'base64txhere==',
            'requestId': 'req-usd-hint',
            'outAmount': '1000000000',
            'toDecimals': 9,
          }),
          200,
        );
      });
      final service = SolanaSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final quote = await service.getQuote(
        fromMint: 'So11111111111111111111111111111111111111112',
        toMint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
        amountLamports: '1000000000',
        walletAddress: 'SoLWaLLetAddresS',
        sellAmountUsd: 100.25,
      );

      expect(quote, isNotNull);
      expect(quote!.requestId, 'req-usd-hint');
    });

    test('falls back to "transaction" field for swapTransaction', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'transaction': 'altbase64tx==',
            'requestId': 'req-002',
            'outAmount': '500000000',
            'toDecimals': 9,
          }),
          200,
        );
      });
      final service = SolanaSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final quote = await service.getQuote(
        fromMint: 'So11111111111111111111111111111111111111112',
        toMint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
        amountLamports: '500000000',
        walletAddress: 'SoLWaLLetAddresS',
      );

      expect(quote, isNotNull);
      expect(quote!.swapTransaction, 'altbase64tx==');
    });

    test('parses backend SwapResponse tx_data payload', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'amount_out': '1234500',
            'fee_usd': 0.02,
            'fee_bps': 75,
            'request_id': 'req-nested',
            'tx_data': {
              'transaction': 'nestedbase64tx==',
              'outAmount': '1234500',
              'feeBps': 75,
              'router': 'jupiter-v2',
              'mode': 'manual',
            },
          }),
          200,
        );
      });
      final service = SolanaSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final quote = await service.getQuote(
        fromMint: 'So11111111111111111111111111111111111111112',
        toMint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
        amountLamports: '222000',
        walletAddress: 'SoLWaLLetAddresS',
      );

      expect(quote, isNotNull);
      expect(quote!.swapTransaction, 'nestedbase64tx==');
      expect(quote.requestId, 'req-nested');
      expect(quote.amountOutRaw, '1234500');
      expect(quote.platformFeeUsd, 0.02);
      expect(quote.platformFeeBps, 75);
    });

    test('falls back to "serializedTransaction" field', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'serializedTransaction': 'serbase64tx==',
            'request_id': 'req-003',
            'amountOut': '250000000',
            'toDecimals': 9,
          }),
          200,
        );
      });
      final service = SolanaSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final quote = await service.getQuote(
        fromMint: 'So11111111111111111111111111111111111111112',
        toMint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
        amountLamports: '250000000',
        walletAddress: 'SoLWaLLetAddresS',
      );

      expect(quote, isNotNull);
      expect(quote!.swapTransaction, 'serbase64tx==');
      expect(quote.requestId, 'req-003');
    });

    test(
      'returns null and sets error when swapTransaction is absent',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'outAmount': '1000000000', 'toDecimals': 9}),
            200,
          );
        });
        final service = SolanaSwapService(
          httpClientService: HttpClientServiceMock(mockClient),
        );

        final quote = await service.getQuote(
          fromMint: 'So11111111111111111111111111111111111111112',
          toMint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
          amountLamports: '1000000000',
          walletAddress: 'SoLWaLLetAddresS',
        );

        expect(quote, isNull);
        expect(
          service.lastError,
          'The swap quote is incomplete. Please try again.',
        );
      },
    );

    test(
      'sanitizes 2xx Jupiter insufficient funds without transaction',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'outAmount': '8902176519',
              'tx_data': {
                'transaction': '',
                'error': 'Insufficient funds',
                'router': 'metis',
              },
            }),
            200,
          );
        });
        final service = SolanaSwapService(
          httpClientService: HttpClientServiceMock(mockClient),
        );

        final quote = await service.getQuote(
          fromMint: 'So11111111111111111111111111111111111111112',
          toMint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
          amountLamports: '100000000000',
          walletAddress: 'SoLWaLLetAddresS',
        );

        expect(quote, isNull);
        expect(
          service.lastError,
          'You don\'t have enough SOL to complete this swap. Add more SOL to cover the swap amount plus network fees.',
        );
      },
    );

    test('returns null on non-2xx status and sets lastError', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Route not found for token pair'}),
          400,
        );
      });
      final service = SolanaSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final quote = await service.getQuote(
        fromMint: 'So11111111111111111111111111111111111111112',
        toMint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
        amountLamports: '1000000000',
        walletAddress: 'SoLWaLLetAddresS',
      );

      expect(quote, isNull);
      expect(service.lastError, isNotNull);
      expect(service.lastError, isNotEmpty);
    });

    test('returns null on unexpected response format', () async {
      final mockClient = MockClient((request) async {
        return http.Response('[1, 2, 3]', 200);
      });
      final service = SolanaSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final quote = await service.getQuote(
        fromMint: 'So11111111111111111111111111111111111111112',
        toMint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
        amountLamports: '1000000000',
        walletAddress: 'SoLWaLLetAddresS',
      );

      expect(quote, isNull);
      expect(service.lastError, contains('Unexpected response format'));
    });
  });

  group('SolanaSwapService.executeSwap', () {
    test('returns txid from "txid" field', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'txid': 'solana-tx-sig-001'}), 200);
      });
      final service = SolanaSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final txHash = await service.executeSwap(
        signedTransactionBase64: 'signedbase64tx==',
        requestId: 'req-001',
      );

      expect(txHash, 'solana-tx-sig-001');
    });

    test('falls back to "signature" field', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'signature': 'sig-value-002'}), 200);
      });
      final service = SolanaSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final txHash = await service.executeSwap(
        signedTransactionBase64: 'signedbase64tx==',
        requestId: 'req-001',
      );

      expect(txHash, 'sig-value-002');
    });

    test('falls back to "transactionHash" field', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'transactionHash': 'txhash-003'}),
          200,
        );
      });
      final service = SolanaSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final txHash = await service.executeSwap(
        signedTransactionBase64: 'signedbase64tx==',
        requestId: 'req-001',
      );

      expect(txHash, 'txhash-003');
    });

    test('falls back to "txHash" field', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'txHash': 'txhash-via-txHash-field'}),
          200,
        );
      });
      final service = SolanaSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final txHash = await service.executeSwap(
        signedTransactionBase64: 'signedbase64tx==',
        requestId: 'req-001',
      );

      expect(txHash, 'txhash-via-txHash-field');
    });

    test(
      'returns null and sets error when 2xx response has no tx signature',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'status': 'submitted'}), 200);
        });
        final service = SolanaSwapService(
          httpClientService: HttpClientServiceMock(mockClient),
        );

        final txHash = await service.executeSwap(
          signedTransactionBase64: 'signedbase64tx==',
          requestId: 'req-001',
        );

        expect(txHash, isNull);
        expect(
          service.lastError,
          contains('no transaction signature returned'),
        );
      },
    );

    test('returns null on non-2xx status and sets lastError', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'message': 'Simulation failed'}), 400);
      });
      final service = SolanaSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final txHash = await service.executeSwap(
        signedTransactionBase64: 'signedbase64tx==',
        requestId: 'req-001',
      );

      expect(txHash, isNull);
      expect(service.lastError, isNotNull);
      expect(service.lastError, isNotEmpty);
    });
  });
}
