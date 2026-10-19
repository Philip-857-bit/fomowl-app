import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/models/bitcoin_offramp_intent.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_account_store.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_offramp_journal.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_submission_journal.dart';
import 'helpers/bitcoin_memory_store.dart';

const identity = '0xabc';
const reference = 'OWL-PAY-1234567890';
BitcoinOfframpIntent intent() =>
    BitcoinOfframpIntent.fromWithdrawalPlan(reference, {
      'reference': reference,
      'action': 'transfer',
      'networkKey': 'bitcoin:mainnet',
      'chainFamily': 'bitcoin',
      'assetSymbol': 'BTC',
      'nativeSymbol': 'BTC',
      'decimals': 8,
      'fundingExpiresAt': '2099-01-01T00:00:00Z',
      'amountBaseUnits': '4730',
      'toAddress':
          'bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr',
    });
BitcoinPreProviderRejection
rejection() => BitcoinPreProviderRejection.fromBackendResponse(
  403,
  '{"error":"Forbidden","message":"The wallet session does not match the requested wallet."}',
)!;
BitcoinTransactionStatus status({bool found = true, bool confirmed = true}) =>
    BitcoinTransactionStatus.fromJson({
      'found': found,
      'confirmed': confirmed,
      'status': confirmed ? 'confirmed' : 'pending',
      'confirmations': confirmed ? 1 : 0,
      'blockHeight': confirmed ? 100 : null,
      'blockHash': confirmed ? '22' * 32 : null,
    });

