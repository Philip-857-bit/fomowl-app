import 'package:flutter/foundation.dart';

import '../utils/app_error_utils.dart';
import 'solana_swap_service.dart';
import 'wallet_service.dart';

/// Result of a Solana swap execution attempt.
class SolanaSwapExecutionResult {
  final bool success;
  final String? transactionHash;
  final String? error;
  final String? analyticsEventId;

  const SolanaSwapExecutionResult({
    required this.success,
    this.transactionHash,
    this.error,
    this.analyticsEventId,
  });
}

/// Handles the sign → broadcast pipeline for Solana swaps.
///
/// The backend already built and returned the unsigned transaction inside
/// [SolanaSwapQuote.swapTransaction] (base64). This service signs that
/// payload with the native VersionedTransaction helper, then POSTs it to
/// [SolanaSwapService.executeSwap].
class SolanaSwapExecutionService {
  SolanaSwapExecutionService({
    WalletService? walletService,
    SolanaSwapService? swapService,
  }) : _walletService = walletService ?? WalletService(),
       _swapService = swapService ?? SolanaSwapService();

  final WalletService _walletService;
  final SolanaSwapService _swapService;

  Future<SolanaSwapExecutionResult> execute({
    required SolanaSwapQuote quote,
    required String walletAddress,
  }) async {
    try {
      final signedTxBase64 = await _walletService
          .signSerializedSolanaTransaction(
            walletAddress,
            quote.swapTransaction,
          );

      final txHash = await _swapService.executeSwap(
        signedTransactionBase64: signedTxBase64,
        requestId: quote.requestId,
      );

      if (txHash != null && txHash.isNotEmpty) {
        return SolanaSwapExecutionResult(
          success: true,
          transactionHash: txHash,
          analyticsEventId: quote.analyticsEventId,
        );
      }

      return SolanaSwapExecutionResult(
        success: false,
        error: _swapService.lastError ?? 'Swap execution failed.',
      );
    } catch (e) {
      debugPrint('SolanaSwapExecutionService.execute error: $e');
      return SolanaSwapExecutionResult(
        success: false,
        error: AppErrorUtils.userMessage(
          e,
          fallback: 'Solana swap execution failed. Please try again.',
        ),
      );
    }
  }
}
