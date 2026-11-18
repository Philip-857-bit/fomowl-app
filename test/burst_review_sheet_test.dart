import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_api_client.dart';
import 'package:fomowl_wallet/features/burst/burst_review_screen.dart';
import 'package:fomowl_wallet/features/burst/burst_transaction_executor.dart';
import 'package:fomowl_wallet/features/burst/burst_network_fee.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TestJournal implements BurstSubmissionJournal {
  @override
  Future<void> clear(String reference) async {}
  @override
  Future<Map<String, String>?> read(String reference) async => null;
  @override
  Future<void> write(String reference, Map<String, String> entry) async {}
}

void main() {
  final transport = MockClient((_) async => http.Response('{}', 200));
  final api = BurstApiClient(
    api: (path) => Uri.parse('https://example.test/api$path'),
    client: transport,
    authorize: (request) async =>
        http.Response.fromStream(await transport.send(request)),
  );
  final executor = BurstTransactionExecutor(
    api: api,
    journal: _TestJournal(),
    wallet: '0x1111111111111111111111111111111111111111',
    chainId: 56,
    isCurrent: () async => true,
    approve: (_) async => true,
    broadcast: (_) async => '0x${'ab' * 32}',
  );

  const samplePrepared = {
    'campaign': {
      'id': 'campaign-123',
      'title': 'Test Airdrop',
      'assetKind': 'native',
      'assetSymbol': 'BNB',
      'assetDecimals': 18,
      'totalAmountBaseUnits': '1000000000000000000',
      'chainId': 56,
      'maxParticipants': 10,
      'platformFeeBaseUnits': '5000000000000000',
      'gasSponsorshipFeeBaseUnits': '0',
    },
    'joinCode': 'TEST-CODE-1234',
    'transactions': [],
    'nativePriceUsd': 300.0,
    'networkFeeUsd': 0.03,
  };

  testWidgets('loads network fee and includes every native fee in total', (
    tester,
  ) async {
    final prepared = Map<String, dynamic>.from(samplePrepared)
      ..remove('networkFeeUsd');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BurstReviewSheet(
            prepared: prepared,
            executor: executor,
            nativeSymbol: 'BNB',
            loadNetworkFee: () async => BigInt.from(100000000000000),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(r'$0.03'), findsOneWidget);
    expect(find.text('1.0051 BNB'), findsOneWidget);
    expect(find.text(r'($301.53)'), findsOneWidget);
  });

  testWidgets('failed network estimate offers retry and recovers', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BurstReviewSheet(
            prepared: Map<String, dynamic>.from(samplePrepared)
              ..remove('networkFeeUsd'),
            executor: executor,
            nativeSymbol: 'BNB',
            loadNetworkFee: () async {
              if (attempts++ == 0) throw StateError('RPC unavailable');
              return BigInt.from(100000000000000);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to estimate network fee. Retry'), findsOneWidget);
    await tester.tap(find.text('Unable to estimate network fee. Retry'));
    await tester.pumpAndSettle();
    expect(find.text(r'$0.03'), findsOneWidget);
  });

  testWidgets('network fee remains visible without a USD price', (
    tester,
  ) async {
    final prepared = Map<String, dynamic>.from(samplePrepared)
      ..remove('networkFeeUsd')
      ..remove('nativePriceUsd');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BurstReviewSheet(
            prepared: prepared,
            executor: executor,
            nativeSymbol: 'BNB',
            loadNetworkFee: () async => BigInt.from(100000000000000),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0.0001 BNB'), findsOneWidget);
    expect(find.text('1.0051 BNB'), findsOneWidget);
  });

  testWidgets(
    'insufficient BNB explains unavailable fee and blocks creation until retry succeeds',
    (tester) async {
      var funded = false;
      final prepared = Map<String, dynamic>.from(samplePrepared);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BurstReviewSheet(
              prepared: prepared,
              executor: executor,
              nativeSymbol: 'BNB',
              loadNetworkFee: () async {
                if (!funded) throw const BurstInsufficientNativeBalance();
                return BigInt.from(100000000000000);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Insufficient BNB'), findsOneWidget);
      expect(
        find.text('Add BNB to cover the Burst amount and fees, then retry.'),
        findsOneWidget,
      );
      expect(find.text('Unable to estimate network fee. Retry'), findsNothing);
      expect(find.text(r'$0.03'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Create Burst'),
            )
            .onPressed,
        isNull,
      );
      funded = true;
      await tester.tap(find.text('Retry network fee'));
      await tester.pumpAndSettle();
      expect(find.text('Insufficient BNB'), findsNothing);
      expect(find.text(r'$0.03'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Create Burst'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('BurstReviewSheet renders matching Figma node 5888:8978 specs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => BurstReviewSheet(
                        prepared: samplePrepared,
                        executor: executor,
                        nativeSymbol: 'BNB',
                        chainName: 'BNB Smart Chain',
                      ),
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              );
            },
          ),
        ),
      ),
    );

    // Open sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // 1. Confirm title is present, AppBar is absent
    expect(find.text('Confirm Burst'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);

    // 2. Pull handle indicator is rendered
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.maxWidth == 36 &&
            w.constraints?.maxHeight == 4,
      ),
      findsOneWidget,
    );

    // 3. Decorated modal container has pitch black background and 8px top radius
    final sheetContainer = tester.widget<Container>(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == const Color(0xff000000) &&
            (w.decoration as BoxDecoration).borderRadius ==
                const BorderRadius.vertical(top: Radius.circular(8)),
      ),
    );
    expect(sheetContainer, isNotNull);

    // 4. Field inventory verification: obsolete fields removed
    expect(find.text('Starts'), findsNothing);
    expect(find.text('Claims end'), findsNothing);
    expect(find.text('Gas sponsorship'), findsNothing);
    expect(find.text('Upfront native cost'), findsNothing);

    // 5. Total. Burst Amount + Fees row present with Electric Red highlight
    expect(find.text('Total. Burst Amount + Fees'), findsOneWidget);
    expect(find.text(r'($301.53)'), findsOneWidget);

    // 6. Primary CTA uses the adaptive accent and its matching ambient glow
    final ctaText = find.text('Create Burst');
    expect(ctaText, findsOneWidget);
    final ctaButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create Burst'),
    );
    final ctaColor = ctaButton.style?.backgroundColor?.resolve({});
    expect(ctaColor, isNotNull);

    final glowDecorated = find.byWidgetPredicate((w) {
      if (w is Container && w.decoration is BoxDecoration) {
        final box = w.decoration as BoxDecoration;
        final shadows = box.boxShadow;
        if (shadows != null && shadows.isNotEmpty) {
          return shadows.any(
            (s) =>
                s.color == ctaColor!.withValues(alpha: 0.30) &&
                s.blurRadius == 30.0 &&
                s.spreadRadius == 0.0,
          );
        }
      }
      return false;
    });
    expect(glowDecorated, findsOneWidget);

    // Dismiss sheet
    Navigator.of(tester.element(find.text('Confirm Burst'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Confirm Burst'), findsNothing);
  });

  testWidgets(
    'BurstCreatedSuccessScreen renders celebration route matching Figma node 5888:9424',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var viewRequested = false;

      await tester.pumpWidget(
        MaterialApp(
          home: BurstCreatedSuccessScreen(
            campaign: const {
              'title': 'Test Airdrop',
              'assetKind': 'native',
              'assetSymbol': 'BNB',
              'totalAmountBaseUnits': '1000000000000000000',
              'maxParticipants': 10,
            },
            joinCode: 'TEST-CODE-9999',
            nativeSymbol: 'BNB',
            onViewBurst: () => viewRequested = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check celebration elements
      expect(find.text('Burst Created!'), findsOneWidget);
      expect(find.text('TEST-CODE-9999'), findsOneWidget);
      expect(find.text('Share code'), findsOneWidget);
      expect(find.text('View My Burst'), findsOneWidget);

      // Tap View My Burst
      await tester.tap(find.text('View My Burst'));
      await tester.pumpAndSettle();
      expect(viewRequested, isTrue);
    },
  );

  testWidgets(
    'failed fee estimation disables Create Burst until retry succeeds',
    (tester) async {
      var shouldFail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BurstReviewSheet(
              prepared: Map<String, dynamic>.from(samplePrepared)
                ..remove('networkFeeUsd'),
              executor: executor,
              nativeSymbol: 'BNB',
              loadNetworkFee: () async {
                if (shouldFail) throw StateError('RPC unavailable');
                return BigInt.from(100000000000000);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Create Burst'),
            )
            .onPressed,
        isNull,
      );

      shouldFail = false;
      await tester.tap(find.text('Unable to estimate network fee. Retry'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Create Burst'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'insufficient balance still displays overridden network fee estimate',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BurstReviewSheet(
              prepared: Map<String, dynamic>.from(samplePrepared)
                ..remove('networkFeeUsd'),
              executor: executor,
              nativeSymbol: 'BNB',
              loadNetworkFee: () async => throw BurstInsufficientNativeBalance(
                estimatedFeeWei: BigInt.from(100000000000000),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(r'$0.03'), findsOneWidget);
      expect(find.text('1.0051 BNB'), findsOneWidget);
      expect(
        find.text('Add BNB to cover the Burst amount and fees, then retry.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Create Burst'),
            )
            .onPressed,
        isNull,
      );
    },
  );
}
