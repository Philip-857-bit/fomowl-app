import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fomowl_wallet/services/tron_swap_service.dart';
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
  group('TronSwapService.getQuote', () {
    test('parses valid quote with raw_data_hex', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'outAmount': '1000000',
            'toDecimals': 6,
            'networkFeeUsd': 0.5,
            'platformFeeUsd': 0.2,
            'platformFeeBps': 100,
            'transaction': {
              'raw_data_hex': 'aabbcc',
              'visible': true,
            },
          }),
          200,
        );
      });
      final service = TronSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final quote = await service.getQuote(
        fromToken: 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb',
        toToken: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        amountSun: '1000000',
        walletAddress: 'TXyz',
      );

      expect(quote, isNotNull);
      expect(quote!.amountOutRaw, '1000000');
      expect(quote.platformFeeBps, 100);
      expect(quote.platformFeePercent, 1.0);
      expect(quote.networkFeeUsd, 0.5);
      expect(quote.platformFeeUsd, 0.2);
      expect(quote.unsignedTx['raw_data_hex'], 'aabbcc');
    });

    test('parses valid quote with rawDataHex (camelCase field)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'amountOut': '500000',
            'toDecimals': 6,
            'transaction': {'rawDataHex': 'ddeeff'},
          }),
          200,
        );
      });
      final service = TronSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final quote = await service.getQuote(
        fromToken: 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb',
        toToken: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        amountSun: '500000',
        walletAddress: 'TXyz',
      );

      expect(quote, isNotNull);
      expect(quote!.amountOutRaw, '500000');
      expect(quote.unsignedTx['rawDataHex'], 'ddeeff');
    });

    test('falls back to toAmount field for outAmount', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'toAmount': '750000',
            'toDecimals': 6,
            'transaction': {'raw_data_hex': '112233'},
          }),
          200,
        );
      });
      final service = TronSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final quote = await service.getQuote(
        fromToken: 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb',
        toToken: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        amountSun: '1000000',
        walletAddress: 'TXyz',
      );

      expect(quote, isNotNull);
      expect(quote!.amountOutRaw, '750000');
    });

    test('returns null when transaction field is missing', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'outAmount': '1000000', 'toDecimals': 6}),
          200,
        );
      });
      final service = TronSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final quote = await service.getQuote(
        fromToken: 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb',
        toToken: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        amountSun: '1000000',
        walletAddress: 'TXyz',
      );

      expect(quote, isNull);
      expect(service.lastError, contains('missing the unsigned transaction'));
    });

    test('returns null when raw_data_hex and rawDataHex are both absent',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'outAmount': '1000000',
            'transaction': {'visible': true},
          }),
          200,
        );
      });
      final service = TronSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final quote = await service.getQuote(
        fromToken: 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb',
        toToken: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        amountSun: '1000000',
        walletAddress: 'TXyz',
      );

      expect(quote, isNull);
      expect(service.lastError, contains('raw_data_hex'));
    });

    test('returns null on non-2xx status and sets lastError', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Insufficient liquidity'}),
          400,
        );
      });
      final service = TronSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final quote = await service.getQuote(
        fromToken: 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb',
        toToken: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        amountSun: '1000000',
        walletAddress: 'TXyz',
      );

      expect(quote, isNull);
      expect(service.lastError, isNotNull);
      expect(service.lastError, isNotEmpty);
    });

    test('returns null on unexpected response format and sets lastError',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response('[1, 2, 3]', 200);
      });
      final service = TronSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final quote = await service.getQuote(
        fromToken: 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb',
        toToken: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        amountSun: '1000000',
        walletAddress: 'TXyz',
      );

      expect(quote, isNull);
      expect(service.lastError, contains('Unexpected response format'));
    });
  });

  group('TronSwapService.broadcastSignedTx', () {
    test('returns txid from "txid" field', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'txid': 'abc123txid'}),
          200,
        );
      });
      final service = TronSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final txid = await service.broadcastSignedTx({
        'raw_data_hex': 'aabbcc',
        'signature': ['sighere'],
      });

      expect(txid, 'abc123txid');
    });

    test('falls back to txHash field', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'txHash': 'hash456'}),
          200,
        );
      });
      final service = TronSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final txid = await service.broadcastSignedTx({
        'raw_data_hex': 'aabbcc',
        'signature': ['sighere'],
      });

      expect(txid, 'hash456');
    });

    test('falls back to transactionHash field', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'transactionHash': 'txhash789'}),
          200,
        );
      });
      final service = TronSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final txid = await service.broadcastSignedTx({
        'raw_data_hex': 'aabbcc',
        'signature': ['sighere'],
      });

      expect(txid, 'txhash789');
    });

    test('falls back to id field', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'id': 'idvalue000'}),
          200,
        );
      });
      final service = TronSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final txid = await service.broadcastSignedTx({
        'raw_data_hex': 'aabbcc',
        'signature': ['sighere'],
      });

      expect(txid, 'idvalue000');
    });

    test('returns null and sets error when 2xx response has no txid', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'result': true}), 200);
      });
      final service = TronSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final txid = await service.broadcastSignedTx({
        'raw_data_hex': 'aabbcc',
        'signature': ['sighere'],
      });

      expect(txid, isNull);
      expect(service.lastError, contains('no txid returned'));
    });

    test('returns null on non-2xx status and sets lastError', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Transaction already broadcast'}),
          400,
        );
      });
      final service = TronSwapService(
        httpClientService: HttpClientServiceMock(mockClient),
      );

      final txid = await service.broadcastSignedTx({
        'raw_data_hex': 'aabbcc',
        'signature': ['sighere'],
      });

      expect(txid, isNull);
      expect(service.lastError, isNotNull);
      expect(service.lastError, isNotEmpty);
    });
  });
}
