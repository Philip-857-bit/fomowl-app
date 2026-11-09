import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fomowl_wallet/config/app_environment.dart';
import 'package:fomowl_wallet/services/blockchain/asset_chain_bridge_client.dart';
import 'package:fomowl_wallet/services/bridge_service.dart';

void main() {
  const testSecretKey = 'test_secret_key_12345';
  const testClientName = 'fomowl-test-client';

  group('Group 1: Cryptographic Test Vectors & API Guard Signer', () {
    test('TC-SIG-01: TV-1 Canonical string and signature for GET /tokens (empty body)', () {
      final canonical = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '/tokens',
        timestamp: '1710000000',
        body: null,
      );

      const expectedCanonical = 'GET\n/tokens\n1710000000\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      expect(canonical, expectedCanonical);

      final signature = AssetChainApiGuardSigner.calculateSignature(
        canonicalString: canonical,
        clientSecret: testSecretKey,
      );
      expect(signature, '6ac528dfb0e93e3a31a1c97cac956e3b48e8f02b99c1dab828b36bf972451d24');
    });

    test('TC-SIG-02: TV-2 Canonical string and signature for GET /bridges (empty body)', () {
      final canonical = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '/bridges',
        timestamp: '1710000000',
        body: null,
      );

      const expectedCanonical = 'GET\n/bridges\n1710000000\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      expect(canonical, expectedCanonical);

      final signature = AssetChainApiGuardSigner.calculateSignature(
        canonicalString: canonical,
        clientSecret: testSecretKey,
      );
      expect(signature, 'c17ec79c01230dec121fadb07fc8dcea56f99d632975d7b81352fea566814035');
    });

    test('TC-SIG-03: TV-3 Query parameter stripping for GET /transactions', () {
      final canonical = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '/transactions?userAddress=0x1111111111111111111111111111111111111111&symbol=USDC',
        timestamp: '1710000050',
        body: null,
      );

      const expectedCanonical = 'GET\n/transactions\n1710000050\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      expect(canonical, expectedCanonical);

      final signature = AssetChainApiGuardSigner.calculateSignature(
        canonicalString: canonical,
        clientSecret: testSecretKey,
      );
      expect(signature, '817ac52a1c65ae25b98613d9cc11dee9a9bbd1b198ba20df0bbf1c6dcc90ee77');
    });

    test('TC-SIG-04: TV-4 JSON body SHA-256 hash and signature for POST /transactions', () {
      const body = '{"bridgeId":"c3d4e5f6-a7b8-4901-8234-567890abcdef","index":"3","userAddress":"0x1111111111111111111111111111111111111111","transactionHash":"0xabc"}';
      final canonical = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'POST',
        path: '/transactions',
        timestamp: '1710000100',
        body: body,
      );

      const expectedCanonical = 'POST\n/transactions\n1710000100\n103252bbe46479d329f5570628ce03ddb74c0c951434318d12090b4ec6c58218';
      expect(canonical, expectedCanonical);

      final signature = AssetChainApiGuardSigner.calculateSignature(
        canonicalString: canonical,
        clientSecret: testSecretKey,
      );
      expect(signature, '28a607c4b708a4dfc408a67a716fd17c14994c98c0fa1a25338d9f0d3e3d0e5a');
    });

    test('TC-SIG-05: TV-5 JSON body SHA-256 hash and signature for PUT /transactions', () {
      const body = '{"transactionId":"a1b2c3d4-e5f6-4789-a012-3456789abcde","claimTransactionHash":"0xdef","toBridgeId":"c3d4e5f6-a7b8-4901-8234-567890abcdef"}';
      final canonical = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'PUT',
        path: '/transactions',
        timestamp: '1710000150',
        body: body,
      );

      const expectedCanonical = 'PUT\n/transactions\n1710000150\nc81a406a76f0e1c0fc3c209f4cf3e6ca34ff211209ccff48cb2b2ed83ab2b38d';
      expect(canonical, expectedCanonical);

      final signature = AssetChainApiGuardSigner.calculateSignature(
        canonicalString: canonical,
        clientSecret: testSecretKey,
      );
      expect(signature, 'd5985729770cea61d6b209e13649cc708a3e01bb35588e16d37d62a48f509784');
    });

    test('TC-SIG-06: TV-6 Query parameter stripping for GET /blockchain/sign', () {
      final canonical = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '/blockchain/sign?bridgeId=c3d4e5f6-a7b8-4901-8234-567890abcdef&index=3&fromUser=0x1111111111111111111111111111111111111111',
        timestamp: '1710000200',
        body: null,
      );

      const expectedCanonical = 'GET\n/blockchain/sign\n1710000200\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      expect(canonical, expectedCanonical);

      final signature = AssetChainApiGuardSigner.calculateSignature(
        canonicalString: canonical,
        clientSecret: testSecretKey,
      );
      expect(signature, 'ec34f19a97be8fcbda0cc535afaabfaf63142ad5e844931147fb7ce966621caf');
    });

    test('TC-SIG-07: Method normalization and leading slash enforcement', () {
      final canonical = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'get',
        path: 'tokens',
        timestamp: '1710000000',
        body: '',
      );
      expect(canonical.startsWith('GET\n/tokens\n1710000000\n'), isTrue);
    });

    test('TC-SIG-08: Header generation includes guard headers and conditional Content-Type', () {
      final headersNoBody = AssetChainApiGuardSigner.generateHeaders(
        method: 'GET',
        path: '/tokens',
        clientName: testClientName,
        clientSecret: testSecretKey,
        customTimestamp: '1710000000',
      );
      expect(headersNoBody['x-client-name'], testClientName);
      expect(headersNoBody['x-timestamp'], '1710000000');
      expect(headersNoBody['x-signature'], '6ac528dfb0e93e3a31a1c97cac956e3b48e8f02b99c1dab828b36bf972451d24');
      expect(headersNoBody.containsKey('Content-Type'), isFalse);
      expect(headersNoBody['Accept'], 'application/json');

      final headersWithBody = AssetChainApiGuardSigner.generateHeaders(
        method: 'POST',
        path: '/transactions',
        clientName: testClientName,
        clientSecret: testSecretKey,
        body: '{"foo":"bar"}',
        customTimestamp: '1710000100',
      );
      expect(headersWithBody['Content-Type'], 'application/json');
    });
  });

  group('Group 2: Mock HTTP Integration (6 Endpoints via MockClient)', () {
    test('TC-EP-01: GET /tokens parses response and verifies guard headers', () async {
      late http.Request captured;
      final mockClient = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'id': '8b1c0c2e-1d2a-4c3b-9f10-0a1b2c3d4e5f',
                'tokenAddress': '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
                'decimal': 6,
                'symbol': 'USDC',
                'name': 'USD Coin',
                'chainId': '84532',
                'maxClaimAmount': '50000000000',
                'createdAt': '2026-01-01T00:00:00.000Z',
                'updatedAt': '2026-01-01T00:00:00.000Z',
              }
            ],
          }),
          200,
        );
      });

      final client = AssetChainBridgeClient(
        baseUrl: 'https://bridge-testnet.assetchain.org',
        clientName: testClientName,
        clientSecret: testSecretKey,
        mockEnabled: false,
        httpClient: mockClient,
      );

      final tokens = await client.getTokens(chainId: '84532');
      expect(tokens, hasLength(1));
      expect(tokens.first.symbol, 'USDC');
      expect(tokens.first.decimal, 6);
      expect(tokens.first.chainId, '84532');

      expect(captured.method, 'GET');
      expect(captured.url.path, '/tokens');
      expect(captured.url.queryParameters['chainId'], '84532');
      expect(captured.headers['x-client-name'], testClientName);
      expect(captured.headers['x-signature'], isNotEmpty);
      expect(captured.headers['x-timestamp'], isNotEmpty);
    });

    test('TC-EP-02: GET /bridges parses deployment list and nested token', () async {
      late http.Request captured;
      final mockClient = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'id': 'c3d4e5f6-a7b8-4901-8234-567890abcdef',
                'bridgeAddress': '0xEC91dd5f2048DB18C32e15Ca75a59e1e72E5E267',
                'chainId': '421614',
                'fees': {'feeFulfill': 0, 'feeSend': 0},
                'tokenId': '9c2d1e3f-2e3b-5d4c-a021-1b2c3d4e5f60',
                'limitPerSend': '10000000000',
                'tokenDecimal': 6,
                'token': {
                  'id': '9c2d1e3f-2e3b-5d4c-a021-1b2c3d4e5f60',
                  'tokenAddress': '0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9',
                  'decimal': 6,
                  'symbol': 'USDC',
                  'name': 'USD Coin',
                  'chainId': '421614',
                },
              }
            ],
          }),
          200,
        );
      });

      final client = AssetChainBridgeClient(
        baseUrl: 'https://bridge.assetchain.org',
        clientName: testClientName,
        clientSecret: testSecretKey,
        httpClient: mockClient,
      );

      final bridges = await client.getBridges();
      expect(bridges, hasLength(1));
      expect(bridges.first.bridgeAddress, '0xEC91dd5f2048DB18C32e15Ca75a59e1e72E5E267');
      expect(bridges.first.token?.symbol, 'USDC');
      expect(captured.url.path, '/bridges');
    });

    test('TC-EP-03: GET /transactions parses paginated transactions', () async {
      late http.Request captured;
      final mockClient = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'items': [
                {
                  'id': 'a1b2c3d4-e5f6-4789-a012-3456789abcde',
                  'amount': '1000000',
                  'timestamp': '1710000000',
                  'fromUser': '0x1111111111111111111111111111111111111111',
                  'toUser': '0x2222222222222222222222222222222222222222',
                  'fromChain': '84532',
                  'toChain': '421614',
                  'nonce': 3,
                  'symbol': 'USDC',
                  'fulfilled': false,
                  'index': 3,
                  'userAddress': '0x1111111111111111111111111111111111111111',
                  'chainId': '84532',
                  'transactionHash': '0xabc',
                }
              ],
              'pagination': {
                'page': 1,
                'limit': 10,
                'totalCount': 1,
                'totalPages': 1,
                'hasNextPage': false,
                'hasPreviousPage': false,
              },
            },
          }),
          200,
        );
      });

      final client = AssetChainBridgeClient(
        baseUrl: 'https://bridge.assetchain.org',
        clientName: testClientName,
        clientSecret: testSecretKey,
        httpClient: mockClient,
      );

      final result = await client.getTransactions(
        userAddress: '0x1111111111111111111111111111111111111111',
        symbol: 'XRWA',
        fulfilled: false,
        page: 1,
        limit: 10,
      );

      expect(result.items, hasLength(1));
      expect(result.pagination.totalCount, 1);
      expect(result.items.first.symbol, 'USDC');
      expect(captured.url.queryParameters['symbol'], 'RWA'); // normalizes XRWA -> RWA
      expect(captured.url.queryParameters['userAddress'], '0x1111111111111111111111111111111111111111');
    });

    test('TC-EP-04: POST /transactions records on-chain deposit event', () async {
      late http.Request captured;
      final mockClient = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'success': true,
              'message': 'Transaction added successfully',
              'data': {
                'id': 'a1b2c3d4-e5f6-4789-a012-3456789abcde',
                'amount': '1000000',
                'timestamp': '1710000000',
                'fromUser': '0x1111111111111111111111111111111111111111',
                'toUser': '0x2222222222222222222222222222222222222222',
                'fromChain': '84532',
                'toChain': '421614',
                'symbol': 'USDC',
                'fulfilled': false,
                'index': 3,
                'userAddress': '0x1111111111111111111111111111111111111111',
                'chainId': '84532',
                'transactionHash': '0xabc',
                'bridgeInfoId': 'c3d4e5f6-a7b8-4901-8234-567890abcdef',
              },
            },
          }),
          201,
        );
      });

      final client = AssetChainBridgeClient(
        baseUrl: 'https://bridge.assetchain.org',
        clientName: testClientName,
        clientSecret: testSecretKey,
        httpClient: mockClient,
      );

      final tx = await client.recordTransaction(
        bridgeId: 'c3d4e5f6-a7b8-4901-8234-567890abcdef',
        index: '3',
        userAddress: '0x1111111111111111111111111111111111111111',
        transactionHash: '0xabc',
      );

      expect(tx.id, 'a1b2c3d4-e5f6-4789-a012-3456789abcde');
      expect(tx.transactionHash, '0xabc');
      expect(captured.method, 'POST');
      expect(captured.headers['Content-Type'], 'application/json');
      final payload = jsonDecode(captured.body);
      expect(payload['bridgeId'], 'c3d4e5f6-a7b8-4901-8234-567890abcdef');
    });

    test('TC-EP-05: PUT /transactions notifies fulfillment and marks claimed', () async {
      late http.Request captured;
      final mockClient = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'success': true,
              'message': 'Transaction marked as claimed',
              'data': {
                'id': 'a1b2c3d4-e5f6-4789-a012-3456789abcde',
                'fulfilled': true,
                'claimTransactionHash': '0xdef',
                'amount': '1000000',
                'fromChain': '84532',
                'toChain': '421614',
                'index': 3,
                'userAddress': '0x1111111111111111111111111111111111111111',
                'bridgeInfoId': 'c3d4e5f6-a7b8-4901-8234-567890abcdef',
              },
            },
          }),
          200,
        );
      });

      final client = AssetChainBridgeClient(
        baseUrl: 'https://bridge.assetchain.org',
        clientName: testClientName,
        clientSecret: testSecretKey,
        httpClient: mockClient,
      );

      final claim = await client.updateTransactionFulfillment(
        transactionId: 'a1b2c3d4-e5f6-4789-a012-3456789abcde',
        claimTransactionHash: '0xdef',
        toBridgeId: 'c3d4e5f6-a7b8-4901-8234-567890abcdef',
      );

      expect(claim.success, isTrue);
      expect(claim.fulfilled, isTrue);
      expect(claim.claimTransactionHash, '0xdef');
      expect(captured.method, 'PUT');
    });

    test('TC-EP-06: GET /blockchain/sign parses relayer signatures array', () async {
      late http.Request captured;
      final mockClient = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'signature': [
              '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1b',
              '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1c',
            ],
          }),
          200,
        );
      });

      final client = AssetChainBridgeClient(
        baseUrl: 'https://bridge.assetchain.org',
        clientName: testClientName,
        clientSecret: testSecretKey,
        httpClient: mockClient,
      );

      final res = await client.getRelayerSignatures(
        bridgeId: 'c3d4e5f6-a7b8-4901-8234-567890abcdef',
        index: '3',
        fromUser: '0x1111111111111111111111111111111111111111',
      );

      expect(res.signatures, hasLength(2));
      expect(res.signatures.first, startsWith('0xaaaa'));
      expect(captured.url.path, '/blockchain/sign');
      expect(captured.url.queryParameters['bridgeId'], 'c3d4e5f6-a7b8-4901-8234-567890abcdef');
    });
  });

  group('Group 3: Offline Mock Fallback Engine', () {
    test('TC-MOCK-01: Client detects mock mode when credentials are missing or blank', () {
      final unconfigured = AssetChainBridgeClient(clientName: null, clientSecret: null);
      expect(unconfigured.isMockMode, isTrue);

      final blank = AssetChainBridgeClient(clientName: '', clientSecret: '   ');
      expect(blank.isMockMode, isTrue);

      final explicitMock = AssetChainBridgeClient(
        clientName: 'name',
        clientSecret: 'secret',
        mockEnabled: true,
      );
      expect(explicitMock.isMockMode, isTrue);

      final live = AssetChainBridgeClient(
        clientName: 'name',
        clientSecret: 'secret',
        mockEnabled: false,
      );
      expect(live.isMockMode, isFalse);

      final proxy = AssetChainBridgeClient.fromEnvironment();
      expect(proxy.useProxy, isTrue);
      expect(proxy.isMockMode, isFalse);
    });

    test('TC-MOCK-02: Zero Network I/O in mock mode (HTTP transport never called)', () async {
      final throwingMockClient = MockClient((_) async {
        throw StateError('Network should never be contacted in mock mode');
      });

      final client = AssetChainBridgeClient(
        mockEnabled: true,
        httpClient: throwingMockClient,
      );

      final tokens = await client.getTokens();
      expect(tokens, hasLength(4));

      final bridges = await client.getBridges();
      expect(bridges, hasLength(3));

      final txs = await client.getTransactions(
        userAddress: '0x1111111111111111111111111111111111111111',
      );
      expect(txs.items, hasLength(1));

      final recorded = await client.recordTransaction(
        bridgeId: 'test-bridge',
        index: '1',
        userAddress: '0x1111111111111111111111111111111111111111',
        transactionHash: '0xmockhash',
      );
      expect(recorded.transactionHash, '0xmockhash');

      final claim = await client.updateTransactionFulfillment(
        transactionId: 'test-id',
        claimTransactionHash: '0xclaimhash',
        toBridgeId: 'dest-bridge',
      );
      expect(claim.fulfilled, isTrue);

      final sigs = await client.getRelayerSignatures(
        bridgeId: 'test-bridge',
        index: '1',
        fromUser: '0x1111111111111111111111111111111111111111',
      );
      expect(sigs.signatures, hasLength(2));
    });

    test('TC-MOCK-03: Mock tokens and bridge filtering by chainId', () async {
      final client = AssetChainBridgeClient(mockEnabled: true);

      final testnetTokens = await client.getTokens(chainId: '42421');
      expect(testnetTokens, hasLength(1));
      expect(testnetTokens.single.symbol, 'RWA');
      expect(testnetTokens.single.chainId, '42421');

      final baseBridges = await client.getBridges(chainId: '84532');
      expect(baseBridges, hasLength(1));
      expect(baseBridges.single.chainId, '84532');
    });
  });

  group('Group 4: Error Handling & Mapping', () {
    test('TC-ERR-01: HTTP 401 Missing signature headers throws AssetChainBridgeException', () async {
      final mockClient = MockClient((_) async => http.Response(
        jsonEncode({'message': 'Missing signature headers'}),
        401,
      ));

      final client = AssetChainBridgeClient(
        clientName: testClientName,
        clientSecret: testSecretKey,
        httpClient: mockClient,
      );

      expect(
        () => client.getTokens(),
        throwsA(isA<AssetChainBridgeException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue)
            .having((e) => e.message, 'message', 'Missing signature headers')),
      );
    });

    test('TC-ERR-02: HTTP 401 Request expired throws with isExpired == true', () async {
      final mockClient = MockClient((_) async => http.Response(
        jsonEncode({'message': 'Request expired'}),
        401,
      ));

      final client = AssetChainBridgeClient(
        clientName: testClientName,
        clientSecret: testSecretKey,
        httpClient: mockClient,
      );

      expect(
        () => client.getBridges(),
        throwsA(isA<AssetChainBridgeException>()
            .having((e) => e.isExpired, 'isExpired', isTrue)),
      );
    });

    test('TC-ERR-03: HTTP 400 Claim requires admin approval throws with actionable diagnostic', () async {
      final mockClient = MockClient((_) async => http.Response(
        jsonEncode({
          'code': 'INTERNAL_ERROR',
          'message': 'Claim requires admin approval',
        }),
        400,
      ));

      final client = AssetChainBridgeClient(
        clientName: testClientName,
        clientSecret: testSecretKey,
        httpClient: mockClient,
      );

      expect(
        () => client.getRelayerSignatures(
          bridgeId: 'bridge',
          index: '0',
          fromUser: '0xuser',
        ),
        throwsA(isA<AssetChainBridgeException>()
            .having((e) => e.isAdminApprovalRequired, 'isAdminApprovalRequired', isTrue)
            .having((e) => e.errorCode, 'errorCode', 'INTERNAL_ERROR')),
      );
    });

    test('TC-ERR-04: HTTP 400 Invalid user address throws with isBadRequest == true', () async {
      final mockClient = MockClient((_) async => http.Response(
        jsonEncode({'error': 'Invalid user address'}),
        400,
      ));

      final client = AssetChainBridgeClient(
        clientName: testClientName,
        clientSecret: testSecretKey,
        httpClient: mockClient,
      );

      expect(
        () => client.getTransactions(userAddress: 'bad-address'),
        throwsA(isA<AssetChainBridgeException>()
            .having((e) => e.isBadRequest, 'isBadRequest', isTrue)
            .having((e) => e.message, 'message', 'Invalid user address')),
      );
    });
  });

  group('Group 5: DTO Round-Trip Serialization', () {
    test('TC-DTO-01: AssetChainBridgeToken serialization round-trip', () {
      final token = AssetChainBridgeToken(
        id: 'token-uuid',
        tokenAddress: '0x123',
        decimal: 18,
        symbol: 'RWA',
        name: 'Asset Chain RWA',
        chainId: '42420',
        maxClaimAmount: '1000',
        createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
      );

      final json = token.toJson();
      final decoded = AssetChainBridgeToken.fromJson(json);

      expect(decoded.id, token.id);
      expect(decoded.symbol, token.symbol);
      expect(decoded.decimal, 18);
      expect(decoded.maxClaimAmount, '1000');
    });

    test('TC-DTO-02: AssetChainBridgeDeployment serialization round-trip', () {
      final deployment = AssetChainBridgeDeployment(
        id: 'dep-id',
        bridgeAddress: '0xbridge',
        chainId: '421614',
        fees: const AssetChainBridgeFees(feeFulfill: 10, feeSend: 20),
        tokenId: 'token-id',
        limitPerSend: '5000',
        tokenDecimal: 6,
      );

      final json = deployment.toJson();
      final decoded = AssetChainBridgeDeployment.fromJson(json);

      expect(decoded.id, 'dep-id');
      expect(decoded.fees.feeFulfill, 10);
      expect(decoded.fees.feeSend, 20);
      expect(decoded.limitPerSend, '5000');
    });

    test('TC-DTO-03: AssetChainBridgeTransaction and Pagination serialization', () {
      final tx = AssetChainBridgeTransaction(
        id: 'tx-1',
        amount: '1000000',
        timestamp: '1710000000',
        fromUser: '0x1',
        toUser: '0x2',
        fromChain: '84532',
        toChain: '421614',
        symbol: 'USDC',
        fulfilled: false,
        index: 3,
        userAddress: '0x1',
        chainId: '84532',
        transactionHash: '0xhash',
      );

      final page = AssetChainBridgePagination(
        page: 1,
        limit: 10,
        totalCount: 1,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false,
      );

      final list = AssetChainBridgeTransactionList(
        items: [tx],
        pagination: page,
      );

      final json = list.toJson();
      final decoded = AssetChainBridgeTransactionList.fromJson(json);

      expect(decoded.items, hasLength(1));
      expect(decoded.items.first.transactionHash, '0xhash');
      expect(decoded.pagination.totalCount, 1);
    });

    test('TC-DTO-04: AssetChainBridgeClaimResult and Signatures serialization', () {
      const claim = AssetChainBridgeClaimResult(
        success: true,
        message: 'Claimed',
        transactionId: 'tx-123',
        fulfilled: true,
        claimTransactionHash: '0xclaim',
      );
      final claimJson = claim.toJson();
      final decodedClaim = AssetChainBridgeClaimResult.fromJson(claimJson);
      expect(decodedClaim.success, isTrue);
      expect(decodedClaim.fulfilled, isTrue);
      expect(decodedClaim.claimTransactionHash, '0xclaim');

      const sigs = AssetChainBridgeSignatures(signatures: ['0x1', '0x2']);
      final sigsJson = sigs.toJson();
      final decodedSigs = AssetChainBridgeSignatures.fromJson(sigsJson);
      expect(decodedSigs.signatures, ['0x1', '0x2']);
    });
  });

  group('Group 6: AppEnvironment & BridgeService Integration', () {
    test('TC-INT-01: AppEnvironment bridge constants and URLs are configured', () {
      final mainnetUrl = AppEnvironment.assetChainBridgeBaseUrl(testnet: false);
      expect(mainnetUrl, 'https://bridge.assetchain.org');

      final testnetUrl = AppEnvironment.assetChainBridgeBaseUrl(testnet: true);
      expect(testnetUrl, 'https://bridge-testnet.assetchain.org');

      // The wallet uses the backend proxy; absent provider credentials are normal.
      expect(AppEnvironment.isAssetChainBridgeMockMode, isFalse);
    });

    test('TC-INT-02: BridgeService integrates AssetChainBridgeClient helper methods', () async {
      final mockBridgeClient = AssetChainBridgeClient(mockEnabled: true);
      final bridgeService = BridgeService(
        assetChainBridgeClient: mockBridgeClient,
      );

      expect(bridgeService.assetChainBridgeClient, isNotNull);

      final tokens = await bridgeService.getAssetChainTokens();
      expect(tokens, isNotEmpty);

      final bridges = await bridgeService.getAssetChainBridges();
      expect(bridges, isNotEmpty);

      final txs = await bridgeService.getAssetChainTransactions(
        userAddress: '0x1111111111111111111111111111111111111111',
      );
      expect(txs.items, isNotEmpty);

      final deposit = await bridgeService.recordAssetChainDeposit(
        bridgeId: 'bridge-1',
        index: '1',
        userAddress: '0x1111111111111111111111111111111111111111',
        transactionHash: '0x123',
      );
      expect(deposit.transactionHash, '0x123');

      final fulfilled = await bridgeService.updateAssetChainFulfillment(
        transactionId: 'tx-1',
        claimTransactionHash: '0xclaim',
        toBridgeId: 'bridge-2',
      );
      expect(fulfilled.fulfilled, isTrue);

      final sigs = await bridgeService.getAssetChainRelayerSignatures(
        bridgeId: 'bridge-1',
        index: '1',
        fromUser: '0x1111111111111111111111111111111111111111',
      );
      expect(sigs.signatures, hasLength(2));
    });
  });
}
