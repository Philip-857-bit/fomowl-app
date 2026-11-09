import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:fomowl_wallet/services/blockchain/asset_chain_bridge_client.dart';

/// Low-level IOOverrides to trap and record any attempt to open a socket.
base class _SocketSpyIOOverrides extends IOOverrides {
  int socketConnectAttempts = 0;
  final List<String> attemptedHosts = [];

  @override
  Future<Socket> socketConnect(
    dynamic host,
    int port, {
    dynamic sourceAddress,
    int sourcePort = 0,
    Duration? timeout,
  }) {
    socketConnectAttempts++;
    attemptedHosts.add('$host:$port');
    throw SocketException(
      'CRITICAL ISOLATION BREACH: Outbound socket connection to $host:$port attempted during offline execution!',
    );
  }

  @override
  Future<ConnectionTask<Socket>> socketStartConnect(
    dynamic host,
    int port, {
    dynamic sourceAddress,
    int sourcePort = 0,
  }) {
    socketConnectAttempts++;
    attemptedHosts.add('$host:$port');
    throw SocketException(
      'CRITICAL ISOLATION BREACH: Outbound socket startConnect to $host:$port attempted during offline execution!',
    );
  }

  Future<ConnectionTask<SecureSocket>> secureSocketStartConnect(
    dynamic host,
    int port, {
    SecurityContext? context,
    dynamic sourceAddress,
    int sourcePort = 0,
    void Function(X509Certificate)? onBadCertificate,
    List<String>? supportedProtocols,
  }) {
    socketConnectAttempts++;
    attemptedHosts.add('$host:$port');
    throw SocketException(
      'CRITICAL ISOLATION BREACH: Outbound secure socket startConnect to $host:$port attempted during offline execution!',
    );
  }
}

/// Transport-level spy verifying that http.BaseClient.send is never invoked.
class _TransportSpyClient extends http.BaseClient {
  int sendCalls = 0;
  final List<String> capturedUrls = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    sendCalls++;
    capturedUrls.add(request.url.toString());
    throw StateError(
      'CRITICAL ISOLATION BREACH: http.Client.send invoked for ${request.url} in offline mock mode!',
    );
  }
}

