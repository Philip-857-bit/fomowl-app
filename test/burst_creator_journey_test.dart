import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_api_client.dart';
import 'package:fomowl_wallet/features/burst/burst_create_screen.dart';
import 'package:fomowl_wallet/features/burst/burst_draft_store.dart';
import 'package:fomowl_wallet/features/burst/burst_prepared_campaign.dart';
import 'package:fomowl_wallet/features/burst/burst_review_screen.dart';
import 'package:fomowl_wallet/features/burst/burst_transaction_executor.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/nft_service.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'burst_draft_store_test.dart' show MemoryStorage;
import 'burst_creation_fixture.dart';

class TestJournal implements BurstSubmissionJournal {
  final entries = <String, Map<String, String>>{};
  @override
  Future<void> clear(String reference) async => entries.remove(reference);
  @override
  Future<Map<String, String>?> read(String reference) async =>
      entries[reference];
  @override
  Future<void> write(String reference, Map<String, String> entry) async {
    entries[reference] = entry;
  }
}

class EmptyAddressNativeChain extends BlockchainService {
  @override
  List<Token> get tokens => [activeNativeToken.copyWith(contractAddress: '')];
}

class AddressedNativeChain extends BlockchainService {
  @override
  List<Token> get tokens => [
    activeNativeToken.copyWith(
      contractAddress: '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
    ),
  ];
}

class SwitchableNativeChain extends EmptyAddressNativeChain {
  var switched = false;
  @override
  EvmChain get activeChain => BlockchainService.builtInChains[switched ? 1 : 0];
}

