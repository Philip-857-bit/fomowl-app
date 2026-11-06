import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_api_client.dart';
import 'package:fomowl_wallet/features/burst/burst_transaction_executor.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryJournal implements BurstSubmissionJournal {
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

class SwitchOnWriteJournal extends MemoryJournal {
  bool current = true;
  @override
  Future<void> write(String reference, Map<String, String> entry) async {
    await super.write(reference, entry);
    if (!entry.containsKey('hash')) current = false;
  }
}

void main() {
  const wallet = '0x1111111111111111111111111111111111111111';
  const to = '0x2222222222222222222222222222222222222222';
  final hash = '0x${'aa' * 32}';
  Map<String, dynamic> plan({String value = '0'}) => {
    'status': 'prepared',
    'walletAddress': wallet,
    'campaignId': 'campaign',
    'transaction': {
      'reference': 'reference',
      'operation': 'set_root',
      'chainId': 56,
      'toAddress': to,
      'valueBaseUnits': value,
      'calldata': '0x7cb6475900',
      'expiresAt': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .toIso8601String(),
    },
  };
  BurstApiClient api(MockClient client) => BurstApiClient(
    api: (path) => Uri.parse('https://example.test/api$path'),
    client: client,
    authorize: (request) async =>
        http.Response.fromStream(await client.send(request)),
  );

  test('paused recovery cannot broadcast a new transaction', () async {
    var broadcasts = 0;
    final client = MockClient(
      (_) async => http.Response(jsonEncode(plan()), 200),
    );
    final executor = BurstTransactionExecutor(
      api: api(client),
      journal: MemoryJournal(),
      wallet: wallet,
      chainId: 56,
      allowNewTransactions: false,
      isCurrent: () async => true,
      approve: (_) async => true,
      broadcast: (_) async {
        broadcasts++;
        return hash;
      },
    );
    await expectLater(executor.execute('reference'), throwsStateError);
    expect(broadcasts, 0);
    client.close();
  });

  test('paused recovery can confirm a submitted transaction', () async {
    var broadcasts = 0;
    final client = MockClient((request) async {
      if (request.url.path.contains('/execution')) {
        return http.Response(
          jsonEncode({
            ...plan(),
            'status': 'submitted',
            'transactionHash': hash,
          }),
          200,
        );
      }
      return http.Response('{"status":"confirmed"}', 200);
    });
    final executor = BurstTransactionExecutor(
      api: api(client),
      journal: MemoryJournal(),
      wallet: wallet,
      chainId: 56,
      allowNewTransactions: false,
      isCurrent: () async => true,
      approve: (_) async => true,
      broadcast: (_) async {
        broadcasts++;
        return hash;
      },
    );
    expect((await executor.execute('reference')).confirmed, isTrue);
    expect(broadcasts, 0);
    client.close();
  });

  test('wallet change before broadcast clears the unsent marker', () async {
    var broadcasts = 0;
    final journal = SwitchOnWriteJournal();
    final client = MockClient((request) async {
      if (request.url.path.contains('/execution')) {
        return http.Response(jsonEncode(plan()), 200);
      }
      return http.Response('{"status":"confirmed"}', 200);
    });
    final executor = BurstTransactionExecutor(
      api: api(client),
      journal: journal,
      wallet: wallet,
      chainId: 56,
      isCurrent: () async => journal.current,
      approve: (_) async => true,
      broadcast: (_) async {
        broadcasts++;
        return hash;
      },
    );
    await expectLater(executor.execute('reference'), throwsStateError);
    expect(broadcasts, 0);
    expect(journal.entries, isEmpty);
    client.close();
  });

  test(
    'a failed wallet check before broadcast clears the unsent marker',
    () async {
      var broadcasts = 0;
      final journal = SwitchOnWriteJournal();
      final client = MockClient(
        (_) async => http.Response(jsonEncode(plan()), 200),
      );
      final executor = BurstTransactionExecutor(
        api: api(client),
        journal: journal,
        wallet: wallet,
        chainId: 56,
        isCurrent: () async {
          if (!journal.current) throw StateError('Unsupported network');
          return true;
        },
        approve: (_) async => true,
        broadcast: (_) async {
          broadcasts++;
          return hash;
        },
      );
      await expectLater(executor.execute('reference'), throwsStateError);
      expect(broadcasts, 0);
      expect(journal.entries, isEmpty);
      client.close();
    },
  );

  test(
    'recovery after a failed acknowledgement never broadcasts twice',
    () async {
      var submits = 0;
      var broadcasts = 0;
      final client = MockClient((request) async {
        if (request.url.path.contains('/execution')) {
          return http.Response(jsonEncode(plan()), 200);
        }
        if (request.url.path.endsWith('/submit') && submits++ == 0) {
          return http.Response('{"message":"unavailable"}', 503);
        }
        return http.Response('{"status":"confirmed"}', 200);
      });
      final executor = BurstTransactionExecutor(
        api: api(client),
        journal: MemoryJournal(),
        wallet: wallet,
        chainId: 56,
        isCurrent: () async => true,
        approve: (_) async => true,
        broadcast: (_) async {
          broadcasts++;
          return hash;
        },
      );
      await expectLater(
        executor.execute('reference'),
        throwsA(isA<BurstApiException>()),
      );
      expect((await executor.execute('reference')).confirmed, isTrue);
      expect(broadcasts, 1);
      client.close();
    },
  );

  test(
    'a changed plan and an unknown prior broadcast never reach signing',
    () async {
      var fetches = 0;
      var broadcasts = 0;
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode(plan(value: fetches++ == 0 ? '0' : '1')),
          200,
        ),
      );
      final journal = MemoryJournal();
      final executor = BurstTransactionExecutor(
        api: api(client),
        journal: journal,
        wallet: wallet,
        chainId: 56,
        isCurrent: () async => true,
        approve: (_) async => true,
        broadcast: (_) async {
          broadcasts++;
          return hash;
        },
      );
      await expectLater(executor.execute('reference'), throwsStateError);
      expect(broadcasts, 0);
      journal.entries['reference'] = {
        'wallet': wallet,
        'chainId': '56',
        'campaignId': 'campaign',
        'operation': 'set_root',
      };
      await expectLater(
        executor.execute('reference'),
        throwsA(isA<BurstUnknownSubmission>()),
      );
      expect(broadcasts, 0);
      client.close();
    },
  );

  test(
    'a transaction different from the campaign review is rejected',
    () async {
      var approved = false;
      final client = MockClient(
        (request) async => http.Response(jsonEncode(plan(value: '1')), 200),
      );
      final executor = BurstTransactionExecutor(
        api: api(client),
        journal: MemoryJournal(),
        wallet: wallet,
        chainId: 56,
        isCurrent: () async => true,
        approve: (_) async {
          approved = true;
          return true;
        },
        broadcast: (_) async => hash,
      );
      await expectLater(
        executor.execute(
          'reference',
          expectedTransaction: Map<String, dynamic>.from(
            plan()['transaction'] as Map,
          ),
          expectedCampaignId: 'campaign',
        ),
        throwsStateError,
      );
      expect(approved, isFalse);
      client.close();
    },
  );

  test(
    'unknown submission is recovered only after matching the chain transaction',
    () async {
      var verified = false;
      final journal = MemoryJournal()
        ..entries['reference'] = {
          'wallet': wallet,
          'chainId': '56',
          'campaignId': 'campaign',
          'operation': 'set_root',
        };
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.contains('/execution')
                ? plan()
                : {'status': 'confirmed'},
          ),
          200,
        ),
      );
      final executor = BurstTransactionExecutor(
        api: api(client),
        journal: journal,
        wallet: wallet,
        chainId: 56,
        isCurrent: () async => true,
        approve: (_) async => true,
        broadcast: (_) async => throw StateError('must not sign'),
        verifyBroadcast: (_, _) async => verified,
      );
      final expected = Map<String, dynamic>.from(plan()['transaction'] as Map);
      await expectLater(
        executor.recoverUnknown(
          'reference',
          hash,
          expectedTransaction: expected,
          expectedCampaignId: 'campaign',
        ),
        throwsStateError,
      );
      expect(journal.entries['reference']!['hash'], isNull);
      verified = true;
      expect(
        (await executor.recoverUnknown(
          'reference',
          hash,
          expectedTransaction: expected,
          expectedCampaignId: 'campaign',
        )).confirmed,
        isTrue,
      );
      expect(journal.entries['reference']!['hash'], hash);
      client.close();
    },
  );
}
