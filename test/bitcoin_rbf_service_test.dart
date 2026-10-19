@Tags(['ffi'])
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_account_store.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_broadcast_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_rbf_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_saved_transaction.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_submission_journal.dart';
import 'package:fomowl_wallet/models/bitcoin_offramp_intent.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_offramp_journal.dart';
import 'package:fomowl_wallet/services/wallet_vault_service.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'helpers/bitcoin_memory_store.dart';
import 'helpers/bitcoin_rbf_fixture.dart';

bool current() => true;
BitcoinRbfService service(RbfFixture fixture, {DateTime Function()? now}) =>
    BitcoinRbfService(
      store: fixture.store,
      network: fixture.network,
      signing: fixture.signing,
      now: now,
    );
Future<BitcoinPreparedReplacement> prepare(
  BitcoinRbfService coordinator,
  RbfFixture fixture, {
  int rate = 3,
}) => coordinator.prepare(
  RbfFixture.identity,
  fixture.original.transfer.network,
  fixture.original.transaction.txid,
  BigInt.from(rate),
  isCurrent: current,
);
Future<bool> unlock() async {
  WalletVaultService.unlock();
  return true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => RustLib.init());
  test(
    'verified mainnet RBF winner reconciles only its exact cash-out intent',
    () async {
      final f = await rbfFixture(network: BitcoinProductNetwork.mainnet);
      const reference = 'OWL-PAY-rbf-test';
      final recipient = f.original.transfer.plan.recipients.single;
      final intent = BitcoinOfframpIntent.fromWithdrawalPlan(reference, {
        'reference': reference,
        'action': 'transfer',
        'networkKey': 'bitcoin:mainnet',
        'chainFamily': 'bitcoin',
        'assetSymbol': 'BTC',
        'nativeSymbol': 'BTC',
        'decimals': 8,
        'toAddress': recipient.address,
        'amountBaseUnits': recipient.amountSat.toString(),
        'fundingExpiresAt': '2099-01-01T00:00:00Z',
      });
      final payments = BitcoinOfframpJournal(f.store);
      final attempt = await payments.reserve(
        RbfFixture.identity,
        intent,
        f.original.transaction.txid,
      );
      payments.retainPending(attempt);
      final saved = (await payments.read(RbfFixture.identity, reference))!;
      final coordinator = service(f);
      final approval = await prepare(coordinator, f);
      f.network.accept = (raw) => f.acceptPlan(approval.transfer.plan, raw);
      final outcome = await coordinator.submit(
        approval,
        authenticate: unlock,
        isCurrent: current,
      );
      final winner = (await f.journal.pending(
        RbfFixture.identity,
        BitcoinProductNetwork.mainnet,
      )).singleWhere((entry) => entry.txid == outcome.txid);
      final confirmed = BitcoinTransactionStatus.fromJson({
        'status': 'confirmed',
        'found': true,
        'confirmed': true,
        'confirmations': 1,
        'blockHeight': 10,
        'blockHash': 'aa' * 32,
      });
      expect(
        await f.journal.reconcileConfirmed(
          winner,
          confirmed,
          isCurrent: current,
        ),
        isTrue,
      );
      final proof = (await f.journal.resolvedPayment(
        RbfFixture.identity,
        BitcoinProductNetwork.mainnet,
        saved.txid,
      ))!;
      final journalKey = f.memory.values.keys.singleWhere(
        (key) => key.startsWith('bitcoin_submission_'),
      );
      final originalJournal = f.memory.values[journalKey]!;
      final corrupt = jsonDecode(originalJournal) as Map<String, dynamic>;
      final receipt =
          (corrupt['resolved'] as Map)['mainnet|${saved.txid}'] as Map;
      final signedReceipt =
          (receipt['paymentTransaction'] as Map)['signed'] as Map;
      signedReceipt['wtxid'] = 'ff' * 32;
      f.memory.values[journalKey] = jsonEncode(corrupt);
      await expectLater(
        f.journal.resolvedPayment(
          RbfFixture.identity,
          BitcoinProductNetwork.mainnet,
          saved.txid,
        ),
        throwsA(anything),
      );
      expect(await payments.read(RbfFixture.identity, reference), isNotNull);
      f.memory.values[journalKey] = originalJournal;
      expect(
        await payments.reconcileConfirmed(
          saved,
          network: BitcoinProductNetwork.mainnet,
          observedTxid: outcome.txid,
          status: confirmed,
          backendAcknowledged: true,
        ),
        isFalse,
      );
      expect(
        await payments.reconcileConfirmed(
          saved,
          network: BitcoinProductNetwork.mainnet,
          observedTxid: outcome.txid,
          status: confirmed,
          backendAcknowledged: false,
          replacementProof: proof,
        ),
        isFalse,
      );
      expect(
        await payments.reconcileConfirmed(
          saved,
          network: BitcoinProductNetwork.testnet4,
          observedTxid: outcome.txid,
          status: confirmed,
          backendAcknowledged: true,
          replacementProof: proof,
        ),
        isFalse,
      );
      expect(
        await payments.reconcileConfirmed(
          saved,
          network: BitcoinProductNetwork.mainnet,
          observedTxid: outcome.txid,
          status: confirmed,
          backendAcknowledged: true,
          replacementProof: proof,
        ),
        isTrue,
      );
      expect(await payments.read(RbfFixture.identity, reference), isNull);
    },
  );
  tearDown(() => WalletVaultService.lockAll());
  for (final purpose in BitcoinPurpose.values) {
    for (final network in BitcoinProductNetwork.values) {
      test(
        '$network $purpose replacement preserves the approved payment and one input reservation',
        () async {
          final f = await rbfFixture(purpose: purpose, network: network);
          final coordinator = service(f);
          expect(
            await coordinator.available(
              RbfFixture.identity,
              network,
              f.original.transaction.txid,
              isCurrent: current,
            ),
            isTrue,
          );
          final approval = await prepare(coordinator, f);
          expect(
            approval.transfer.plan.recipients.single.address,
            f.original.transfer.plan.recipients.single.address,
          );
          expect(
            approval.transfer.plan.recipientTotalSat,
            f.original.transfer.plan.recipientTotalSat,
          );
          expect(
            approval.transfer.plan.account,
            f.original.transfer.plan.account,
          );
          expect(
            approval.transfer.plan.changeIndex,
            f.original.transfer.plan.changeIndex,
          );
          expect(approval.additionalFeeSat, greaterThan(BigInt.zero));
          f.network.accept = (raw) => f.acceptPlan(approval.transfer.plan, raw);
          final outcome = await coordinator.submit(
            approval,
            authenticate: unlock,
            isCurrent: current,
          );
          expect(outcome.status, BitcoinSubmissionStatus.accepted);
          expect(outcome.txid, isNot(f.original.transaction.txid));
          expect(f.network.broadcasts, 1);
          expect(await f.journal.reserved(RbfFixture.identity, network), {
            '${'11' * 32}:0',
          });
          final pending = await f.journal.pending(RbfFixture.identity, network);
          expect(pending, hasLength(2));
          expect(
            pending.where((entry) => entry.active).single.txid,
            outcome.txid,
          );
          expect(
            pending.every(
              (entry) => entry.rootTxid == f.original.transaction.txid,
            ),
            isTrue,
          );
          expect(
            await service(f).available(
              RbfFixture.identity,
              network,
              f.original.transaction.txid,
              isCurrent: current,
            ),
            isFalse,
          );
          await expectLater(
            coordinator.submit(
              approval,
              authenticate: unlock,
              isCurrent: current,
            ),
            throwsStateError,
          );
          expect(f.network.broadcasts, 1);
        },
      );
    }
  }
  for (final unavailable in [
    'confirmed',
    'descendants',
    'unsupported',
    'network',
    'txid',
  ]) {
    test('$unavailable observations never authorize a replacement', () async {
      final f = await rbfFixture();
      switch (unavailable) {
        case 'confirmed':
          f.network.confirmed = true;
        case 'descendants':
          f.network.descendants = true;
        case 'unsupported':
          f.network.supported = false;
        case 'network':
          f.network.wrongNetwork = true;
        case 'txid':
          f.network.wrongTxid = true;
      }
      final coordinator = service(f);
      expect(
        await coordinator.available(
          RbfFixture.identity,
          f.original.transfer.network,
          f.original.transaction.txid,
          isCurrent: current,
        ),
        isFalse,
      );
      await expectLater(prepare(coordinator, f), throwsA(anything));
      expect(f.network.broadcasts, 0);
      expect(
        await f.journal.reserved(
          RbfFixture.identity,
          f.original.transfer.network,
        ),
        hasLength(1),
      );
    });
  }
  test(
    'same, lower and out-of-range fee rates fail before authentication',
    () async {
      final f = await rbfFixture();
      final coordinator = service(f);
      for (final rate in [
        BigInt.zero,
        BigInt.one,
        -BigInt.one,
        BigInt.one << 64,
      ]) {
        await expectLater(
          coordinator.prepare(
            RbfFixture.identity,
            f.original.transfer.network,
            f.original.transaction.txid,
            rate,
            isCurrent: current,
          ),
          throwsFormatException,
        );
      }
      expect(f.network.broadcasts, 0);
    },
  );
  test(
    'non-RBF original and missing saved signing metadata are unavailable',
    () async {
      final f = await rbfFixture(rbf: false);
      expect(
        await service(f).available(
          RbfFixture.identity,
          f.original.transfer.network,
          f.original.transaction.txid,
          isCurrent: current,
        ),
        isFalse,
      );
      final key = f.memory.values.keys.singleWhere(
        (key) => key.startsWith('bitcoin_submission_'),
      );
      final json = jsonDecode(f.memory.values[key]!) as Map<String, dynamic>;
      json['version'] = 2;
      json.remove('outbound');
      json.remove('resolved');
      f.memory.values[key] = jsonEncode(json);
      expect(
        await service(f).available(
          RbfFixture.identity,
          f.original.transfer.network,
          f.original.transaction.txid,
          isCurrent: current,
        ),
        isFalse,
      );
      expect(
        await f.journal.reserved(
          RbfFixture.identity,
          f.original.transfer.network,
        ),
        hasLength(1),
      );
    },
  );
  test(
    'tampered saved signatures fail closed without releasing the original',
    () async {
      final f = await rbfFixture();
      final key = f.memory.values.keys.singleWhere(
        (key) => key.startsWith('bitcoin_submission_'),
      );
      final json = jsonDecode(f.memory.values[key]!) as Map<String, dynamic>;
      final record = (json['outbound'] as Map)
          .values
          .single['records'][f.original.transaction.txid];
      record['signed']['rawTransactionHex'] = '00';
      f.memory.values[key] = jsonEncode(json);
      await expectLater(prepare(service(f), f), throwsA(anything));
      expect(f.network.broadcasts, 0);
      expect(
        await f.journal.reserved(
          RbfFixture.identity,
          f.original.transfer.network,
        ),
        hasLength(1),
      );
    },
  );
  for (final race in [
    'confirmation',
    'relay policy',
    'wallet switch',
    'cancel',
  ]) {
    test('$race during authentication aborts before broadcast', () async {
      final f = await rbfFixture();
      final coordinator = service(f);
      final approval = await prepare(coordinator, f);
      var sameWallet = true;
      await expectLater(
        coordinator.submit(
          approval,
          authenticate: () async {
            WalletVaultService.unlock();
            switch (race) {
              case 'confirmation':
                f.network.confirmed = true;
              case 'relay policy':
                f.network.relayRate = 20;
              case 'wallet switch':
                sameWallet = false;
              case 'cancel':
                return false;
            }
            return true;
          },
          isCurrent: () => sameWallet,
        ),
        throwsA(anything),
      );
      expect(f.network.broadcasts, 0);
      expect(
        await f.journal.reserved(
          RbfFixture.identity,
          f.original.transfer.network,
        ),
        hasLength(1),
      );
    });
  }
  test(
    'expired and foreign coordinator approvals cannot be submitted',
    () async {
      final f = await rbfFixture();
      var now = DateTime.utc(2026, 10, 13);
      final coordinator = service(f, now: () => now);
      final approval = await prepare(coordinator, f);
      await expectLater(
        service(f).submit(approval, authenticate: unlock, isCurrent: current),
        throwsStateError,
      );
      now = now.add(const Duration(seconds: 31));
      await expectLater(
        coordinator.submit(approval, authenticate: unlock, isCurrent: current),
        throwsStateError,
      );
      expect(f.network.broadcasts, 0);
    },
  );
  test('a journal write invalidates a stale approval before unlock', () async {
    final f = await rbfFixture();
    final coordinator = service(f);
    final approval = await prepare(coordinator, f);
    final key = f.memory.values.keys.singleWhere(
      (key) => key.startsWith('bitcoin_submission_'),
    );
    await f.store.updateSubmissionState(
      RbfFixture.identity,
      (raw) => (null, raw),
    );
    expect(f.memory.values[key], isNotEmpty);
    var authentications = 0;
    await expectLater(
      coordinator.submit(
        approval,
        authenticate: () async {
          authentications++;
          return true;
        },
        isCurrent: current,
      ),
      throwsStateError,
    );
    expect(authentications, 0);
    expect(f.network.broadcasts, 0);
  });
  for (final outcome in ['timeout', '429', '500', 'mismatch', 'rejection']) {
    test(
      '$outcome preserves the exact parent/replacement uncertainty rules',
      () async {
        final f = await rbfFixture();
        final coordinator = service(f);
        final approval = await prepare(coordinator, f);
        switch (outcome) {
          case 'timeout':
            f.network.broadcastError = const BitcoinNetworkException();
          case '429':
            f.network.broadcastError = const BitcoinNetworkException(429);
          case '500':
            f.network.broadcastError = const BitcoinNetworkException(500);
          case 'mismatch':
            f.network.responseTxid = 'ff' * 32;
          case 'rejection':
            f.network.broadcastError =
                BitcoinPreProviderRejection.fromBackendResponse(
                  403,
                  jsonEncode({
                    'error': 'Forbidden',
                    'message':
                        'The wallet session does not match the requested wallet.',
                  }),
                );
        }
        if (outcome == 'mismatch' || outcome == 'rejection') {
          await expectLater(
            coordinator.submit(
              approval,
              authenticate: unlock,
              isCurrent: current,
            ),
            throwsA(anything),
          );
        } else {
          expect(
            (await coordinator.submit(
              approval,
              authenticate: unlock,
              isCurrent: current,
            )).status,
            BitcoinSubmissionStatus.unknown,
          );
        }
        expect(f.network.broadcasts, 1);
        final restarted = BitcoinSubmissionJournal(
          BitcoinAccountStore(f.memory),
        );
        final pending = await restarted.pending(
          RbfFixture.identity,
          f.original.transfer.network,
        );
        expect(pending, hasLength(outcome == 'rejection' ? 1 : 2));
        expect(
          pending.where((entry) => entry.active).single.txid ==
              f.original.transaction.txid,
          outcome == 'rejection',
        );
        expect(
          await restarted.reserved(
            RbfFixture.identity,
            f.original.transfer.network,
          ),
          hasLength(1),
        );
        await expectLater(
          coordinator.submit(
            approval,
            authenticate: unlock,
            isCurrent: current,
          ),
          throwsStateError,
        );
        expect(f.network.broadcasts, 1);
      },
    );
  }
  for (final winner in ['original', 'replacement']) {
    test(
      'confirmation of $winner reconciles the shared root exactly once',
      () async {
        final f = await rbfFixture();
        final coordinator = service(f);
        final approval = await prepare(coordinator, f);
        f.network.accept = (raw) => f.acceptPlan(approval.transfer.plan, raw);
        final outcome = await coordinator.submit(
          approval,
          authenticate: unlock,
          isCurrent: current,
        );
        final snapshots = await f.journal.pending(
          RbfFixture.identity,
          f.original.transfer.network,
        );
        final snapshot = snapshots.singleWhere(
          (entry) =>
              entry.txid ==
              (winner == 'original'
                  ? f.original.transaction.txid
                  : outcome.txid),
        );
        final confirmed = BitcoinTransactionStatus.fromJson({
          'status': 'confirmed',
          'found': true,
          'confirmed': true,
          'confirmations': 1,
          'blockHeight': 10,
          'blockHash': 'aa' * 32,
          'timestamp': null,
        });
        expect(
          await f.journal.reconcileConfirmed(
            snapshot,
            confirmed,
            isCurrent: current,
          ),
          isTrue,
        );
        expect(
          await f.journal.reconcileConfirmed(
            snapshot,
            confirmed,
            isCurrent: current,
          ),
          isFalse,
        );
        expect(
          await f.journal.reserved(
            RbfFixture.identity,
            f.original.transfer.network,
          ),
          isEmpty,
        );
        final receipts = await BitcoinSubmissionJournal(
          BitcoinAccountStore(f.memory),
        ).resolvedAliases(RbfFixture.identity, f.original.transfer.network);
        final losingHash = winner == 'original'
            ? outcome.txid
            : f.original.transaction.txid;
        expect(receipts[losingHash]!.txid, snapshot.txid);
        expect(
          receipts[losingHash]!.feeSat,
          snapshot.transaction!.signed.feeSat,
        );
        expect(receipts.containsKey(snapshot.txid), isFalse);
        final proof = await f.journal.resolvedPayment(
          RbfFixture.identity,
          f.original.transfer.network,
          losingHash,
        );
        expect(proof, isNotNull);
        expect(proof!.transaction.signed.txid, snapshot.txid);
        expect(
          proof.belongsTo(
            f.memory,
            RbfFixture.identity,
            f.original.transfer.network,
            losingHash,
          ),
          isTrue,
        );
        expect(
          proof.belongsTo(
            f.memory,
            'other-wallet',
            f.original.transfer.network,
            losingHash,
          ),
          isFalse,
        );
      },
    );
  }
  test(
    'stored metadata round trips, is immutable and contains no private fields',
    () async {
      final f = await rbfFixture();
      final restored = BitcoinSavedTransaction.fromJson(f.saved.toJson());
      expect(restored.signed.txid, f.original.transaction.txid);
      expect(restored.planJson, f.saved.planJson);
      expect(() => restored.plan.selectedUtxos.clear(), throwsUnsupportedError);
      final json = jsonEncode(restored.toJson());
      for (final privateField in [
        'xprv',
        'mnemonic',
        'wrappingKey',
        'encryptedVault',
      ]) {
        expect(json, isNot(contains(privateField)));
      }
      expect(
        restored.toString(),
        isNot(contains(restored.signed.rawTransactionHex)),
      );
    },
  );
  test('protected storage failure prevents any network submission', () async {
    final f = await rbfFixture();
    final coordinator = service(f);
    final approval = await prepare(coordinator, f);
    f.memory.dropWrites = true;
    await expectLater(
      coordinator.submit(approval, authenticate: unlock, isCurrent: current),
      throwsStateError,
    );
    expect(f.network.broadcasts, 0);
    expect(
      await f.journal.reserved(
        RbfFixture.identity,
        f.original.transfer.network,
      ),
      hasLength(1),
    );
  });
  test('foreign custody stores are rejected at construction', () async {
    final f = await rbfFixture();
    expect(
      () => BitcoinRbfService(
        store: BitcoinAccountStore(MemoryStore()),
        network: f.network,
        signing: f.signing,
      ),
      throwsArgumentError,
    );
  });
}
