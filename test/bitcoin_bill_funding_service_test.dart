import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_bill_funding_plan.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_bill_funding_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_bill_funding_journal.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_broadcast_service.dart';
// Reuse the established public-plan executor fixtures; no native signing here.
import 'bitcoin_offramp_service_test.dart' as fixtures;

const billReference = 'OWL-BTC-BILL-11111111111111111111111111111111';
BitcoinBillFundingPlan invoice({String beneficiary = '08011111111'}) =>
    BitcoinBillFundingPlan.fromServer(billReference, fixtures.identity, {
      'reference': billReference,
      'walletIdentity': fixtures.identity,
      'collectionPaymentId': 'collection',
      'action': 'transfer',
      'quoteMode': 'owllet_bitcoin_bill',
      'networkKey': 'bitcoin:mainnet',
      'chainFamily': 'bitcoin',
      'assetSymbol': 'BTC',
      'nativeSymbol': 'BTC',
      'decimals': 8,
      'amountBaseUnits': '4730',
      'expiresAt': 4070908800,
      'toAddress': fixtures.destination,
      'billProvider': 'vtpass',
      'bill': {
        'serviceType': 'airtime',
        'serviceId': 'mtn',
        'beneficiary': beneficiary,
        'amountKobo': 160000,
      },
    });

void main() {
  test(
    'confirmed recovery clears only after read-only acknowledgement without invoking the signer again',
    () async {
      for (final retained in [true, false]) {
        var normalAcks = 0, readAcks = 0;
        final executor = fixtures.Executor();
        final service = BitcoinBillFundingService(
          planner: fixtures.Planner(),
          executor: executor,
          fetchIntent: (_, _) async => invoice(),
          acknowledge: (_, _, _) async {
            normalAcks++;
          },
          acknowledgeReadOnly: retained
              ? (_, _, _) async {
                  readAcks++;
                }
              : null,
          fetchStatus: (_, _) async => BitcoinTransactionStatus.fromJson({
            'found': true,
            'confirmed': true,
            'confirmations': 1,
            'status': 'confirmed',
            'blockHeight': 100,
            'blockHash': '22' * 32,
          }),
        );
        final prepared = await service.prepare(
          fixtures.identity,
          billReference,
          isCurrent: () => true,
        );
        await service.execute(
          prepared,
          authenticate: () async => true,
          isCurrent: () => true,
        );
        final result = await service.recover(
          fixtures.identity,
          billReference,
          isCurrent: () => true,
        );
        expect(result.backendAcknowledged, retained);
        expect(normalAcks, 1);
        expect(readAcks, retained ? 1 : 0);
        expect(executor.calls, 1);
        expect(
          await service.journal.read(fixtures.identity, billReference),
          retained ? isNull : isNotNull,
        );
      }
    },
  );
  test('a different wallet invoice cannot be prepared or reserved', () async {
    final other = BitcoinBillFundingPlan.fromServer(
      billReference,
      'other',
      invoice().toServerJson()..['walletIdentity'] = 'other',
    );
    final planner = fixtures.Planner();
    final service = BitcoinBillFundingService(
      planner: planner,
      executor: fixtures.Executor(),
      fetchIntent: (_, _) async => other,
      acknowledge: (_, _, _) async {},
    );
    await expectLater(
      service.prepare(fixtures.identity, billReference, isCurrent: () => true),
      throwsStateError,
    );
    expect(planner.calls, 0);
    expect(
      () => service.journal.reserve(fixtures.identity, other, '11' * 32),
      throwsStateError,
    );
  });
  test(
    'accepted bill funding persists one reference guard and exact acknowledgement',
    () async {
      final planner = fixtures.Planner();
      final executor = fixtures.Executor();
      var acknowledgements = 0;
      final service = BitcoinBillFundingService(
        planner: planner,
        executor: executor,
        fetchIntent: (_, _) async => invoice(),
        acknowledge: (identity, reference, txid) async {
          expect(identity, fixtures.identity);
          expect(reference, billReference);
          expect(txid, '11' * 32);
          acknowledgements++;
        },
      );
      final prepared = await service.prepare(
        fixtures.identity,
        billReference,
        isCurrent: () => true,
      );
      final result = await service.execute(
        prepared,
        authenticate: () async => true,
        isCurrent: () => true,
      );
      expect(result.outcome.status, BitcoinSubmissionStatus.accepted);
      expect(result.backendAcknowledged, isTrue);
      expect(acknowledgements, 1);
      final reopened = BitcoinBillFundingJournal(planner.store);
      expect(
        (await reopened.read(fixtures.identity, billReference))!.accepted,
        isTrue,
      );
      await expectLater(
        service.prepare(
          fixtures.identity,
          billReference,
          isCurrent: () => true,
        ),
        throwsA(isA<BitcoinBillFundingAlreadySubmitted>()),
      );
      expect(executor.calls, 1);
    },
  );
  test(
    'unknown broadcast remains reserved and never acknowledges or automatically resends',
    () async {
      final executor = fixtures.Executor()..unknown = true;
      var acknowledgements = 0;
      final service = BitcoinBillFundingService(
        planner: fixtures.Planner(),
        executor: executor,
        fetchIntent: (_, _) async => invoice(),
        acknowledge: (_, _, _) async {
          acknowledgements++;
        },
      );
      final prepared = await service.prepare(
        fixtures.identity,
        billReference,
        isCurrent: () => true,
      );
      expect(
        (await service.execute(
          prepared,
          authenticate: () async => true,
          isCurrent: () => true,
        )).outcome.status,
        BitcoinSubmissionStatus.unknown,
      );
      expect(acknowledgements, 0);
      await expectLater(
        service.prepare(
          fixtures.identity,
          billReference,
          isCurrent: () => true,
        ),
        throwsA(isA<BitcoinBillFundingAlreadySubmitted>()),
      );
      expect(executor.calls, 1);
    },
  );
  test(
    'bill beneficiary mutation after approval aborts before durable broadcast claim',
    () async {
      var current = invoice();
      final service = BitcoinBillFundingService(
        planner: fixtures.Planner(),
        executor: fixtures.Executor(),
        fetchIntent: (_, _) async => current,
        acknowledge: (_, _, _) async {},
      );
      final prepared = await service.prepare(
        fixtures.identity,
        billReference,
        isCurrent: () => true,
      );
      current = invoice(beneficiary: '08022222222');
      await expectLater(
        service.execute(
          prepared,
          authenticate: () async => true,
          isCurrent: () => true,
        ),
        throwsStateError,
      );
      expect(
        await service.journal.read(fixtures.identity, billReference),
        isNull,
      );
    },
  );
}
