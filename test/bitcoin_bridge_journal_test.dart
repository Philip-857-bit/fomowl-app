import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_bridge_quote.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_account_store.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_bridge_journal.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'helpers/bitcoin_memory_store.dart';

BitcoinBridgeQuote quote(DateTime now, {String marker = '1'}) {
  final request = BitcoinBridgeRequest(
    originChainId: relayBitcoinChainId,
    destinationChainId: 8453,
    originCurrency: relayBitcoinCurrency,
    destinationCurrency: '0x833589fcd6edb6e08f4c7c32d4f71b54bda02913',
    sender: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
    recipient: '0x03508bb71268bba25ecacc8f620e01866650532c',
    amount: BigInt.from(100000),
  );
  return BitcoinBridgeQuote.fromJson(
    {
      'committed': true,
      'requestId': '0x${marker * 64}',
      'intent': {
        'origin': {
          'chainId': relayBitcoinChainId,
          'providerChain': 'bitcoin',
          'family': 'bitcoin',
          'currency': relayBitcoinCurrency,
          'decimals': 8,
        },
        'destination': {
          'chainId': 8453,
          'providerChain': 'base',
          'family': 'evm',
          'currency': request.destinationCurrency,
          'decimals': 6,
        },
        'sender': request.sender,
        'recipient': request.recipient,
        'refundTo': request.sender,
        'amount': '100000',
      },
      'amountOut': '79000000',
      'minimumAmountOut': '78000000',
      'approvalExpiresAt': now.millisecondsSinceEpoch ~/ 1000 + 120,
      'providerDeadline': now.millisecondsSinceEpoch ~/ 1000 + 3600,
      'bitcoinDepositAddress': request.sender,
      'originSteps': <Object?>[],
      'display': {
        'amountOutUsd': '79',
        'bridgeFeeUsd': null,
        'platformFeeUsd': null,
      },
    },
    expected: request,
    now: now,
  );
}

BitcoinTransactionStatus chain({bool confirmed = true, bool found = true}) =>
    BitcoinTransactionStatus.fromJson({
      'found': found,
      'confirmed': confirmed,
      'confirmations': confirmed ? 1 : 0,
      'status': confirmed ? 'confirmed' : 'pending',
      'blockHeight': confirmed ? 100 : null,
      'blockHash': confirmed ? 'a' * 64 : null,
    });

