import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_api_client.dart';
import 'package:fomowl_wallet/features/burst/burst_draft_recovery.dart';
import 'package:fomowl_wallet/features/burst/burst_draft_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'burst_draft_store_test.dart' show MemoryStorage;

void main() {
  test('rejected unprepared drafts clear, uncertain drafts remain', () async {
    var status = 400;
    final client = MockClient(
      (_) async => http.Response('{"message":"failed"}', status),
    );
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    final store = BurstDraftStore(storage: MemoryStorage());
    final draft = <String, dynamic>{
      'request': {'idempotencyKey': 'original'},
    };
    Future<void> save() => store.write('profile', 'wallet', 56, draft);
    Future<Map<String, dynamic>> recover() => recoverBurstDraft(
      saved: draft,
      api: api,
      store: store,
      profileId: 'profile',
      wallet: 'wallet',
      chainId: 56,
    );
    await save();
    await expectLater(recover(), throwsA(isA<BurstApiException>()));
    expect(await store.read('profile', 'wallet', 56), isNull);
    status = 503;
    await save();
    await expectLater(recover(), throwsA(isA<BurstApiException>()));
    expect(await store.read('profile', 'wallet', 56), draft);
    client.close();
  });

  test('prepared drafts resume without re-requesting or clearing', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{}', 400);
    });
    final api = BurstApiClient(
      api: (path) => Uri.parse('https://example.test/api$path'),
      client: client,
      authorize: (request) async =>
          http.Response.fromStream(await client.send(request)),
    );
    final store = BurstDraftStore(storage: MemoryStorage());
    final draft = <String, dynamic>{
      'request': {'idempotencyKey': 'original'},
      'prepared': {'campaign': 'saved'},
    };
    await store.write('profile', 'wallet', 56, draft);
    final result = await recoverBurstDraft(
      saved: draft,
      api: api,
      store: store,
      profileId: 'profile',
      wallet: 'wallet',
      chainId: 56,
    );
    expect(result, {'campaign': 'saved'});
    expect(requests, 0);
    expect(await store.read('profile', 'wallet', 56), draft);
    client.close();
  });
}
