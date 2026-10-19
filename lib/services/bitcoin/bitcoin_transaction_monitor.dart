import 'dart:async';
import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_network_data.dart';
import 'bitcoin_network_service.dart';

/// Bitcoin has no EVM receipt failure flag. Missing/stale provider data stays pending.
class BitcoinTransactionMonitor {
  final BitcoinNetworkApi network;
  BitcoinTransactionMonitor({BitcoinNetworkApi? network})
    : network =
          network ?? BitcoinNetworkService(timeout: const Duration(seconds: 8));
  Future<bool> wait({
    required String txid,
    required BitcoinProductNetwork productNetwork,
    Duration pollInterval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 2),
    Duration requestTimeout = const Duration(seconds: 8),
    bool Function()? isCurrent,
    void Function(int)? onPoll,
  }) async {
    bitcoinTxid(txid);
    if (pollInterval <= Duration.zero ||
        timeout <= Duration.zero ||
        requestTimeout <= Duration.zero) {
      throw ArgumentError('Invalid Bitcoin confirmation timing');
    }
    final deadline = Completer<void>();
    final timer = Timer(timeout, deadline.complete);
    var attempts = 0;
    bool current() => isCurrent?.call() ?? true;
    try {
      while (!deadline.isCompleted && current()) {
        onPoll?.call(++attempts);
        final requestDeadline = Completer<BitcoinTransactionStatus?>();
        final requestTimer = Timer(
          requestTimeout,
          () => requestDeadline.complete(null),
        );
        try {
          final status = await Future.any<BitcoinTransactionStatus?>([
            network.fetchTransactionStatus(productNetwork, txid),
            requestDeadline.future,
            deadline.future.then((_) => null),
          ]);
          if (current() &&
              status != null &&
              status.confirmed &&
              status.confirmations >= 1) {
            return true;
          }
        } catch (_) {
          // Provider failure does not prove transaction failure.
        } finally {
          requestTimer.cancel();
        }
        if (deadline.isCompleted || !current()) break;
        final wake = Completer<void>();
        final pauseTimer = Timer(pollInterval, wake.complete);
        try {
          await Future.any<void>([wake.future, deadline.future]);
        } finally {
          pauseTimer.cancel();
        }
      }
      return false;
    } finally {
      timer.cancel();
    }
  }
}
