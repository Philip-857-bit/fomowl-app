import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_account_store.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_submission_journal.dart';
import 'package:fomowl_wallet/src/rust/api/bitcoin_account.dart';
import 'package:fomowl_wallet/src/rust/api/bitcoin_transaction.dart';
import 'helpers/bitcoin_memory_store.dart';

BitcoinUtxoDto input({int vout = 0, String? txid}) => BitcoinUtxoDto(
  txid: txid ?? '11' * 32,
  vout: vout,
  valueSat: BigInt.from(10000),
  scriptPubkeyHex: '0014${'22' * 20}',
  keychain: BitcoinKeychainDto.external_,
  addressIndex: 0,
);
void main() {
  test(
    'atomic reservation blocks competing transactions and survives wrapper restart',
    () async {
      final memory = MemoryStore();
      final first = BitcoinSubmissionJournal(BitcoinAccountStore(memory));
      final second = BitcoinSubmissionJournal(BitcoinAccountStore(memory));
      final attempted = first.reserve(
        '0xwallet',
        BitcoinProductNetwork.mainnet,
        '33' * 32,
        [input()],
      );
      final competing = second.reserve(
        '0xwallet',
        BitcoinProductNetwork.mainnet,
        '44' * 32,
        [input()],
      );
      final rejected = expectLater(competing, throwsStateError);
      expect(await attempted, isTrue);
      await rejected;
      expect(await second.reserved('0xwallet', BitcoinProductNetwork.mainnet), {
        '${'11' * 32}:0',
      });
      expect(
        await second.reserve(
          '0xwallet',
          BitcoinProductNetwork.mainnet,
          '33' * 32,
          [input()],
        ),
        isFalse,
      );
      expect(
        await second.reserved('0xwallet', BitcoinProductNetwork.testnet4),
        isEmpty,
      );
      await second.store.deleteWallet('0xwallet');
      expect(
        memory.values.keys.where((key) => key.startsWith('bitcoin_submission')),
        isEmpty,
      );
      await expectLater(
        first.reserve('0xwallet', BitcoinProductNetwork.mainnet, '55' * 32, [
          input(),
        ]),
        throwsStateError,
      );
    },
  );
  test(
    'corrupt and transplanted journals fail closed; dropped persistence prevents submission',
    () async {
      final memory = MemoryStore();
      final journal = BitcoinSubmissionJournal(BitcoinAccountStore(memory));
      await journal.reserve(
        '0xwallet',
        BitcoinProductNetwork.mainnet,
        '33' * 32,
        [input()],
      );
      final key = memory.values.keys.single;
      memory.values['bitcoin_submission_v1_0xother'] = memory.values[key]!;
      await expectLater(
        journal.reserved('0xother', BitcoinProductNetwork.mainnet),
        throwsFormatException,
      );
      memory.values[key] = '{invalid';
      await expectLater(
        journal.reserved('0xwallet', BitcoinProductNetwork.mainnet),
        throwsFormatException,
      );
      final dropped = BitcoinSubmissionJournal(
        BitcoinAccountStore(MemoryStore()..dropWrites = true),
      );
      await expectLater(
        dropped.reserve('0xwallet', BitcoinProductNetwork.mainnet, '33' * 32, [
          input(),
        ]),
        throwsStateError,
      );
    },
  );
  test(
    'exact compare-and-release preserves other transactions/networks and stale release cannot clear a later attempt',
    () async {
      final store = BitcoinAccountStore(MemoryStore());
      final journal = BitcoinSubmissionJournal(store);
      final inputs = [input(), input(vout: 1)];
      final first = (await journal.reserveAttempt(
        '0xwallet',
        BitcoinProductNetwork.mainnet,
        '33' * 32,
        inputs,
      ))!;
      expect(
        () => jsonEncode(first),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      await journal.reserve(
        '0xwallet',
        BitcoinProductNetwork.mainnet,
        '44' * 32,
        [input(txid: '22' * 32)],
      );
      await journal.reserve(
        '0xwallet',
        BitcoinProductNetwork.testnet4,
        '33' * 32,
        inputs,
      );
      Future<bool> release(BitcoinSubmissionReservation owner) =>
          journal.releaseRejected(
            reservation: owner,
            identity: '0xwallet',
            network: BitcoinProductNetwork.mainnet,
            txid: '33' * 32,
            expectedInputs: inputs.reversed.toList(),
          );
      expect(await release(first), isTrue);
      expect(
        await journal.reserved('0xwallet', BitcoinProductNetwork.mainnet),
        {'${'22' * 32}:0'},
      );
      expect(
        await journal.reserved('0xwallet', BitcoinProductNetwork.testnet4),
        {'${'11' * 32}:0', '${'11' * 32}:1'},
      );
      final next = (await journal.reserveAttempt(
        '0xwallet',
        BitcoinProductNetwork.mainnet,
        '33' * 32,
        inputs,
      ))!;
      expect(await release(first), isFalse);
      expect(
        await journal.reserved('0xwallet', BitcoinProductNetwork.mainnet),
        contains('${'11' * 32}:0'),
      );
      journal.retainPending(next);
      await expectLater(release(next), throwsStateError);
      expect(
        await journal.reserved('0xwallet', BitcoinProductNetwork.mainnet),
        contains('${'11' * 32}:0'),
      );
    },
  );
  test(
    'wrong wallet/network/txid/store/input set cannot release a live attempt',
    () async {
      final journal = BitcoinSubmissionJournal(
        BitcoinAccountStore(MemoryStore()),
      );
      final inputs = [input(), input(vout: 1)];
      final owner = (await journal.reserveAttempt(
        '0xwallet',
        BitcoinProductNetwork.mainnet,
        '33' * 32,
        inputs,
      ))!;
      for (final caseValue in [
        ('other-wallet', BitcoinProductNetwork.mainnet, '33' * 32, inputs),
        ('0xwallet', BitcoinProductNetwork.testnet4, '33' * 32, inputs),
        ('0xwallet', BitcoinProductNetwork.mainnet, '44' * 32, inputs),
        ('0xwallet', BitcoinProductNetwork.mainnet, '33' * 32, [input()]),
        (
          '0xwallet',
          BitcoinProductNetwork.mainnet,
          '33' * 32,
          [input(), input(vout: 2)],
        ),
      ]) {
        await expectLater(
          journal.releaseRejected(
            reservation: owner,
            identity: caseValue.$1,
            network: caseValue.$2,
            txid: caseValue.$3,
            expectedInputs: caseValue.$4,
          ),
          throwsStateError,
        );
      }
      await expectLater(
        BitcoinSubmissionJournal(
          BitcoinAccountStore(MemoryStore()),
        ).releaseRejected(
          reservation: owner,
          identity: '0xwallet',
          network: BitcoinProductNetwork.mainnet,
          txid: '33' * 32,
          expectedInputs: inputs,
        ),
        throwsStateError,
      );
      expect(
        await journal.reserved('0xwallet', BitcoinProductNetwork.mainnet),
        {'${'11' * 32}:0', '${'11' * 32}:1'},
      );
    },
  );
  test(
    'failed release persistence fails closed and restart retains the durable entry',
    () async {
      final memory = MemoryStore();
      final journal = BitcoinSubmissionJournal(BitcoinAccountStore(memory));
      final owner = (await journal.reserveAttempt(
        '0xwallet',
        BitcoinProductNetwork.mainnet,
        '33' * 32,
        [input()],
      ))!;
      memory.dropWrites = true;
      await expectLater(
        journal.releaseRejected(
          reservation: owner,
          identity: '0xwallet',
          network: BitcoinProductNetwork.mainnet,
          txid: '33' * 32,
          expectedInputs: [input()],
        ),
        throwsStateError,
      );
      final restarted = MemoryStore()..values.addAll(memory.values);
      final restored = BitcoinSubmissionJournal(BitcoinAccountStore(restarted));
      expect(
        await restored.reserved('0xwallet', BitcoinProductNetwork.mainnet),
        {'${'11' * 32}:0'},
      );
      expect(
        await restored.reserveAttempt(
          '0xwallet',
          BitcoinProductNetwork.mainnet,
          '33' * 32,
          [input()],
        ),
        isNull,
      );
      await expectLater(
        restored.releaseRejected(
          reservation: owner,
          identity: '0xwallet',
          network: BitcoinProductNetwork.mainnet,
          txid: '33' * 32,
          expectedInputs: [input()],
        ),
        throwsStateError,
      );
    },
  );
}