void main() {
  testWidgets('back from success returns a completed result', (tester) async {
    final transaction = {
      'reference': 'confirmed',
      'operation': 'create',
      'chainId': 56,
      'toAddress': testBurstFactory,
      'valueBaseUnits': '0',
      'calldata': '0xa4be8afd',
      'expiresAt': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .toIso8601String(),
    };
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'status': 'confirmed',
          'walletAddress': testBurstWallet,
          'campaignId': 'campaign',
          'transaction': transaction,
          'transactionHash': '0x${'ab' * 32}',
        }),
        200,
      ),
    );
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    final executor = BurstTransactionExecutor(
      api: api,
      journal: TestJournal(),
      wallet: testBurstWallet,
      chainId: 56,
      isCurrent: () async => true,
      approve: (_) async => true,
      broadcast: (_) async => '0x${'ab' * 32}',
    );
    bool? result;
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => BurstReviewScreen(
                    prepared: {
                      'campaign': {
                        'id': 'campaign',
                        'assetKind': 'native',
                        'assetSymbol': 'BNB',
                      },
                      'transactions': [transaction],
                      'joinCode': 'ABCDE-FGHIJ',
                    },
                    executor: executor,
                    nativeSymbol: 'BNB',
                    onCompleted: () async {
                      completions++;
                    },
                  ),
                ),
              );
            },
            child: const Text('Open review'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Create Burst'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Create Burst'));
    await tester.tap(find.text('Create Burst'));
    await tester.pumpAndSettle();
    expect(completions, 1);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('View My Burst'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(result, isFalse);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });

  testWidgets('a network switch during prepare clears the original draft', (
    tester,
  ) async {
    final chain = SwitchableNativeChain();
    final originalChain = chain.activeChain.chainId;
    final store = BurstDraftStore(storage: MemoryStorage());
    final client = MockClient((_) async {
      chain.switched = true;
      return http.Response('{"message":"Change the Burst name."}', 400);
    });
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
          home: BurstCreateScreen(
            api: api,
            wallet: testBurstWallet,
            profileId: 'profile',
            store: store,
            config: {
              'chainId': originalChain,
              'supportedAssetKinds': ['native'],
              'maxParticipants': 500,
              'gaslessClaimsEnabled': true,
            },
            onPrepared: (_) async {},
          ),
        ),
      ),
    );
    Finder field(String label) => find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          (widget.key == ValueKey(label) ||
              widget.decoration?.labelText == label),
    );
    await tester.enterText(field('Burst name'), 'Community');
    await tester.enterText(field('Distribution amount'), '1');
    await tester.enterText(field('Maximum participants'), '2');
    await tester.scrollUntilVisible(
      find.text('Review Burst'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Review Burst'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review Burst'));
    await tester.pumpAndSettle();
    expect(chain.switched, isTrue);
    expect(await store.read('profile', testBurstWallet, originalChain), isNull);
    expect(
      await store.read('profile', testBurstWallet, chain.activeChain.chainId),
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    client.close();
  });
  testWidgets('network change stops creation before saving or requesting', (
    tester,
  ) async {
    final chain = EmptyAddressNativeChain();
    final storage = MemoryStorage();
    final store = BurstDraftStore(storage: storage);
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    });
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
          home: BurstCreateScreen(
            api: api,
            wallet: testBurstWallet,
            profileId: 'profile',
            store: store,
            config: {
              'chainId': chain.activeChain.chainId + 1,
              'gaslessClaimsEnabled': true,
            },
            onPrepared: (_) async {},
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Review Burst'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Review Burst'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review Burst'));
    await tester.pumpAndSettle();
    expect(find.textContaining('The network changed.'), findsOneWidget);
    expect(requests, 0);
    expect(
      await store.read('profile', testBurstWallet, chain.activeChain.chainId),
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    client.close();
  });
  testWidgets('gallery selections prepare an ERC-1155 Burst', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chain = EmptyAddressNativeChain();
    NftAsset asset(String id) => NftAsset(
      name: 'NFT $id',
      collection: 'Collection',
      description: '',
      count: 1,
      chainName: chain.activeChain.name,
      chainId: chain.activeChain.chainId,
      imageUrl: '',
      contractAddress: testBurstWallet,
      tokenId: id,
      tokenType: 'ERC1155',
      isProjectNft: false,
    );
    Map<String, dynamic>? sentDraft;
    var reviewed = false;
    final client = MockClient((request) async {
      sentDraft = jsonDecode(request.body) as Map<String, dynamic>;
      final fixture = burstFixture(sentDraft!);
      return http.Response(
        jsonEncode({
          'campaign': {
            ...sentDraft!,
            'amountPerParticipantBaseUnits': null,
            'id': 'campaign',
            'campaignId': fixture['campaignId'],
            'platformFeeBaseUnits': '0',
            'gasSponsorshipFeeBaseUnits': '0',
          },
          'transactions': fixture['transactions'],
          'joinCode': 'ABCDE-FGHIJ',
        }),
        201,
      );
    });
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
          home: BurstCreateScreen(
            api: api,
            wallet: testBurstWallet,
            profileId: 'profile',
            store: BurstDraftStore(storage: MemoryStorage()),
            config: const {
              'supportedAssetKinds': ['erc1155'],
              'maxParticipants': 500,
              'gaslessClaimsEnabled': true,
              'factoryAddress': testBurstFactory,
              'proxyInitCodeHash': testBurstInitHash,
            },
            loadNfts:
                ({
                  required chainId,
                  required chainName,
                  required walletAddress,
                }) async => [asset('1'), asset('2')],
            onPrepared: (_) async {
              reviewed = true;
            },
          ),
        ),
      ),
    );
    Finder field(String label) => find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          (widget.key == ValueKey(label) ||
              widget.decoration?.labelText == label),
    );
    await tester.tap(find.text('NFT Burst'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Burst name'), 'NFT drop');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Select NFTs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select NFTs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NFT 1'));
    await tester.tap(find.text('NFT 2'));
    await tester.tap(find.text('Confirm selection'));
    await tester.pumpAndSettle();
    expect(find.text('2 allocations selected'), findsOneWidget);
    await tester.ensureVisible(field('Maximum participants'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Maximum participants'), '2');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Review Burst'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review Burst'));
    await tester.pumpAndSettle();
    expect(reviewed, isTrue);
    expect(sentDraft!['assetKind'], 'erc1155');
    expect(
      (sentDraft!['nftAllocations'] as List)
          .map((entry) => entry['tokenId'])
          .toSet(),
      {'1', '2'},
    );
    await tester.pumpWidget(const SizedBox());
    client.close();
    chain.dispose();
  });

  testWidgets('creation form is usable on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chain = EmptyAddressNativeChain();
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
          home: BurstCreateScreen(
            api: api,
            wallet: testBurstWallet,
            profileId: 'profile',
            store: BurstDraftStore(storage: MemoryStorage()),
            config: const {
              'supportedAssetKinds': ['native'],
              'maxParticipants': 500,
              'gaslessClaimsEnabled': true,
            },
            onPrepared: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Review Burst'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Review Burst'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    client.close();
    chain.dispose();
  });

  testWidgets(
    'NFT creation confirms approval and creation before depositing, and resumes a pending deposit',
    (tester) async {
      final draft = <String, dynamic>{
        'chainId': 56,
        'title': 'NFT Burst',
        'assetKind': 'erc721',
        'assetAddress': testBurstWallet,
        'assetSymbol': 'NFT',
        'assetDecimals': 0,
        'totalAmountBaseUnits': '0',
        'amountPerParticipantBaseUnits': '0',
        'maxParticipants': 1,
        'startTime': 100,
        'endTime': 200,
        'nftAllocations': [
          {'tokenId': '17', 'amount': '1'},
        ],
      };
      final fixture = burstFixture(draft);
      final plans = (fixture['transactions'] as List<Map<String, dynamic>>);
      final prepared = <String, dynamic>{
        'campaign': {
          ...draft,
          'amountPerParticipantBaseUnits': null,
          'id': 'campaign',
          'campaignId': fixture['campaignId'],
          'platformFeeBaseUnits': '0',
          'gasSponsorshipFeeBaseUnits': '0',
        },
        'transactions': plans,
        'joinCode': 'ABCDE-FGHIJ',
      };
      BurstPreparedCampaign.parse(
        prepared,
        draft,
        factoryAddress: testBurstFactory,
        wallet: testBurstWallet,
        proxyInitCodeHash: testBurstInitHash,
      );
      final statuses = <String, String>{};
      final hashes = <String, String>{};
      final sent = <String>[];
      var depositChecks = 0;
      final client = MockClient((request) async {
        final segments = request.url.pathSegments;
        if (segments.last == 'execution') {
          final reference = segments[segments.length - 2];
          final plan = plans.singleWhere(
            (item) => item['reference'] == reference,
          );
          final operation = plan['operation'] as String;
          return http.Response(
            jsonEncode({
              'walletAddress': testBurstWallet,
              'campaignId': 'campaign',
              'status': statuses[operation] ?? 'prepared',
              'transaction': plan,
              if (hashes[operation] != null)
                'transactionHash': hashes[operation],
            }),
            200,
          );
        }
        final operation = segments[segments.length - 2];
        if (segments.last == 'submit') {
          hashes[operation] =
              (jsonDecode(request.body) as Map)['transactionHash'] as String;
          statuses[operation] = 'submitted';
          return http.Response('{"status":"submitted"}', 202);
        }
        if (segments.last == 'confirm') {
          if (operation == 'push' && depositChecks++ == 0) {
            return http.Response('{"status":"pending_confirmations"}', 202);
          }
          statuses[operation] = 'confirmed';
          return http.Response('{"status":"confirmed"}', 200);
        }
        return http.Response('{}', 404);
      });
      final api = BurstApiClient(
        api: (path) => Uri.parse('https://example.test/api$path'),
        client: client,
        authorize: (request) async =>
            http.Response.fromStream(await client.send(request)),
      );
      final executor = BurstTransactionExecutor(
        api: api,
        journal: TestJournal(),
        wallet: testBurstWallet,
        chainId: 56,
        confirmPollAttempts: 1,
        isCurrent: () async => true,
        approve: (_) async => true,
        broadcast: (plan) async {
          sent.add(plan.operation);
          return '0x${(sent.length.toRadixString(16)).padLeft(64, '0')}';
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BurstReviewScreen(
            prepared: prepared,
            executor: executor,
            nativeSymbol: 'BNB',
          ),
        ),
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Create Burst'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create Burst'));
      await tester.pumpAndSettle();
      expect(sent, ['approve', 'create', 'push']);
      expect(find.text('Burst Created!'), findsNothing);
      expect(find.textContaining('transaction is pending'), findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Create Burst'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create Burst'));
      await tester.pumpAndSettle();
      expect(sent, ['approve', 'create', 'push']);
      expect(find.text('Burst Created!'), findsOneWidget);
      expect(find.text('ABCDE-FGHIJ'), findsOneWidget);
      expect(find.text('Share code'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      client.close();
    },
  );

  test(
    'upfront native cost keeps token distributions separate from native fees',
    () {
      final campaign = {
        'assetKind': 'erc20',
        'totalAmountBaseUnits': '1000000000000000000000',
        'platformFeeBaseUnits': '10000000000000000',
        'gasSponsorshipFeeBaseUnits': '20000000000000000',
      };
      expect(burstUpfrontNativeCost(campaign, 'BNB'), '0.03 BNB');
      expect(
        burstUpfrontNativeCost({
          ...campaign,
          'assetKind': 'native',
          'totalAmountBaseUnits': '1000000000000000000',
        }, 'BNB'),
        '1.03 BNB',
      );
      expect(
        burstUpfrontNativeCost({
          ...campaign,
          'platformFeeBaseUnits': 'invalid',
        }, 'BNB'),
        'Unavailable',
      );
    },
  );
  testWidgets(
    'creator prepares, reviews, signs once, and receives a join code',
    (tester) async {
      const wallet = '0x1111111111111111111111111111111111111111';
      const destination = '0x2222222222222222222222222222222222222222';
      final chain = AddressedNativeChain();
      final chainId = chain.activeChain.chainId;
      final symbol = chain.tokens.first.symbol;
      final storage = MemoryStorage();
      final store = BurstDraftStore(storage: storage);
      final journal = TestJournal();
      var broadcasts = 0;
      var viewRequested = false;
      Map<String, dynamic>? preparedTransaction;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/campaigns/prepare')) {
          final draft = jsonDecode(request.body) as Map<String, dynamic>;
          expect(draft['assetKind'], 'native');
          expect(draft['assetAddress'], isNull);
          final fixture = burstFixture(draft);
          preparedTransaction =
              (fixture['transactions'] as List<Map<String, dynamic>>).single;
          return http.Response(
            jsonEncode({
              'campaign': {
                ...draft,
                'id': 'campaign',
                'campaignId': fixture['campaignId'],
                'platformFeeBaseUnits': '0',
                'gasSponsorshipFeeBaseUnits': '0',
              },
              'transactions': [preparedTransaction],
              'joinCode': 'ABCDE-FGHIJ',
            }),
            201,
          );
        }
        if (path.endsWith('/execution')) {
          return http.Response(
            jsonEncode({
              'walletAddress': wallet,
              'campaignId': 'campaign',
              'status': 'prepared',
              'transaction': preparedTransaction,
            }),
            200,
          );
        }
        if (path.endsWith('/submit')) {
          return http.Response('{"status":"submitted"}', 202);
        }
        if (path.endsWith('/confirm')) {
          return http.Response('{"status":"confirmed"}', 200);
        }
        return http.Response('{}', 404);
      });
      final api = BurstApiClient(
        api: (path) => Uri.parse('https://example.test/api$path'),
        client: client,
        authorize: (request) async =>
            http.Response.fromStream(await client.send(request)),
      );
      final executor = BurstTransactionExecutor(
        api: api,
        journal: journal,
        wallet: wallet,
        chainId: chainId,
        isCurrent: () async => true,
        approve: (_) async => true,
        broadcast: (_) async {
          broadcasts++;
          return '0x${'ab' * 32}';
        },
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<BlockchainService>.value(
          value: chain,
          child: MaterialApp(
            home: Builder(
              builder: (context) => BurstCreateScreen(
                api: api,
                wallet: wallet,
                profileId: 'profile',
                store: store,
                config: const {
                  'supportedAssetKinds': ['native'],
                  'maxParticipants': 500,
                  'gaslessClaimsEnabled': true,
                  'factoryAddress': destination,
                },
                onPrepared: (prepared) async {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => BurstReviewScreen(
                        prepared: prepared,
                        executor: executor,
                        nativeSymbol: symbol,
                      ),
                    ),
                  );
                  viewRequested = result == true;
                },
              ),
            ),
          ),
        ),
      );
      Finder field(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.key == ValueKey(label) ||
                widget.decoration?.labelText == label),
      );
      await tester.enterText(field('Burst name'), 'Community');
      await tester.enterText(field('Distribution amount'), '1');
      await tester.enterText(field('Maximum participants'), '2');
      await tester.scrollUntilVisible(
        find.text('Review Burst'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.text('Review Burst'));
      await tester.pumpAndSettle();
      expect(find.text('0.5 $symbol'), findsOneWidget);
      await tester.tap(find.text('Review Burst'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm Burst'), findsOneWidget);
      expect(find.text('1 $symbol'), findsWidgets);
      expect(find.text('Total. Burst Amount + Fees'), findsOneWidget);
      expect(find.text('Upfront native cost'), findsNothing);
      expect(find.text('Starts'), findsNothing);
      expect(find.text('Claims end'), findsNothing);
      expect(await store.read('profile', wallet, chainId), isNotNull);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Create Burst'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create Burst'));
      await tester.pumpAndSettle();
      expect(find.text('ABCDE-FGHIJ'), findsOneWidget);
      expect(broadcasts, 1);
      await tester.ensureVisible(find.text('View My Burst'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View My Burst'));
      await tester.pumpAndSettle();
      expect(viewRequested, isTrue);
      await tester.pumpWidget(const SizedBox());
      client.close();
      chain.dispose();
    },
  );

  testWidgets(
    'validation errors unlock the draft but uncertain errors preserve it',
    (tester) async {
      const wallet = '0x1111111111111111111111111111111111111111';
      final chain = EmptyAddressNativeChain();
      final store = BurstDraftStore(storage: MemoryStorage());
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        return requests == 1
            ? http.Response('{"message":"Change the Burst name."}', 400)
            : http.Response('{"message":"Try again later."}', 503);
      });
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
            home: BurstCreateScreen(
              api: api,
              wallet: wallet,
              profileId: 'profile',
              store: store,
              config: const {
                'supportedAssetKinds': ['native'],
                'maxParticipants': 500,
                'gaslessClaimsEnabled': true,
              },
              onPrepared: (_) async {},
            ),
          ),
        ),
      );
      Finder field(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.key == ValueKey(label) ||
                widget.decoration?.labelText == label),
      );
      await tester.enterText(field('Burst name'), 'Community');
      await tester.enterText(field('Distribution amount'), '1');
      await tester.enterText(field('Maximum participants'), '2');
      await tester.scrollUntilVisible(
        find.text('Review Burst'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.text('Review Burst'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review Burst'));
      await tester.pumpAndSettle();
      expect(find.text('Change the Burst name.'), findsOneWidget);
      expect(
        await store.read('profile', wallet, chain.activeChain.chainId),
        isNull,
      );
      await tester.scrollUntilVisible(
        field('Burst name'),
        -250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.widget<TextField>(field('Burst name')).enabled, isTrue);
      await tester.enterText(field('Burst name'), 'Updated Community');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Review Burst'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.text('Review Burst'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review Burst'));
      await tester.pumpAndSettle();
      expect(find.text('Try again later.'), findsOneWidget);
      expect(
        await store.read('profile', wallet, chain.activeChain.chainId),
        isNotNull,
      );
      await tester.scrollUntilVisible(
        field('Burst name'),
        -250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.widget<TextField>(field('Burst name')).enabled, isFalse);
      await tester.pumpWidget(const SizedBox());
      client.close();
      chain.dispose();
    },
  );

  testWidgets(
    'does not prepare a campaign when the claim relayer is unavailable',
    (tester) async {
      var requests = 0;
      final chain = BlockchainService();
      final client = MockClient((request) async {
        requests++;
        return http.Response('{}', 200);
      });
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
            home: BurstCreateScreen(
              api: api,
              wallet: '0x1111111111111111111111111111111111111111',
              profileId: 'profile',
              store: BurstDraftStore(storage: MemoryStorage()),
              config: const {
                'supportedAssetKinds': ['native'],
                'maxParticipants': 500,
                'gaslessClaimsEnabled': false,
              },
              onPrepared: (_) async {},
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Review Burst'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.text('Review Burst'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review Burst'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('claims are currently unavailable'),
        findsOneWidget,
      );
      expect(requests, 0);
      await tester.pumpWidget(const SizedBox());
      client.close();
      chain.dispose();
    },
  );
}
