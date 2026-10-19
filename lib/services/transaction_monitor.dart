import 'dart:async';
import '../models/bitcoin_account_state.dart';
import 'bitcoin/bitcoin_network_service.dart';
import 'bitcoin/bitcoin_transaction_monitor.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';

import '../config/app_environment.dart';
import '../models/chain.dart';
import 'blockchain_service.dart';
import 'http_client_service.dart';

enum TransactionConfirmationStatus { confirmed, failed, pending }

class TransactionMonitor {
  final BitcoinTransactionMonitor _bitcoin;
  TransactionMonitor({BitcoinNetworkApi? bitcoinNetwork})
    : _bitcoin = BitcoinTransactionMonitor(network: bitcoinNetwork);
  final HttpClientService _httpClientService = HttpClientService();

  Future<TransactionConfirmationStatus> waitForConfirmation({
    required String txHash,
    required BlockchainService blockchain,
    String? networkKey,
    EvmChain? evmChain,
    Duration pollInterval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 2),
    Duration receiptTimeout = const Duration(seconds: 8),
    void Function(int attempts)? onPoll,
    bool Function()? isCurrent,
  }) async {
    final effectiveNetworkKey = networkKey?.trim().isNotEmpty == true
        ? networkKey!.trim()
        : blockchain.activeNetworkKey;
    final family = NetworkKey.familyOf(effectiveNetworkKey);

    if (family == ChainFamily.bitcoin) {
      final confirmed = await _bitcoin.wait(
        txid: txHash,
        productNetwork: BitcoinProductNetwork.fromId(
          NetworkKey.bitcoinNetworkIdOf(effectiveNetworkKey),
        ),
        pollInterval: pollInterval,
        timeout: timeout,
        requestTimeout: receiptTimeout,
        onPoll: onPoll,
        isCurrent: isCurrent,
      );
      return confirmed
          ? TransactionConfirmationStatus.confirmed
          : TransactionConfirmationStatus.pending;
    }

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

  Future<TransactionConfirmationStatus> _waitForEvmConfirmation({
    required String txHash,
    required BlockchainService blockchain,
    EvmChain? evmChain,
    required Duration pollInterval,
    required Duration timeout,
    required Duration receiptTimeout,
    void Function(int attempts)? onPoll,
  }) async {
    final chain = evmChain ?? blockchain.activeChain;
    // The configured URL is Owllet's RPC proxy in production. Sending the
    // receipt request directly lets the backend's shared cache select an
    // upstream once per chain instead of running a separate eth_chainId probe
    // in every screen before confirmation polling begins.
    final client = Web3Client(chain.rpcUrl, _httpClientService.client);
    final completer = Completer<TransactionConfirmationStatus>();
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
        if (!completer.isCompleted) {
          completer.complete(TransactionConfirmationStatus.pending);
        }
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
            completer.complete(
              confirmationStatusFromEvmReceipt(receipt.status),
            );
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
        if (!completer.isCompleted) {
          completer.complete(TransactionConfirmationStatus.pending);
        }
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
  Future<TransactionConfirmationStatus> _waitForNonEvmConfirmation({
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

    final completer = Completer<TransactionConfirmationStatus>();
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
        if (!completer.isCompleted) {
          completer.complete(TransactionConfirmationStatus.pending);
        }
        return;
      }
      pollInFlight = true;
      try {
        final response = await _httpClientService.client
            .get(uri)
            .timeout(receiptTimeout);

        if (response.statusCode != 200 && response.statusCode != 202) {
          // An unavailable status endpoint does not prove that a broadcast
          // transaction failed. Keep polling until the bounded timeout.
          return;
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Still pending — keep polling.
        if (data['pending'] == true) return;

        timer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(_nonEvmStatus(data, networkKey));
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
        if (!completer.isCompleted) {
          completer.complete(TransactionConfirmationStatus.pending);
        }
        return;
      }
      unawaited(pollStatus());
    });

    await pollStatus();
    return completer.future;
  }

  @visibleForTesting
  TransactionConfirmationStatus confirmationStatusFromEvmReceipt(
    bool? receiptStatus,
  ) {
    if (receiptStatus == true) return TransactionConfirmationStatus.confirmed;
    if (receiptStatus == false) return TransactionConfirmationStatus.failed;
    return TransactionConfirmationStatus.pending;
  }

  @visibleForTesting
  TransactionConfirmationStatus nonEvmStatusForTest(
    Map<String, dynamic> data,
    String networkKey,
  ) => _nonEvmStatus(data, networkKey);

  TransactionConfirmationStatus _nonEvmStatus(
    Map<String, dynamic> data,
    String networkKey,
  ) {
    if (data['pending'] == true) {
      return TransactionConfirmationStatus.pending;
    }
    if (networkKey.startsWith('solana:')) {
      // Solana: status=1 means success, status=0 means on-chain failure.
      final status = data['status'];
      if (status is num) {
        return status.toInt() == 1
            ? TransactionConfirmationStatus.confirmed
            : TransactionConfirmationStatus.failed;
      }
      if (data.containsKey('err')) {
        return data['err'] == null
            ? TransactionConfirmationStatus.confirmed
            : TransactionConfirmationStatus.failed;
      }
      return TransactionConfirmationStatus.pending;
    }
    if (networkKey.startsWith('tron:')) {
      final result = data['result']?.toString().trim().toUpperCase();
      if (result == null || result.isEmpty) {
        return TransactionConfirmationStatus.pending;
      }
      return result == 'SUCCESS'
          ? TransactionConfirmationStatus.confirmed
          : TransactionConfirmationStatus.failed;
    }
    return TransactionConfirmationStatus.pending;
  }
}