void main() {
  test(
    'legacy display receipts never become verified payment evidence',
    () async {
      final store = BitcoinAccountStore(MemoryStore());
      final alias = '11' * 32;
      await store.updateSubmissionState(
        identity,
        (_) => (
          null,
          jsonEncode({
            'version': 3,
            'identity': identity,
            'entries': {},
            'legacyEntries': [],
            'outbound': {},
            'resolved': {
              'mainnet|$alias': {
                'txid': '22' * 32,
                'feeSat': '141',
                'recipientTotalSat': '4730',
              },
            },
          }),
        ),
      );
      final ledger = BitcoinSubmissionJournal(store);
      expect(
        (await ledger.resolvedAliases(
          identity,
          BitcoinProductNetwork.mainnet,
        ))[alias]!.txid,
        '22' * 32,
      );
      expect(
        await ledger.resolvedPayment(
          identity,
          BitcoinProductNetwork.mainnet,
          alias,
        ),
        isNull,
      );
    },
  );
  test(
    'one reference claim wins across concurrent wrappers and restart',
    () async {
      final memory = MemoryStore();
      final first = BitcoinOfframpJournal(BitcoinAccountStore(memory));
      final second = BitcoinOfframpJournal(BitcoinAccountStore(memory));
      final results = await Future.wait([
        first
            .reserve(identity, intent(), '11' * 32)
            .then((_) => true, onError: (_) => false),
        second
            .reserve('0xABC', intent(), '33' * 32)
            .then((_) => true, onError: (_) => false),
      ]);
      expect(results.where((won) => won).length, 1);
      final saved = await BitcoinOfframpJournal(
        BitcoinAccountStore(memory),
      ).read(identity, reference);
      expect(saved, isNotNull);
      expect(saved!.accepted, isFalse);
      await expectLater(
        second.reserve(identity, intent(), '44' * 32),
        throwsStateError,
      );
      expect(await second.read('0xother', reference), isNull);
    },
  );

  test(
    'rejection capability is exact, single-use and cannot clear a later claim',
    () async {
      final memory = MemoryStore();
      final journal = BitcoinOfframpJournal(BitcoinAccountStore(memory));
      final old = await journal.reserve(identity, intent(), '11' * 32);
      final foreign = BitcoinOfframpJournal(BitcoinAccountStore(memory));
      expect(await foreign.releaseRejected(old, rejection()), isFalse);
      expect(await journal.releaseRejected(old, rejection()), isTrue);
      await journal.reserve(identity, intent(), '11' * 32);
      expect(await journal.releaseRejected(old, rejection()), isFalse);
      expect(await journal.read(identity, reference), isNotNull);
    },
  );

  test(
    'accepted and uncertain attempts never gain a later rejection capability',
    () async {
      for (final accepted in [true, false]) {
        final journal = BitcoinOfframpJournal(
          BitcoinAccountStore(MemoryStore()),
        );
        final attempt = await journal.reserve(identity, intent(), '11' * 32);
        if (accepted) {
          await journal.markAccepted(attempt);
        } else {
          journal.retainPending(attempt);
        }
        expect(await journal.releaseRejected(attempt, rejection()), isFalse);
        expect((await journal.read(identity, reference))!.accepted, accepted);
      }
    },
  );

  test(
    'only exact positive confirmation plus backend acknowledgement reconciles',
    () async {
      final journal = BitcoinOfframpJournal(BitcoinAccountStore(MemoryStore()));
      await journal.reserve(identity, intent(), '11' * 32);
      final saved = (await journal.read(identity, reference))!;
      for (final observation in [
        status(found: false, confirmed: false),
        status(confirmed: false),
      ]) {
        expect(
          await journal.reconcileConfirmed(
            saved,
            network: BitcoinProductNetwork.mainnet,
            observedTxid: saved.txid,
            status: observation,
            backendAcknowledged: true,
          ),
          isFalse,
        );
      }
      expect(
        await journal.reconcileConfirmed(
          saved,
          network: BitcoinProductNetwork.testnet4,
          observedTxid: saved.txid,
          status: status(),
          backendAcknowledged: true,
        ),
        isFalse,
      );
      expect(
        await journal.reconcileConfirmed(
          saved,
          network: BitcoinProductNetwork.mainnet,
          observedTxid: '33' * 32,
          status: status(),
          backendAcknowledged: true,
        ),
        isFalse,
      );
      expect(
        await journal.reconcileConfirmed(
          saved,
          network: BitcoinProductNetwork.mainnet,
          observedTxid: saved.txid,
          status: status(),
          backendAcknowledged: false,
        ),
        isFalse,
      );
      expect(
        await journal.reconcileConfirmed(
          saved,
          network: BitcoinProductNetwork.mainnet,
          observedTxid: saved.txid,
          status: status(),
          backendAcknowledged: true,
        ),
        isTrue,
      );
      await journal.reserve(identity, intent(), saved.txid);
      expect(
        await journal.reconcileConfirmed(
          saved,
          network: BitcoinProductNetwork.mainnet,
          observedTxid: saved.txid,
          status: status(),
          backendAcknowledged: true,
        ),
        isFalse,
      );
    },
  );

  test(
    'corrupt/transplanted state is never reset into a sendable reference',
    () async {
      final memory = MemoryStore();
      final journal = BitcoinOfframpJournal(BitcoinAccountStore(memory));
      await journal.reserve(identity, intent(), '11' * 32);
      final key = memory.values.keys.singleWhere(
        (key) => key.startsWith('bitcoin_offramp_'),
      );
      final data = jsonDecode(memory.values[key]!) as Map<String, dynamic>;
      data['walletIdentity'] = '0xother';
      memory.values[key] = jsonEncode(data);
      await expectLater(
        journal.read(identity, reference),
        throwsFormatException,
      );
      await expectLater(
        journal.reserve(identity, intent(), '33' * 32),
        throwsFormatException,
      );
    },
  );

  test('failed durable claim does not authorize payment', () async {
    final memory = MemoryStore()..dropWrites = true;
    final journal = BitcoinOfframpJournal(BitcoinAccountStore(memory));
    await expectLater(
      journal.reserve(identity, intent(), '11' * 32),
      throwsStateError,
    );
  });

  test('malformed journal errors do not expose the stored payload', () async {
    final memory = MemoryStore();
    final journal = BitcoinOfframpJournal(BitcoinAccountStore(memory));
    await journal.reserve(identity, intent(), '11' * 32);
    final key = memory.values.keys.singleWhere(
      (key) => key.startsWith('bitcoin_offramp_'),
    );
    memory.values[key] = '{"reference":"private-fixture';
    await expectLater(
      journal.read(identity, reference),
      throwsA(
        isA<FormatException>().having(
          (error) => error.toString(),
          'redacted error',
          isNot(contains('private-fixture')),
        ),
      ),
    );
  });
}
