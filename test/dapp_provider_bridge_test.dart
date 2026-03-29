import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fomowl_wallet/features/discover/browser/browser_session_controller.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_catalog_snapshot.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_dapp_entry.dart';
import 'package:fomowl_wallet/features/discover/provider/dapp_provider_bridge.dart';
import 'package:fomowl_wallet/features/discover/provider/discover_provider_approval_request.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/rpc_service.dart';

import '../test_support/discover/fake_blockchain_service.dart';
import '../test_support/discover/fake_dapp_permission_service.dart';
import '../test_support/discover/fake_discover_catalog_service.dart';
import '../test_support/discover/fake_rpc_service.dart';
import '../test_support/discover/fake_wallet_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DiscoverDappEntry entryForTestDapp({
    String id = 'test-dapp',
    String origin = 'https://app.example',
    List<int> supportedChainIds = const [1],
  }) {
    return DiscoverDappEntry(
      id: id,
      slug: id,
      origin: origin,
      launchUrl: origin,
      title: 'Test DApp',
      subtitle: 'Harness',
      logoUrl: null,
      heroImageUrl: null,
      badgeText: 'TEST',
      categories: const ['test'],
      supportedChainIds: supportedChainIds,
      featuredRank: 1,
      trendingRank: 1,
      isActive: true,
      createdAt: '2026-03-28T00:00:00Z',
      updatedAt: '2026-03-28T00:00:00Z',
    );
  }

  Future<BrowserSessionController> controllerForEntry(
    DiscoverDappEntry entry,
  ) async {
    final controller = BrowserSessionController(
      catalogService: FakeDiscoverCatalogService(
        snapshot: DiscoverCatalogSnapshot(
          dapps: [entry],
          fetchedAt: DateTime.now().toUtc(),
        ),
      ),
    );
    await controller.loadCatalog();
    controller.openDapp(entry);
    return controller;
  }

  Future<BuildContext> pumpBridgeHarness(
    WidgetTester tester, {
    required BlockchainService blockchainService,
    required RpcService rpcService,
  }) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BlockchainService>.value(
            value: blockchainService,
          ),
          ChangeNotifierProvider<RpcService>.value(value: rpcService),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return capturedContext;
  }

  group('DappProviderBridge', () {
    testWidgets('eth_requestAccounts returns 4001 when approval is rejected', (
      tester,
    ) async {
      final entry = entryForTestDapp(
        origin: 'https://app.example',
        supportedChainIds: [1],
      );
      final controller = await controllerForEntry(entry);
      final context = await pumpBridgeHarness(
        tester,
        blockchainService: FakeBlockchainService(),
        rpcService: FakeRpcService(),
      );
      final bridge = DappProviderBridge(
        sessionController: controller,
        permissionService: FakeDappPermissionService(),
        walletService: FakeWalletService(),
        approvalHandler:
            (
              BuildContext context,
              DiscoverProviderApprovalRequest request,
            ) async => false,
      );

      final response = await bridge.handleRequest(
        context: context,
        origin: entry.origin,
        payload: const {'method': 'eth_requestAccounts', 'params': []},
        evaluateJavaScript: (_) async {},
      );

      expect(response['error']['code'], 4001);
    });

    testWidgets(
      'wallet_switchEthereumChain switches active chain when approved',
      (tester) async {
        final entry = entryForTestDapp(
          origin: 'https://app.example',
          supportedChainIds: [1, 56],
        );
        final controller = await controllerForEntry(entry);
        final blockchainService = FakeBlockchainService();
        final context = await pumpBridgeHarness(
          tester,
          blockchainService: blockchainService,
          rpcService: FakeRpcService(),
        );
        final bridge = DappProviderBridge(
          sessionController: controller,
          permissionService: FakeDappPermissionService(),
          walletService: FakeWalletService(),
          approvalHandler:
              (
                BuildContext context,
                DiscoverProviderApprovalRequest request,
              ) async => true,
        );

        final response = await bridge.handleRequest(
          context: context,
          origin: entry.origin,
          payload: const {
            'method': 'wallet_switchEthereumChain',
            'params': [
              {'chainId': '0x38'},
            ],
          },
          evaluateJavaScript: (_) async {},
        );

        expect(response['result'], isNull);
        expect(blockchainService.activeChain.chainId, 56);
      },
    );

    testWidgets('wallet_addEthereumChain rejects non-https RPC URLs', (
      tester,
    ) async {
      final entry = entryForTestDapp(
        origin: 'https://app.example',
        supportedChainIds: [11155111],
      );
      final controller = await controllerForEntry(entry);
      final context = await pumpBridgeHarness(
        tester,
        blockchainService: FakeBlockchainService(),
        rpcService: FakeRpcService(),
      );
      final bridge = DappProviderBridge(
        sessionController: controller,
        permissionService: FakeDappPermissionService(),
        walletService: FakeWalletService(),
        approvalHandler:
            (
              BuildContext context,
              DiscoverProviderApprovalRequest request,
            ) async => true,
      );

      final response = await bridge.handleRequest(
        context: context,
        origin: entry.origin,
        payload: const {
          'method': 'wallet_addEthereumChain',
          'params': [
            {
              'chainId': '0xaa36a7',
              'chainName': 'Sepolia',
              'rpcUrls': ['http://localhost:8545'],
              'blockExplorerUrls': ['https://sepolia.etherscan.io'],
              'nativeCurrency': {'symbol': 'ETH'},
            },
          ],
        },
        evaluateJavaScript: (_) async {},
      );

      expect(response['error']['code'], -32602);
      expect(
        response['error']['message'],
        contains('At least one HTTPS RPC URL is required'),
      );
    });

    testWidgets('wallet_addEthereumChain adds a verified custom chain', (
      tester,
    ) async {
      final entry = entryForTestDapp(
        origin: 'https://app.example',
        supportedChainIds: [11155111],
      );
      final controller = await controllerForEntry(entry);
      final blockchainService = FakeBlockchainService();
      final context = await pumpBridgeHarness(
        tester,
        blockchainService: blockchainService,
        rpcService: FakeRpcService(
          chainIdsByUrl: const {'https://rpc.sepolia.test': 11155111},
        ),
      );
      final bridge = DappProviderBridge(
        sessionController: controller,
        permissionService: FakeDappPermissionService(),
        walletService: FakeWalletService(),
        approvalHandler:
            (
              BuildContext context,
              DiscoverProviderApprovalRequest request,
            ) async => true,
      );

      final response = await bridge.handleRequest(
        context: context,
        origin: entry.origin,
        payload: const {
          'method': 'wallet_addEthereumChain',
          'params': [
            {
              'chainId': '0xaa36a7',
              'chainName': 'Sepolia',
              'rpcUrls': ['https://rpc.sepolia.test'],
              'blockExplorerUrls': ['https://sepolia.etherscan.io'],
              'nativeCurrency': {'symbol': 'ETH'},
            },
          ],
        },
        evaluateJavaScript: (_) async {},
      );

      expect(response['result'], isNull);
      expect(
        blockchainService.allChains.any((chain) => chain.chainId == 11155111),
        isTrue,
      );
    });

    testWidgets('eth_sendTransaction rejects a non-active from address', (
      tester,
    ) async {
      final entry = entryForTestDapp(
        origin: 'https://app.example',
        supportedChainIds: [1],
      );
      final controller = await controllerForEntry(entry);
      final context = await pumpBridgeHarness(
        tester,
        blockchainService: FakeBlockchainService(),
        rpcService: FakeRpcService(),
      );
      final bridge = DappProviderBridge(
        sessionController: controller,
        permissionService: FakeDappPermissionService(),
        walletService: FakeWalletService(),
        approvalHandler:
            (
              BuildContext context,
              DiscoverProviderApprovalRequest request,
            ) async => true,
      );

      final response = await bridge.handleRequest(
        context: context,
        origin: entry.origin,
        payload: const {
          'method': 'eth_sendTransaction',
          'params': [
            {
              'from': '0x0000000000000000000000000000000000000001',
              'to': '0x0000000000000000000000000000000000000002',
            },
          ],
        },
        evaluateJavaScript: (_) async {},
      );

      expect(response['error']['code'], 4100);
      expect(response['error']['message'], contains('active wallet'));
    });
  });
}
