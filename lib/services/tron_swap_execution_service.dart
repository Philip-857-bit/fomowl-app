import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../utils/app_error_utils.dart';
import 'tron_swap_service.dart';
import 'transaction_monitor.dart';
import 'wallet_service.dart';
import 'blockchain_service.dart';

/// Result of a Tron swap execution attempt.
class TronSwapExecutionResult {
  final bool success;
  final String? transactionHash;
  final String? error;
  final String? analyticsEventId;
  final bool feeCollectionFailed;

  const TronSwapExecutionResult({
    required this.success,
    this.transactionHash,
    this.error,
    this.analyticsEventId,
    this.feeCollectionFailed = false,
  });
}

/// Handles the sign → broadcast pipeline for Tron swaps.
///
/// [TronSwapService.getQuote] already returns the unsigned transaction as a
/// JSON map. This service:
///   1. Signs the `raw_data_hex` field with the wallet's Tron secp256k1 key.
///   2. Attaches the signature to the transaction map.
///   3. Broadcasts the signed transaction via [TronSwapService.broadcastSignedTx].
class TronSwapExecutionService {
  TronSwapExecutionService({
    WalletService? walletService,
    TronSwapService? swapService,
    TransactionMonitor? transactionMonitor,
  }) : _walletService = walletService ?? WalletService(),
       _swapService = swapService ?? TronSwapService(),
       _transactionMonitor = transactionMonitor ?? TransactionMonitor();

  final WalletService _walletService;
  final TronSwapService _swapService;
  final TransactionMonitor _transactionMonitor;

  Future<TronSwapExecutionResult> execute({
    required TronSwapQuote quote,
    required String walletAddress,
    required BlockchainService blockchain,
  }) async {
    try {
      final approval = quote.approvalTx;
      if (approval != null) {
        final approvalHash = await _signBroadcastAndConfirm(
          transaction: approval,
          walletAddress: walletAddress,
          blockchain: blockchain,
          label: 'Token approval',
        );
        if (approvalHash.error != null) {
          return TronSwapExecutionResult(
            success: false,
            error: approvalHash.error,
          );
        }
      }

      var unsignedTransaction = quote.unsignedTx;
      if (unsignedTransaction == null) {
        final typedData = quote.permitTypedData;
        final finalizePayload = quote.finalizePayload;
        if (typedData == null || finalizePayload == null) {
          return const TronSwapExecutionResult(
            success: false,
            error: 'This TRON swap authorization is incomplete. Refresh the quote.',
          );
        }
        final permitSignature = await _walletService.signTypedDataForAddress(
          walletAddress,
          jsonEncode(typedData),
        );
        unsignedTransaction = await _swapService.finalizePermitSwap(
          payload: finalizePayload,
          signature: permitSignature,
        );
        if (unsignedTransaction == null) {
          return TronSwapExecutionResult(
            success: false,
            error:
                _swapService.lastError ?? 'Unable to authorize this TRON swap.',
          );
        }
      }

      // Sign the unsigned transaction. WalletService.signTronTransactionRaw
      // handles SHA-256 hashing of raw_data_hex and secp256k1 signing,
      // returning the tx map with `signature` list appended.
      final signedTx = await _walletService.signTronTransactionRaw(
        walletAddress,
        unsignedTransaction,
      );

      // Broadcast the signed transaction.
      final txid = await _swapService.broadcastSignedTx(
        signedTx,
        networkKey: blockchain.activeNetworkKey,
      );

      if (txid != null && txid.isNotEmpty) {
        final swapStatus = await _transactionMonitor.waitForConfirmation(
          txHash: txid,
          blockchain: blockchain,
          networkKey: blockchain.activeNetworkKey,
        );
        if (swapStatus == TransactionConfirmationStatus.failed) {
          return const TronSwapExecutionResult(
            success: false,
            error: 'The TRON swap reverted on-chain.',
          );
        }
        if (swapStatus == TransactionConfirmationStatus.pending) {
          return TronSwapExecutionResult(
            success: false,
            transactionHash: txid,
            error: 'The swap was submitted but is still pending. Do not submit it again.',
          );
        }

        return TronSwapExecutionResult(
          success: true,
          transactionHash: txid,
          analyticsEventId: quote.analyticsEventId,
          feeCollectionFailed: false,
        );
      }

      return TronSwapExecutionResult(
        success: false,
        error: _swapService.lastError ?? 'Swap broadcast failed.',
      );
    } catch (e) {
      debugPrint('TronSwapExecutionService.execute error: $e');
      return TronSwapExecutionResult(
        success: false,
        error: AppErrorUtils.userMessage(
          e,
          fallback: 'Tron swap execution failed. Please try again.',
        ),
      );
    }
  }

  Future<({String? hash, String? error})> _signBroadcastAndConfirm({
    required Map<String, dynamic> transaction,
    required String walletAddress,
    required BlockchainService blockchain,
    required String label,
  }) async {
    final signed = await _walletService.signTronTransactionRaw(
      walletAddress,
      transaction,
    );
    final hash = await _swapService.broadcastSignedTx(
      signed,
      networkKey: blockchain.activeNetworkKey,
    );
    if (hash == null || hash.isEmpty) {
      return (
        hash: null,
        error: _swapService.lastError ?? '$label broadcast failed.',
      );
    }
    final status = await _transactionMonitor.waitForConfirmation(
      txHash: hash,
      blockchain: blockchain,
      networkKey: blockchain.activeNetworkKey,
    );
    return switch (status) {
      TransactionConfirmationStatus.confirmed => (hash: hash, error: null),
      TransactionConfirmationStatus.failed => (
        hash: hash,
        error: '$label failed on-chain.',
      ),
      TransactionConfirmationStatus.pending => (
        hash: hash,
        error: '$label is still pending. Do not submit the swap again.',
      ),
    };
  }
}
