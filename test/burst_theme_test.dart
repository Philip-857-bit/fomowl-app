import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_api_client.dart';
import 'package:fomowl_wallet/features/burst/burst_home_components.dart';
import 'package:fomowl_wallet/features/burst/burst_join_screen.dart';
import 'package:fomowl_wallet/features/burst/burst_native_screen.dart';
import 'package:fomowl_wallet/features/burst/burst_theme.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/theme/theme_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

class _Chain extends ChangeNotifier implements BlockchainService {
  String key = 'evm:56';
  @override
  String get activeNetworkKey => key;
  void select(String value) {
    key = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ClassicTheme extends ChangeNotifier implements ThemeController {
  @override
  bool get isClassic => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnavailableChain extends ChangeNotifier implements BlockchainService {
  EvmChain? selected;
  @override
  String get activeNetworkKey => 'evm:1';
  @override
  String get activeNetworkName => 'Ethereum';
  @override
  List<EvmChain> get allChains => BlockchainService.builtInChains;
  @override
  void setActiveChain(EvmChain chain) {
    selected = chain;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'unsupported network shows available chains before authentication',
    (tester) async {
      final chain = _UnavailableChain();
      await tester.pumpWidget(
        ChangeNotifierProvider<BlockchainService>.value(
          value: chain,
          child: MaterialApp(
            home: BurstNativeScreen(
              networksLoader: () async => {
                'supportedChains': [
                  {
                    'chainId': 56,
                    'name': 'BNB Smart Chain',
                    'networkKey': 'evm:56',
                  },
                ],
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Burst is coming soon to Ethereum.'), findsOneWidget);
      expect(find.text('BNB Smart Chain'), findsOneWidget);
      expect(find.text('Use this wallet for Burst'), findsNothing);
      await tester.tap(find.text('BNB Smart Chain'));
      expect(chain.selected?.chainId, 56);
      await tester.pumpWidget(const SizedBox());
      chain.dispose();
    },
  );

  testWidgets(
    'Two-Tier Theme: Tier 1 invariant Electric Red and Tier 2 dynamic chain accent',
    (tester) async {
      final chain = _Chain();
      await tester.pumpWidget(
        ChangeNotifierProvider<BlockchainService>.value(
          value: chain,
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  BurstPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('Burst route')),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final routeElement = tester.element(find.text('Burst route'));
      Color primary() => Theme.of(routeElement).colorScheme.primary;
      // Tier 1: Invariant Electric Red regardless of network
      expect(primary(), const Color(0xffea2a33));
      expect(burstAccent(routeElement), const Color(0xffea2a33));
      expect(Theme.of(routeElement).colorScheme.onSecondary, Colors.white);
      // Tier 2: Dynamic chain accent matches BSC
      expect(burstChainAccent(routeElement), const Color(0xfff3ba2f));

      chain.select('evm:8453');
      await tester.pump();
      final updatedElement = tester.element(find.text('Burst route'));
      // Tier 1 remains Electric Red on Base
      expect(primary(), const Color(0xffea2a33));
      expect(burstAccent(updatedElement), const Color(0xffea2a33));
      // Tier 2 updates dynamically to Base blue
      expect(burstChainAccent(updatedElement), const Color(0xff0052ff));
    },
  );

  testWidgets('Burst actions use invariant Electric Red across chains', (
    tester,
  ) async {
    final chain = _Chain();
    final client = MockClient((_) async => http.Response('{}', 200));
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<BlockchainService>.value(
        value: chain,
        child: MaterialApp(
          home: BurstJoinScreen(
            api: api,
            walletAddress: '0x1111111111111111111111111111111111111111',
            chainId: 56,
          ),
        ),
      ),
    );
    ButtonStyle? style() => tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Join Burst'))
        .style;
    // On BSC: invariant Electric Red
    expect(style()!.backgroundColor!.resolve({}), const Color(0xffea2a33));
    expect(style()!.foregroundColor!.resolve({}), Colors.white);

    chain.select('evm:8453');
    await tester.pump();
    // On Base: still invariant Electric Red
    expect(style()!.backgroundColor!.resolve({}), const Color(0xffea2a33));
    expect(style()!.foregroundColor!.resolve({}), Colors.white);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BurstHomeAction(
            iconAsset: 'assets/burst/create_icon.png',
            title: 'Start Burst',
            subtitle: 'Start a new Burst',
            onTap: null,
          ),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.color, const Color(0xffea2a33));
    client.close();
  });

  testWidgets('Classic keeps Burst red on an adaptive network', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BlockchainService>.value(value: _Chain()),
          ChangeNotifierProvider<ThemeController>.value(value: _ClassicTheme()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: BurstHomeAction(
              iconAsset: 'assets/burst/create_icon.png',
              title: 'Start Burst',
              subtitle: 'Start a new Burst',
              onTap: null,
            ),
          ),
        ),
      ),
    );
    expect(
      tester.widget<Image>(find.byType(Image)).color,
      const Color(0xffea2a33),
    );
  });
}
