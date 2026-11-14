import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/mini_apps/cashin_execution_submission.dart';
import 'helpers/bitcoin_memory_store.dart';

void main() {
  const hash =
      '0xb51d9a2ec0ceda453dab9d26ab9750089a85f0ac09084391dc12e72accd54d2a';
  late MemoryStore store;
  late CashinExecutionSubmission submission;
  final key = cashinExecutionSubmissionKey(
    reference: 'OWL-PAY-test',
    routeId: 'route',
    stepId: 'step',
    walletAddress: '0xabc',
    chainId: 8453,
  );

  setUp(() async {
    store = MemoryStore();
    submission = CashinExecutionSubmission(store);
  });

  test(
    'payment checkpoint recovers a hash before any execution-plan lookup',
    () async {
      final contextKey = cashinExecutionSubmissionContextKey(
        reference: 'OWL-PAY-test',
        routeId: 'route',
        walletAddress: '0xabc',
      );
      await expectLater(
        submission.run(
          key: key,
          contextKey: contextKey,
          broadcast: (before, abort) async {
            await before(hash);
            throw TimeoutException('provider response lost');
          },
          record: (_) async {},
        ),
        throwsA(isA<CashinExecutionPendingException>()),
      );
      expect(
        await CashinExecutionSubmission(store).savedHash(contextKey),
        hash,
      );
    },
  );

  test(
    'abort restores earlier payment evidence without releasing an earlier step',
    () async {
      const previous =
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const contextKey = 'payment-context';
      store.values[contextKey] = previous;
      await expectLater(
        submission.run(
          key: key,
          contextKey: contextKey,
          broadcast: (before, abort) async {
            await before(hash);
            await abort();
            throw StateError('aborted before provider send');
          },
          record: (_) async {},
        ),
        throwsStateError,
      );
      expect(await submission.savedHash(key), isNull);
      expect(await submission.savedHash(contextKey), previous);
    },
  );

  test(
    'record failure and app restart never create a second transfer',
    () async {
      var broadcasts = 0;
      Future<String> broadcast(
        Future<void> Function(String) before,
        Future<void> Function() abort,
      ) async {
        broadcasts++;
        await before(hash);
        expect(await submission.savedHash(key), hash);
        return hash;
      }

      await expectLater(
        submission.run(
          key: key,
          broadcast: broadcast,
          record: (_) async => throw TimeoutException('registration timed out'),
        ),
        throwsA(
          isA<CashinExecutionPendingException>().having(
            (e) => e.transactionHash,
            'original hash',
            hash,
          ),
        ),
      );
      // A new coordinator models closing and reopening the mini-app/app.
      final reopened = CashinExecutionSubmission(store);
      String? registered;
      expect(
        await reopened.run(
          key: key,
          broadcast: broadcast,
          record: (h) async {
            registered = h;
          },
        ),
        hash,
      );
      expect(registered, hash);
      expect(broadcasts, 1);
    },
  );

  test(
    'provider timeout after signing retains the deterministic hash',
    () async {
      await expectLater(
        submission.run(
          key: key,
          broadcast: (before, abort) async {
            await before(hash);
            throw TimeoutException('RPC response lost');
          },
          record: (_) async => fail('Not recorded yet'),
        ),
        throwsA(isA<CashinExecutionPendingException>()),
      );
      expect(
        await submission.run(
          key: key,
          broadcast: (_, _) async => throw StateError('Must not resend'),
          record: (h) async => expect(h, hash),
        ),
        hash,
      );
    },
  );

  test('concurrent requests share one broadcast and registration', () async {
    final release = Completer<void>();
    var broadcasts = 0;
    var records = 0;
    Future<String> execute() => submission.run(
      key: key,
      broadcast: (before, abort) async {
        broadcasts++;
        await before(hash);
        await release.future;
        return hash;
      },
      record: (_) async {
        records++;
      },
    );
    final a = execute();
    final b = execute();
    release.complete();
    expect(await Future.wait([a, b]), [hash, hash]);
    expect(broadcasts, 1);
    expect(records, 1);
  });

  test('signing failure before broadcast leaves the step retryable', () async {
    await expectLater(
      submission.run(
        key: key,
        broadcast: (_, _) async => throw StateError('Signing rejected'),
        record: (_) async {},
      ),
      throwsStateError,
    );
    expect(await submission.savedHash(key), isNull);
  });

  test(
    'a confirmed abort before provider send releases the reservation',
    () async {
      await expectLater(
        submission.run(
          key: key,
          broadcast: (before, abort) async {
            await before(hash);
            await abort();
            throw StateError('Aborted before provider send');
          },
          record: (_) async {},
        ),
        throwsStateError,
      );
      expect(await submission.savedHash(key), isNull);
    },
  );

  test('saved hash scopes include wallet, route, step and chain', () {
    expect(
      cashinExecutionSubmissionKey(
        reference: 'OWL-PAY-test',
        routeId: 'route',
        stepId: 'step',
        walletAddress: '0xABC',
        chainId: 8453,
      ),
      key,
    );
    for (final other in [
      cashinExecutionSubmissionKey(
        reference: 'other',
        routeId: 'route',
        stepId: 'step',
        walletAddress: '0xabc',
        chainId: 8453,
      ),
      cashinExecutionSubmissionKey(
        reference: 'OWL-PAY-test',
        routeId: 'other',
        stepId: 'step',
        walletAddress: '0xabc',
        chainId: 8453,
      ),
      cashinExecutionSubmissionKey(
        reference: 'OWL-PAY-test',
        routeId: 'route',
        stepId: 'other',
        walletAddress: '0xabc',
        chainId: 8453,
      ),
      cashinExecutionSubmissionKey(
        reference: 'OWL-PAY-test',
        routeId: 'route',
        stepId: 'step',
        walletAddress: '0xdef',
        chainId: 8453,
      ),
      cashinExecutionSubmissionKey(
        reference: 'OWL-PAY-test',
        routeId: 'route',
        stepId: 'step',
        walletAddress: '0xabc',
        chainId: 1,
      ),
    ]) {
      expect(other, isNot(key));
    }
  });

  for (final silentlyDropped in [false, true]) {
    test(
      'unavailable storage prevents provider send (dropped=$silentlyDropped)',
      () async {
        store.failWrites = !silentlyDropped;
        store.dropWrites = silentlyDropped;
        var providerSends = 0;
        await expectLater(
          submission.run(
            key: key,
            broadcast: (before, abort) async {
              await before(hash);
              providerSends++;
              return hash;
            },
            record: (_) async => fail('Must not record an unsent transfer'),
          ),
          throwsStateError,
        );
        expect(providerSends, 0);
      },
    );
  }

  test(
    'a mismatched RPC hash retains the original instead of resending',
    () async {
      await expectLater(
        submission.run(
          key: key,
          broadcast: (before, abort) async {
            await before(hash);
            return '0x${'a' * 64}';
          },
          record: (_) async => fail('Must not register a mismatched hash'),
        ),
        throwsA(isA<CashinExecutionPendingException>()),
      );
      expect(await submission.savedHash(key), hash);
    },
  );
}
