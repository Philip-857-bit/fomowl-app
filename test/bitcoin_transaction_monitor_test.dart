import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/services/transaction_monitor.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';

BitcoinTransactionStatus status({bool confirmed = false, bool found = true}) =>
    BitcoinTransactionStatus.fromJson({
      'status': confirmed ? 'confirmed' : 'pending',
      'confirmed': confirmed,
      'found': found,
      'confirmations': confirmed ? 1 : 0,
      'blockHeight': confirmed ? 100 : null,
      'blockHash': confirmed ? List.filled(64, '1').join() : null,
    });

class StatusNetwork extends Fake implements BitcoinNetworkApi {
  final List<Object> replies;
  int calls = 0;
  StatusNetwork(this.replies);
  @override
  Future<BitcoinTransactionStatus> fetchTransactionStatus(
    BitcoinProductNetwork network,
    String txid,
  ) async {
    expect(network, BitcoinProductNetwork.mainnet);
    final item = replies[calls < replies.length ? calls : replies.length - 1];
    calls++;
    if (item is BitcoinTransactionStatus) return item;
    if (item is Future<BitcoinTransactionStatus>) return item;
    throw item;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'not found and provider outage stay pending until one Bitcoin confirmation',
    () {
      fakeAsync((clock) {
        final network = StatusNetwork([
          status(found: false),
          const BitcoinNetworkException(500),
          status(confirmed: true),
        ]);
        final blockchain = BlockchainService();
        TransactionConfirmationStatus? result;
        TransactionMonitor(bitcoinNetwork: network)
            .waitForConfirmation(
              txHash: List.filled(64, '1').join(),
              blockchain: blockchain,
              networkKey: 'bitcoin:mainnet',
            )
            .then((value) => result = value);
        clock.flushMicrotasks();
        expect(result, isNull);
        clock.elapse(const Duration(seconds: 4));
        expect(result, TransactionConfirmationStatus.confirmed);
        expect(network.calls, 3);
        expect(clock.nonPeriodicTimerCount, 0);
        blockchain.dispose();
      });
    },
  );
  test('bounded timeout returns pending and cancels polling timers', () {
    fakeAsync((clock) {
      final network = StatusNetwork([status(found: false)]);
      final blockchain = BlockchainService();
      TransactionConfirmationStatus? result;
      TransactionMonitor(bitcoinNetwork: network)
          .waitForConfirmation(
            txHash: List.filled(64, '1').join(),
            blockchain: blockchain,
            networkKey: 'bitcoin:mainnet',
            timeout: const Duration(seconds: 3),
          )
          .then((value) => result = value);
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 3));
      expect(result, TransactionConfirmationStatus.pending);
      expect(clock.nonPeriodicTimerCount, 0);
      blockchain.dispose();
    });
  });
  test(
    'late confirmation after wallet switch does not complete the previous flow',
    () {
      fakeAsync((clock) {
        final reply = Completer<BitcoinTransactionStatus>();
        final blockchain = BlockchainService();
        var current = true;
        TransactionConfirmationStatus? result;
        TransactionMonitor(bitcoinNetwork: StatusNetwork([reply.future]))
            .waitForConfirmation(
              txHash: List.filled(64, '1').join(),
              blockchain: blockchain,
              networkKey: 'bitcoin:mainnet',
              isCurrent: () => current,
            )
            .then((value) => result = value);
        clock.flushMicrotasks();
        current = false;
        reply.complete(status(confirmed: true));
        clock.flushMicrotasks();
        expect(result, TransactionConfirmationStatus.pending);
        expect(clock.nonPeriodicTimerCount, 0);
        blockchain.dispose();
      });
    },
  );
}
