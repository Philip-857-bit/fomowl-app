import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/services/wallet_backend_auth_service.dart';

class PublicFixtureAuth extends WalletBackendAuthService {
  @override
  Future<http.Response> sendAuthorized(
    String identity,
    Future<http.Response> Function(Map<String, String>) send,
    Map<String, String> headers,
  ) => send({...headers, 'Authorization': 'Bearer public-fixture-token'});
}

class OversizedClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream.value([0]),
        200,
        contentLength: 16 * 1024 * 1024 + 1,
      );
}

const address = 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';
Map<String, dynamic> activity({List<Object> utxos = const []}) => {
  'address': address,
  'used': true,
  'confirmedBalanceSats': 100,
  'mempoolBalanceSats': -10,
  'txCount': 1,
  'utxos': utxos,
};
Map<String, dynamic> utxo() => {
  'txid': '11' * 32,
  'vout': 0,
  'valueSats': 100,
  'address': address,
  'scriptPubkeyHex': '0014${'11' * 20}',
  'confirmed': true,
  'blockHeight': 100,
};
BitcoinNetworkService service(
  http.Client client, {
  Duration timeout = const Duration(seconds: 1),
}) => BitcoinNetworkService(
  client: client,
  auth: PublicFixtureAuth(),
  timeout: timeout,
);
void main() {
  test(
    'authenticated account request contains addresses only and deduplicates before transmission',
    () async {
      final client = MockClient((request) async {
        expect(
          request.url.path,
          endsWith('/networks/bitcoin:mainnet/account-state'),
        );
        expect(request.headers['Authorization'], 'Bearer public-fixture-token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.keys.toSet(), {'walletAddress', 'addresses'});
        expect(body['walletAddress'], '0xstable');
        expect(body['addresses'], [address]);
        expect(request.body.contains('xpub'), isFalse);
        expect(request.body.contains('seed'), isFalse);
        return http.Response(
          jsonEncode({
            'networkKey': 'bitcoin:mainnet',
            'addresses': [
              activity(utxos: [utxo()]),
            ],
          }),
          200,
        );
      });
      final result = await service(client).fetchAccountState(
        '0xstable',
        BitcoinProductNetwork.mainnet,
        [address, address],
      );
      expect(result.single.confirmedBalanceSats, BigInt.from(100));
      expect(result.single.mempoolBalanceSats, BigInt.from(-10));
      expect(result.single.utxos.single.valueSats, BigInt.from(100));
      await expectLater(
        service(client).fetchAccountState(
          '0xstable',
          BitcoinProductNetwork.mainnet,
          ['xpub-never-transmit'],
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'network mismatch, incomplete address rows and duplicate outpoints fail closed',
    () async {
      for (final response in [
        {
          'networkKey': 'bitcoin:testnet4',
          'addresses': [activity()],
        },
        {'networkKey': 'bitcoin:mainnet', 'addresses': []},
        {
          'networkKey': 'bitcoin:mainnet',
          'addresses': [
            activity(utxos: [utxo(), utxo()]),
          ],
        },
      ]) {
        final client = MockClient(
          (_) async => http.Response(jsonEncode(response), 200),
        );
        await expectLater(
          service(client).fetchAccountState(
            '0xstable',
            BitcoinProductNetwork.mainnet,
            [address],
          ),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'fee rates are ordered positive integers and never rounded from doubles',
    () async {
      final good = {
        'economy': 2,
        'normal': 5,
        'priority': 9,
        'minimum': 1,
        'stale': false,
      };
      final rates = await service(
        MockClient((_) async => http.Response(jsonEncode(good), 200)),
      ).fetchFeeRates(BitcoinProductNetwork.mainnet);
      expect(rates.rate(BitcoinFeeTier.normal), BigInt.from(5));
      for (final response in [
        {...good, 'normal': 0},
        {...good, 'normal': 5.5},
        {...good, 'priority': 10001},
        {...good, 'economy': 8},
      ]) {
        await expectLater(
          service(
            MockClient((_) async => http.Response(jsonEncode(response), 200)),
          ).fetchFeeRates(BitcoinProductNetwork.mainnet),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'temporary missing transaction stays pending and Bitcoin has no receipt failure flag',
    () async {
      final pending = {
        'status': 'pending',
        'confirmed': false,
        'found': false,
        'confirmations': 0,
        'blockHeight': null,
        'blockHash': null,
        'timestamp': null,
      };
      final result = await service(
        MockClient((_) async => http.Response(jsonEncode(pending), 200)),
      ).fetchTransactionStatus(BitcoinProductNetwork.mainnet, '11' * 32);
      expect(result.confirmed, isFalse);
      expect(result.found, isFalse);
      expect(result.confirmations, 0);
      final invalid = {...pending, 'confirmations': 1};
      await expectLater(
        service(
          MockClient((_) async => http.Response(jsonEncode(invalid), 200)),
        ).fetchTransactionStatus(BitcoinProductNetwork.mainnet, '11' * 32),
        throwsFormatException,
      );
    },
  );
  test(
    'broadcast transmits exact signed bytes and returns a typed transaction ID',
    () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body, {
          'walletAddress': '0xstable',
          'signedTransaction': 'aa11',
        });
        return http.Response(
          jsonEncode({
            'success': true,
            'transactionHash': '11' * 32,
            'networkKey': 'bitcoin:mainnet',
          }),
          200,
        );
      });
      expect(
        await service(
          client,
        ).broadcast('0xstable', BitcoinProductNetwork.mainnet, 'aa11'),
        '11' * 32,
      );
      await expectLater(
        service(
          client,
        ).broadcast('0xstable', BitcoinProductNetwork.mainnet, 'invalid'),
        throwsArgumentError,
      );
    },
  );
  test(
    'bounded history validates owned amounts, fee, network and address set',
    () async {
      final tx = {
        'txid': '11' * 32,
        'timestamp': 100,
        'confirmations': 1,
        'blockHeight': 100,
        'blockHash': '22' * 32,
        'ownedInputs': [
          {'address': address, 'valueSats': 100},
        ],
        'ownedOutputs': [
          {'address': address, 'valueSats': 90},
        ],
        'netWalletDeltaSats': -10,
        'feeSats': 10,
        'direction': 'outgoing',
      };
      final client = MockClient((request) async {
        expect(request.url.queryParameters['limit'], '100');
        return http.Response(
          jsonEncode({
            'networkKey': 'bitcoin:mainnet',
            'transactions': [tx],
            'truncated': false,
          }),
          200,
        );
      });
      final result = await service(client).fetchAccountHistory(
        '0xstable',
        BitcoinProductNetwork.mainnet,
        [address],
      );
      expect(result.transactions.single.netWalletDeltaSats, BigInt.from(-10));
      expect(result.transactions.single.feeSats, BigInt.from(10));
      final forged = {...tx, 'netWalletDeltaSats': -20};
      final bad = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'networkKey': 'bitcoin:mainnet',
            'transactions': [forged],
            'truncated': false,
          }),
          200,
        ),
      );
      await expectLater(
        service(bad).fetchAccountHistory(
          '0xstable',
          BitcoinProductNetwork.mainnet,
          [address],
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'oversized bodies are rejected before buffering their payload',
    () async {
      await expectLater(
        service(OversizedClient()).fetchFeeRates(BitcoinProductNetwork.mainnet),
        throwsFormatException,
      );
    },
  );

  test(
    'transport errors never reflect upstream payloads and a broadcast timeout is not retried',
    () async {
      final fail = service(
        MockClient((_) async => http.Response('private-secret-payload', 500)),
      );
      await expectLater(
        fail.fetchFeeRates(BitcoinProductNetwork.mainnet),
        throwsA(
          isA<BitcoinNetworkException>().having(
            (error) => error.toString(),
            'redacted',
            isNot(contains('private-secret-payload')),
          ),
        ),
      );
      final corrupt = service(
        MockClient((_) async => http.Response('{private-secret-payload', 200)),
      );
      await expectLater(
        corrupt.fetchFeeRates(BitcoinProductNetwork.mainnet),
        throwsA(
          isA<FormatException>().having(
            (error) => error.toString(),
            'redacted',
            isNot(contains('private-secret-payload')),
          ),
        ),
      );
      var requests = 0;
      final slow = service(
        MockClient((_) async {
          requests++;
          await Future<void>.delayed(const Duration(milliseconds: 40));
          return http.Response('{}', 200);
        }),
        timeout: const Duration(milliseconds: 5),
      );
      await expectLater(
        slow.broadcast('0xstable', BitcoinProductNetwork.mainnet, 'aa11'),
        throwsA(isA<BitcoinNetworkException>()),
      );
      expect(requests, 1);
    },
  );
}
