import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_api_client.dart';
import 'package:fomowl_wallet/features/burst/burst_draft_editor.dart';
import 'package:fomowl_wallet/features/burst/burst_draft_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'burst_draft_store_test.dart' show MemoryStorage;

void main() {
  for (final status in [400, 409]) {
    test(
      'rejected edit ($status) leaves the saved draft recoverable',
      () async {
        final client = MockClient((_) async => http.Response('{}', status));
        final api = BurstApiClient(
          api: (p) => Uri.parse('https://example.test/api$p'),
          client: client,
          authorize: (r) async =>
              http.Response.fromStream(await client.send(r)),
        );
        final store = BurstDraftStore(storage: MemoryStorage());
        final saved = <String, dynamic>{
          'request': {'idempotencyKey': 'old-key-123'},
          'prepared': {
            'campaign': {'id': 'campaign'},
          },
        };
        await store.write('p', 'w', 56, saved);
        final editor = BurstDraftEditor(
          api: api,
          store: store,
          profileId: 'p',
          wallet: 'w',
          chainId: 56,
          validate: (_, _) {},
        );
        await expectLater(
          editor.update(
            saved: saved,
            request: {'idempotencyKey': 'new-key-123'},
          ),
          throwsA(isA<BurstApiException>()),
        );
        expect(await store.read('p', 'w', 56), saved);
        client.close();
      },
    );
  }
  test(
    'uncertain edit preserves old recovery and retries the exact revision',
    () async {
      var status = 503;
      final requests = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, endsWith('/campaigns/campaign/draft'));
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          status == 200 ? '{"campaign":{"id":"campaign"}}' : '{}',
          status,
        );
      });
      final api = BurstApiClient(
        api: (path) => Uri.parse('https://example.test/api$path'),
        client: client,
        authorize: (request) async =>
            http.Response.fromStream(await client.send(request)),
      );
      final store = BurstDraftStore(storage: MemoryStorage());
      final old = <String, dynamic>{
        'request': {'idempotencyKey': 'old-key-123'},
        'prepared': {
          'campaign': {'id': 'campaign'},
        },
      };
      await store.write('profile', 'wallet', 56, old);
      final editor = BurstDraftEditor(
        api: api,
        store: store,
        profileId: 'profile',
        wallet: 'wallet',
        chainId: 56,
        validate: (_, _) {},
      );
      final payload = <String, dynamic>{
        'idempotencyKey': 'new-key-123',
        'title': 'Edited',
      };
      await expectLater(
        editor.update(saved: old, request: payload),
        throwsA(isA<BurstApiException>()),
      );
      final pending = (await store.read('profile', 'wallet', 56))!;
      expect(pending['prepared'], old['prepared']);
      expect(pending['request'], old['request']);
      status = 200;
      await editor.update(
        saved: pending,
        request: {'title': 'must not replace uncertain request'},
      );
      expect(requests[0], requests[1]);
      expect(requests.last['previousIdempotencyKey'], 'old-key-123');
      final saved = (await store.read('profile', 'wallet', 56))!;
      expect(saved['request'], payload);
      expect(saved.containsKey('pendingUpdate'), isFalse);
      client.close();
    },
  );
}