void main() {
  final initial = DateTime.utc(2026, 10, 15);
  test(
    'completed order remains blocked after its short approval window',
    () async {
      var now = initial;
      final journal = BitcoinBridgeJournal(
        BitcoinAccountStore(MemoryStore()),
        now: () => now,
      );
      final attempt = await journal.reserve('wallet', quote(now), 'a' * 64);
      final saved = attempt.submission;
      expect(
        await journal.completeDelivered(
          saved,
          observedTxid: saved.txid,
          chainStatus: chain(),
          providerRequestId: saved.quote.requestId,
          providerStatus: 'success',
        ),
        isTrue,
      );
      now = now.add(const Duration(minutes: 3));
      final another = await journal.reserve(
        'wallet',
        quote(now, marker: '2'),
        'b' * 64,
      );
      expect(
        await journal.completeDelivered(
          another.submission,
          observedTxid: another.submission.txid,
          chainStatus: chain(),
          providerRequestId: another.submission.quote.requestId,
          providerStatus: 'success',
        ),
        isTrue,
      );
      expect(
        await journal.canPrepare('wallet', saved.quote.requestId),
        isFalse,
      );
      await expectLater(
        journal.reserve('wallet', quote(now), 'c' * 64),
        throwsStateError,
      );
    },
  );
  test(
    'final provider refund requires confirmed exact funding and never clears input reservations',
    () async {
      final memory = MemoryStore();
      final store = BitcoinAccountStore(memory);
      final journal = BitcoinBridgeJournal(store, now: () => initial);
      final attempt = await journal.reserve('wallet', quote(initial), 'a' * 64);
      await store.updateSubmissionState(
        'wallet',
        (_) => (null, 'unchanged-input-state'),
      );
      final saved = attempt.submission;
      expect(
        await journal.completeRefunded(
          saved,
          observedTxid: saved.txid,
          chainStatus: chain(confirmed: false),
          providerRequestId: saved.quote.requestId,
          providerStatus: 'refund',
        ),
        isFalse,
      );
      expect(
        await journal.completeRefunded(
          saved,
          observedTxid: saved.txid,
          chainStatus: chain(),
          providerRequestId: '0x${'2' * 64}',
          providerStatus: 'refund',
        ),
        isFalse,
      );
      expect(
        await journal.completeRefunded(
          saved,
          observedTxid: saved.txid,
          chainStatus: chain(),
          providerRequestId: saved.quote.requestId,
          providerStatus: 'failure',
        ),
        isFalse,
      );
      expect(
        await journal.completeRefunded(
          saved,
          observedTxid: saved.txid,
          chainStatus: chain(),
          providerRequestId: saved.quote.requestId,
          providerStatus: 'refund',
        ),
        isTrue,
      );
      expect(await journal.pending('wallet'), isNull);
      expect((await journal.latest('wallet'))!.resolution, 'refunded');
      expect(
        await journal.canPrepare('wallet', saved.quote.requestId),
        isFalse,
      );
      expect(
        await store.updateSubmissionState('wallet', (value) => (value, null)),
        'unchanged-input-state',
      );
    },
  );
  test(
    'a saved attempt blocks every new quote across wrappers and restart',
    () async {
      final memory = MemoryStore();
      final first = BitcoinBridgeJournal(
        BitcoinAccountStore(memory),
        now: () => initial,
      );
      final second = BitcoinBridgeJournal(
        BitcoinAccountStore(memory),
        now: () => initial,
      );
      await first.reserve('wallet', quote(initial), 'a' * 64);
      expect(
        (await second.pending('WALLET'))!.quote.requestId,
        '0x${'1' * 64}',
      );
      await expectLater(
        second.reserve('wallet', quote(initial, marker: '2'), 'b' * 64),
        throwsStateError,
      );
      expect(await second.pending('other-wallet'), isNull);
    },
  );
  test('concurrent wrappers cannot reserve two bridge payments', () async {
    final memory = MemoryStore();
    var success = 0, rejected = 0;
    await Future.wait(
      ['1', '2'].map((marker) async {
        try {
          await BitcoinBridgeJournal(
            BitcoinAccountStore(memory),
            now: () => initial,
          ).reserve('wallet', quote(initial, marker: marker), marker * 64);
          success++;
        } on StateError {
          rejected++;
        }
      }),
    );
    expect(success, 1);
    expect(rejected, 1);
  });
  test(
    'expiry never releases an unresolved payment and historical decoding does not renew approval',
    () async {
      var now = initial;
      final memory = MemoryStore();
      final journal = BitcoinBridgeJournal(
        BitcoinAccountStore(memory),
        now: () => now,
      );
      final original = quote(now);
      await journal.reserve('wallet', original, 'a' * 64);
      now = now.add(const Duration(days: 1));
      final saved = (await journal.pending('wallet'))!;
      expect(saved.quote.approvalExpiresAt.isBefore(now), isTrue);
      await expectLater(
        journal.reserve('wallet', quote(now, marker: '2'), 'b' * 64),
        throwsStateError,
      );
      expect(
        () => BitcoinBridgeQuote.fromJson(
          original.toJson(),
          expected: original.request,
          now: now,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'only the owning live attempt can use definitive rejection evidence',
    () async {
      final memory = MemoryStore();
      final store = BitcoinAccountStore(memory);
      final journal = BitcoinBridgeJournal(store, now: () => initial);
      final foreign = BitcoinBridgeJournal(store, now: () => initial);
      final proof = BitcoinPreProviderRejection.fromBackendResponse(
        403,
        '{"error":"Forbidden","message":"The wallet session does not match the requested wallet."}',
      )!;
      final attempt = await journal.reserve('wallet', quote(initial), 'a' * 64);
      expect(await foreign.releaseRejected(attempt, proof), isFalse);
      expect(await journal.releaseRejected(attempt, proof), isTrue);
      expect(await journal.pending('wallet'), isNull);
      final accepted = await journal.reserve(
        'wallet',
        quote(initial),
        'a' * 64,
      );
      await journal.markAccepted(accepted);
      expect(await journal.releaseRejected(accepted, proof), isFalse);
      expect(await journal.pending('wallet'), isNotNull);
    },
  );
  test(
    'delivery requires exact tx chain confirmation and matching successful provider request',
    () async {
      final memory = MemoryStore();
      final journal = BitcoinBridgeJournal(
        BitcoinAccountStore(memory),
        now: () => initial,
      );
      final attempt = await journal.reserve('wallet', quote(initial), 'a' * 64);
      final saved = attempt.submission;
      for (final status in ['pending', 'refund', 'refunded', 'failure']) {
        expect(
          await journal.completeDelivered(
            saved,
            observedTxid: saved.txid,
            chainStatus: chain(),
            providerRequestId: saved.quote.requestId,
            providerStatus: status,
          ),
          isFalse,
        );
      }
      expect(
        await journal.completeDelivered(
          saved,
          observedTxid: 'b' * 64,
          chainStatus: chain(),
          providerRequestId: saved.quote.requestId,
          providerStatus: 'success',
        ),
        isFalse,
      );
      expect(
        await journal.completeDelivered(
          saved,
          observedTxid: saved.txid,
          chainStatus: chain(confirmed: false, found: false),
          providerRequestId: saved.quote.requestId,
          providerStatus: 'success',
        ),
        isFalse,
      );
      expect(
        await journal.completeDelivered(
          saved,
          observedTxid: saved.txid,
          chainStatus: chain(),
          providerRequestId: '0x${'2' * 64}',
          providerStatus: 'success',
        ),
        isFalse,
      );
      expect(
        await journal.completeDelivered(
          saved,
          observedTxid: saved.txid,
          chainStatus: chain(),
          providerRequestId: saved.quote.requestId,
          providerStatus: 'success',
        ),
        isTrue,
      );
      expect(await journal.pending('wallet'), isNull);
      await expectLater(
        journal.reserve('wallet', quote(initial), 'a' * 64),
        throwsStateError,
      );
      await journal.reserve('wallet', quote(initial, marker: '2'), 'b' * 64);
    },
  );
  test(
    'ambiguous attempts remain blocked and corrupt or deleted state fails closed',
    () async {
      final memory = MemoryStore();
      final store = BitcoinAccountStore(memory);
      final journal = BitcoinBridgeJournal(store, now: () => initial);
      final attempt = await journal.reserve('wallet', quote(initial), 'a' * 64);
      journal.retainPending(attempt);
      expect(await journal.pending('wallet'), isNotNull);
      await store.updateBridgeState('wallet', (_) => (null, 'corrupt'));
      await expectLater(journal.pending('wallet'), throwsFormatException);
      await store.deleteWallet('wallet');
      await expectLater(journal.pending('wallet'), throwsStateError);
      await store.activateWallet('wallet');
      expect(await journal.pending('wallet'), isNull);
    },
  );
}
