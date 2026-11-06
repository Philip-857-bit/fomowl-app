import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/mini_apps/burst_account_session.dart';
import 'package:fomowl_wallet/features/mini_apps/burst_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const address = '0x1111111111111111111111111111111111111111';
  const challengeId = '11111111-2222-4333-8444-555555555555';
  final expiry = DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 10))
      .toIso8601String();
  BurstSignInIdentity identity() => const BurstSignInIdentity(
    address: address,
    networkKey: 'evm:56',
    origin: 'native',
    profileId: 'account-a',
  );
  String message(String id) =>
      'Owllet Burst wallet connection\nAccount: account-a\nWallet: $address\nChallenge: $id\n\nLink this wallet to your existing Owllet account for Burst. No transaction or gas fee.\nExpires At: $expiry';

  test('noninteractive access never starts a connection', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{}', 200);
    });
    final service = BurstAccountSessionService(
      client: client,
      api: (path) => Uri.parse('https://example.test/api$path'),
      readAccountToken: () async => 'account-jwt',
      readIdentity: () async => identity(),
      confirm: (_, _) async => true,
      authenticate: () async => true,
      signMessage: (_, _) async => '0x${'11' * 65}',
    );
    await expectLater(
      service.connect(),
      throwsA(
        isA<BurstConnectionFailure>().having(
          (e) => e.code,
          'code',
          'CONNECTION_REQUIRED',
        ),
      ),
    );
    expect(calls, 0);
    client.close();
  });

  test(
    'only the matching backend challenge is signed and a scoped token returned',
    () async {
      final requests = <http.Request>[];
      final token = 'bs_${'a' * 64}';
      final client = MockClient((request) async {
        requests.add(request);
        final data = request.url.path.endsWith('/challenge')
            ? {
                'profileId': 'account-a',
                'address': address,
                'challengeId': challengeId,
                'message': message(challengeId),
              }
            : {
                'profileId': 'account-a',
                'address': address,
                'token': token,
                'expiresAt': expiry,
                'linkedWallets': [address],
              };
        return http.Response(jsonEncode({'success': true, 'data': data}), 200);
      });
      var signed = 0;
      final service = BurstAccountSessionService(
        client: client,
        api: (path) => Uri.parse('https://example.test/api$path'),
        readAccountToken: () async => 'account-jwt',
        readIdentity: () async => identity(),
        confirm: (_, _) async => true,
        authenticate: () async => true,
        signMessage: (_, _) async {
          signed++;
          return '0x${'11' * 65}';
        },
      );
      final session = await service.connect(interactive: true);
      expect(session['token'], token);
      expect(session.values, isNot(contains('account-jwt')));
      expect(signed, 1);
      expect(
        requests.map((r) => r.headers['Authorization']),
        everyElement('Bearer account-jwt'),
      );
      client.close();
    },
  );

  test(
    'rejects a challenge whose message names a different challenge id',
    () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'profileId': 'account-a',
              'address': address,
              'challengeId': challengeId,
              'message': message('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'),
            },
          }),
          200,
        ),
      );
      var signed = false;
      final service = BurstAccountSessionService(
        client: client,
        api: (path) => Uri.parse('https://example.test/api$path'),
        readAccountToken: () async => 'account-jwt',
        readIdentity: () async => identity(),
        confirm: (_, _) async => true,
        authenticate: () async => true,
        signMessage: (_, _) async {
          signed = true;
          return '0x${'11' * 65}';
        },
      );
      await expectLater(
        service.connect(interactive: true),
        throwsA(isA<BurstConnectionFailure>()),
      );
      expect(signed, isFalse);
      client.close();
    },
  );

  test(
    'pure Web3 wallet-first authentication succeeds without account token or profile id',
    () async {
      final requests = <http.Request>[];
      final token = 'bs_${'b' * 64}';
      const walletProfileId = 'wallet-profile-uuid-1234';
      final client = MockClient((request) async {
        requests.add(request);
        final data = request.url.path.endsWith('/challenge')
            ? {
                'profileId': walletProfileId,
                'address': address,
                'challengeId': challengeId,
                'message':
                    'Owllet Burst wallet connection\nAccount: $walletProfileId\nWallet: $address\nChallenge: $challengeId\n\nLink this wallet to your existing Owllet account for Burst. No transaction or gas fee.\nExpires At: $expiry',
              }
            : {
                'profileId': walletProfileId,
                'address': address,
                'token': token,
                'expiresAt': expiry,
                'linkedWallets': [address],
              };
        return http.Response(jsonEncode({'success': true, 'data': data}), 200);
      });
      var signed = 0;
      final service = BurstAccountSessionService(
        client: client,
        api: (path) => Uri.parse('https://example.test/api$path'),
        readAccountToken: () async => null,
        readIdentity: () async => const BurstSignInIdentity(
          address: address,
          networkKey: 'evm:56',
          origin: 'native',
          profileId: '',
        ),
        confirm: (_, _) async => true,
        authenticate: () async => true,
        signMessage: (_, _) async {
          signed++;
          return '0x${'22' * 65}';
        },
      );
      final session = await service.connect(interactive: true);
      expect(session['token'], token);
      expect(session['profileId'], walletProfileId);
      expect(session['address'], address);
      expect(signed, 1);
      expect(requests.length, 2);
      expect(
        requests.every((r) => r.headers['Authorization'] == null),
        isTrue,
        reason: 'Wallet-first flow must omit Authorization header',
      );

      final snapshot = service.takeReusableSession();
      expect(snapshot, isNotNull);
      client.close();
    },
  );
}
