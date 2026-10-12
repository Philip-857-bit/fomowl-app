import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_account_store.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_submission_journal.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_submission_reconciliation_service.dart';
import 'bitcoin_submission_journal_test.dart' show input;
import 'helpers/bitcoin_memory_store.dart';

final hash = '33' * 32;
const identity = '0xwallet';
const mainnet = BitcoinProductNetwork.mainnet;
const testnet = BitcoinProductNetwork.testnet4;

Map<String, dynamic> statusJson({bool found = true, bool confirmed = true}) => {
  'status': confirmed ? 'confirmed' : 'pending',
  'found': found,
  'confirmed': confirmed,
  'confirmations': confirmed ? 1 : 0,
  'blockHeight': confirmed ? 10 : null,
  'blockHash': confirmed ? 'aa' * 32 : null,
  'timestamp': null,
};
BitcoinTransactionStatus confirmed() =>
    BitcoinTransactionStatus.fromJson(statusJson());

class StatusNetwork extends Fake implements BitcoinNetworkApi {
  final values = <String, Object>{};
  final calls = <(BitcoinProductNetwork, String)>[];
  Completer<BitcoinTransactionStatus>? gate;
  final started = Completer<void>();
  @override
  Future<BitcoinTransactionStatus> fetchTransactionStatus(
    BitcoinProductNetwork network,
    String txid,
  ) async {
    calls.add((network, txid));
    if (!started.isCompleted) started.complete();
    if (gate != null) return gate!.future;
    final value = values[txid] ?? statusJson();
    if (value is Map<String, dynamic>) {
      return BitcoinTransactionStatus.fromJson(value);
    }
    throw value;
  }
}

Future<
  ({
    MemoryStore memory,
    BitcoinSubmissionJournal journal,
    StatusNetwork api,
    BitcoinSubmissionReconciliationService service,
  })
>
fixture({
  BitcoinProductNetwork network = mainnet,
  int maximumChecks = 32,
  Duration requestTimeout = const Duration(seconds: 8),
  Duration batchTimeout = const Duration(seconds: 30),
}) async {
  final memory = MemoryStore();
  final journal = BitcoinSubmissionJournal(BitcoinAccountStore(memory));
  await journal.reserve(identity, network, hash, [input()]);
  final api = StatusNetwork();
  return (
    memory: memory,
    journal: journal,
    api: api,
    service: BitcoinSubmissionReconciliationService(
      journal: journal,
      network: api,
      maximumChecks: maximumChecks,
      requestTimeout: requestTimeout,
      batchTimeout: batchTimeout,
    ),
  );
}

