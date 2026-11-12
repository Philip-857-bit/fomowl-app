import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_api_client.dart';
import 'package:fomowl_wallet/features/burst/burst_join_screen.dart';
import 'package:fomowl_wallet/features/burst/burst_review_screen.dart';
import 'package:fomowl_wallet/features/burst/burst_theme.dart';
import 'package:fomowl_wallet/features/burst/burst_transaction_executor.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

class _AdversarialChainService extends ChangeNotifier
    implements BlockchainService {
  String _networkKey = 'evm:56';
  @override
  String get activeNetworkKey => _networkKey;

  void switchChain(String key) {
    _networkKey = key;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockJournal implements BurstSubmissionJournal {
  @override
  Future<void> clear(String reference) async {}
  @override
  Future<Map<String, String>?> read(String reference) async => null;
  @override
  Future<void> write(String reference, Map<String, String> entry) async {}
}

void main() {
  const electricRed = Color(0xffea2a33);

  final testNetworks = [
    {
      'name': 'BNB Smart Chain',
      'key': 'evm:56',
      'chainId': 56,
      'expectedAccent': const Color(0xfff3ba2f),
    },
    {
      'name': 'Base',
      'key': 'evm:8453',
      'chainId': 8453,
      'expectedAccent': const Color(0xff0052ff),
    },
    {
      'name': 'Arbitrum One',
      'key': 'evm:42161',
      'chainId': 42161,
      'expectedAccent': const Color(0xff28a0f0),
    },
    {
      'name': 'Asset Chain',
      'key': 'evm:42420',
      'chainId': 42420,
      'expectedAccent': const Color(0xff26c4e8),
    },
    {
      'name': 'Ethereum',
      'key': 'evm:1',
      'chainId': 1,
      'expectedAccent': const Color(0xff627eea),
    },
  ];

  final transport = MockClient((_) async => http.Response('{}', 200));
  final api = BurstApiClient(
    api: (path) => Uri.parse('https://example.test/api$path'),
    client: transport,
    authorize: (request) async =>
        http.Response.fromStream(await transport.send(request)),
  );
  final executor = BurstTransactionExecutor(
    api: api,
    journal: _MockJournal(),
    wallet: '0x1111111111111111111111111111111111111111',
    chainId: 56,
    isCurrent: () async => true,
    approve: (_) async => true,
    broadcast: (_) async => '0x${'ab' * 32}',
  );

  const samplePrepared = {
    'campaign': {
      'id': 'campaign-adv-123',
      'title': 'Adversarial Test Airdrop',
      'assetKind': 'native',
      'assetSymbol': 'TEST',
      'assetDecimals': 18,
      'totalAmountBaseUnits': '250000000000000000000',
      'chainId': 56,
      'maxParticipants': 20,
      'platformFeeBaseUnits': '4000000000000000',
      'gasSponsorshipFeeBaseUnits': '30000000000000',
    },
    'joinCode': 'ADV-BURST-777',
    'transactions': [],
    'nativePriceUsd': 300.0,
    'networkFeeUsd': 0.03,
    'networkFeeBaseUnits': '100000000000000',
  };

  group('Two-Tier Adaptive Theme Hierarchy Adversarial Verification', () {
    for (final net in testNetworks) {
      final name = net['name'] as String;
      final key = net['key'] as String;
      final expectedAccent = net['expectedAccent'] as Color;

      testWidgets('Network $name ($key): Theme tokens separation', (
        tester,
      ) async {
        final chainService = _AdversarialChainService()..switchChain(key);
        late BuildContext capturedContext;

        await tester.pumpWidget(
          ChangeNotifierProvider<BlockchainService>.value(
            value: chainService,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  capturedContext = context;
                  return Container();
                },
              ),
            ),
          ),
        );

        // Tier 1: Invariant Electric Red
        expect(
          burstPrimaryActionColor,
          electricRed,
          reason: 'burstPrimaryActionColor must be Electric Red #EA2A33',
        );
        expect(
          burstAccent(capturedContext),
          expectedAccent,
          reason: 'burstAccent must follow the chain accent on $name',
        );

        // Tier 2: Dynamic Chain Accent
        final chainAccent = burstChainAccent(capturedContext);
        expect(
          chainAccent,
          expectedAccent,
          reason: 'burstChainAccent for $name must match $expectedAccent',
        );
      });

      testWidgets(
        'Network $name ($key): BurstReviewSheet primary CTA and Total highlight follow the chain accent',
        (tester) async {
          final chainService = _AdversarialChainService()..switchChain(key);
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            ChangeNotifierProvider<BlockchainService>.value(
              value: chainService,
              child: MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (ctx) => ElevatedButton(
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: ctx,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => BurstReviewSheet(
                            prepared: samplePrepared,
                            executor: executor,
                            nativeSymbol: 'TEST',
                            chainName: name,
                          ),
                        );
                      },
                      child: const Text('Open Sheet'),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open Sheet'));
          await tester.pumpAndSettle();

          // 1. Primary CTA button ("Create Burst") MUST be Electric Red #EA2A33, NOT hijacked by chain accent
          final buttonWidget = tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Create Burst'),
          );
          final bgColor = buttonWidget.style?.backgroundColor?.resolve({});
          expect(
            bgColor,
            expectedAccent,
            reason: 'Create Burst button on $name must follow the chain accent',
          );

          // 2. Primary CTA ambient glow shadow MUST be red Color(0x4dea2a33)
          final glowFinder = find.byWidgetPredicate((w) {
            if (w is Container && w.decoration is BoxDecoration) {
              final shadows = (w.decoration as BoxDecoration).boxShadow;
              if (shadows != null && shadows.isNotEmpty) {
                return shadows.any(
                  (s) =>
                      s.color == expectedAccent.withValues(alpha: 0.30) &&
                      s.blurRadius == 30.0,
                );
              }
            }
            return false;
          });
          expect(
            glowFinder,
            findsOneWidget,
            reason: 'Ambient glow must be 30px blur Electric Red on $name',
          );

          // 3. Total amount highlight ("250 TEST") MUST be Electric Red #EA2A33
          final totalTextFinder = find.byWidgetPredicate((w) {
            if (w is Text && w.data != null && w.data!.contains('TEST')) {
              return w.style?.color == expectedAccent && w.style?.fontSize == 16;
            }
            return false;
          });
          expect(
            totalTextFinder,
            findsOneWidget,
            reason: 'Total highlight amount text must follow the chain accent on $name',
          );

          // Total includes distribution, platform fee, sponsorship, and network gas.
          expect(
            find.text(r'($75001.24)'),
            findsOneWidget,
            reason: 'Total USD must include every charged fee',
          );
          expect(
            find.text(r'($308.454)'),
            findsNothing,
            reason: 'Must NOT contain typographical transposition \$308.454',
          );

          // 5. Clean review sheet: obsolete scheduling and internal gas rows must be absent
          expect(find.text('Starts'), findsNothing);
          expect(find.text('Claims end'), findsNothing);
          expect(find.text('Gas sponsorship'), findsNothing);
          expect(find.text('Upfront native cost'), findsNothing);

          Navigator.of(tester.element(find.text('Confirm Burst'))).pop();
          await tester.pumpAndSettle();
        },
      );

      testWidgets(
        'Network $name ($key): BurstCreatedSuccessScreen "Share code" CTA follows the chain accent',
        (tester) async {
          final chainService = _AdversarialChainService()..switchChain(key);
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            ChangeNotifierProvider<BlockchainService>.value(
              value: chainService,
              child: MaterialApp(
                home: BurstCreatedSuccessScreen(
                  campaign: samplePrepared['campaign'] as Map<String, dynamic>,
                  joinCode: 'ADV-BURST-777',
                  nativeSymbol: 'TEST',
                  chainName: name,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // "Share code" button MUST be Electric Red #EA2A33
          final shareButton = tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Share code'),
          );
          final shareBgColor = shareButton.style?.backgroundColor?.resolve({});
          expect(
            shareBgColor,
            expectedAccent,
            reason: 'Share code CTA on $name must follow the chain accent',
          );

          // Join code text MUST be Electric Red
          final codeText = tester.widget<SelectableText>(
            find.byType(SelectableText),
          );
          expect(
            codeText.style?.color,
            expectedAccent,
            reason: 'Join code text on $name must follow the chain accent',
          );
        },
      );

      testWidgets(
        'Network $name ($key): BurstJoinScreen "Join Burst" CTA follows the chain accent',
        (tester) async {
          final chainService = _AdversarialChainService()..switchChain(key);

          await tester.pumpWidget(
            ChangeNotifierProvider<BlockchainService>.value(
              value: chainService,
              child: MaterialApp(
                home: BurstJoinScreen(
                  api: api,
                  walletAddress: '0x1111111111111111111111111111111111111111',
                  chainId: net['chainId'] as int,
                ),
              ),
            ),
          );

          final joinButton = tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Join Burst'),
          );
          final joinBgColor = joinButton.style?.backgroundColor?.resolve({});
          expect(
            joinBgColor,
            expectedAccent,
            reason: 'Join Burst CTA on $name must follow the chain accent',
          );
        },
      );
    }
  });
}
