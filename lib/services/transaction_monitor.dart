import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';

import '../config/app_environment.dart';
import '../models/chain.dart';
import 'blockchain_service.dart';
import 'http_client_service.dart';
import 'rpc_service.dart';

class TransactionMonitor {
  final HttpClientService _httpClientService = HttpClientService();
  final RpcService _rpcService = RpcService();

  Future<bool> waitForConfirmation({
    required String txHash,
    required BlockchainService blockchain,
    String? networkKey,
    EvmChain? evmChain,
    Duration pollInterval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 2),
    Duration receiptTimeout = const Duration(seconds: 8),
    void Function(int attempts)? onPoll,
  }) async {
    final effectiveNetworkKey = networkKey?.trim().isNotEmpty == true
        ? networkKey!.trim()
        : blockchain.activeNetworkKey;
    final family = NetworkKey.familyOf(effectiveNetworkKey);

    if (family == ChainFamily.solana || family == ChainFamily.tron) {
      return _waitForNonEvmConfirmation(
        txHash: txHash,
        networkKey: effectiveNetworkKey,
        pollInterval: pollInterval,
        timeout: timeout,
        receiptTimeout: receiptTimeout,
        onPoll: onPoll,
      );
    }

    return _waitForEvmConfirmation(
      txHash: txHash,
      blockchain: blockchain,
      evmChain: evmChain,
      pollInterval: pollInterval,
      timeout: timeout,
      receiptTimeout: receiptTimeout,
      onPoll: onPoll,
    );
  }

  // ── EVM ────────────────────────────────────────────────────────────────────

  Future<bool> _waitForEvmConfirmation({
    required String txHash,
    required BlockchainService blockchain,
    EvmChain? evmChain,
    required Duration pollInterval,
    required Duration timeout,
    required Duration receiptTimeout,
    void Function(int attempts)? onPoll,
  }) async {
    final chain = evmChain ?? blockchain.activeChain;
    final rpcUrl = await _rpcService.resolveWorkingRpcUrl(
      chainId: chain.chainId,
      primaryRpcUrl: chain.rpcUrl,
    );
    final client = Web3Client(rpcUrl, _httpClientService.client);
    final completer = Completer<bool>();
    final stopwatch = Stopwatch()..start();
    int attempts = 0;
    var pollInFlight = false;
    Timer? timer;

    Future<void> pollReceipt() async {
      if (pollInFlight || completer.isCompleted) return;
      attempts++;
      onPoll?.call(attempts);
      if (stopwatch.elapsed >= timeout) {
        timer?.cancel();
        if (!completer.isCompleted) completer.complete(false);
        return;
      }
      pollInFlight = true;
      try {
        final receipt = await client
            .getTransactionReceipt(txHash)
            .timeout(receiptTimeout);
        if (receipt != null) {
          timer?.cancel();
          if (!completer.isCompleted) {
            completer.complete(receipt.status ?? false);
          }
        }
      } catch (e) {
        debugPrint('EVM tx monitor error: $e');
      } finally {
        pollInFlight = false;
      }
    }

    timer = Timer.periodic(pollInterval, (_) {
      if (stopwatch.elapsed >= timeout) {
        timer?.cancel();
        if (!completer.isCompleted) completer.complete(false);
        return;
      }
      unawaited(pollReceipt());
    });

    await pollReceipt();
    return completer.future;
  }

  // ── Solana / Tron ──────────────────────────────────────────────────────────

  /// Polls the backend `/networks/{networkKey}/transaction/{hash}` endpoint.
  ///
  /// The backend returns:
  ///   - `{ "pending": true }` while the tx is not yet finalised
  ///   - Solana: `{ "status": 1 }` for success, `{ "status": 0 }` for failure
  ///   - Tron:   `{ "result": "SUCCESS" }` for success, anything else for failure
  Future<bool> _waitForNonEvmConfirmation({
    required String txHash,
    required String networkKey,
    required Duration pollInterval,
    required Duration timeout,
    required Duration receiptTimeout,
    void Function(int attempts)? onPoll,
  }) async {
    final encodedKey = Uri.encodeComponent(networkKey);
    final encodedHash = Uri.encodeComponent(txHash);
    final uri = AppEnvironment.blockchain(
      '/networks/$encodedKey/transaction/$encodedHash',
    );

    final completer = Completer<bool>();
    final stopwatch = Stopwatch()..start();
    int attempts = 0;
    var pollInFlight = false;
    Timer? timer;

    Future<void> pollStatus() async {
      if (pollInFlight || completer.isCompleted) return;
      attempts++;
      onPoll?.call(attempts);
      if (stopwatch.elapsed >= timeout) {
        timer?.cancel();
        if (!completer.isCompleted) completer.complete(false);
        return;
      }
      pollInFlight = true;
      try {
        final response = await _httpClientService.client
            .get(uri)
            .timeout(receiptTimeout);

        if (response.statusCode != 200 && response.statusCode != 202) {
          // Non-retryable error from backend — stop polling.
          timer?.cancel();
          if (!completer.isCompleted) completer.complete(false);
          return;
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Still pending — keep polling.
        if (data['pending'] == true) return;

        timer?.cancel();
        if (!completer.isCompleted) {
          final confirmed = _isNonEvmSuccess(data, networkKey);
          completer.complete(confirmed);
        }
      } catch (e) {
        debugPrint('Non-EVM tx monitor error: $e');
      } finally {
        pollInFlight = false;
      }
    }

    timer = Timer.periodic(pollInterval, (_) {
      if (stopwatch.elapsed >= timeout) {
        timer?.cancel();
        if (!completer.isCompleted) completer.complete(false);
        return;
      }
      unawaited(pollStatus());
    });

    await pollStatus();
    return completer.future;
  }

  bool _isNonEvmSuccess(Map<String, dynamic> data, String networkKey) {
    if (networkKey.startsWith('solana:')) {
      // Solana: status=1 means success, status=0 means on-chain failure.
      final status = data['status'];
      if (status is int) return status == 1;
      if (status is num) return status.toInt() == 1;
      // err field being null also indicates success.
      return data['err'] == null;
    }
    if (networkKey.startsWith('tron:')) {
      // Tron: result="SUCCESS" means success.
      return data['result']?.toString().toUpperCase() == 'SUCCESS';
    }
    return false;
  }
}
