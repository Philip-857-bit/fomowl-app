import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/features/discover/browser/browser_session_controller.dart';
import 'package:fomowl_wallet/features/discover/browser/discover_tab_manager.dart';
import 'package:fomowl_wallet/features/discover/browser/discover_tab_storage.dart';
import 'package:fomowl_wallet/features/discover/browser/widgets/discover_browser_view.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_catalog_snapshot.dart';
import 'package:fomowl_wallet/features/discover/discover_screen.dart';
import 'package:fomowl_wallet/features/discover/permissions/dapp_permission_service.dart';
import 'package:fomowl_wallet/features/discover/provider/dapp_provider_bridge.dart';
import 'package:fomowl_wallet/features/shell/app_shell_controller.dart';
import 'package:fomowl_wallet/features/shell/app_shell_screen.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import '../test_support/discover/fake_dapp_permission_service.dart';
import '../test_support/discover/fake_discover_catalog_service.dart';
import '../test_support/discover/fake_wallet_service.dart';
import 'helpers/bitcoin_memory_store.dart';
import 'helpers/test_fonts.dart';

// Only the native WebView surface is stubbed. The real Discover screen, browser
// controller, URL routing, network notifications and close action execute.
class _WebPlatform extends InAppWebViewPlatform {
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) => _WebSurface(params);
}

class _WebSurface extends PlatformInAppWebViewWidget {
  _WebSurface(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('test-native-web-surface'));
  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      throw UnimplementedError('Native controller is outside this widget test');
  @override
  void dispose() {}
}

Future<BlockchainService> _chain(String network) async {
  final chain = BlockchainService();
  chain.setActiveWalletContext(
    address: '0xpublic-wallet-fixture',
    supportedFamilies: ChainFamily.values.toSet(),
  );
  await chain.setEnabledFamilies(ChainFamily.values.toSet());
  chain.configureBitcoinAvailability(available: true, testnetEnabled: true);
  chain.setActiveNetworkKey(network);
  expect(chain.activeNetworkKey, network);
  return chain;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousPlatform = InAppWebViewPlatform.instance;
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    InAppWebViewPlatform.instance = _WebPlatform();
  });
  tearDownAll(() {
    if (previousPlatform != null) {
      InAppWebViewPlatform.instance = previousPlatform;
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });
  setUp(installTestFonts);

  for (final network in ['bitcoin:mainnet', 'bitcoin:testnet4']) {
    testWidgets('shell Discover navigation remains accessible on $network', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final chain = await _chain(network);
      final shell = AppShellController();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BlockchainService>.value(value: chain),
            ChangeNotifierProvider<AppShellController>.value(value: shell),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AppShellScreen(walletPage: Text('Wallet fixture')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discover').last);
      await tester.pumpAndSettle();
      expect(shell.currentTab, AppShellTab.discover);
      expect(
        find.byKey(const ValueKey('discover-search-field')),
        findsOneWidget,
      );
      expect(
        find.text('This feature is not available for Bitcoin yet.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      chain.dispose();
      shell.dispose();
    });
  }

  for (final network in [
    'bitcoin:mainnet',
    'bitcoin:testnet4',
    'evm:1',
    'evm:56',
    'evm:137',
    'evm:8453',
    'evm:42161',
    'solana:mainnet-beta',
    'tron:mainnet',
  ]) {
    testWidgets(
      'Discover opens, browses and survives network switching on $network',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final chain = await _chain(network);
        final shell = AppShellController()..selectTab(AppShellTab.discover);
        final manager = DiscoverTabManager(
          catalogService: FakeDiscoverCatalogService(
            snapshot: DiscoverCatalogSnapshot(
              dapps: const [],
              fetchedAt: DateTime.now().toUtc(),
            ),
          ),
          permissionService: DappPermissionService(),
          storage: DiscoverTabStorage(secureStore: MemoryStore()),
        );
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<BlockchainService>.value(value: chain),
              ChangeNotifierProvider<AppShellController>.value(value: shell),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: DiscoverScreen(
                tabManager: manager,
                walletService: FakeWalletService(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final search = find.byKey(const ValueKey('discover-search-field'));
        expect(search, findsOneWidget);
        await tester.enterText(search, 'https://example.com/browse');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.byType(DiscoverBrowserView), findsOneWidget);
        expect(
          find.byKey(const ValueKey('test-native-web-surface')),
          findsOneWidget,
        );
        expect(
          manager.activeTab.sessionController.currentUri?.host,
          'example.com',
        );
        chain.setActiveNetworkKey(
          network.startsWith('bitcoin:') ? 'evm:1' : 'bitcoin:mainnet',
        );
        await tester.pumpAndSettle();
        expect(
          manager.activeTab.sessionController.viewState,
          DiscoverViewState.browser,
        );
        expect(find.byType(DiscoverBrowserView), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close_rounded).first);
        await tester.pumpAndSettle();
        expect(search, findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        chain.dispose();
        shell.dispose();
      },
    );
  }

  for (final network in ['bitcoin:mainnet', 'bitcoin:testnet4']) {
    testWidgets(
      '$network rejects unsupported provider requests without approval or signing',
      (tester) async {
        final chain = await _chain(network);
        late BuildContext context;
        await tester.pumpWidget(
          ChangeNotifierProvider<BlockchainService>.value(
            value: chain,
            child: MaterialApp(
              home: Builder(
                builder: (value) {
                  context = value;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        final controller = BrowserSessionController(
          catalogService: FakeDiscoverCatalogService(
            snapshot: DiscoverCatalogSnapshot(
              dapps: const [],
              fetchedAt: DateTime.now().toUtc(),
            ),
          ),
        );
        controller.openManualInput('https://example.com');
        final wallet = FakeWalletService();
        var approvals = 0;
        final bridge = DappProviderBridge(
          sessionController: controller,
          permissionService: FakeDappPermissionService(),
          walletService: wallet,
          approvalHandler: (_, _) async {
            approvals++;
            return true;
          },
        );
        for (final method in [
          'bitcoin_signPsbt',
          'btc_signTransaction',
          'eth_requestAccounts',
          'personal_sign',
          'eth_sendTransaction',
          'solana_signTransaction',
          'tron_signTransaction',
        ]) {
          final response = await bridge.handleRequest(
            context: context,
            origin: 'https://example.com',
            payload: {'method': method, 'params': []},
            evaluateJavaScript: (_) async =>
                fail('Unsupported request injected wallet state'),
          );
          expect(response['error']['code'], 4200);
          expect(response['error']['message'], contains('Bitcoin'));
        }
        expect(approvals, 0);
        expect(wallet.lastSignedMessage, isNull);
        expect(wallet.lastTransactionTo, isNull);
        expect(controller.viewState, DiscoverViewState.browser);
        controller.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        chain.dispose();
      },
    );
  }
}
