import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_discovery.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_account_store.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_bridge_funding_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_broadcast_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_native_crypto.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_send_service.dart';
import 'package:fomowl_wallet/services/bridge_service.dart';
import 'helpers/bitcoin_memory_store.dart';
import 'bitcoin_bridge_journal_test.dart' as facts;
import 'bitcoin_account_store_test.dart' as state_fixtures;
import 'bitcoin_offramp_service_test.dart' as execution;

final initial = DateTime.utc(2026, 10, 15);

class Crypto implements BitcoinCryptoApi {
  bool wrongAddress = false;
  @override
  Future<String> deriveAddress(
    BitcoinHdAccountMetadata account,
    BitcoinKeychain keychain,
    int index,
  ) async => wrongAddress ? 'unowned' : facts.quote(initial).request.sender;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Orchestration only: these public placeholder plans do not claim native signing.
class Planner extends BitcoinSendService {
  int calls = 0;
  Planner(Crypto crypto)
    : super(store: BitcoinAccountStore(MemoryStore()), crypto: crypto);
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
  }) {
    calls++;
    return execution.Planner().prepareTransfer(
      wallet,
      network,
      recipient,
      amount,
    );
  }
}

Future<BitcoinDerivedAddress> provision(Planner planner) async {
  final slot = state_fixtures.slot(identity: execution.identity);
  final record = state_fixtures.record(slot);
  try {
    await planner.store.createIfAbsent(slot, record);
  } finally {
    record.dispose();
  }
  return BitcoinDerivedAddress(
    account: (await planner.store.readState(slot))!.metadata,
    keychain: BitcoinKeychain.receive,
    addressIndex: 0,
    address: facts.quote(initial).request.sender,
  );
}

