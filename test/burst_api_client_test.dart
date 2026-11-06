import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/config/app_environment.dart';
import 'package:fomowl_wallet/features/burst/burst_api_client.dart';
import 'package:fomowl_wallet/features/mini_apps/burst_account_session.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads supported networks without requiring a wallet session', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/burst/networks');
      expect(request.headers.containsKey('Authorization'), isFalse);
      return http.Response(
        '{"supportedChains":[{"chainId":56,"name":"BNB Smart Chain","networkKey":"evm:56"}]}',
        200,
      );
    });
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (_) => throw StateError('Unexpected authentication'),
    );
    expect((await api.networks())['supportedChains'], hasLength(1));
    client.close();
  });

  test('preserves wallet change guidance for Burst screens', () async {
    final client = MockClient((request) async => http.Response('{}', 200));
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (_) async => throw const BurstConnectionFailure(
        'CONTEXT_CHANGED',
        'Your wallet or network changed. Open Burst again.',
      ),
    );
    await expectLater(
      api.campaigns(),
      throwsA(
        isA<BurstApiException>()
            .having((e) => e.code, 'code', 'CONTEXT_CHANGED')
            .having(
              (e) => e.message,
              'message',
              'Your wallet or network changed. Open Burst again.',
            ),
      ),
    );
    client.close();
  });

  test(
    'uses the app URI builder for chain and message query parameters',
    () async {
      final seen = <http.Request>[];
      final client = MockClient((request) async {
        seen.add(request);
        return http.Response('{"enabled":true}', 200);
      });
      final api = BurstApiClient(
        api: AppEnvironment.api,
        client: client,
        authorize: (request) async =>
            http.Response.fromStream(await client.send(request)),
      );
      await api.config(56);
      await api.messages('campaign', after: 'cursor+with/characters');
      await api.config(56, recovery: true);
      expect(seen[0].url.path, '/api/burst/config');
      expect(seen[0].url.queryParameters, {'chainId': '56'});
      expect(seen[1].url.path, '/api/burst/campaigns/campaign/messages');
      expect(seen[1].url.queryParameters, {'after': 'cursor+with/characters'});
      expect(seen[2].url.queryParameters, {'chainId': '56', 'recovery': '1'});
      client.close();
    },
  );

  test(
    'uses public config and scopes campaign requests to native session',
    () async {
      final seen = <http.Request>[];
      final client = MockClient((request) async {
        seen.add(request);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'enabled': true},
          }),
          200,
        );
      });
      final api = BurstApiClient(
        api: (path) => Uri.parse('https://example.test/api$path'),
        client: client,
        authorize: (request) async {
          request.headers['Authorization'] = 'Bearer bs_scoped';
          return http.Response.fromStream(await client.send(request));
        },
      );
      expect((await api.config(56))['enabled'], isTrue);
      expect((await api.campaigns())['enabled'], isTrue);
      expect(
        seen[0].url.toString(),
        'https://example.test/api/burst/config?chainId=56',
      );
      expect(seen[0].headers.containsKey('Authorization'), isFalse);
      expect(seen[1].headers['Authorization'], 'Bearer bs_scoped');
      client.close();
    },
  );

  test('encodes codes and reports backend failures', () async {
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response(
        jsonEncode({'error': 'NOT_OPEN', 'message': 'Burst is closed.'}),
        409,
      );
    });
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    await expectLater(
      api.join('ABC/DEF'),
      throwsA(
        isA<BurstApiException>()
            .having((e) => e.code, 'code', 'NOT_OPEN')
            .having((e) => e.statusCode, 'status', 409),
      ),
    );
    expect(seen.url.pathSegments.last, 'ABC/DEF');
    expect(seen.method, 'POST');
    client.close();
  });
}
