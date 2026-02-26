import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

import 'blockchain_service.dart';

class TransactionMonitor {
  Future<bool> waitForConfirmation({
    required String txHash,
    required BlockchainService blockchain,
    Duration pollInterval = const Duration(seconds: 5),
    Duration timeout = const Duration(minutes: 2),
    void Function(int attempts)? onPoll,
  }) async {
    final client = Web3Client(blockchain.activeChain.rpcUrl, http.Client());
    try {
      final completer = Completer<bool>();
      final stopwatch = Stopwatch()..start();
      int attempts = 0;

      Timer.periodic(pollInterval, (timer) async {
        attempts++;
        onPoll?.call(attempts);
        if (stopwatch.elapsed >= timeout) {
          timer.cancel();
          if (!completer.isCompleted) completer.complete(false);
          return;
        }

        try {
          final receipt = await client.getTransactionReceipt(txHash);
          if (receipt != null) {
            timer.cancel();
            completer.complete(receipt.status ?? false);
          }
        } catch (e) {
          debugPrint('Tx monitor error: $e');
        }
      });

      final confirmed = await completer.future;
      return confirmed;
    } finally {
      client.dispose();
    }
  }
}
