import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_account_verifier.dart';
import 'package:http/http.dart' as http;

void main() {
  test(
    'expired session signs in again and replaces a stale profile in memory',
    () async {
      String? token = 'expired';
      Map<String, dynamic>? cached = {'id': 'old'};
      var logouts = 0;
      var signIns = 0;
      final verifier = BurstAccountVerifier(
        readToken: () async => token,
        logout: () async {
          logouts++;
          token = null;
        },
        signIn: () async {
          signIns++;
          token = 'fresh';
          return true;
        },
        fetchProfile: (value) async => value == 'expired'
            ? http.Response('{}', 401)
            : http.Response(
                jsonEncode({
                  'success': true,
                  'data': {'id': 'new'},
                }),
                200,
              ),
        readCachedProfile: () async => cached,
        saveTransientProfile: (profile) async {
          cached = profile;
        },
      );
      await verifier.ensureAccount();
      expect(logouts, 1);
      expect(signIns, 1);
      expect(cached?['id'], 'new');
    },
  );

  test('server failures never erase the account session', () async {
    var logouts = 0;
    final verifier = BurstAccountVerifier(
      readToken: () async => 'existing',
      logout: () async {
        logouts++;
      },
      signIn: () async => false,
      fetchProfile: (_) async => http.Response('{}', 503),
      readCachedProfile: () async => {'id': 'profile'},
      saveTransientProfile: (_) async {},
    );
    await expectLater(verifier.ensureAccount(), throwsStateError);
    expect(logouts, 0);
  });

  test(
    'a late unauthorized response cannot log out a different account',
    () async {
      var token = 'old';
      var logouts = 0;
      final verifier = BurstAccountVerifier(
        readToken: () async => token,
        logout: () async {
          logouts++;
        },
        signIn: () async => false,
        fetchProfile: (_) async {
          token = 'new';
          return http.Response('{}', 401);
        },
        readCachedProfile: () async => null,
        saveTransientProfile: (_) async {},
      );
      await expectLater(verifier.ensureAccount(), throwsStateError);
      expect(logouts, 0);
      expect(token, 'new');
    },
  );
}
