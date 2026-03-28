import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';

import 'blockchain_service.dart';
import 'http_client_service.dart';

class TransactionMonitor {
  final HttpClientService _httpClientService = HttpClientService();

  Future<bool> waitForConfirmation({
    required String txHash,
    required BlockchainService blockchain,
    Duration pollInterval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 2),
    void Function(int attempts)? onPoll,
  }) async {
    final client = Web3Client(
      blockchain.activeChain.rpcUrl,
      _httpClientService.client,
    );
    try {
      final completer = Completer<bool>();
      final stopwatch = Stopwatch()..start();
      int attempts = 0;
      var pollInFlight = false;
      Timer? timer;

      Future<void> pollReceipt() async {
        if (pollInFlight || completer.isCompleted) {
          return;
        }
        attempts++;
        onPoll?.call(attempts);
        if (stopwatch.elapsed >= timeout) {
          timer?.cancel();
          if (!completer.isCompleted) {
            completer.complete(false);
          }
          return;
        }

        pollInFlight = true;
        try {
          final receipt = await client.getTransactionReceipt(txHash);
          if (receipt != null) {
            timer?.cancel();
            if (!completer.isCompleted) {
              completer.complete(receipt.status ?? false);
            }
          }
        } catch (e) {
          debugPrint('Tx monitor error: $e');
        } finally {
          pollInFlight = false;
        }
      }

      timer = Timer.periodic(pollInterval, (_) {
        if (stopwatch.elapsed >= timeout) {
          timer?.cancel();
          if (!completer.isCompleted) {
            completer.complete(false);
          }
          return;
        }
        unawaited(pollReceipt());
      });

      await pollReceipt();

      final confirmed = await completer.future;
      return confirmed;
    } finally {
      // client.dispose() intentionally removed — HttpClient is a shared singleton.
    }
  }
}
