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
  }) {
    return request();
  }
}

void main() {
  group('SolanaSwapService.getQuote', () {
    test('parses valid quote with swapTransaction field', () async {
      final mockClient = MockClient((request) async {
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
        expect(service.lastError, contains('missing the unsigned transaction'));
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
