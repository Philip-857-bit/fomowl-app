import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/services/wallet_backend_auth_service.dart';

class PublicFixtureAuth extends WalletBackendAuthService {
  final String? sessionIdentity;
  PublicFixtureAuth({this.sessionIdentity});
  String? authenticatedIdentity;
  final invalidated = <String>[];
  @override
  Future<void> invalidateSession(String identity) async {
    invalidated.add(identity);
  }

  @override
  Future<http.Response> sendAuthorized(
    String identity,
    Future<http.Response> Function(Map<String, String>) send,
    Map<String, String> headers,
  ) {
    authenticatedIdentity = sessionIdentity ?? identity.trim().toLowerCase();
    return send({...headers, 'Authorization': 'Bearer public-fixture-token'});
  }
}

class FailingSetupAuth extends PublicFixtureAuth {
  @override
  Future<http.Response> sendAuthorized(
    String identity,
    Future<http.Response> Function(Map<String, String>) send,
    Map<String, String> headers,
  ) async {
    throw StateError('Private fixture exception that must not escape');
  }
}

class RetryingFixtureAuth extends PublicFixtureAuth {
  @override
  Future<http.Response> sendAuthorized(
    String identity,
    Future<http.Response> Function(Map<String, String>) send,
    Map<String, String> headers,
  ) async {
    authenticatedIdentity = identity;
    final response = await send(headers);
    if (response.statusCode == 401) return send(headers);
    return response;
  }
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
        expect(request.followRedirects, isFalse);
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
        'inputs': [
          {'position': 0, 'address': address, 'valueSats': 100},
        ],
        'outputs': [
          {'position': 0, 'address': address, 'valueSats': 90},
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
  test(
    'broadcast body uses the same canonical identity as the wallet session',
    () async {
      const mixed = '0x9858EfFD232B4033E47d90003D41EC34EcaEda94';
      final auth = PublicFixtureAuth();
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        // Model the backend's literal comparison to its lowercase session row.
        if (body['walletAddress'] != auth.authenticatedIdentity) {
          return http.Response(
            jsonEncode({
              'error': 'Forbidden',
              'message':
                  'The wallet session does not match the requested wallet.',
            }),
            403,
          );
        }
        expect(body['signedTransaction'], 'aa11');
        return http.Response(
          jsonEncode({
            'success': true,
            'transactionHash': '11' * 32,
            'networkKey': 'bitcoin:testnet4',
          }),
          200,
        );
      });
      final api = BitcoinNetworkService(client: client, auth: auth);
      expect(
        await api.broadcast(mixed, BitcoinProductNetwork.testnet4, 'aa11'),
        '11' * 32,
      );
      expect(auth.authenticatedIdentity, mixed.toLowerCase());
    },
  );
  test(
    'canonicalization does not authorize a different wallet or retry a 403',
    () async {
      var calls = 0;
      const requested = '0x2222222222222222222222222222222222222222';
      final auth = PublicFixtureAuth(
        sessionIdentity: '0x1111111111111111111111111111111111111111',
      );
      final api = BitcoinNetworkService(
        auth: auth,
        client: MockClient((request) async {
          calls++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['walletAddress'], requested);
          expect(body['walletAddress'], isNot(auth.authenticatedIdentity));
          return http.Response(
            jsonEncode({
              'error': 'Forbidden',
              'message':
                  'The wallet session does not match the requested wallet.',
            }),
            403,
          );
        }),
      );
      await expectLater(
        api.broadcast(requested, BitcoinProductNetwork.testnet4, 'aa11'),
        throwsA(
          isA<BitcoinNetworkException>().having(
            (error) => error.statusCode,
            'status code',
            403,
          ),
        ),
      );
      expect(calls, 1);
    },
  );
  test('only exact known backend pre-provider responses establish rejection', () {
    for (final sample in [
      (400, {'error': 'Invalid Bitcoin transaction encoding'}),
      (401, {'error': 'Wallet authentication required'}),
      (
        401,
        {
          'error': 'Authentication required',
          'message': 'The wallet session has expired.',
        },
      ),
      (
        403,
        {
          'error': 'Forbidden',
          'message': 'The wallet session does not match the requested wallet.',
        },
      ),
    ]) {
      expect(
        BitcoinPreProviderRejection.fromBackendResponse(
          sample.$1,
          jsonEncode(sample.$2),
        ),
        isA<BitcoinPreProviderRejection>(),
      );
    }
    for (final sample in [
      (400, '{"error":"provider rejected"}'),
      (401, '<html>Proxy authentication error</html>'),
      (403, '{"error":"Forbidden","message":"Unknown rejection"}'),
      (
        403,
        '{"error":"Forbidden","message":"The wallet session does not match the requested wallet.","success":true}',
      ),
      (429, '{"error":"Wallet authentication required"}'),
      (500, '{"error":"Wallet authentication required"}'),
      (200, '{"error":"Wallet authentication required"}'),
    ]) {
      expect(
        BitcoinPreProviderRejection.fromBackendResponse(sample.$1, sample.$2),
        isNull,
      );
    }
  });
  for (final known in [true, false]) {
    test(
      'broadcast 401 cannot trigger a hidden auth retry (known=$known)',
      () async {
        var calls = 0;
        final auth = RetryingFixtureAuth();
        final api = BitcoinNetworkService(
          auth: auth,
          client: MockClient((request) async {
            calls++;
            return http.Response(
              known
                  ? jsonEncode({
                      'error': 'Authentication required',
                      'message': 'The wallet session has expired.',
                    })
                  : '<html>Unknown proxy error</html>',
              401,
            );
          }),
        );
        await expectLater(
          api.broadcast('0xstable', BitcoinProductNetwork.mainnet, 'aa11'),
          known
              ? throwsA(isA<BitcoinPreProviderRejection>())
              : throwsA(
                  isA<BitcoinNetworkException>().having(
                    (e) => e is BitcoinPreProviderRejection,
                    'proven rejection',
                    isFalse,
                  ),
                ),
        );
        expect(calls, 1);
        expect(auth.invalidated, known ? ['0xstable'] : isEmpty);
      },
    );
  }
  test(
    'session setup failure proves no Bitcoin POST occurred and hides private errors',
    () async {
      var calls = 0;
      final api = BitcoinNetworkService(
        auth: FailingSetupAuth(),
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 500);
        }),
      );
      await expectLater(
        api.broadcast('0xstable', BitcoinProductNetwork.mainnet, 'aa11'),
        throwsA(
          isA<BitcoinPreProviderRejection>().having(
            (e) => e.toString(),
            'safe error',
            isNot(contains('Private fixture')),
          ),
        ),
      );
      expect(calls, 0);
    },
  );
  group('Bitcoin replacement observations', () {
    final txid = '22' * 32;
    Map<String, dynamic> context() => {
      'networkKey': 'bitcoin:mainnet',
      'txid': txid,
      'originalUnconfirmed': true,
      'hasDescendants': false,
      'outputCount': 2,
      'incrementalRelayFeeSatVb': 1,
    };
    test('requires explicit compatible replacement capability', () async {
      for (final flag in [null, false, true]) {
        final api = service(
          MockClient(
            (_) async => http.Response(
              jsonEncode({
                'networkKey': 'bitcoin:mainnet',
                'maxAddresses': 40,
                'available': true,
                'rbfContext': ?flag,
              }),
              200,
            ),
          ),
        );
        expect(
          await api.replacementAvailable(BitcoinProductNetwork.mainnet),
          flag == true,
        );
      }
    });
    test('fetches only exact public transaction identity', () async {
      final api = service(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.path,
            endsWith('/bitcoin:mainnet/transaction/$txid/replacement-context'),
          );
          expect(request.body, isEmpty);
          return http.Response(jsonEncode(context()), 200);
        }),
      );
      final observation = await api.fetchReplacementContext(
        BitcoinProductNetwork.mainnet,
        txid,
      );
      observation.requireOriginal(BitcoinProductNetwork.mainnet, txid, 2);
      expect(observation.incrementalRelayFeeSatVb, BigInt.one);
    });
    test(
      'rejects malformed and cross-network or cross-transaction observations',
      () async {
        for (final mutation in <Map<String, dynamic>>[
          {'networkKey': 'bitcoin:testnet4'},
          {'txid': '33' * 32},
          {'originalUnconfirmed': 'true'},
          {'hasDescendants': 0},
          {'outputCount': 0},
          {'outputCount': 10001},
          {'incrementalRelayFeeSatVb': 0},
          {'incrementalRelayFeeSatVb': 10001},
          {'incrementalRelayFeeSatVb': 1.5},
          {'unexpected': true},
        ]) {
          final api = service(
            MockClient(
              (_) async =>
                  http.Response(jsonEncode({...context(), ...mutation}), 200),
            ),
          );
          await expectLater(
            api.fetchReplacementContext(BitcoinProductNetwork.mainnet, txid),
            throwsFormatException,
          );
        }
      },
    );
    test(
      'confirmed or descendant observations never authorize replacement',
      () async {
        for (final mutation in [
          {'originalUnconfirmed': false},
          {'hasDescendants': true},
        ]) {
          final api = service(
            MockClient(
              (_) async =>
                  http.Response(jsonEncode({...context(), ...mutation}), 200),
            ),
          );
          final observation = await api.fetchReplacementContext(
            BitcoinProductNetwork.mainnet,
            txid,
          );
          expect(
            () => observation.requireOriginal(
              BitcoinProductNetwork.mainnet,
              txid,
              2,
            ),
            throwsStateError,
          );
        }
      },
    );
    test(
      'provider failure does not become positive mempool evidence',
      () async {
        var calls = 0;
        final api = service(
          MockClient((_) async {
            calls++;
            return http.Response(
              '{"error":"Bitcoin provider unavailable"}',
              503,
            );
          }),
        );
        await expectLater(
          api.fetchReplacementContext(BitcoinProductNetwork.mainnet, txid),
          throwsA(isA<BitcoinNetworkException>()),
        );
        expect(calls, 1);
      },
    );
  });
}
