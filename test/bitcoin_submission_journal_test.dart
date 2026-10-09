import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_account_store.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_submission_journal.dart';
import 'package:fomowl_wallet/src/rust/api/bitcoin_account.dart';
import 'package:fomowl_wallet/src/rust/api/bitcoin_transaction.dart';
import 'helpers/bitcoin_memory_store.dart';

BitcoinUtxoDto input() => BitcoinUtxoDto(
  txid: '11' * 32,
  vout: 0,
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
}
