import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/walletconnect/wallet_connect_models.dart';
import 'package:fomowl_wallet/widgets/walletconnect/wallet_connect_proposal_modal.dart';
import 'package:fomowl_wallet/widgets/walletconnect/wallet_connect_request_modal.dart';

void main() {
  group('WalletConnect Modals Widget Tests', () {
    testWidgets('WalletConnectProposalModal renders DApp info, chains, and buttons', (tester) async {
      const proposal = WcSessionProposalModel(
        id: 1,
        dappName: 'Uniswap Protocol',
        dappUrl: 'https://app.uniswap.org',
        dappDescription: 'Swap tokens across networks',
        requestedChains: ['eip155:1', 'eip155:137'],
        requestedMethods: ['personal_sign', 'eth_sendTransaction'],
        requestedEvents: ['chainChanged', 'accountsChanged'],
        isVerified: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WalletConnectProposalModal(
              proposal: proposal,
              walletAddress: '0x1234567890abcdef1234567890abcdef12345678',
            ),
          ),
        ),
      );

      expect(find.text('Uniswap Protocol'), findsOneWidget);
      expect(find.text('app.uniswap.org'), findsOneWidget);
      expect(find.text('Ethereum'), findsOneWidget);
      expect(find.text('Polygon'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
      expect(find.text('0x1234...5678'), findsOneWidget);
    });

    testWidgets('WalletConnectRequestModal renders signature request details', (tester) async {
      const request = WcSessionRequestModel(
        id: 2,
        topic: 'topic_123',
        method: 'personal_sign',
        chainId: 'eip155:1',
        dappName: 'OpenSea',
        dappUrl: 'https://opensea.io',
        params: ['0x48656c6c6f', '0x1234'],
        formattedPreview: 'Sign in to OpenSea with nonce: 987654',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WalletConnectRequestModal(
              request: request,
            ),
          ),
        ),
      );

      expect(find.text('OpenSea'), findsOneWidget);
      expect(find.text('opensea.io'), findsOneWidget);
      expect(find.text('Signature Request'), findsOneWidget);
      expect(find.text('Sign in to OpenSea with nonce: 987654'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
    });

    testWidgets('WalletConnectRequestModal renders transaction request with Confirm button', (tester) async {
      const request = WcSessionRequestModel(
        id: 3,
        topic: 'topic_456',
        method: 'eth_sendTransaction',
        chainId: 'eip155:1',
        dappName: 'Aave V3',
        dappUrl: 'https://app.aave.com',
        params: [
          {'to': '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D', 'value': '0x2386f26fc10000'}
        ],
        formattedPreview: '{"to": "0x7a25...", "value": "0.01 ETH"}',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WalletConnectRequestModal(
              request: request,
            ),
          ),
        ),
      );

      expect(find.text('Aave V3'), findsOneWidget);
      expect(find.text('Send Transaction'), findsOneWidget);
      expect(find.text('TRANSACTION'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    });
  });
}
