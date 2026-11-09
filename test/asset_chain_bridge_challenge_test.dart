import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fomowl_wallet/config/app_environment.dart';
import 'package:fomowl_wallet/services/blockchain/asset_chain_bridge_client.dart';

void main() {
  const testClientName = 'fomowl-stress-client';
  const testSecretKey = 'stress_secret_key_99999';

  group('CHALLENGE 1: Mock Fallback Isolation & Zero Network Leakage', () {
    test(
      'ADV-MOCK-01: Exhaustive credential permutations guarantee isMockMode == true',
      () {
        final permutations = [
          [null, null],
          ['', ''],
          ['   ', '   '],
          ['\t\n', '\r\n '],
          ['valid_client', null],
          [null, 'valid_secret'],
          ['valid_client', ''],
          ['', 'valid_secret'],
          ['valid_client', '   '],
          ['   ', 'valid_secret'],
          ['valid_client', '\t\n'],
        ];

        for (final p in permutations) {
          final client = AssetChainBridgeClient(
            clientName: p[0],
            clientSecret: p[1],
            mockEnabled: false,
          );
          expect(
            client.isMockMode,
            isTrue,
            reason: 'Failed for clientName="${p[0]}", clientSecret="${p[1]}"',
          );
        }

        // Explicit mockEnabled overrides valid credentials
        final forcedMock = AssetChainBridgeClient(
          clientName: 'valid_client',
          clientSecret: 'valid_secret',
          mockEnabled: true,
        );
        expect(forcedMock.isMockMode, isTrue);

        // Only valid non-empty credentials AND mockEnabled: false produces live mode
        final liveClient = AssetChainBridgeClient(
          clientName: 'valid_client',
          clientSecret: 'valid_secret',
          mockEnabled: false,
        );
        expect(liveClient.isMockMode, isFalse);
      },
    );

    test(
      'ADV-MOCK-02: Zero Network Leakage under multi-endpoint stress burst',
      () async {
        int networkCallCount = 0;
        final trackingMockClient = MockClient((request) async {
          networkCallCount++;
          throw StateError(
            'CRITICAL: Remote network call attempted in mock mode! URL: ${request.url}',
          );
        });

        final mockClient = AssetChainBridgeClient(
          clientName: null,
          clientSecret: null,
          mockEnabled: false, // fallback should trigger due to null credentials
          httpClient: trackingMockClient,
        );

        expect(mockClient.isMockMode, isTrue);

        // Execute repeated bursts across all 6 routes
        for (int i = 0; i < 10; i++) {
          final tokens = await mockClient.getTokens(
            chainId: i % 2 == 0 ? '42421' : null,
          );
          expect(tokens, isNotEmpty);

          final bridges = await mockClient.getBridges(
            chainId: i % 2 == 0 ? '84532' : null,
          );
          expect(bridges, isNotEmpty);

          final txs = await mockClient.getTransactions(
            userAddress: '0x1111111111111111111111111111111111111111',
            page: i + 1,
            limit: 10 + i,
            symbol: i % 2 == 0 ? 'USDC' : 'XRWA',
          );
          expect(txs.items, isNotEmpty);

          final recorded = await mockClient.recordTransaction(
            bridgeId: 'burst-bridge-$i',
            index: '$i',
            userAddress: '0x1111111111111111111111111111111111111111',
            transactionHash: '0xhash$i',
          );
          expect(recorded.index, i);

          final claim = await mockClient.updateTransactionFulfillment(
            transactionId: 'tx-$i',
            claimTransactionHash: '0xclaim$i',
            toBridgeId: 'dest-bridge-$i',
          );
          expect(claim.fulfilled, isTrue);

          final sigs = await mockClient.getRelayerSignatures(
            bridgeId: 'burst-bridge-$i',
            index: '$i',
            fromUser: '0x1111111111111111111111111111111111111111',
          );
          expect(sigs.signatures, isNotEmpty);
        }

        // Assert strictly zero HTTP network calls were made
        expect(
          networkCallCount,
          0,
          reason: 'Zero network calls must leak to HTTP transport in mock mode',
        );
      },
    );

    test(
      'ADV-MOCK-03: Environment client reaches backend without provider credentials',
      () async {
        var requests = 0;
        final envClient = AssetChainBridgeClient.fromEnvironment(
          httpClient: MockClient((request) async {
            requests++;
            expect(
              request.url.host,
              Uri.parse(AppEnvironment.backendBaseUrl).host,
            );
            expect(
              request.url.path,
              endsWith('/swap/assetchain/bridge/tokens'),
            );
            expect(request.headers.containsKey('x-signature'), isFalse);
            return http.Response('{"success":true,"data":[]}', 200);
          }),
        );
        expect(envClient.isMockMode, isFalse);
        expect(await envClient.getTokens(), isEmpty);
        expect(requests, 1);
        expect(AppEnvironment.isAssetChainBridgeMockMode, isFalse);
      },
    );
  });

  group('CHALLENGE 2: Error Responses & Exception Classifications', () {
    test('ADV-ERR-01: Unauthorized (401) classification matrix', () async {
      // 401 Missing headers
      final c1 = AssetChainBridgeClient(
        clientName: testClientName,
        clientSecret: testSecretKey,
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'Missing signature headers'}),
            401,
          ),
        ),
      );

      try {
        await c1.getTokens();
        fail('Should have thrown AssetChainBridgeException');
      } on AssetChainBridgeException catch (e) {
        expect(e.statusCode, 401);
        expect(e.isUnauthorized, isTrue);
        expect(e.isExpired, isFalse);
      }

      // 401 Request expired (case-insensitive checking)
      final c2 = AssetChainBridgeClient(
        clientName: testClientName,
        clientSecret: testSecretKey,
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'REQUEST EXPIRED: timestamp skew'}),
            401,
          ),
        ),
      );

      try {
        await c2.getBridges();
        fail('Should have thrown AssetChainBridgeException');
      } on AssetChainBridgeException catch (e) {
        expect(e.statusCode, 401);
        expect(e.isUnauthorized, isTrue);
        expect(e.isExpired, isTrue);
      }
    });

    test(
      'ADV-ERR-02: Bad Request (400) and Admin Approval Required classification',
      () async {
        final c1 = AssetChainBridgeClient(
          clientName: testClientName,
          clientSecret: testSecretKey,
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'code': 'LIMIT_EXCEEDED',
                'message':
                    'Claim Requires Admin Approval: amount exceeds ceiling',
              }),
              400,
            ),
          ),
        );

        try {
          await c1.getRelayerSignatures(
            bridgeId: 'b1',
            index: '1',
            fromUser: '0xuser',
          );
          fail('Should have thrown AssetChainBridgeException');
        } on AssetChainBridgeException catch (e) {
          expect(e.statusCode, 400);
          expect(e.isBadRequest, isTrue);
          expect(e.isAdminApprovalRequired, isTrue);
          expect(e.errorCode, 'LIMIT_EXCEEDED');
        }
      },
    );

    test('ADV-ERR-03: Not Found (404) classification', () async {
      final c1 = AssetChainBridgeClient(
        clientName: testClientName,
        clientSecret: testSecretKey,
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'Transaction record not found'}),
            404,
          ),
        ),
      );

      try {
        await c1.getTransactions(userAddress: '0xnotfound');
        fail('Should have thrown AssetChainBridgeException');
      } on AssetChainBridgeException catch (e) {
        expect(e.statusCode, 404);
        expect(e.isNotFound, isTrue);
      }
    });

    test(
      'ADV-ERR-04: Non-JSON Server Error responses (500 HTML / 502 Bad Gateway)',
      () async {
        const html502 =
            '<html><body>502 Bad Gateway: upstream server error</body></html>';
        final c1 = AssetChainBridgeClient(
          clientName: testClientName,
          clientSecret: testSecretKey,
          httpClient: MockClient((_) async => http.Response(html502, 502)),
        );

        try {
          await c1.getTokens();
          fail('Should have thrown AssetChainBridgeException on 502 HTML');
        } on AssetChainBridgeException catch (e) {
          expect(e.statusCode, 502);
          expect(e.message, html502);
          expect(e.responseBody, html502);
        }

        final c2 = AssetChainBridgeClient(
          clientName: testClientName,
          clientSecret: testSecretKey,
          httpClient: MockClient(
            (_) async => http.Response('Internal Server Error', 500),
          ),
        );

        try {
          await c2.getBridges();
          fail('Should have thrown AssetChainBridgeException on 500 PlainText');
        } on AssetChainBridgeException catch (e) {
          expect(e.statusCode, 500);
          expect(e.message, 'Internal Server Error');
        }
      },
    );
  });

  group('CHALLENGE 3: DTO & Route Invariant Fuzzing', () {
    test(
      'ADV-FUZZ-01: getTransactions edge inputs and symbol normalization',
      () async {
        late http.Request captured;
        final c = AssetChainBridgeClient(
          clientName: testClientName,
          clientSecret: testSecretKey,
          httpClient: MockClient((req) async {
            captured = req;
            return http.Response(
              jsonEncode({
                'data': {
                  'items': [],
                  'pagination': {
                    'page': 0,
                    'limit': 0,
                    'totalCount': 0,
                    'totalPages': 0,
                    'hasNextPage': false,
                    'hasPreviousPage': false,
                  },
                },
              }),
              200,
            );
          }),
        );

        // Edge inputs: empty address, page 0, limit 0, symbol XRWA
        final res1 = await c.getTransactions(
          userAddress: '',
          page: 0,
          limit: 0,
          symbol: 'XRWA',
        );
        expect(res1.items, isEmpty);
        expect(
          captured.url.queryParameters['symbol'],
          'RWA',
        ); // XRWA normalized to RWA
        expect(captured.url.queryParameters['page'], '0');
        expect(captured.url.queryParameters['limit'], '0');

        // Edge inputs: pagination large numbers, forceSync true, chainIds comma-separated
        await c.getTransactions(
          userAddress: '0x9999999999999999999999999999999999999999',
          secondaryAddress: '0x8888888888888888888888888888888888888888',
          chainIds: '42420,42421,84532,421614',
          fulfilled: false,
          forceSync: true,
          symbol: 'USDC',
          page: 999999,
          limit: 5000,
        );
        expect(
          captured.url.queryParameters['chainIds'],
          '42420,42421,84532,421614',
        );
        expect(captured.url.queryParameters['forceSync'], 'true');
        expect(captured.url.queryParameters['fulfilled'], 'false');
        expect(captured.url.queryParameters['symbol'], 'USDC');
        expect(captured.url.queryParameters['page'], '999999');
        expect(captured.url.queryParameters['limit'], '5000');
      },
    );

    test(
      'ADV-FUZZ-02: recordTransaction non-integer and boundary index inputs',
      () async {
        late http.Request captured;
        final c = AssetChainBridgeClient(
          clientName: testClientName,
          clientSecret: testSecretKey,
          httpClient: MockClient((req) async {
            captured = req;
            return http.Response(
              jsonEncode({
                'data': {
                  'id': 'rec-1',
                  'amount': '500000',
                  'timestamp': '1710000000',
                  'fromUser': '0x1',
                  'toUser': '0x2',
                  'fromChain': '84532',
                  'toChain': '421614',
                  'symbol': 'USDC',
                  'fulfilled': false,
                  'index': 99999,
                  'userAddress': '0x1',
                  'chainId': '84532',
                  'transactionHash': '0xhash',
                },
              }),
              201,
            );
          }),
        );

        final tx = await c.recordTransaction(
          bridgeId: 'bridge-special-!@#\$%',
          index: '99999',
          userAddress: '0x1111111111111111111111111111111111111111',
          transactionHash: '0xabcdef0123456789',
        );

        expect(tx.id, 'rec-1');
        expect(tx.index, 99999);
        final body = jsonDecode(captured.body);
        expect(body['bridgeId'], 'bridge-special-!@#\$%');
        expect(body['index'], '99999');
      },
    );

    test(
      'ADV-FUZZ-03: updateTransactionFulfillment handles both flattened and deeply nested payloads',
      () async {
        // Shape A: deeply nested data -> data -> id
        final cDeep = AssetChainBridgeClient(
          clientName: testClientName,
          clientSecret: testSecretKey,
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'success': true,
                'message': 'Success',
                'data': {
                  'data': {
                    'id': 'tx-deep',
                    'fulfilled': true,
                    'claimTransactionHash': '0xdeepclaim',
                    'amount': '100',
                  },
                },
              }),
              200,
            ),
          ),
        );

        final resDeep = await cDeep.updateTransactionFulfillment(
          transactionId: 'tx-deep',
          claimTransactionHash: '0xdeepclaim',
          toBridgeId: 'b-deep',
        );
        expect(resDeep.transactionId, 'tx-deep');
        expect(resDeep.fulfilled, isTrue);
        expect(resDeep.claimTransactionHash, '0xdeepclaim');

        // Shape B: flattened root
        final cFlat = AssetChainBridgeClient(
          clientName: testClientName,
          clientSecret: testSecretKey,
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'success': true,
                'message': 'Claimed',
                'id': 'tx-flat',
                'fulfilled': true,
                'claimTransactionHash': '0xflatclaim',
              }),
              200,
            ),
          ),
        );

        final resFlat = await cFlat.updateTransactionFulfillment(
          transactionId: 'tx-flat',
          claimTransactionHash: '0xflatclaim',
          toBridgeId: 'b-flat',
        );
        expect(resFlat.transactionId, 'tx-flat');
        expect(resFlat.fulfilled, isTrue);
        expect(resFlat.claimTransactionHash, '0xflatclaim');
      },
    );

    test(
      'ADV-FUZZ-04: getRelayerSignatures resilient to alternate field names and empty responses',
      () async {
        // Shape A: field name is 'signature' (as documented by Asset Chain API)
        final cSig = AssetChainBridgeClient(
          clientName: testClientName,
          clientSecret: testSecretKey,
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'signature': ['0xsig1', '0xsig2'],
              }),
              200,
            ),
          ),
        );
        final res1 = await cSig.getRelayerSignatures(
          bridgeId: 'b',
          index: '1',
          fromUser: '0xu',
        );
        expect(res1.signatures, ['0xsig1', '0xsig2']);

        // Shape B: field name is 'signatures'
        final cSigs = AssetChainBridgeClient(
          clientName: testClientName,
          clientSecret: testSecretKey,
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'signatures': ['0xalt1'],
              }),
              200,
            ),
          ),
        );
        final res2 = await cSigs.getRelayerSignatures(
          bridgeId: 'b',
          index: '1',
          fromUser: '0xu',
        );
        expect(res2.signatures, ['0xalt1']);

        // Shape C: empty / missing array
        final cEmpty = AssetChainBridgeClient(
          clientName: testClientName,
          clientSecret: testSecretKey,
          httpClient: MockClient(
            (_) async => http.Response(jsonEncode({}), 200),
          ),
        );
        final res3 = await cEmpty.getRelayerSignatures(
          bridgeId: 'b',
          index: '1',
          fromUser: '0xu',
        );
        expect(res3.signatures, isEmpty);
      },
    );

    test(
      'ADV-FUZZ-05: DTO null-safety resilience against incomplete API payloads',
      () {
        // Empty JSON does not crash DTO parsers
        final emptyToken = AssetChainBridgeToken.fromJson({});
        expect(emptyToken.id, '');
        expect(emptyToken.decimal, 18);
        expect(emptyToken.symbol, '');
        expect(emptyToken.maxClaimAmount, isNull);

        final emptyDeployment = AssetChainBridgeDeployment.fromJson({});
        expect(emptyDeployment.id, '');
        expect(emptyDeployment.limitPerSend, '0');
        expect(emptyDeployment.fees.feeFulfill, 0);

        final emptyTx = AssetChainBridgeTransaction.fromJson({});
        expect(emptyTx.id, '');
        expect(emptyTx.amount, '0');
        expect(emptyTx.fulfilled, isFalse);
        expect(emptyTx.index, 0);
        final stringIndexed = AssetChainBridgeTransaction.fromJson({
          'index': '3',
          'nonce': '4',
          'fulfillNonce': '9',
        });
        expect(stringIndexed.index, 3);
        expect(stringIndexed.nonce, 4);
        expect(stringIndexed.fulfillNonce, 9);

        final emptyPage = AssetChainBridgePagination.fromJson({});
        expect(emptyPage.page, 1);
        expect(emptyPage.limit, 10);
        expect(emptyPage.totalCount, 0);

        final emptyClaim = AssetChainBridgeClaimResult.fromJson({});
        expect(emptyClaim.success, isFalse);
        expect(emptyClaim.fulfilled, isFalse);
        expect(emptyClaim.transactionId, '');
      },
    );

    test(
      'ADV-FUZZ-06: Signer canonical string path normalization and query stripping',
      () {
        // Unnormalized paths with trailing query strings, multiple query params, or missing slash
        final canonical1 = AssetChainApiGuardSigner.buildCanonicalString(
          method: 'post',
          path: 'transactions?param1=val1&param2=val2#anchor',
          timestamp: '1710000500',
          body: '',
        );
        expect(
          canonical1.startsWith(
            'POST\n/transactions\n1710000500\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          ),
          isTrue,
        );

        final canonical2 = AssetChainApiGuardSigner.buildCanonicalString(
          method: 'GET',
          path: '/blockchain/sign?bridgeId=xyz&index=0&fromUser=0x123',
          timestamp: '1710000600',
          body: null,
        );
        expect(
          canonical2,
          'GET\n/blockchain/sign\n1710000600\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        );
      },
    );
  });
}
