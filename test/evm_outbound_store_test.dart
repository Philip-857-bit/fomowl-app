import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/evm_outbound_transaction.dart';
import 'package:fomowl_wallet/services/evm_outbound_store.dart';
import 'helpers/bitcoin_memory_store.dart';

const sender = '0x1111111111111111111111111111111111111111';
const destination = '0x2222222222222222222222222222222222222222';
String hash(int n) => '0x${n.toRadixString(16).padLeft(64, '0')}';
EvmOutboundTransaction entry(
  int id, {
  int chain = 1,
  int nonce = 7,
  int? parent,
  int? root,
  String wallet = sender,
}) => EvmOutboundTransaction(
  fields: EvmTransactionFields(
    chainId: chain,
    sender: wallet,
    nonce: nonce,
    destination: destination,
    valueWei: BigInt.one,
    dataHex: '0x',
    gasLimit: 23100,
    gasPriceWei: BigInt.from(100 + id),
  ),
  hash: hash(id),
  rootHash: root == null ? null : hash(root),
  replacesHash: parent == null ? null : hash(parent),
  state: EvmOutboundState.unknown,
  createdAt: DateTime.utc(2026, 10, 12),
);
void main() {
  test('exact public fields survive restart and submitted evidence', () async {
    final memory = MemoryStore();
    final store = EvmOutboundStore(memory);
    final original = entry(1);
    final reservation = await store.reserve(original, confirmedNonce: 7);
    store.beginProviderSend(reservation);
    await store.submitted(reservation, original.hash);
    final recovered = await EvmOutboundStore(memory).list(sender);
    expect(recovered.single.fields.toJson(), original.fields.toJson());
    expect(recovered.single.state, EvmOutboundState.submitted);
    expect(recovered.single.hash, original.hash);
    expect(memory.values.values.single, isNot(contains('privateKey')));
  });
  test(
    'unknown outcomes reserve nonce across restart; other chains and wallets remain isolated',
    () async {
      final memory = MemoryStore();
      final store = EvmOutboundStore(memory);
      await store.reserve(entry(1));
      await expectLater(
        EvmOutboundStore(memory).reserve(entry(2)),
        throwsA(isA<EvmReplacementException>()),
      );
      await store.reserve(entry(3, chain: 56));
      await store.reserve(entry(4, wallet: destination));
      expect(await store.list(sender), hasLength(2));
      expect(await store.list(destination), hasLength(1));
    },
  );
  test('only exact current parent permits one replacement', () async {
    final store = EvmOutboundStore(MemoryStore());
    await store.reserve(entry(1));
    final snapshot = (await store.snapshot(sender, 1, hash(1)))!;
    await store.reserve(entry(2, parent: 1, root: 1), replacing: snapshot);
    await expectLater(
      store.reserve(entry(3, parent: 1, root: 1), replacing: snapshot),
      throwsA(isA<EvmReplacementException>()),
    );
    final refreshed = (await store.snapshot(sender, 1, hash(1)))!;
    await expectLater(
      store.validate(refreshed),
      throwsA(isA<EvmReplacementException>()),
    );
    expect((await store.list(sender)).last.state, EvmOutboundState.unknown);
  });
  test(
    'foreign snapshot and altered nonce cannot authorize replacement',
    () async {
      final first = EvmOutboundStore(MemoryStore());
      final second = EvmOutboundStore(MemoryStore());
      await first.reserve(entry(1));
      await second.reserve(entry(1));
      final snapshot = (await first.snapshot(sender, 1, hash(1)))!;
      await expectLater(
        second.reserve(entry(2, parent: 1, root: 1), replacing: snapshot),
        throwsA(isA<EvmReplacementException>()),
      );
      await expectLater(
        first.reserve(
          entry(2, nonce: 8, parent: 1, root: 1),
          replacing: snapshot,
        ),
        throwsA(isA<EvmReplacementException>()),
      );
    },
  );
  test(
    'intervening write invalidates approval even with unchanged original fields',
    () async {
      final store = EvmOutboundStore(MemoryStore());
      final cap = await store.reserve(entry(1));
      final snapshot = (await store.snapshot(sender, 1, hash(1)))!;
      store.beginProviderSend(cap);
      await store.submitted(cap, hash(1));
      await expectLater(
        store.validate(snapshot),
        throwsA(isA<EvmReplacementException>()),
      );
    },
  );
  test(
    'wallet deletion invalidates snapshots and live reservations; explicit verified reopening starts fresh',
    () async {
      final store = EvmOutboundStore(MemoryStore());
      final cap = await store.reserve(entry(1));
      final snapshot = (await store.snapshot(sender, 1, hash(1)))!;
      await store.deleteWallet(sender);
      await expectLater(
        store.list(sender),
        throwsA(isA<EvmReplacementException>()),
      );
      await store.activate(sender);
      await store.reserve(entry(1));
      await expectLater(
        store.validate(snapshot),
        throwsA(isA<EvmReplacementException>()),
      );
      await expectLater(
        store.submitted(cap, hash(1)),
        throwsA(isA<EvmReplacementException>()),
      );
    },
  );
  test(
    'successful no-provider abort releases only its exact live reservation',
    () async {
      final store = EvmOutboundStore(MemoryStore());
      final cap = await store.reserve(entry(1));
      await store.rejectedBeforeProvider(cap);
      expect(
        (await store.list(sender)).single.state,
        EvmOutboundState.rejected,
      );
      await store.reserve(entry(2));
      await expectLater(
        store.rejectedBeforeProvider(cap),
        throwsA(isA<EvmReplacementException>()),
      );
      expect((await store.list(sender)).last.state, EvmOutboundState.unknown);
    },
  );
  test('provider hash mismatch never converts unknown to submitted', () async {
    final store = EvmOutboundStore(MemoryStore());
    final cap = await store.reserve(entry(1));
    await expectLater(
      store.submitted(cap, hash(2)),
      throwsA(isA<EvmReplacementException>()),
    );
    expect((await store.list(sender)).single.state, EvmOutboundState.unknown);
  });
  test('no-provider release capability is sealed once send starts', () async {
    final store = EvmOutboundStore(MemoryStore());
    final cap = await store.reserve(entry(1));
    store.beginProviderSend(cap);
    await expectLater(
      store.rejectedBeforeProvider(cap),
      throwsA(isA<EvmReplacementException>()),
    );
    await store.submitted(cap, hash(1));
    await expectLater(
      store.rejectedBeforeProvider(cap),
      throwsA(isA<EvmReplacementException>()),
    );
    expect((await store.list(sender)).single.state, EvmOutboundState.submitted);
  });
  test(
    'confirmed nonce advances settle only earlier entries on the same chain',
    () async {
      final store = EvmOutboundStore(MemoryStore());
      await store.reserve(entry(1));
      await store.reserve(entry(2, chain: 56));
      await store.reserve(entry(3, nonce: 8), confirmedNonce: 8);
      final records = await store.list(sender);
      expect(records[0].state, EvmOutboundState.settled);
      expect(records[1].state, EvmOutboundState.unknown);
      expect(records[2].state, EvmOutboundState.unknown);
    },
  );
  test('concurrent same-nonce sends have exactly one durable winner', () async {
    final memory = MemoryStore();
    final first = EvmOutboundStore(memory);
    final second = EvmOutboundStore(memory);
    int winners = 0;
    await Future.wait([
      first.reserve(entry(1)).then((_) {
        winners++;
      }, onError: (_) {}),
      second.reserve(entry(2)).then((_) {
        winners++;
      }, onError: (_) {}),
    ]);
    expect(winners, 1);
    expect(await first.list(sender), hasLength(1));
  });
  test(
    'dropped protected write fails before broadcast authorization',
    () async {
      final memory = MemoryStore()..dropWrites = true;
      await expectLater(
        EvmOutboundStore(memory).reserve(entry(1)),
        throwsA(isA<EvmReplacementException>()),
      );
      expect(memory.values, isEmpty);
    },
  );
  test('storage error details are redacted', () async {
    final memory = MemoryStore()..failWrites = true;
    try {
      await EvmOutboundStore(memory).reserve(entry(1));
      fail('Expected failure');
    } catch (error) {
      expect(error, isA<EvmReplacementException>());
      expect(error.toString(), isNot(contains('secret-wrapping-data')));
    }
  });
  for (final (index, raw) in [
    '{',
    jsonEncode({
      'version': 1,
      'transactions': [entry(1).toJson(), entry(1).toJson()],
    }),
    jsonEncode({'version': 99, 'transactions': []}),
    'x' * (4 * 1024 * 1024 + 1),
    jsonEncode({
      'version': 1,
      'transactions': [entry(1).toJson(), entry(2).toJson()],
    }),
    jsonEncode({
      'version': 1,
      'transactions': [entry(2, parent: 1, root: 1).toJson()],
    }),
  ].indexed) {
    test(
      'corrupt/oversized outbound history fails closed ($index, ${raw.length})',
      () async {
        final memory = MemoryStore();
        memory.values['evm_outbound_v1_$sender'] = raw;
        await expectLater(
          EvmOutboundStore(memory).list(sender),
          throwsA(isA<EvmReplacementException>()),
        );
      },
    );
  }
}
