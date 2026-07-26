import 'package:flutter/foundation.dart';

import '../utils/app_error_utils.dart';
import 'tron_swap_service.dart';
import 'wallet_service.dart';

/// Result of a Tron swap execution attempt.
class TronSwapExecutionResult {
  final bool success;
  final String? transactionHash;
  final String? error;
  final String? analyticsEventId;

  const TronSwapExecutionResult({
    required this.success,
    this.transactionHash,
    this.error,
    this.analyticsEventId,
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
  }) : _walletService = walletService ?? WalletService(),
       _swapService = swapService ?? TronSwapService();

  final WalletService _walletService;
  final TronSwapService _swapService;

  Future<TronSwapExecutionResult> execute({
    required TronSwapQuote quote,
    required String walletAddress,
  }) async {
    try {
      // Sign the unsigned transaction. WalletService.signTronTransactionRaw
      // handles SHA-256 hashing of raw_data_hex and secp256k1 signing,
      // returning the tx map with `signature` list appended.
      final signedTx = await _walletService.signTronTransactionRaw(
        walletAddress,
        quote.unsignedTx,
      );

      // Broadcast the signed transaction.
      final txid = await _swapService.broadcastSignedTx(signedTx);

      if (txid != null && txid.isNotEmpty) {
        return TronSwapExecutionResult(
          success: true,
          transactionHash: txid,
          analyticsEventId: quote.analyticsEventId,
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
}
