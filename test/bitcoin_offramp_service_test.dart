import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/models/bitcoin_offramp_intent.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_account_store.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_broadcast_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_offramp_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_send_service.dart';
import 'package:fomowl_wallet/src/rust/api/bitcoin_account.dart';
import 'package:fomowl_wallet/src/rust/api/bitcoin_transaction.dart';
import 'helpers/bitcoin_memory_store.dart';

const identity = '0xabc';
const reference = 'OWL-PAY-1234567890';
const destination =
    'bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr';
BitcoinOfframpIntent intent({
  String amount = '4730',
  String expiry = '2099-01-01T00:00:00Z',
}) => BitcoinOfframpIntent.fromWithdrawalPlan(reference, {
  'reference': reference,
  'action': 'transfer',
  'networkKey': 'bitcoin:mainnet',
  'chainFamily': 'bitcoin',
  'assetSymbol': 'BTC',
  'nativeSymbol': 'BTC',
  'decimals': 8,
  'fundingExpiresAt': expiry,
  'amountBaseUnits': amount,
  'toAddress': destination,
});

// Public placeholder plan: these orchestration tests never claim Rust signing.
class Planner extends BitcoinSendService {
  String? overrideIdentity;
  int calls = 0;
  Planner() : super(store: BitcoinAccountStore(MemoryStore()));
  @override
  Future<BitcoinPreparedTransfer> prepareTransfer(
    String wallet,
    BitcoinProductNetwork network,
    String recipient,
    BigInt amount, {
    BitcoinPurpose? purpose,
    BitcoinFeeTier feeTier = BitcoinFeeTier.normal,
    bool feeTierWasSelected = false,
    bool rbf = true,
    bool Function()? isCurrent,
  }) async {
    calls++;
    return BitcoinPreparedTransfer(
      walletIdentity: overrideIdentity ?? wallet,
      network: network,
      purpose: BitcoinPurpose.bip84,
      plan: BitcoinTransactionPlanDto(
        account: const BitcoinAccountDto(
          network: BitcoinNetworkDto.mainnet,
          purpose: BitcoinPurposeDto.bip84,
          accountIndex: 0,
          masterFingerprint: '12345678',
          accountXpub: 'public-placeholder',
        ),
        unsignedTxHex: '00',
        selectedUtxos: const [],
        recipients: [
          BitcoinRecipientDto(address: recipient, amountSat: amount),
        ],
        changeIndex: 0,
        rbf: true,
        feeRateSatVb: BigInt.one,
        recipientTotalSat: amount,
        changeSat: BigInt.zero,
        feeSat: BigInt.from(141),
        estimatedVbytes: BigInt.from(141),
      ),
    );
  }
}

class Executor implements BitcoinOfframpExecutor {
  int calls = 0;
  bool unknown = false;
  bool reject = false;
  Future<void> Function()? afterDurableClaim;
  @override
  Future<BitcoinBroadcastOutcome> execute(
    BitcoinPreparedTransfer transfer, {
    required Future<bool> Function() authenticate,
    required bool Function() isCurrent,
    required Future<void> Function(String txid) beforeBroadcast,
  }) async {
    calls++;
    if (!await authenticate()) throw StateError('Authentication cancelled');
    await beforeBroadcast('11' * 32);
    await afterDurableClaim?.call();
    if (reject) {
      throw BitcoinPreProviderRejection.fromBackendResponse(
        403,
        '{"error":"Forbidden","message":"The wallet session does not match the requested wallet."}',
      )!;
    }
    return BitcoinBroadcastOutcome(
      '11' * 32,
      unknown
          ? BitcoinSubmissionStatus.unknown
          : BitcoinSubmissionStatus.accepted,
    );
  }
}

