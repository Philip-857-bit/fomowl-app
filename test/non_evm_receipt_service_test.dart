import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fomowl_wallet/models/non_evm_receipt_facts.dart';
import 'package:fomowl_wallet/services/non_evm_receipt_service.dart';

final solHash = '2' * 88;
final tronHash = 'a' * 64;
Map<String, dynamic> sol() => {
  'networkKey': 'solana:mainnet',
  'transactionHash': solHash,
  'status': 1,
  'slot': 42,
  'feeLamports': '18446744073709551615',
  'computeUnitsConsumed': '1234',
};
Map<String, dynamic> tron() => {
  'networkKey': 'tron:mainnet',
  'transactionHash': tronHash,
  'result': 'UNKNOWN',
  'blockNumber': 52,
  'feeSun': '42000',
  'feeLimitSun': '150000000',
  'receipt': {
    'result': 'SUCCESS',
    'energy_usage_total': 100,
    'net_usage': 32,
    'energy_fee': 42000,
    'net_fee': 0,
  },
};

void main() {
  test(
    'Solana receipt preserves exact integers and does not invent priority fees',
    () async {
      var calls = 0;
      final service = NonEvmReceiptService(
        client: MockClient((request) async {
          calls++;
          expect(request.method, 'GET');
          expect(request.url.pathSegments, contains('solana:mainnet'));
          expect(request.url.queryParameters, isEmpty);
          expect(request.body, isEmpty);
          return http.Response(jsonEncode(sol()), 200);
        }),
      );
      final facts = await service.fetch(
        networkKey: 'solana:mainnet-beta',
        transactionHash: solHash,
      );
      expect(facts.networkKey, 'solana:mainnet');
      expect(facts.feeBaseUnits, BigInt.parse('18446744073709551615'));
      expect(facts.computeUnitsConsumed, BigInt.from(1234));
      expect(facts.priorityFeeLamports, isNull);
      expect(facts.success, isTrue);
      expect(calls, 1);
    },
  );
  test(
    'TRON uses only actual receipt resources and the bound energy fee limit',
    () {
      final facts = NonEvmReceiptFacts.fromJson(
        tron(),
        networkKey: 'tron:mainnet',
        transactionHash: tronHash.toUpperCase(),
      );
      expect(facts.success, isTrue);
      expect(facts.feeBaseUnits, BigInt.from(42000));
      expect(facts.energyUsed, BigInt.from(100));
      expect(facts.bandwidthUsed, BigInt.from(32));
      expect(facts.feeLimitSun, BigInt.from(150000000));
      expect(facts.bandwidthFeeSun, BigInt.zero);
    },
  );
  test('unknown or malformed money never becomes a zero fee', () {
    for (final bad in [
      null,
      -1,
      1.5,
      '01',
      '-1',
      '1e3',
      '18446744073709551616',
    ]) {
      final data = sol()..['feeLamports'] = bad;
      final facts = NonEvmReceiptFacts.fromJson(
        data,
        networkKey: 'solana:mainnet',
        transactionHash: solHash,
      );
      expect(facts.feeBaseUnits, isNull);
    }
    final facts = NonEvmReceiptFacts.fromJson(
      {
        'networkKey': 'tron:mainnet',
        'transactionHash': tronHash,
        'result': 'UNKNOWN',
      },
      networkKey: 'tron:mainnet',
      transactionHash: tronHash,
    );
    expect(facts.success, isNull);
    expect(facts.feeBaseUnits, isNull);
    expect(facts.energyUsed, isNull);
  });
  test(
    'pending observations discard apparent confirmed fee and resource fields',
    () async {
      final service = NonEvmReceiptService(
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode(sol()..['pending'] = true), 202),
        ),
      );
      final facts = await service.fetch(
        networkKey: 'solana:mainnet',
        transactionHash: solHash,
      );
      expect(facts.pending, isTrue);
      expect(facts.success, isNull);
      expect(facts.feeBaseUnits, isNull);
      expect(facts.computeUnitsConsumed, isNull);
    },
  );
  test('wrong network or transaction metadata is rejected', () {
    for (final data in [
      sol()..['networkKey'] = 'tron:mainnet',
      sol()..['transactionHash'] = '3' * 88,
      sol()..['pending'] = 'true',
    ]) {
      expect(
        () => NonEvmReceiptFacts.fromJson(
          data,
          networkKey: 'solana:mainnet',
          transactionHash: solHash,
        ),
        throwsFormatException,
      );
    }
  });
  test('ambiguous execution results remain unknown', () {
    final badSol = sol()..['status'] = 1.0;
    expect(
      NonEvmReceiptFacts.fromJson(
        badSol,
        networkKey: 'solana:mainnet',
        transactionHash: solHash,
      ).success,
      isNull,
    );
    final conflicting = tron()..['result'] = 'FAILED';
    expect(
      NonEvmReceiptFacts.fromJson(
        conflicting,
        networkKey: 'tron:mainnet',
        transactionHash: tronHash,
      ).success,
      isNull,
    );
  });
  test(
    'unsupported networks fail before transport instead of using an EVM receipt',
    () async {
      var calls = 0;
      final service = NonEvmReceiptService(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        service.fetch(networkKey: 'bitcoin:mainnet', transactionHash: tronHash),
        throwsFormatException,
      );
      expect(calls, 0);
    },
  );
  test('provider errors and malformed responses never retry', () async {
    for (final response in [
      http.Response('{}', 429),
      http.Response('{}', 503),
      http.Response('[]', 200),
      http.Response(' ' * 65537, 200),
      http.Response(jsonEncode(sol()), 202),
    ]) {
      var calls = 0;
      final service = NonEvmReceiptService(
        client: MockClient((_) async {
          calls++;
          return response;
        }),
      );
      await expectLater(
        service.fetch(networkKey: 'solana:mainnet', transactionHash: solHash),
        throwsFormatException,
      );
      expect(calls, 1);
    }
  });
  test('timeout remains an unavailable observation without a retry', () async {
    var calls = 0;
    final service = NonEvmReceiptService(
      timeout: const Duration(milliseconds: 10),
      client: MockClient((_) {
        calls++;
        return Completer<http.Response>().future;
      }),
    );
    await expectLater(
      service.fetch(networkKey: 'solana:mainnet', transactionHash: solHash),
      throwsA(isA<TimeoutException>()),
    );
    expect(calls, 1);
  });
}