void main() {
  const testUserAddress = '0x1111111111111111111111111111111111111111';

  group('CHALLENGER: Offline Mock Isolation & OS Socket Zero-Emission', () {
    test('Empirical Proof 1: Zero OS-level outbound sockets opened across all 6 endpoints when mockEnabled=true', () async {
      final spy = _SocketSpyIOOverrides();

      await IOOverrides.runWithIOOverrides(() async {
        // Construct client without providing a mock httpClient — using the default real http.Client()
        final client = AssetChainBridgeClient(
          baseUrl: 'https://bridge-testnet.assetchain.org',
          mockEnabled: true,
        );

        expect(client.isMockMode, isTrue);

        // 1. GET /tokens
        final tokens = await client.getTokens();
        expect(tokens, isNotEmpty);
        expect(tokens.any((t) => t.symbol == 'RWA'), isTrue);

        final testnetTokens = await client.getTokens(chainId: '42421');
        expect(testnetTokens, hasLength(1));
        expect(testnetTokens.first.chainId, '42421');

        // 2. GET /bridges
        final bridges = await client.getBridges();
        expect(bridges, isNotEmpty);

        final baseBridges = await client.getBridges(chainId: '84532');
        expect(baseBridges, hasLength(1));

        // 3. GET /transactions
        final txs = await client.getTransactions(userAddress: testUserAddress);
        expect(txs.items, isNotEmpty);
        expect(txs.items.first.fromUser, testUserAddress);

        // 4. POST /transactions
        final recorded = await client.recordTransaction(
          bridgeId: 'mock-bridge-id',
          index: '42',
          userAddress: testUserAddress,
          transactionHash: '0xmocktxhash42',
        );
        expect(recorded.index, 42);
        expect(recorded.transactionHash, '0xmocktxhash42');

        // 5. PUT /transactions
        final claim = await client.updateTransactionFulfillment(
          transactionId: 'mock-tx-id',
          claimTransactionHash: '0xmockclaimhash42',
          toBridgeId: 'mock-dest-bridge-id',
        );
        expect(claim.success, isTrue);
        expect(claim.fulfilled, isTrue);

        // 6. GET /blockchain/sign
        final sigs = await client.getRelayerSignatures(
          bridgeId: 'mock-bridge-id',
          index: '42',
          fromUser: testUserAddress,
        );
        expect(sigs.signatures, hasLength(2));

        // Verify strictly 0 outbound socket connections were initiated
        expect(spy.socketConnectAttempts, 0);
        expect(spy.attemptedHosts, isEmpty);

        client.dispose();
      }, spy);
    });

    test('Empirical Proof 2: Automatic fallback with unconfigured credentials produces zero OS sockets', () async {
      final spy = _SocketSpyIOOverrides();

      await IOOverrides.runWithIOOverrides(() async {
        final unconfiguredClient = AssetChainBridgeClient(
          clientName: null,
          clientSecret: null,
        );
        expect(unconfiguredClient.isMockMode, isTrue);

        final tokens = await unconfiguredClient.getTokens();
        expect(tokens, isNotEmpty);

        final emptyCredentialsClient = AssetChainBridgeClient(
          clientName: '',
          clientSecret: '   ',
        );
        expect(emptyCredentialsClient.isMockMode, isTrue);

        final bridges = await emptyCredentialsClient.getBridges();
        expect(bridges, isNotEmpty);

        final envClient = AssetChainBridgeClient.fromEnvironment(useProxy: false);
        expect(envClient.isMockMode, isTrue);

        final txs = await envClient.getTransactions(userAddress: testUserAddress);
        expect(txs.items, isNotEmpty);

        expect(spy.socketConnectAttempts, 0);
        expect(spy.attemptedHosts, isEmpty);

        unconfiguredClient.dispose();
        emptyCredentialsClient.dispose();
        envClient.dispose();
      }, spy);
    });

    test('Empirical Proof 3: Zero HTTP transport send() calls under 50-iteration burst stress', () async {
      final transportSpy = _TransportSpyClient();

      final client = AssetChainBridgeClient(
        mockEnabled: true,
        httpClient: transportSpy,
      );

      for (int i = 0; i < 50; i++) {
        await client.getTokens(chainId: i % 2 == 0 ? '42420' : '42421');
        await client.getBridges(chainId: i % 2 == 0 ? '84532' : '421614');
        await client.getTransactions(userAddress: testUserAddress);
        await client.recordTransaction(
          bridgeId: 'bridge-$i',
          index: '$i',
          userAddress: testUserAddress,
          transactionHash: '0xhash$i',
        );
        await client.updateTransactionFulfillment(
          transactionId: 'tx-$i',
          claimTransactionHash: '0xclaim$i',
          toBridgeId: 'bridge-dest-$i',
        );
        await client.getRelayerSignatures(
          bridgeId: 'bridge-$i',
          index: '$i',
          fromUser: testUserAddress,
        );
      }

      expect(transportSpy.sendCalls, 0);
      expect(transportSpy.capturedUrls, isEmpty);

      client.dispose();
    });

    test('Empirical Proof 4 (Negative Oracle): When mock mode is disabled, outbound HTTP call is attempted and trapped', () async {
      final transportSpy = _TransportSpyClient();

      final liveClient = AssetChainBridgeClient(
        baseUrl: 'https://bridge.assetchain.org',
        clientName: 'live-client',
        clientSecret: 'live-secret-12345',
        mockEnabled: false,
        httpClient: transportSpy,
      );

      expect(liveClient.isMockMode, isFalse);

      // Attempting to make an outbound call must invoke transport and trigger our blocker
      expect(
        () => liveClient.getTokens(),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('CRITICAL ISOLATION BREACH'),
        )),
      );

      expect(transportSpy.sendCalls, 1);
      expect(transportSpy.capturedUrls, contains('https://bridge.assetchain.org/tokens'));

      liveClient.dispose();
    });
  });
}