void main() {
  test(
    'provider failure is distinct and keeps the funding guard across restart',
    () async {
      final planner = Planner(Crypto());
      final refund = await provision(planner);
      final executor = execution.Executor();
      BitcoinBridgeFundingService service() => BitcoinBridgeFundingService(
        planner: planner,
        executor: executor,
        now: () => initial,
        chainStatus: (_, _) async => facts.chain(),
        providerStatus: (_) async =>
            const BridgeStatus(status: 'failure', txHashes: []),
      );
      final first = service();
      final prepared = await first.prepare(
        execution.identity,
        facts.quote(initial),
        refundAddress: refund,
        isCurrent: () => true,
      );
      await first.execute(
        prepared,
        authenticate: () async => true,
        isCurrent: () => true,
      );
      final restarted = service();
      expect(
        (await restarted.recover(
          execution.identity,
          isCurrent: () => true,
        )).phase,
        BitcoinBridgePhase.failed,
      );
      expect(await restarted.journal.pending(execution.identity), isNotNull);
      await expectLater(
        restarted.prepare(
          execution.identity,
          facts.quote(initial, marker: '2'),
          refundAddress: refund,
          isCurrent: () => true,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'refund completion persists separately and never retries a payment',
    () async {
      var confirmed = false;
      final planner = Planner(Crypto());
      final refund = await provision(planner);
      final executor = execution.Executor();
      final service = BitcoinBridgeFundingService(
        planner: planner,
        executor: executor,
        now: () => initial,
        chainStatus: (_, _) async => facts.chain(confirmed: confirmed),
        providerStatus: (_) async =>
            const BridgeStatus(status: 'refund', txHashes: []),
      );
      final prepared = await service.prepare(
        execution.identity,
        facts.quote(initial),
        refundAddress: refund,
        isCurrent: () => true,
      );
      await service.execute(
        prepared,
        authenticate: () async => true,
        isCurrent: () => true,
      );
      expect(
        (await service.recover(
          execution.identity,
          isCurrent: () => true,
        )).phase,
        BitcoinBridgePhase.refundReported,
      );
      expect(await service.journal.pending(execution.identity), isNotNull);
      confirmed = true;
      expect(
        (await service.recover(
          execution.identity,
          isCurrent: () => true,
        )).phase,
        BitcoinBridgePhase.refunded,
      );
      final restarted = BitcoinBridgeFundingService(
        planner: planner,
        executor: executor,
        now: () => initial,
        chainStatus: (_, _) async => facts.chain(),
        providerStatus: (_) async => null,
      );
      expect(
        (await restarted.recover(
          execution.identity,
          isCurrent: () => true,
        )).phase,
        BitcoinBridgePhase.refunded,
      );
      await expectLater(
        service.prepare(
          execution.identity,
          facts.quote(initial),
          refundAddress: refund,
          isCurrent: () => true,
        ),
        throwsStateError,
      );
      expect(planner.calls, 1);
      expect(executor.calls, 1);
    },
  );
  test(
    'exact approved bridge is durably claimed before broadcast and double tap executes once',
    () async {
      final planner = Planner(Crypto());
      final refund = await provision(planner);
      final executor = execution.Executor();
      final service = BitcoinBridgeFundingService(
        planner: planner,
        executor: executor,
        now: () => initial,
      );
      final prepared = await service.prepare(
        execution.identity,
        facts.quote(initial),
        refundAddress: refund,
        isCurrent: () => true,
      );
      executor.afterDurableClaim = () async {
        final saved = (await service.journal.pending(execution.identity))!;
        expect(saved.txid, '11' * 32);
        expect(
          saved.quote.request.amount,
          prepared.transfer.plan.recipientTotalSat,
        );
      };
      final results = await Future.wait(
        List.generate(
          2,
          (_) => service.execute(
            prepared,
            authenticate: () async => true,
            isCurrent: () => true,
          ),
        ),
      );
      expect(executor.calls, 1);
      expect(
        results.every(
          (result) => result.status == BitcoinSubmissionStatus.accepted,
        ),
        isTrue,
      );
      expect(
        (await service.journal.pending(execution.identity))!.accepted,
        isTrue,
      );
    },
  );
  test(
    'unknown broadcast stays reserved across read-only recovery and fresh quote',
    () async {
      final planner = Planner(Crypto());
      final refund = await provision(planner);
      final executor = execution.Executor()..unknown = true;
      final service = BitcoinBridgeFundingService(
        planner: planner,
        executor: executor,
        now: () => initial,
        chainStatus: (_, _) async =>
            facts.chain(confirmed: false, found: false),
        providerStatus: (_) async => null,
      );
      final prepared = await service.prepare(
        execution.identity,
        facts.quote(initial),
        refundAddress: refund,
        isCurrent: () => true,
      );
      await service.execute(
        prepared,
        authenticate: () async => true,
        isCurrent: () => true,
      );
      final recovered = await service.recover(
        execution.identity,
        isCurrent: () => true,
      );
      expect(recovered.phase, BitcoinBridgePhase.checkingSubmission);
      await expectLater(
        service.prepare(
          execution.identity,
          facts.quote(initial, marker: '2'),
          refundAddress: refund,
          isCurrent: () => true,
        ),
        throwsStateError,
      );
      expect(planner.calls, 1);
      expect(executor.calls, 1);
    },
  );
  test(
    'refund ownership is derived from protected wallet metadata before planning',
    () async {
      final crypto = Crypto();
      final planner = Planner(crypto);
      final refund = await provision(planner);
      crypto.wrongAddress = true;
      final service = BitcoinBridgeFundingService(
        planner: planner,
        executor: execution.Executor(),
        now: () => initial,
      );
      await expectLater(
        service.prepare(
          execution.identity,
          facts.quote(initial),
          refundAddress: refund,
          isCurrent: () => true,
        ),
        throwsStateError,
      );
      expect(planner.calls, 0);
    },
  );
  test(
    'authentication cancellation creates no submission and definitive rejection releases exact guard',
    () async {
      final planner = Planner(Crypto());
      final refund = await provision(planner);
      final executor = execution.Executor();
      final service = BitcoinBridgeFundingService(
        planner: planner,
        executor: executor,
        now: () => initial,
      );
      var prepared = await service.prepare(
        execution.identity,
        facts.quote(initial),
        refundAddress: refund,
        isCurrent: () => true,
      );
      await expectLater(
        service.execute(
          prepared,
          authenticate: () async => false,
          isCurrent: () => true,
        ),
        throwsStateError,
      );
      expect(await service.journal.pending(execution.identity), isNull);
      executor.reject = true;
      prepared = await service.prepare(
        execution.identity,
        facts.quote(initial),
        refundAddress: refund,
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
      expect(await service.journal.pending(execution.identity), isNull);
    },
  );
  test(
    'expiry during authentication aborts before durable broadcast claim',
    () async {
      var now = initial;
      final planner = Planner(Crypto());
      final refund = await provision(planner);
      final service = BitcoinBridgeFundingService(
        planner: planner,
        executor: execution.Executor(),
        now: () => now,
      );
      final prepared = await service.prepare(
        execution.identity,
        facts.quote(now),
        refundAddress: refund,
        isCurrent: () => true,
      );
      await expectLater(
        service.execute(
          prepared,
          authenticate: () async {
            now = now.add(const Duration(minutes: 3));
            return true;
          },
          isCurrent: () => true,
        ),
        throwsStateError,
      );
      expect(await service.journal.pending(execution.identity), isNull);
    },
  );
  test(
    'provider success alone cannot complete funding and confirmed delivery prevents replay',
    () async {
      var confirmed = false;
      final planner = Planner(Crypto());
      final refund = await provision(planner);
      final executor = execution.Executor();
      final service = BitcoinBridgeFundingService(
        planner: planner,
        executor: executor,
        now: () => initial,
        chainStatus: (_, _) async => facts.chain(confirmed: confirmed),
        providerStatus: (_) async =>
            const BridgeStatus(status: 'success', txHashes: []),
      );
      final prepared = await service.prepare(
        execution.identity,
        facts.quote(initial),
        refundAddress: refund,
        isCurrent: () => true,
      );
      await service.execute(
        prepared,
        authenticate: () async => true,
        isCurrent: () => true,
      );
      expect(
        (await service.recover(
          execution.identity,
          isCurrent: () => true,
        )).delivered,
        isFalse,
      );
      confirmed = true;
      expect(
        (await service.recover(
          execution.identity,
          isCurrent: () => true,
        )).phase,
        BitcoinBridgePhase.delivered,
      );
      await expectLater(
        service.prepare(
          execution.identity,
          facts.quote(initial),
          refundAddress: refund,
          isCurrent: () => true,
        ),
        throwsStateError,
      );
      expect(planner.calls, 1);
      expect(executor.calls, 1);
    },
  );
}