void main() {
  for (final network in BitcoinProductNetwork.values) {
    test(
      'confirmed exact entry prunes on ${network.id}, preserving other scopes and restart',
      () async {
        final f = await fixture(network: network);
        final otherNetwork = network == mainnet ? testnet : mainnet;
        await f.journal.reserve(identity, otherNetwork, hash, [input()]);
        await f.journal.reserve('0xother', network, hash, [input()]);
        await f.journal.reserve(identity, network, '44' * 32, [input(vout: 1)]);
        f.api.values['44' * 32] = statusJson(confirmed: false);
        expect(
          await f.service.reconcile(identity, network, isCurrent: () => true),
          1,
        );
        expect(await f.journal.reserved(identity, network), {'${'11' * 32}:1'});
        expect(await f.journal.reserved(identity, otherNetwork), {
          '${'11' * 32}:0',
        });
        expect(await f.journal.reserved('0xother', network), {
          '${'11' * 32}:0',
        });
        final restarted = MemoryStore()..values.addAll(f.memory.values);
        final restored = BitcoinSubmissionJournal(
          BitcoinAccountStore(restarted),
        );
        expect(
          (await restored.pending(
            identity,
            network,
          )).map((entry) => entry.txid),
          ['44' * 32],
        );
        expect(f.api.calls.every((call) => call.$1 == network), isTrue);
      },
    );
  }
  for (final condition in [
    'pending',
    'absent',
    'timeout',
    '429',
    '500',
    '503',
    'malformed',
    'zero-confirmations',
    'not-found-confirmed',
  ]) {
    test('$condition always keeps the reservation', () async {
      final f = await fixture();
      f.api.values[hash] = switch (condition) {
        'pending' => statusJson(confirmed: false),
        'absent' => statusJson(confirmed: false, found: false),
        'timeout' => TimeoutException('timeout'),
        '429' => const BitcoinNetworkException(429),
        '500' => const BitcoinNetworkException(500),
        '503' => const BitcoinNetworkException(503),
        'zero-confirmations' => statusJson()..['confirmations'] = 0,
        'not-found-confirmed' => statusJson(found: false),
        _ => {'status': 'confirmed'},
      };
      expect(
        await f.service.reconcile(identity, mainnet, isCurrent: () => true),
        0,
      );
      expect(await f.journal.reserved(identity, mainnet), {'${'11' * 32}:0'});
      expect(f.api.calls, [(mainnet, hash)]);
    });
  }
  test(
    'actual hanging request is bounded and a late confirmation never releases',
    () async {
      final f = await fixture(requestTimeout: const Duration(milliseconds: 10));
      f.api.gate = Completer();
      expect(
        await f.service.reconcile(identity, mainnet, isCurrent: () => true),
        0,
      );
      f.api.gate!.complete(confirmed());
      expect(await f.journal.reserved(identity, mainnet), {'${'11' * 32}:0'});
    },
  );
  test(
    'stale lookup cannot delete a later reservation with identical txid and inputs',
    () async {
      final f = await fixture();
      final old = (await f.journal.pending(identity, mainnet)).single;
      f.api.gate = Completer();
      final operation = f.service.reconcile(
        identity,
        mainnet,
        isCurrent: () => true,
      );
      await f.api.started.future;
      expect(
        await f.journal.reconcileConfirmed(
          old,
          confirmed(),
          isCurrent: () => true,
        ),
        isTrue,
      );
      await f.journal.reserve(identity, mainnet, hash, [input()]);
      f.api.gate!.complete(confirmed());
      expect(await operation, 0);
      expect(await f.journal.reserved(identity, mainnet), {'${'11' * 32}:0'});
    },
  );
  test(
    'stale snapshot from another wrapper and foreign storage cannot remove entries',
    () async {
      final f = await fixture();
      final old = (await f.journal.pending(identity, mainnet)).single;
      final wrapper = BitcoinSubmissionJournal(BitcoinAccountStore(f.memory));
      await wrapper.store.updateSubmissionState(identity, (raw) => (true, raw));
      expect(
        await wrapper.reconcileConfirmed(
          old,
          confirmed(),
          isCurrent: () => true,
        ),
        isFalse,
      );
      final foreign = await fixture();
      await expectLater(
        foreign.journal.reconcileConfirmed(
          old,
          confirmed(),
          isCurrent: () => true,
        ),
        throwsStateError,
      );
      expect(await f.journal.reserved(identity, mainnet), {'${'11' * 32}:0'});
      expect(await foreign.journal.reserved(identity, mainnet), {
        '${'11' * 32}:0',
      });
    },
  );
  test(
    'multiple confirmed entries prune in one batch with fresh observations',
    () async {
      final f = await fixture();
      await f.journal.reserve(identity, mainnet, '44' * 32, [input(vout: 1)]);
      expect(
        await f.service.reconcile(identity, mainnet, isCurrent: () => true),
        2,
      );
      expect(await f.journal.reserved(identity, mainnet), isEmpty);
      expect(
        await f.service.reconcile(identity, mainnet, isCurrent: () => true),
        0,
      );
      expect(f.api.calls.length, 2);
    },
  );
  test(
    'bounded batches rotate past unresolved entries instead of starving later confirmations',
    () async {
      final f = await fixture(maximumChecks: 1);
      f.api.values[hash] = statusJson(confirmed: false);
      await f.journal.reserve(identity, mainnet, '44' * 32, [input(vout: 1)]);
      expect(
        await f.service.reconcile(identity, mainnet, isCurrent: () => true),
        0,
      );
      expect(
        await f.service.reconcile(identity, mainnet, isCurrent: () => true),
        1,
      );
      expect(await f.journal.reserved(identity, mainnet), {'${'11' * 32}:0'});
    },
  );
  test(
    'coalesces concurrent wrappers without duplicate status requests',
    () async {
      final f = await fixture();
      f.api.gate = Completer();
      final first = f.service.reconcile(
        identity,
        mainnet,
        isCurrent: () => true,
      );
      await f.api.started.future;
      final second = BitcoinSubmissionReconciliationService(
        journal: BitcoinSubmissionJournal(BitcoinAccountStore(f.memory)),
        network: f.api,
      ).reconcile(identity, mainnet, isCurrent: () => true);
      f.api.gate!.complete(confirmed());
      expect(await first, 1);
      expect(await second, 1);
      expect(f.api.calls.length, 1);
    },
  );
  test('wallet switch during lookup preserves exact reservation', () async {
    final f = await fixture();
    var current = true;
    f.api.gate = Completer();
    final operation = f.service.reconcile(
      identity,
      mainnet,
      isCurrent: () => current,
    );
    await f.api.started.future;
    current = false;
    f.api.gate!.complete(confirmed());
    expect(await operation, 0);
    expect(await f.journal.reserved(identity, mainnet), {'${'11' * 32}:0'});
  });
  test('expired batch is a cancellation condition, never release evidence', () {
    fakeAsync((clock) {
      int? result;
      late StatusNetwork api;
      late BitcoinSubmissionJournal journal;
      fixture(batchTimeout: const Duration(milliseconds: 5)).then((f) {
        api = f.api;
        journal = f.journal;
        api.gate = Completer();
        f.service
            .reconcile(identity, mainnet, isCurrent: () => true)
            .then((value) => result = value);
      });
      clock.flushMicrotasks();
      expect(api.started.isCompleted, isTrue);
      clock.elapse(const Duration(milliseconds: 5));
      api.gate!.complete(confirmed());
      clock.flushMicrotasks();
      expect(result, 0);
      Set<String>? reserved;
      journal.reserved(identity, mainnet).then((value) => reserved = value);
      clock.flushMicrotasks();
      expect(reserved, {'${'11' * 32}:0'});
    });
  });
  test(
    'failed persistence, corruption and changed persisted input set fail closed',
    () async {
      final f = await fixture();
      f.memory.dropWrites = true;
      expect(
        await f.service.reconcile(identity, mainnet, isCurrent: () => true),
        0,
      );
      expect(await f.journal.reserved(identity, mainnet), {'${'11' * 32}:0'});
      f.memory.dropWrites = false;
      final snapshot = (await f.journal.pending(identity, mainnet)).single;
      final key = f.memory.values.keys.single;
      final document =
          jsonDecode(f.memory.values[key]!) as Map<String, dynamic>;
      document['entries']['mainnet|$hash'] = ['${'11' * 32}:1'];
      f.memory.values[key] = jsonEncode(document);
      expect(
        await f.journal.reconcileConfirmed(
          snapshot,
          confirmed(),
          isCurrent: () => true,
        ),
        isFalse,
      );
      f.memory.values[key] = '{corrupted';
      await expectLater(
        f.service.reconcile(identity, mainnet, isCurrent: () => true),
        throwsFormatException,
      );
      expect(f.memory.values[key], '{corrupted');
    },
  );
  test(
    'a live submission retains rejection ownership until its submitter finishes',
    () async {
      final memory = MemoryStore();
      final journal = BitcoinSubmissionJournal(BitcoinAccountStore(memory));
      final live = (await journal.reserveAttempt(identity, mainnet, hash, [
        input(),
      ]))!;
      final snapshot = (await journal.pending(identity, mainnet)).single;
      expect(
        await journal.reconcileConfirmed(
          snapshot,
          confirmed(),
          isCurrent: () => true,
        ),
        isFalse,
      );
      journal.retainPending(live);
      expect(
        await journal.reconcileConfirmed(
          snapshot,
          confirmed(),
          isCurrent: () => true,
        ),
        isTrue,
      );
    },
  );
  test(
    'confirmed legacy entry prunes without widening manual Testnet4 recovery',
    () async {
      final memory = MemoryStore();
      memory.values['bitcoin_submission_v1_$identity'] = jsonEncode({
        'version': 1,
        'identity': identity,
        'entries': {
          'mainnet|$hash': ['${'11' * 32}:0'],
        },
      });
      final journal = BitcoinSubmissionJournal(BitcoinAccountStore(memory));
      final snapshot = (await journal.pending(identity, mainnet)).single;
      expect(snapshot.legacy, isTrue);
      await expectLater(
        journal.recoverLegacyTestnet4(snapshot, checkAuthorization: () {}),
        throwsStateError,
      );
      expect(
        await journal.reconcileConfirmed(
          snapshot,
          confirmed(),
          isCurrent: () => true,
        ),
        isTrue,
      );
      expect(await journal.reserved(identity, mainnet), isEmpty);
    },
  );
  test(
    'wallet deletion invalidates an in-flight observation before restoration',
    () async {
      final f = await fixture();
      f.api.gate = Completer();
      final operation = f.service.reconcile(
        identity,
        mainnet,
        isCurrent: () => true,
      );
      await f.api.started.future;
      await f.journal.store.deleteWallet(identity);
      await f.journal.store.activateWallet(identity);
      await f.journal.reserve(identity, mainnet, hash, [input()]);
      f.api.gate!.complete(confirmed());
      expect(await operation, 0);
      expect(await f.journal.reserved(identity, mainnet), {'${'11' * 32}:0'});
    },
  );
}