void main() {
  test(
    'restart recovery acknowledges observed payment without planning or signing',
    () async {
      final planner = Planner();
      final executor = Executor();
      var confirmed = false;
      var acknowledgements = 0;
      final service = BitcoinOfframpService(
        planner: planner,
        executor: executor,
        fetchIntent: (_, _) async =>
            throw StateError('Recovery must not fetch a funding plan'),
        acknowledge: (wallet, ref, hash) async {
          expect(wallet, identity);
          expect(ref, reference);
          expect(hash, '11' * 32);
          acknowledgements++;
        },
        fetchStatus: (network, hash) async {
          expect(network, BitcoinProductNetwork.mainnet);
          expect(hash, '11' * 32);
          return BitcoinTransactionStatus.fromJson({
            'found': true,
            'confirmed': confirmed,
            'status': confirmed ? 'confirmed' : 'pending',
            'confirmations': confirmed ? 1 : 0,
            'blockHeight': confirmed ? 100 : null,
            'blockHash': confirmed ? '22' * 32 : null,
          });
        },
      );
      final attempt = await service.journal.reserve(
        identity,
        intent(),
        '11' * 32,
      );
      service.journal.retainPending(attempt);
      final pending = await service.recover(
        identity,
        reference,
        isCurrent: () => true,
      );
      expect(pending.backendAcknowledged, isTrue);
      expect(await service.journal.read(identity, reference), isNotNull);
      confirmed = true;
      final done = await service.recover(
        identity,
        reference,
        isCurrent: () => true,
      );
      expect(done.status.confirmed, isTrue);
      expect(await service.journal.read(identity, reference), isNull);
      expect(acknowledgements, 2);
      expect(planner.calls, 0);
      expect(executor.calls, 0);
    },
  );
  test(
    'missing payment and failed acknowledgement never clear restart guard',
    () async {
      final planner = Planner();
      final executor = Executor();
      var found = false;
      var callbacks = 0;
      final service = BitcoinOfframpService(
        planner: planner,
        executor: executor,
        fetchIntent: (_, _) async => throw StateError('No funding plan'),
        acknowledge: (_, _, _) async {
          callbacks++;
          throw StateError('Bookkeeping unavailable');
        },
        fetchStatus: (_, _) async => BitcoinTransactionStatus.fromJson({
          'found': found,
          'confirmed': found,
          'status': found ? 'confirmed' : 'pending',
          'confirmations': found ? 1 : 0,
          'blockHeight': found ? 100 : null,
          'blockHash': found ? '22' * 32 : null,
        }),
      );
      final attempt = await service.journal.reserve(
        identity,
        intent(),
        '11' * 32,
      );
      service.journal.retainPending(attempt);
      expect(
        (await service.recover(
          identity,
          reference,
          isCurrent: () => true,
        )).backendAcknowledged,
        isFalse,
      );
      expect(callbacks, 0);
      found = true;
      expect(
        (await service.recover(
          identity,
          reference,
          isCurrent: () => true,
        )).backendAcknowledged,
        isFalse,
      );
      expect(await service.journal.read(identity, reference), isNotNull);
      expect(callbacks, 1);
      expect(planner.calls, 0);
      expect(executor.calls, 0);
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'backend bookkeeping failure cannot retry an accepted payment',
    () async {
      final planner = Planner();
      final executor = Executor();
      final service = BitcoinOfframpService(
        planner: planner,
        executor: executor,
        fetchIntent: (_, _) async => intent(),
        acknowledge: (_, _, _) async => throw StateError('fixture outage'),
      );
      final prepared = await service.prepare(
        identity,
        reference,
        isCurrent: () => true,
      );
      final result = await service.execute(
        prepared,
        authenticate: () async => true,
        isCurrent: () => true,
      );
      expect(result.outcome.status, BitcoinSubmissionStatus.accepted);
      expect(result.backendAcknowledged, isFalse);
      expect(
        (await service.journal.read(identity, reference))!.accepted,
        isTrue,
      );
      await service.execute(
        prepared,
        authenticate: () async => fail('No second authentication'),
        isCurrent: () => true,
      );
      expect(executor.calls, 1);
    },
  );

  test(
    'cancellation and wallet switch during authentication do not claim a payment',
    () async {
      for (final cancelled in [true, false]) {
        var current = true;
        final service = BitcoinOfframpService(
          planner: Planner(),
          executor: Executor(),
          fetchIntent: (_, _) async => intent(),
          acknowledge: (_, _, _) async => fail('No payment'),
        );
        final prepared = await service.prepare(
          identity,
          reference,
          isCurrent: () => current,
        );
        await expectLater(
          service.execute(
            prepared,
            authenticate: () async {
              if (!cancelled) current = false;
              return !cancelled;
            },
            isCurrent: () => current,
          ),
          throwsStateError,
        );
        expect(await service.journal.read(identity, reference), isNull);
      }
    },
  );

  test(
    'approval executes once and persists the reference before network submission',
    () async {
      final planner = Planner();
      final executor = Executor();
      var fetches = 0;
      var acknowledgements = 0;
      var authentications = 0;
      late BitcoinOfframpService service;
      service = BitcoinOfframpService(
        planner: planner,
        executor: executor,
        fetchIntent: (_, _) async {
          fetches++;
          return intent();
        },
        acknowledge: (wallet, ref, hash) async {
          expect(wallet, identity);
          expect(ref, reference);
          expect(hash, '11' * 32);
          acknowledgements++;
        },
      );
      executor.afterDurableClaim = () async {
        expect(await service.journal.read(identity, reference), isNotNull);
      };
      final prepared = await service.prepare(
        '0xABC',
        reference,
        isCurrent: () => true,
      );
      final results = await Future.wait(
        List.generate(
          2,
          (_) => service.execute(
            prepared,
            authenticate: () async {
              authentications++;
              return true;
            },
            isCurrent: () => true,
          ),
        ),
      );
      expect(results.every((result) => result.backendAcknowledged), isTrue);
      expect(executor.calls, 1);
      expect(authentications, 1);
      expect(fetches, 2);
      expect(acknowledgements, 1);
      expect(
        (await service.journal.read(identity, reference))!.accepted,
        isTrue,
      );
      await expectLater(
        service.prepare(identity, reference, isCurrent: () => true),
        throwsA(isA<BitcoinOfframpAlreadySubmitted>()),
      );
    },
  );

  test(
    'changed server intent after authentication never reaches broadcast',
    () async {
      final planner = Planner();
      final executor = Executor();
      var fetches = 0;
      final service = BitcoinOfframpService(
        planner: planner,
        executor: executor,
        fetchIntent: (_, _) async =>
            intent(amount: ++fetches == 1 ? '4730' : '4731'),
        acknowledge: (_, _, _) async => fail('No acknowledgement expected'),
      );
      final prepared = await service.prepare(
        identity,
        reference,
        isCurrent: () => true,
      );
      await expectLater(
        service.execute(
          prepared,
          authenticate: () async => true,
          isCurrent: () => true,
        ),
        throwsStateError,
      );
      expect(await service.journal.read(identity, reference), isNull);
    },
  );

  test(
    'unknown outcome retains reference and never acknowledges or re-prepares',
    () async {
      final planner = Planner();
      final executor = Executor()..unknown = true;
      final service = BitcoinOfframpService(
        planner: planner,
        executor: executor,
        fetchIntent: (_, _) async => intent(),
        acknowledge: (_, _, _) async => fail('Unknown outcome'),
      );
      final prepared = await service.prepare(
        identity,
        reference,
        isCurrent: () => true,
      );
      final result = await service.execute(
        prepared,
        authenticate: () async => true,
        isCurrent: () => true,
      );
      expect(result.outcome.status, BitcoinSubmissionStatus.unknown);
      expect(result.backendAcknowledged, isFalse);
      await expectLater(
        service.prepare(identity, reference, isCurrent: () => true),
        throwsA(isA<BitcoinOfframpAlreadySubmitted>()),
      );
      expect(planner.calls, 1);
    },
  );

  test(
    'proven pre-provider rejection permits a fresh preparation only',
    () async {
      final planner = Planner();
      final executor = Executor()..reject = true;
      final service = BitcoinOfframpService(
        planner: planner,
        executor: executor,
        fetchIntent: (_, _) async => intent(),
        acknowledge: (_, _, _) async {},
      );
      final prepared = await service.prepare(
        identity,
        reference,
        isCurrent: () => true,
      );
      await expectLater(
        service.execute(
          prepared,
          authenticate: () async => true,
          isCurrent: () => true,
        ),
        throwsA(isA<BitcoinPreProviderRejection>()),
      );
      expect(await service.journal.read(identity, reference), isNull);
      await service.prepare(identity, reference, isCurrent: () => true);
      expect(planner.calls, 2);
    },
  );

  test(
    'foreign-wallet planner result and expired approval fail closed',
    () async {
      final planner = Planner()..overrideIdentity = '0xother';
      var now = DateTime.utc(2026);
      final executor = Executor();
      final service = BitcoinOfframpService(
        planner: planner,
        executor: executor,
        fetchIntent: (_, _) async => intent(),
        acknowledge: (_, _, _) async {},
        now: () => now,
      );
      await expectLater(
        service.prepare(identity, reference, isCurrent: () => true),
        throwsStateError,
      );
      planner.overrideIdentity = null;
      final prepared = await service.prepare(
        identity,
        reference,
        isCurrent: () => true,
      );
      now = now.add(const Duration(minutes: 3));
      expect(
        () => service.execute(
          prepared,
          authenticate: () async => true,
          isCurrent: () => true,
        ),
        throwsStateError,
      );
      expect(executor.calls, 0);
    },
  );
  test('server deadline expires independently of the local approval', () async {
    final planner = Planner();
    final executor = Executor();
    var now = DateTime.utc(2026);
    final service = BitcoinOfframpService(
      planner: planner,
      executor: executor,
      fetchIntent: (_, _) async => intent(expiry: '2026-01-01T00:00:30Z'),
      acknowledge: (_, _, _) async =>
          fail('Expired payment cannot be acknowledged'),
      now: () => now,
    );
    final prepared = await service.prepare(
      identity,
      reference,
      isCurrent: () => true,
    );
    now = now.add(const Duration(seconds: 30));
    expect(
      () => service.execute(
        prepared,
        authenticate: () async => true,
        isCurrent: () => true,
      ),
      throwsStateError,
    );
    await expectLater(
      service.prepare(identity, reference, isCurrent: () => true),
      throwsStateError,
    );
    expect(planner.calls, 1);
    expect(executor.calls, 0);
    expect(await service.journal.read(identity, reference), isNull);
  });
}
