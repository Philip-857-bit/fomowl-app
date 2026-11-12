import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_api_client.dart';
import 'package:fomowl_wallet/features/burst/burst_create_screen.dart';
import 'package:fomowl_wallet/features/burst/burst_draft_store.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'burst_creator_journey_test.dart' show EmptyAddressNativeChain;
import 'burst_draft_store_test.dart' show MemoryStorage;
import 'burst_creation_fixture.dart';

class ChangedAssetChain extends EmptyAddressNativeChain {
  @override
  List<Token> get tokens => [
    activeNativeToken,
    const Token(
      symbol: 'TEST',
      name: 'Test',
      contractAddress: testBurstFactory,
      decimals: 6,
      balance: 1,
      valueUsd: 0,
      changePercent24h: 0,
    ),
  ];
}

void main() {
  Map<String, dynamic> preparedFor(Map<String, dynamic> request) {
    final fixture = burstFixture(request);
    return {
      'campaign': {
        ...request,
        'id': 'campaign',
        'campaignId': fixture['campaignId'],
        'platformFeeBaseUnits': '0',
        'gasSponsorshipFeeBaseUnits': '0',
      },
      'transactions': fixture['transactions'],
      'joinCode': 'ABCDE-FGHIJ',
    };
  }

  testWidgets('changed token decimals cannot reinterpret a saved amount', (
    tester,
  ) async {
    final chain = ChangedAssetChain();
    final request = <String, dynamic>{
      'chainId': chain.activeChain.chainId,
      'title': 'Saved',
      'description': '',
      'assetKind': 'erc20',
      'assetAddress': testBurstFactory,
      'assetSymbol': 'TEST',
      'assetDecimals': 18,
      'totalAmountBaseUnits': '1000000000000000000',
      'amountPerParticipantBaseUnits': '1000000000000000000',
      'maxParticipants': 1,
      'idempotencyKey': 'old-key-123',
    };
    final saved = <String, dynamic>{
      'request': request,
      'prepared': preparedFor(request),
    };
    final store = BurstDraftStore(storage: MemoryStorage());
    await store.write('p', testBurstWallet, chain.activeChain.chainId, saved);
    var sends = 0;
    final client = MockClient((_) async {
      sends++;
      return http.Response('{}', 200);
    });
    final api = BurstApiClient(
      api: (p) => Uri.parse('https://example.test/api$p'),
      client: client,
      authorize: (r) async => http.Response.fromStream(await client.send(r)),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<BlockchainService>.value(
        value: chain,
        child: MaterialApp(
          home: BurstCreateScreen(
            api: api,
            wallet: testBurstWallet,
            profileId: 'p',
            store: store,
            initialDraft: saved,
            config: {
              'chainId': chain.activeChain.chainId,
              'gaslessClaimsEnabled': true,
              'supportedAssetKinds': ['native', 'erc20'],
              'maxParticipants': 500,
              'factoryAddress': testBurstFactory,
              'proxyInitCodeHash': testBurstInitHash,
            },
            onPrepared: (_) async {},
          ),
        ),
      ),
    );
    expect(
      find.text(
        'The saved asset is unavailable. Select another asset to continue.',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Review Burst'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Review Burst'));
    await tester.pumpAndSettle();
    expect(
      find.text('The selected asset is no longer available.'),
      findsOneWidget,
    );
    expect(sends, 0);
    expect(
      await store.read('p', testBurstWallet, chain.activeChain.chainId),
      saved,
    );
    client.close();
    await tester.pumpWidget(const SizedBox());
    chain.dispose();
  });

  testWidgets('restored uncertain edits retry exactly after app restart', (
    tester,
  ) async {
    final chain = EmptyAddressNativeChain();
    final original = <String, dynamic>{
      'chainId': chain.activeChain.chainId,
      'title': 'Original',
      'description': 'Saved',
      'assetKind': 'native',
      'assetSymbol': chain.activeNativeToken.symbol,
      'assetDecimals': 18,
      'totalAmountBaseUnits': '1000000000000000000',
      'amountPerParticipantBaseUnits': '1000000000000000000',
      'maxParticipants': 1,
      'idempotencyKey': 'old-key-123',
    };
    final next = {
      ...original,
      'title': 'Pending edit',
      'idempotencyKey': 'retry-key-123',
      'previousIdempotencyKey': 'old-key-123',
    };
    final saved = <String, dynamic>{
      'request': original,
      'prepared': preparedFor(original),
      'pendingUpdate': next,
    };
    final store = BurstDraftStore(storage: MemoryStorage());
    await store.write('p', testBurstWallet, chain.activeChain.chainId, saved);
    Map<String, dynamic>? sent;
    final client = MockClient((r) async {
      sent = jsonDecode(r.body) as Map<String, dynamic>;
      return http.Response(jsonEncode(preparedFor(sent!)), 200);
    });
    final api = BurstApiClient(
      api: (p) => Uri.parse('https://example.test/api$p'),
      client: client,
      authorize: (r) async => http.Response.fromStream(await client.send(r)),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<BlockchainService>.value(
        value: chain,
        child: MaterialApp(
          home: BurstCreateScreen(
            api: api,
            wallet: testBurstWallet,
            profileId: 'p',
            store: store,
            initialDraft: saved,
            config: {
              'chainId': chain.activeChain.chainId,
              'gaslessClaimsEnabled': true,
              'factoryAddress': testBurstFactory,
              'proxyInitCodeHash': testBurstInitHash,
            },
            onPrepared: (_) async {},
          ),
        ),
      ),
    );
    expect(find.text('Pending edit'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('Burst name')))
          .enabled,
      isFalse,
    );
    await tester.scrollUntilVisible(
      find.text('Review Burst'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Review Burst'));
    await tester.pumpAndSettle();
    expect(sent, next);
    expect(
      (await store.read(
        'p',
        testBurstWallet,
        chain.activeChain.chainId,
      ))!.containsKey('pendingUpdate'),
      isFalse,
    );
    client.close();
    await tester.pumpWidget(const SizedBox());
    chain.dispose();
  });

  testWidgets(
    'reopens a saved draft and submits edited fields with revision guard',
    (tester) async {
      final chain = EmptyAddressNativeChain();
      final request = <String, dynamic>{
        'chainId': chain.activeChain.chainId,
        'title': 'Original',
        'description': 'Saved description',
        'assetKind': 'native',
        'assetSymbol': chain.activeNativeToken.symbol,
        'assetDecimals': 18,
        'totalAmountBaseUnits': '1000000000000000000',
        'amountPerParticipantBaseUnits': '500000000000000000',
        'maxParticipants': 2,
        'idempotencyKey': 'original-key-123',
      };
      final saved = <String, dynamic>{
        'request': request,
        'prepared': preparedFor(request),
      };
      final store = BurstDraftStore(storage: MemoryStorage());
      await store.write(
        'profile',
        testBurstWallet,
        chain.activeChain.chainId,
        saved,
      );
      Map<String, dynamic>? sent;
      final client = MockClient((r) async {
        expect(r.method, 'PUT');
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(preparedFor(sent!)), 200);
      });
      final api = BurstApiClient(
        api: (p) => Uri.parse('https://example.test/api$p'),
        client: client,
        authorize: (r) async => http.Response.fromStream(await client.send(r)),
      );
      var reviews = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider<BlockchainService>.value(
          value: chain,
          child: MaterialApp(
            home: BurstCreateScreen(
              api: api,
              wallet: testBurstWallet,
              profileId: 'profile',
              store: store,
              initialDraft: saved,
              config: {
                'chainId': chain.activeChain.chainId,
                'supportedAssetKinds': ['native'],
                'maxParticipants': 500,
                'gaslessClaimsEnabled': true,
                'factoryAddress': testBurstFactory,
                'proxyInitCodeHash': testBurstInitHash,
              },
              onPrepared: (_) async {
                reviews++;
              },
            ),
          ),
        ),
      );
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Saved description'), findsOneWidget);
      final amount = tester.widget<TextField>(
        find.byKey(const ValueKey('Distribution amount')),
      );
      expect(amount.controller!.text, '1');
      await tester.enterText(
        find.byKey(const ValueKey('Burst name')),
        'Updated',
      );
      await tester.scrollUntilVisible(
        find.text('Review Burst'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Review Burst'));
      await tester.pumpAndSettle();
      expect(sent?['title'], 'Updated');
      expect(sent?['previousIdempotencyKey'], 'original-key-123');
      expect(sent?['idempotencyKey'], isNot('original-key-123'));
      expect(reviews, 1);
      client.close();
      await tester.pumpWidget(const SizedBox());
      chain.dispose();
    },
  );
}
