import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/config/app_environment.dart';
import 'package:fomowl_wallet/services/walletconnect/wallet_connect_models.dart';

void main() {
  group('WalletConnect Models & Environment Tests', () {
    test('AppEnvironment provides non-empty walletConnectProjectId', () {
      final projectId = AppEnvironment.walletConnectProjectId;
      expect(projectId, isNotEmpty);
      expect(projectId.length, greaterThanOrEqualTo(8));
    });

    test(
      'WcSessionProposalModel holds valid metadata and requested namespaces',
      () {
        const proposal = WcSessionProposalModel(
          id: 12345,
          dappName: 'Uniswap',
          dappUrl: 'https://app.uniswap.org',
          dappDescription: 'Swap tokens on Ethereum',
          dappIcon: 'https://app.uniswap.org/favicon.png',
          requestedChains: ['eip155:1', 'eip155:137', 'solana:mainnet'],
          requestedMethods: ['personal_sign', 'eth_sendTransaction'],
          requestedEvents: ['chainChanged', 'accountsChanged'],
          isVerified: true,
        );

        expect(proposal.id, 12345);
        expect(proposal.dappName, 'Uniswap');
        expect(proposal.dappUrl, 'https://app.uniswap.org');
        expect(proposal.requestedChains, contains('eip155:1'));
        expect(proposal.requestedMethods, contains('personal_sign'));
        expect(proposal.isVerified, isTrue);
      },
    );

    test('WcSessionRequestModel formats and exposes request attributes', () {
      const request = WcSessionRequestModel(
        id: 67890,
        topic: 'test_topic_abc_123',
        method: 'personal_sign',
        chainId: 'eip155:1',
        dappName: 'OpenSea',
        dappUrl: 'https://opensea.io',
        dappIcon: 'https://opensea.io/icon.png',
        params: [
          '0x48656c6c6f204f776c6c6574',
          '0x1234567890abcdef1234567890abcdef12345678',
        ],
        formattedPreview: 'Hello Owllet',
      );

      expect(request.id, 67890);
      expect(request.topic, 'test_topic_abc_123');
      expect(request.method, 'personal_sign');
      expect(request.formattedPreview, 'Hello Owllet');
    });

    test('WcActiveSessionModel formats short topic correctly', () {
      final session = WcActiveSessionModel(
        topic: '1234567890abcdef1234567890abcdef',
        pairingTopic: 'pairing_topic_123',
        dappName: 'Aave',
        dappUrl: 'https://app.aave.com',
        chains: ['eip155:1'],
        accounts: ['eip155:1:0x1234567890abcdef1234567890abcdef12345678'],
        expiry: DateTime.now().add(const Duration(days: 7)),
      );

      expect(session.shortTopic, '123456...cdef');
    });
  });
}
