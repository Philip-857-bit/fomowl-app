import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/app/app_routes.dart';
import 'package:fomowl_wallet/features/mini_apps/mini_app_host_screen.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/runtime_config_service.dart';

// Model stale persisted selections too: a disabled family must not gain access
// merely because its network key is still Bitcoin mainnet.
class _PayChain extends BlockchainService {
  _PayChain({
    this.network = 'bitcoin:mainnet',
    this.available = true,
    this.supported = true,
    this.enabled = true,
  });
  final String network;
  final bool available;
  final bool supported;
  final bool enabled;
  @override
  String get activeNetworkKey => network;
  @override
  Set<ChainFamily> get enabledFamilies => {
    ChainFamily.evm,
    if (enabled) ChainFamily.bitcoin,
  };
  @override
  Set<ChainFamily> get activeWalletSupportedFamilies => {
    ChainFamily.evm,
    if (supported) ChainFamily.bitcoin,
  };
  @override
  bool isBitcoinNetworkAvailable(String key) => available;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'owllet.runtime_policy.last_good.v1': jsonEncode({
        ...const RuntimePolicySnapshot(cashOutEnabled: false).toJson(),
        'persistedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    });
    await RuntimeConfigService.instance.hydrate();
  });
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

  Future<void> open(
    WidgetTester tester,
    _PayChain chain, {
    String route = '/owllet-pay',
    Object? arguments,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<BlockchainService>.value(
        value: chain,
        child: MaterialApp(
          routes: buildAppRoutes(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(route, arguments: arguments),
              child: const Text('Open Pay'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Pay'));
    await tester.pumpAndSettle();
  }

  for (final route in ['/owllet-pay', '/cash-in', '/mini-app-host']) {
    testWidgets('eligible Bitcoin mainnet reaches OwlletPay through $route', (
      tester,
    ) async {
      final chain = _PayChain();
      await open(tester, chain, route: route);
      // No hosted URL is configured in this test build. Reaching this message
      // proves the real host ran; no native WebView or live payment is needed.
      expect(find.text('OwlletPay coming soon'), findsOneWidget);
      expect(
        find.text('This feature is not available for Bitcoin yet.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      chain.dispose();
    });
  }

  for (final entry in <String, _PayChain Function()>{
    'Testnet4': () => _PayChain(network: 'bitcoin:testnet4'),
    'unavailable backend/runtime': () => _PayChain(available: false),
    'unsupported private-key wallet': () => _PayChain(supported: false),
    'disabled user preference': () => _PayChain(enabled: false),
  }.entries) {
    testWidgets('OwlletPay blocks ${entry.key}', (tester) async {
      final chain = entry.value();
      await open(tester, chain);
      expect(
        find.text('This feature is not available for Bitcoin yet.'),
        findsOneWidget,
      );
      expect(find.text('OwlletPay coming soon'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      chain.dispose();
    });
  }

  testWidgets('other mini apps stay blocked for Bitcoin', (tester) async {
    final chain = _PayChain();
    await open(tester, chain, route: '/mini-app-host', arguments: 'affiliate');
    expect(
      find.text('This feature is not available for Bitcoin yet.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    chain.dispose();
  });

  testWidgets('runtime cash-out disable still blocks the withdrawal route', (
    tester,
  ) async {
    final chain = _PayChain();
    await open(
      tester,
      chain,
      arguments: const MiniAppHostArguments(
        miniAppId: 'owllet_pay',
        initialUrl: 'https://owlletpaystaging.owlletapp.com/withdraw',
      ),
    );
    expect(find.text('OwlletPay withdrawals unavailable'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    chain.dispose();
  });
}
