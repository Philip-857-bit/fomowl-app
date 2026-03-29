import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/discover/browser/browser_session_controller.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_catalog_snapshot.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_dapp_entry.dart';
import 'package:fomowl_wallet/features/discover/provider/dapp_provider_bridge.dart';
import 'package:integration_test/integration_test.dart';

import '../test_support/discover/discover_browser_test_harness.dart';
import '../test_support/discover/fake_blockchain_service.dart';
import '../test_support/discover/fake_dapp_permission_service.dart';
import '../test_support/discover/fake_discover_catalog_service.dart';
import '../test_support/discover/fake_rpc_service.dart';
import '../test_support/discover/fake_wallet_service.dart';
import 'support/discover_test_dapp_server.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitForCondition(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (condition()) {
        return;
      }
    }
    throw TestFailure('Timed out waiting for Discover browser condition.');
  }

  DiscoverDappEntry entryForHarness({
    required String origin,
    required String launchUrl,
    required List<int> supportedChainIds,
  }) {
    return DiscoverDappEntry(
      id: 'discover-harness',
      slug: 'discover-harness',
      origin: origin,
      launchUrl: launchUrl,
      title: 'Discover Harness',
      subtitle: 'Local test dapp',
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

  Future<
    ({
      BrowserSessionController controller,
      FakeBlockchainService blockchainService,
    })
  >
  pumpHarness(
    WidgetTester tester, {
    required DiscoverTestDappServer server,
    required String scenario,
    required List<int> supportedChainIds,
  }) async {
    final entry = entryForHarness(
      origin: server.origin(),
      launchUrl: server.urlForScenario(scenario),
      supportedChainIds: supportedChainIds,
    );
    final controller = BrowserSessionController(
      catalogService: FakeDiscoverCatalogService(
        snapshot: DiscoverCatalogSnapshot(
          dapps: [entry],
          fetchedAt: DateTime.now().toUtc(),
        ),
      ),
    );
    await controller.loadCatalog();
    controller.openManualInput(server.urlForScenario(scenario));

    final blockchainService = FakeBlockchainService();
    final providerBridge = DappProviderBridge(
      sessionController: controller,
      permissionService: FakeDappPermissionService(),
      walletService: FakeWalletService(),
    );
    await tester.pumpWidget(
      DiscoverBrowserTestHarness(
        sessionController: controller,
        providerBridge: providerBridge,
        blockchainService: blockchainService,
        rpcService: FakeRpcService(
          chainIdsByUrl: const {
            DiscoverTestDappServer.mockAddChainRpcUrl: 11155111,
          },
        ),
      ),
    );
    await tester.pump();
    return (controller: controller, blockchainService: blockchainService);
  }

  testWidgets('injects provider for an approved localhost origin', (
    tester,
  ) async {
    final server = DiscoverTestDappServer();
    await server.start();
    addTearDown(server.close);

    final harness = await pumpHarness(
      tester,
      server: server,
      scenario: 'provider',
      supportedChainIds: const [1, 56, 11155111],
    );

    await waitForCondition(
      tester,
      () => harness.controller.pageTitle == 'provider:yes',
    );

    expect(harness.controller.pageTitle, 'provider:yes');
  });

  testWidgets('blocks navigation when approved origin redirects away', (
    tester,
  ) async {
    final server = DiscoverTestDappServer();
    await server.start();
    addTearDown(server.close);

    final harness = await pumpHarness(
      tester,
      server: server,
      scenario: 'blocked-redirect',
      supportedChainIds: const [1, 56, 11155111],
    );

    await waitForCondition(
      tester,
      () => harness.controller.viewState == DiscoverViewState.blocked,
    );

    expect(harness.controller.blockedState?.origin, 'https://blocked.example');
  });

  testWidgets('connect approval returns the active wallet address', (
    tester,
  ) async {
    final server = DiscoverTestDappServer();
    await server.start();
    addTearDown(server.close);

    final harness = await pumpHarness(
      tester,
      server: server,
      scenario: 'connect',
      supportedChainIds: const [1, 56, 11155111],
    );

    await waitForCondition(
      tester,
      () => find.text('Connect wallet').evaluate().isNotEmpty,
    );
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    await waitForCondition(
      tester,
      () =>
          (harness.controller.pageTitle ?? '').startsWith('accounts:0xbF75A6'),
    );

    expect(
      harness.controller.pageTitle,
      'accounts:0xbF75A6D2F5824A42b0BF946c15580A5f504c8c5F',
    );
  });

  testWidgets('switch chain approval updates the browser session chain', (
    tester,
  ) async {
    final server = DiscoverTestDappServer();
    await server.start();
    addTearDown(server.close);

    final harness = await pumpHarness(
      tester,
      server: server,
      scenario: 'switch',
      supportedChainIds: const [1, 56],
    );

    await waitForCondition(
      tester,
      () => find.text('Switch network').evaluate().isNotEmpty,
    );
    await tester.tap(find.text('Switch'));
    await tester.pumpAndSettle();

    await waitForCondition(
      tester,
      () => harness.controller.pageTitle == 'chain:0x38',
    );

    expect(harness.blockchainService.activeChain.chainId, 56);
    expect(harness.controller.pageTitle, 'chain:0x38');
  });

  testWidgets('add-chain approval adds a verified custom chain', (
    tester,
  ) async {
    final server = DiscoverTestDappServer();
    await server.start();
    addTearDown(server.close);

    final harness = await pumpHarness(
      tester,
      server: server,
      scenario: 'addchain',
      supportedChainIds: const [1, 11155111],
    );

    await waitForCondition(
      tester,
      () => find.text('Add network').evaluate().isNotEmpty,
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add network'));
    await tester.pumpAndSettle();

    await waitForCondition(
      tester,
      () => harness.controller.pageTitle == 'addchain:ok',
    );

    expect(
      harness.blockchainService.allChains.any(
        (chain) => chain.chainId == 11155111,
      ),
      isTrue,
    );
  });

  testWidgets('invalid add-chain request is rejected before approval', (
    tester,
  ) async {
    final server = DiscoverTestDappServer();
    await server.start();
    addTearDown(server.close);

    final harness = await pumpHarness(
      tester,
      server: server,
      scenario: 'addchain-invalid',
      supportedChainIds: const [1, 11155111],
    );

    await waitForCondition(
      tester,
      () => harness.controller.pageTitle == 'error:-32602',
    );

    expect(find.text('Add network'), findsNothing);
  });
}
