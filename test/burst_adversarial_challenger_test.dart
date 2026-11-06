import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_native_screen.dart';
import 'package:fomowl_wallet/features/mini_apps/burst_account_session.dart';
import 'package:fomowl_wallet/features/mini_apps/burst_sign_in.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/widgets/bottom_navigation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

class _MockBlockchainService extends ChangeNotifier
    implements BlockchainService {
  _MockBlockchainService({
    this.networkKey = 'evm:1',
    this.networkName = 'Ethereum',
  });

  final String networkKey;
  final String networkName;
  EvmChain? selectedChain;

  @override
  String get activeNetworkKey => networkKey;

  @override
  String get activeNetworkName => networkName;

  @override
  List<EvmChain> get allChains => BlockchainService.builtInChains;

  @override
  void setActiveChain(EvmChain chain) {
    selectedChain = chain;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ChallengerPopObserver extends NavigatorObserver {
  bool didPopRoute = false;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    didPopRoute = true;
    super.didPop(route, previousRoute);
  }
}

void main() {
  const address = '0x1111111111111111111111111111111111111111';
  const challengeId = '11111111-2222-4333-8444-555555555555';
  final futureExpiry = DateTime.now()
      .toUtc()
      .add(const Duration(hours: 1))
      .toIso8601String();
  final pastExpiry = DateTime.now()
      .toUtc()
      .subtract(const Duration(hours: 1))
      .toIso8601String();

  group('Adversarial UI & Navigation Edge Cases for BurstNativeScreen', () {
    testWidgets(
      'Loading state: Transparent AppBar, centered title, leading back button pops, NO BottomNavBar, NO actions',
      (tester) async {
        final chain = _MockBlockchainService();
        final observer = _ChallengerPopObserver();
        final completer = Completer<Map<String, dynamic>>();

        await tester.pumpWidget(
          ChangeNotifierProvider<BlockchainService>.value(
            value: chain,
            child: MaterialApp(
              navigatorObservers: [observer],
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BurstNativeScreen(
                          networksLoader: () => completer.future,
                        ),
                      ),
                    ),
                    child: const Text('Go Burst'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Go Burst'));
        await tester.pump();
        await tester.pump(
          const Duration(milliseconds: 100),
        ); // Advance post-frame callback to trigger _open()

        // Check CircularProgressIndicator is visible (loading state)
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Check AppBar properties
        final appBarFinder = find.byType(AppBar);
        expect(appBarFinder, findsOneWidget);
        final appBar = tester.widget<AppBar>(appBarFinder);
        expect(appBar.backgroundColor, Colors.transparent);
        expect(appBar.foregroundColor, Colors.white);
        expect(appBar.elevation, 0);
        expect(appBar.centerTitle, isTrue);
        expect(
          find.descendant(of: appBarFinder, matching: find.text('Burst')),
          findsOneWidget,
        );

        // Check absence of BottomNavBar
        expect(find.byType(BottomNavBar), findsNothing);

        // Check clean header: no actions, no settings, no wallet switcher
        expect(appBar.actions, anyOf(isNull, isEmpty));
        expect(
          find.byIcon(Icons.account_balance_wallet_outlined),
          findsNothing,
        );
        expect(find.byIcon(Icons.settings), findsNothing);
        expect(find.text('Switch'), findsNothing);

        // Check leading back arrow and pop cleanly
        final backButton = find.descendant(
          of: appBarFinder,
          matching: find.byType(IconButton),
        );
        expect(backButton, findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(observer.didPopRoute, isTrue);
        expect(find.text('Go Burst'), findsOneWidget);

        // Cleanup
        completer.complete({'supportedChains': <Map<String, dynamic>>[]});
        await tester.pumpWidget(const SizedBox());
        chain.dispose();
      },
    );

    testWidgets(
      'Unsupported network state: Transparent AppBar, centered title, leading back button pops, NO BottomNavBar, NO actions',
      (tester) async {
        final chain = _MockBlockchainService(
          networkKey: 'evm:1',
          networkName: 'Ethereum',
        );
        final observer = _ChallengerPopObserver();

        await tester.pumpWidget(
          ChangeNotifierProvider<BlockchainService>.value(
            value: chain,
            child: MaterialApp(
              navigatorObservers: [observer],
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BurstNativeScreen(
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
                    child: const Text('Go Burst'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Go Burst'));
        await tester.pumpAndSettle();

        // Check unsupported network content is visible
        expect(find.text('Burst is coming soon to Ethereum.'), findsOneWidget);
        expect(find.text('BNB Smart Chain'), findsOneWidget);

        // Check AppBar properties
        final appBarFinder = find.byType(AppBar);
        expect(appBarFinder, findsOneWidget);
        final appBar = tester.widget<AppBar>(appBarFinder);
        expect(appBar.backgroundColor, Colors.transparent);
        expect(appBar.foregroundColor, Colors.white);
        expect(appBar.elevation, 0);
        expect(appBar.centerTitle, isTrue);
        expect(
          find.descendant(of: appBarFinder, matching: find.text('Burst')),
          findsOneWidget,
        );

        // Check absence of BottomNavBar
        expect(find.byType(BottomNavBar), findsNothing);

        // Check clean header
        expect(appBar.actions, anyOf(isNull, isEmpty));
        expect(
          find.byIcon(Icons.account_balance_wallet_outlined),
          findsNothing,
        );
        expect(find.byIcon(Icons.settings), findsNothing);

        // Check back button pop
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(observer.didPopRoute, isTrue);
        expect(find.text('Go Burst'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        chain.dispose();
      },
    );

    testWidgets(
      'Error state: Transparent AppBar, centered title, leading back button pops, NO BottomNavBar, NO actions',
      (tester) async {
        final chain = _MockBlockchainService();
        final observer = _ChallengerPopObserver();

        await tester.pumpWidget(
          ChangeNotifierProvider<BlockchainService>.value(
            value: chain,
            child: MaterialApp(
              navigatorObservers: [observer],
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BurstNativeScreen(
                          networksLoader: () async =>
                              throw Exception('Forced error for testing'),
                        ),
                      ),
                    ),
                    child: const Text('Go Burst'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Go Burst'));
        await tester.pumpAndSettle();

        // Check error state content
        expect(
          find.text('Exception: Forced error for testing'),
          findsOneWidget,
        );
        expect(find.text('Try again'), findsOneWidget);

        // Check AppBar properties
        final appBarFinder = find.byType(AppBar);
        expect(appBarFinder, findsOneWidget);
        final appBar = tester.widget<AppBar>(appBarFinder);
        expect(appBar.backgroundColor, Colors.transparent);
        expect(appBar.foregroundColor, Colors.white);
        expect(appBar.elevation, 0);
        expect(appBar.centerTitle, isTrue);
        expect(
          find.descendant(of: appBarFinder, matching: find.text('Burst')),
          findsOneWidget,
        );

        // Check absence of BottomNavBar
        expect(find.byType(BottomNavBar), findsNothing);

        // Check clean header
        expect(appBar.actions, anyOf(isNull, isEmpty));
        expect(
          find.byIcon(Icons.account_balance_wallet_outlined),
          findsNothing,
        );
        expect(find.byIcon(Icons.settings), findsNothing);

        // Check back button pop
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(observer.didPopRoute, isTrue);
        expect(find.text('Go Burst'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        chain.dispose();
      },
    );
  });

  group('Adversarial Pure Web3 Wallet Auth & Session Edge Cases', () {
    test(
      'Wallet-first: readAccountToken returns null and profileId is empty string, omits Authorization header and succeeds',
      () async {
        final capturedRequests = <http.Request>[];
        const walletProfileId = 'wallet-profile-gen-7788';
        const burstToken =
            'bs_0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

        final client = MockClient((request) async {
          capturedRequests.add(request);
          if (request.url.path.endsWith('/challenge')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'challengeId': challengeId,
                  'profileId': walletProfileId,
                  'address': address,
                  'message':
                      'Owllet Burst wallet connection\nAccount: $walletProfileId\nWallet: $address\nChallenge: $challengeId\n\nLink this wallet to your existing Owllet account for Burst. No transaction or gas fee.\nExpires At: $futureExpiry',
                  'expiresAt': futureExpiry,
                },
              }),
              200,
            );
          } else if (request.url.path.endsWith('/connect')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'token': burstToken,
                  'profileId': walletProfileId,
                  'address': address,
                  'expiresAt': futureExpiry,
                  'linkedWallets': [address],
                },
              }),
              200,
            );
          }
          return http.Response('{"error": "NOT_FOUND"}', 404);
        });

        final service = BurstAccountSessionService(
          client: client,
          api: (path) => Uri.parse('https://api.test$path'),
          readAccountToken: () async => null,
          readIdentity: () async => const BurstSignInIdentity(
            address: address,
            networkKey: 'evm:56',
            origin: 'native',
            profileId: '',
          ),
          confirm: (_, _) async => true,
          authenticate: () async => true,
          signMessage: (_, _) async => '0x${'33' * 65}',
        );

        final session = await service.connect(interactive: true);

        expect(session['token'], burstToken);
        expect(session['profileId'], walletProfileId);
        expect(session['address'], address);

        expect(capturedRequests.length, 2);
        // Assert Authorization header is strictly absent in both challenge and connect requests
        for (final req in capturedRequests) {
          expect(
            req.headers.containsKey('Authorization'),
            isFalse,
            reason:
                'Wallet-first request to ${req.url.path} must NOT include Authorization header',
          );
        }

        // Test taking and restoring reusable session
        final snapshot = service.takeReusableSession();
        expect(snapshot, isNotNull);
        service.restoreReusableSession(snapshot!);

        client.close();
      },
    );

    test(
      'Wallet-first: readAccountToken returns empty string (""), omits Authorization header',
      () async {
        final capturedRequests = <http.Request>[];
        const walletProfileId = 'wallet-profile-empty-token';
        const burstToken =
            'bs_9999999999abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

        final client = MockClient((request) async {
          capturedRequests.add(request);
          if (request.url.path.endsWith('/challenge')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'challengeId': challengeId,
                  'profileId': walletProfileId,
                  'address': address,
                  'message':
                      'Owllet Burst wallet connection\nAccount: $walletProfileId\nWallet: $address\nChallenge: $challengeId\n\nLink this wallet to your existing Owllet account for Burst. No transaction or gas fee.\nExpires At: $futureExpiry',
                  'expiresAt': futureExpiry,
                },
              }),
              200,
            );
          } else if (request.url.path.endsWith('/connect')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'token': burstToken,
                  'profileId': walletProfileId,
                  'address': address,
                  'expiresAt': futureExpiry,
                  'linkedWallets': [address],
                },
              }),
              200,
            );
          }
          return http.Response('{"error": "NOT_FOUND"}', 404);
        });

        final service = BurstAccountSessionService(
          client: client,
          api: (path) => Uri.parse('https://api.test$path'),
          readAccountToken: () async => '',
          readIdentity: () async => const BurstSignInIdentity(
            address: address,
            networkKey: 'evm:56',
            origin: 'native',
            profileId: '',
          ),
          confirm: (_, _) async => true,
          authenticate: () async => true,
          signMessage: (_, _) async => '0x${'33' * 65}',
        );

        final session = await service.connect(interactive: true);
        expect(session['token'], burstToken);
        for (final req in capturedRequests) {
          expect(
            req.headers.containsKey('Authorization'),
            isFalse,
            reason:
                'Empty string account token must NOT produce Authorization header',
          );
        }
        client.close();
      },
    );

    test(
      'Existing profile session: readAccountToken returns Bearer JWT, properly sends Authorization header and matches profileId',
      () async {
        final capturedRequests = <http.Request>[];
        const existingProfileId = 'existing-user-uuid-9999';
        const accountJwt = 'valid-account-bearer-jwt';
        const burstToken =
            'bs_aaaaaaaaaaaaaaaa0123456789abcdef0123456789abcdef0123456789abcdef';

        final client = MockClient((request) async {
          capturedRequests.add(request);
          if (request.url.path.endsWith('/challenge')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'challengeId': challengeId,
                  'profileId': existingProfileId,
                  'address': address,
                  'message':
                      'Owllet Burst wallet connection\nAccount: $existingProfileId\nWallet: $address\nChallenge: $challengeId\n\nLink this wallet to your existing Owllet account for Burst. No transaction or gas fee.\nExpires At: $futureExpiry',
                  'expiresAt': futureExpiry,
                },
              }),
              200,
            );
          } else if (request.url.path.endsWith('/connect')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'token': burstToken,
                  'profileId': existingProfileId,
                  'address': address,
                  'expiresAt': futureExpiry,
                  'linkedWallets': [address],
                },
              }),
              200,
            );
          }
          return http.Response('{"error": "NOT_FOUND"}', 404);
        });

        final service = BurstAccountSessionService(
          client: client,
          api: (path) => Uri.parse('https://api.test$path'),
          readAccountToken: () async => accountJwt,
          readIdentity: () async => const BurstSignInIdentity(
            address: address,
            networkKey: 'evm:56',
            origin: 'native',
            profileId: existingProfileId,
          ),
          confirm: (_, _) async => true,
          authenticate: () async => true,
          signMessage: (_, _) async => '0x${'44' * 65}',
        );

        final session = await service.connect(interactive: true);
        expect(session['token'], burstToken);
        expect(session['profileId'], existingProfileId);
        expect(capturedRequests.length, 2);
        for (final req in capturedRequests) {
          expect(
            req.headers['Authorization'],
            'Bearer $accountJwt',
            reason:
                'Existing profile session must include Bearer token in Authorization header',
          );
        }
        client.close();
      },
    );

    test(
      'Adversarial Attack: Existing profile session detects mismatched profileId in challenge and rejects',
      () async {
        const legitimateProfileId = 'legitimate-profile-uuid';
        const maliciousProfileId = 'malicious-attacker-profile-uuid';

        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'challengeId': challengeId,
                'profileId': maliciousProfileId, // Mismatched!
                'address': address,
                'message':
                    'Owllet Burst wallet connection\nAccount: $maliciousProfileId\nWallet: $address\nChallenge: $challengeId\n\nLink this wallet to your existing Owllet account for Burst. No transaction or gas fee.\nExpires At: $futureExpiry',
                'expiresAt': futureExpiry,
              },
            }),
            200,
          );
        });

        var messageSigned = false;
        final service = BurstAccountSessionService(
          client: client,
          api: (path) => Uri.parse('https://api.test$path'),
          readAccountToken: () async => 'legitimate-jwt',
          readIdentity: () async => const BurstSignInIdentity(
            address: address,
            networkKey: 'evm:56',
            origin: 'native',
            profileId: legitimateProfileId,
          ),
          confirm: (_, _) async => true,
          authenticate: () async => true,
          signMessage: (_, _) async {
            messageSigned = true;
            return '0x${'55' * 65}';
          },
        );

        await expectLater(
          service.connect(interactive: true),
          throwsA(
            isA<BurstConnectionFailure>().having(
              (e) => e.code,
              'code',
              'INVALID_CHALLENGE',
            ),
          ),
        );
        expect(messageSigned, isFalse);
        client.close();
      },
    );

    test(
      'Adversarial Attack: BurstSignInController rejects mismatched profileId when identity has non-empty profileId',
      () async {
        final controller = BurstSignInController();
        const legitimateProfileId = 'legitimate-profile-uuid';
        const maliciousProfileId = 'malicious-attacker-profile-uuid';

        await expectLater(
          controller.sign(
            miniAppId: 'burst',
            payload: {
              'address': address,
              'message':
                  'Owllet Burst wallet connection\nAccount: $maliciousProfileId\nWallet: $address\nChallenge: $challengeId\n\nLink this wallet to your existing Owllet account for Burst. No transaction or gas fee.\nExpires At: $futureExpiry',
            },
            readIdentity: () async => const BurstSignInIdentity(
              address: address,
              networkKey: 'evm:56',
              origin: 'native',
              profileId: legitimateProfileId,
            ),
            confirm: (_, _) async => true,
            authenticate: () async => true,
            signMessage: (_, _) async => '0x${'66' * 65}',
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'BurstSignInController accepts challenge when profileId is empty (Pure Web3)',
      () async {
        final controller = BurstSignInController();
        const serverAssignedProfileId = 'server-generated-wallet-profile-id';

        final result = await controller.sign(
          miniAppId: 'burst',
          payload: {
            'address': address,
            'message':
                'Owllet Burst wallet connection\nAccount: $serverAssignedProfileId\nWallet: $address\nChallenge: $challengeId\n\nLink this wallet to your existing Owllet account for Burst. No transaction or gas fee.\nExpires At: $futureExpiry',
          },
          readIdentity: () async => const BurstSignInIdentity(
            address: address,
            networkKey: 'evm:56',
            origin: 'native',
            profileId: '', // Empty profile ID
          ),
          confirm: (_, _) async => true,
          authenticate: () async => true,
          signMessage: (_, _) async => '0x${'77' * 65}',
        );

        expect(result['ok'], isTrue);
        expect(result['address'], address);
        expect(result['signature'], '0x${'77' * 65}');
      },
    );

    test(
      'BurstSignInController strictly rejects expired challenges in wallet-first mode',
      () async {
        final controller = BurstSignInController();
        await expectLater(
          controller.sign(
            miniAppId: 'burst',
            payload: {
              'address': address,
              'message':
                  'Owllet Burst wallet connection\nAccount: server-generated-id\nWallet: $address\nChallenge: $challengeId\n\nLink this wallet to your existing Owllet account for Burst. No transaction or gas fee.\nExpires At: $pastExpiry',
            },
            readIdentity: () async => const BurstSignInIdentity(
              address: address,
              networkKey: 'evm:56',
              origin: 'native',
              profileId: '',
            ),
            confirm: (_, _) async => true,
            authenticate: () async => true,
            signMessage: (_, _) async => '0x${'88' * 65}',
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'The sign-in challenge has expired.',
            ),
          ),
        );
      },
    );

    test(
      'BurstSignInController rejects mismatched wallet address in wallet-first mode',
      () async {
        final controller = BurstSignInController();
        const differentAddress = '0x2222222222222222222222222222222222222222';
        await expectLater(
          controller.sign(
            miniAppId: 'burst',
            payload: {
              'address': differentAddress,
              'message':
                  'Owllet Burst wallet connection\nAccount: server-generated-id\nWallet: $differentAddress\nChallenge: $challengeId\n\nLink this wallet to your existing Owllet account for Burst. No transaction or gas fee.\nExpires At: $futureExpiry',
            },
            readIdentity: () async => const BurstSignInIdentity(
              address: address,
              networkKey: 'evm:56',
              origin: 'native',
              profileId: '',
            ),
            confirm: (_, _) async => true,
            authenticate: () async => true,
            signMessage: (_, _) async => '0x${'88' * 65}',
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'Cached session re-verification succeeds for wallet-first user and detects wallet switch',
      () async {
        const walletProfileId = 'wallet-profile-cached-test';
        const burstToken =
            'bs_feedbeef0123456789abcdef0123456789abcdef0123456789abcdef01234567';
        var getSessionCalled = 0;

        final client = MockClient((request) async {
          if (request.url.path.endsWith('/challenge')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'challengeId': challengeId,
                  'profileId': walletProfileId,
                  'address': address,
                  'message':
                      'Owllet Burst wallet connection\nAccount: $walletProfileId\nWallet: $address\nChallenge: $challengeId\n\nLink this wallet to your existing Owllet account for Burst. No transaction or gas fee.\nExpires At: $futureExpiry',
                  'expiresAt': futureExpiry,
                },
              }),
              200,
            );
          } else if (request.url.path.endsWith('/connect')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'token': burstToken,
                  'profileId': walletProfileId,
                  'address': address,
                  'expiresAt': futureExpiry,
                  'linkedWallets': [address],
                },
              }),
              200,
            );
          } else if (request.url.path.endsWith('/session') &&
              request.method == 'GET') {
            getSessionCalled++;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'profileId': walletProfileId,
                  'address': address,
                  'expiresAt': futureExpiry,
                  'linkedWallets': [address],
                },
              }),
              200,
            );
          }
          return http.Response('{"error": "NOT_FOUND"}', 404);
        });

        var currentAddress = address;

        final service = BurstAccountSessionService(
          client: client,
          api: (path) => Uri.parse('https://api.test$path'),
          readAccountToken: () async => null,
          readIdentity: () async => BurstSignInIdentity(
            address: currentAddress,
            networkKey: 'evm:56',
            origin: 'native',
            profileId: '',
          ),
          confirm: (_, _) async => true,
          authenticate: () async => true,
          signMessage: (_, _) async => '0x${'99' * 65}',
        );

        // Step 1: Initial connect
        final session1 = await service.connect(interactive: true);
        expect(session1['token'], burstToken);

        // Step 2: Non-interactive re-check with same wallet
        final session2 = await service.connect(interactive: false);
        expect(session2['token'], burstToken);
        expect(getSessionCalled, 1);

        // Step 3: Wallet switched to another address
        currentAddress = '0x2222222222222222222222222222222222222222';
        await expectLater(
          service.connect(interactive: false),
          throwsA(
            isA<BurstConnectionFailure>().having(
              (e) => e.code,
              'code',
              'CONNECTION_REQUIRED',
            ),
          ),
        );

        client.close();
      },
    );
  });
}
