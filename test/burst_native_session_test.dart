import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_api_client.dart';
import 'package:fomowl_wallet/features/burst/burst_native_session.dart';
import 'package:fomowl_wallet/features/mini_apps/burst_account_session.dart';
import 'package:fomowl_wallet/features/mini_apps/burst_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'reopening reuses a verified session but changing wallet reconnects',
    () async {
      var wallet = '0x1111111111111111111111111111111111111111';
      var accountToken = 'account-token';
      const id = '11111111-2222-4333-8444-555555555555';
      final expiry = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 10))
          .toIso8601String();
      var signed = 0;
      var verified = 0;
      var revoked = 0;
      var rejectSession = false;
      final client = MockClient((request) async {
        if (request.method == 'DELETE') {
          revoked++;
          return http.Response('{"success":true,"data":{}}', 200);
        }
        if (request.method == 'GET') {
          verified++;
          if (rejectSession) {
            return http.Response(
              '{"error":"BURST_CONNECTION_EXPIRED","message":"Connect again."}',
              401,
            );
          }
        }
        final data = request.url.path.endsWith('/challenge')
            ? {
                'profileId': 'account',
                'address': wallet,
                'challengeId': id,
                'message':
                    'Owllet Burst wallet connection\nAccount: account\nWallet: $wallet\nChallenge: $id\n\nLink this wallet to your existing Owllet account for Burst. No transaction or gas fee.\nExpires At: $expiry',
              }
            : {
                'profileId': 'account',
                'address': wallet,
                'token': 'bs_${'a' * 64}',
                'expiresAt': expiry,
                'linkedWallets': [wallet],
              };
        return http.Response(jsonEncode({'success': true, 'data': data}), 200);
      });
      BurstNativeSession session() => BurstNativeSession(
        client: client,
        api: (path) => Uri.parse('https://example.test/api$path'),
        readAccountToken: () async => accountToken,
        readIdentity: () async => BurstSignInIdentity(
          address: wallet,
          networkKey: 'evm:56',
          origin: 'native',
          profileId: 'account',
        ),
        confirm: (_, _) async => true,
        authenticate: () async => true,
        signMessage: (_, _) async {
          signed++;
          return '0x${'11' * 65}';
        },
      );
      final first = session();
      await first.open();
      await first.close(retainForReuse: true);
      final second = session();
      await second.open();
      expect(signed, 1);
      expect(verified, 1);
      await second.close(retainForReuse: true);
      rejectSession = true;
      final refreshed = session();
      await refreshed.open();
      expect(signed, 2);
      expect(revoked, 1);
      await refreshed.close(retainForReuse: true);
      rejectSession = false;
      accountToken = 'new-account-token';
      final third = session();
      await third.open();
      expect(signed, 3);
      expect(revoked, 2);
      await third.close(retainForReuse: true);
      wallet = '0x2222222222222222222222222222222222222222';
      final fourth = session();
      await fourth.open();
      expect(signed, 4);
      expect(revoked, 3);
      await fourth.close();
      client.close();
    },
  );

  test('explicit disconnect wins while a request is still in flight', () async {
    const wallet = '0x1111111111111111111111111111111111111111';
    const id = '11111111-2222-4333-8444-555555555555';
    final expiry = DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 10))
        .toIso8601String();
    final started = Completer<void>();
    final release = Completer<http.Response>();
    var revoked = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/campaigns')) {
        started.complete();
        return release.future;
      }
      if (request.method == 'DELETE') {
        revoked++;
        return http.Response('{"success":true,"data":{}}', 200);
      }
      final data = request.url.path.endsWith('/challenge')
          ? {
              'profileId': 'account',
              'address': wallet,
              'challengeId': id,
              'message':
                  'Owllet Burst wallet connection\nAccount: account\nWallet: $wallet\nChallenge: $id\n\nLink this wallet to your existing Owllet account for Burst. No transaction or gas fee.\nExpires At: $expiry',
            }
          : {
              'profileId': 'account',
              'address': wallet,
              'token': 'bs_${'a' * 64}',
              'expiresAt': expiry,
            };
      return http.Response(jsonEncode({'success': true, 'data': data}), 200);
    });
    final session = BurstNativeSession(
      client: client,
      api: (path) => Uri.parse('https://example.test/api$path'),
      readAccountToken: () async => 'account-token',
      readIdentity: () async => const BurstSignInIdentity(
        address: wallet,
        networkKey: 'evm:56',
        origin: 'native',
        profileId: 'account',
      ),
      confirm: (_, _) async => true,
      authenticate: () async => true,
      signMessage: (_, _) async => '0x${'11' * 65}',
    );
    final api = await session.open();
    final request = api.campaigns();
    await started.future;
    final retain = session.close(retainForReuse: true);
    final disconnect = session.close();
    release.complete(http.Response('{"campaigns":[]}', 200));
    await request;
    await Future.wait([retain, disconnect]);
    expect(revoked, 1);
    client.close();
  });

  test('closing during final wallet recheck revokes the connection', () async {
    const wallet = '0x1111111111111111111111111111111111111111';
    const id = '11111111-2222-4333-8444-555555555555';
    const identity = BurstSignInIdentity(
      address: wallet,
      networkKey: 'evm:56',
      origin: 'native',
      profileId: 'account',
    );
    final expiry = DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 10))
        .toIso8601String();
    final checking = Completer<void>();
    final release = Completer<void>();
    var replied = false;
    var checksAfterReply = 0;
    var revoked = 0;
    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        revoked++;
        return http.Response('{"success":true,"data":{}}', 200);
      }
      if (request.url.path.endsWith('/challenge')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'profileId': 'account',
              'address': wallet,
              'challengeId': id,
              'message':
                  'Owllet Burst wallet connection\nAccount: account\nWallet: $wallet\nChallenge: $id\n\nLink this wallet to your existing Owllet account for Burst. No transaction or gas fee.\nExpires At: $expiry',
            },
          }),
          200,
        );
      }
      replied = true;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'profileId': 'account',
            'address': wallet,
            'token': 'bs_${'a' * 64}',
            'expiresAt': expiry,
          },
        }),
        200,
      );
    });
    final session = BurstNativeSession(
      client: client,
      api: (path) => Uri.parse('https://example.test/api$path'),
      readAccountToken: () async => 'account-token',
      readIdentity: () async {
        if (replied && ++checksAfterReply == 2) {
          checking.complete();
          await release.future;
        }
        return identity;
      },
      confirm: (_, _) async => true,
      authenticate: () async => true,
      signMessage: (_, _) async => '0x${'11' * 65}',
    );
    final openingResult = expectLater(
      session.open(),
      throwsA(isA<BurstConnectionFailure>()),
    );
    await checking.future;
    final closing = session.close();
    release.complete();
    await openingResult;
    await closing;
    expect(revoked, 1);
    client.close();
  });

  test(
    'closing during connection revokes the session after it arrives',
    () async {
      const wallet = '0x1111111111111111111111111111111111111111';
      const id = '11111111-2222-4333-8444-555555555555';
      final expiry = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 10))
          .toIso8601String();
      final connecting = Completer<void>();
      final reply = Completer<void>();
      var revoked = 0;
      final client = MockClient((request) async {
        if (request.method == 'DELETE') {
          revoked++;
          return http.Response('{"success":true,"data":{}}', 200);
        }
        if (request.url.path.endsWith('/challenge')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'profileId': 'account',
                'address': wallet,
                'challengeId': id,
                'message':
                    'Owllet Burst wallet connection\nAccount: account\nWallet: $wallet\nChallenge: $id\n\nLink this wallet to your existing Owllet account for Burst. No transaction or gas fee.\nExpires At: $expiry',
              },
            }),
            200,
          );
        }
        connecting.complete();
        await reply.future;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'profileId': 'account',
              'address': wallet,
              'token': 'bs_${'a' * 64}',
              'expiresAt': expiry,
            },
          }),
          200,
        );
      });
      final session = BurstNativeSession(
        client: client,
        api: (path) => Uri.parse('https://example.test/api$path'),
        readAccountToken: () async => 'account-token',
        readIdentity: () async => const BurstSignInIdentity(
          address: wallet,
          networkKey: 'evm:56',
          origin: 'native',
          profileId: 'account',
        ),
        confirm: (_, _) async => true,
        authenticate: () async => true,
        signMessage: (_, _) async => '0x${'11' * 65}',
      );
      final opening = session.open();
      final openingResult = expectLater(opening, throwsStateError);
      await connecting.future;
      final closing = session.close();
      reply.complete();
      await openingResult;
      await closing;
      expect(revoked, 1);
      expect(() => session.open(), throwsStateError);
      client.close();
    },
  );

  test('native requests stop when the selected wallet changes', () async {
    var wallet = '0x1111111111111111111111111111111111111111';
    const id = '11111111-2222-4333-8444-555555555555';
    final expiry = DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 10))
        .toIso8601String();
    var campaignRequests = 0;
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/campaigns')) {
        campaignRequests++;
        return http.Response('{"campaigns":[]}', 200);
      }
      if (request.method == 'DELETE') {
        return http.Response('{"success":true,"data":{}}', 200);
      }
      final value = path.endsWith('/challenge')
          ? {
              'profileId': 'account',
              'address': wallet,
              'challengeId': id,
              'message':
                  'Owllet Burst wallet connection\nAccount: account\nWallet: $wallet\nChallenge: $id\n\nLink this wallet to your existing Owllet account for Burst. No transaction or gas fee.\nExpires At: $expiry',
            }
          : {
              'profileId': 'account',
              'address': wallet,
              'token': 'bs_${'a' * 64}',
              'expiresAt': expiry,
              'linkedWallets': [wallet],
            };
      return http.Response(jsonEncode({'success': true, 'data': value}), 200);
    });
    final session = BurstNativeSession(
      client: client,
      api: (path) => Uri.parse('https://example.test/api$path'),
      readAccountToken: () async => 'account-token',
      readIdentity: () async => BurstSignInIdentity(
        address: wallet,
        networkKey: 'evm:56',
        origin: 'native',
        profileId: 'account',
      ),
      confirm: (_, _) async => true,
      authenticate: () async => true,
      signMessage: (_, _) async => '0x${'11' * 65}',
    );
    final api = await session.open();
    wallet = '0x2222222222222222222222222222222222222222';
    await expectLater(
      api.campaigns(),
      throwsA(
        isA<BurstApiException>().having(
          (e) => e.code,
          'code',
          'CONTEXT_CHANGED',
        ),
      ),
    );
    expect(campaignRequests, 0);
    await session.close();
    client.close();
  });
}
