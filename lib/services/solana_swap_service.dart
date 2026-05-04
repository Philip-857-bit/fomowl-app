import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../config/app_environment.dart';
import '../utils/app_error_utils.dart';
import 'http_client_service.dart';

/// Quote result returned by the backend Jupiter /api/swap/quote endpoint
/// when the active chain is Solana.
class SolanaSwapQuote {
  final String amountOutFormatted;
  final String amountOutRaw;
  final double networkFeeUsd;
  final double platformFeeUsd;
  final int platformFeeBps;

  /// The base64-encoded unsigned swap transaction from Jupiter.
  final String swapTransaction;

  /// Jupiter V2 requestId – must be forwarded on execute.
  final String requestId;

  const SolanaSwapQuote({
    required this.amountOutFormatted,
    required this.amountOutRaw,
    required this.networkFeeUsd,
    required this.platformFeeUsd,
    required this.platformFeeBps,
    required this.swapTransaction,
    required this.requestId,
  });

  double get platformFeePercent => platformFeeBps / 100.0;
}

/// Thin service that wraps the backend Jupiter swap endpoints for Solana.
///
/// Flow:
///   1. [getQuote]  → returns [SolanaSwapQuote] (includes unsigned tx)
///   2. Caller signs [SolanaSwapQuote.swapTransaction] with Ed25519 key
///   3. [executeSwap] → POSTs signed tx to /api/swap/jupiter/execute
class SolanaSwapService {
  SolanaSwapService({HttpClientService? httpClientService})
    : _http = httpClientService ?? HttpClientService();

  final HttpClientService _http;
  String? _lastError;

  String? get lastError => _lastError;

  /// Fetch a Jupiter V2 swap quote for a Solana token pair.
  ///
  /// [fromMint] and [toMint] are SPL mint addresses; use the special
  /// "So11111111111111111111111111111111111111112" for native SOL.
  Future<SolanaSwapQuote?> getQuote({
    required String fromMint,
    required String toMint,
    required String amountLamports,
    required String walletAddress,
    int slippageBps = 50,
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/quote', {
        'chainId': 'solana',
        'src': fromMint,
        'dst': toMint,
        'amount': amountLamports,
        'taker': walletAddress,
        'slippageBps': '$slippageBps',
      });

      final response = await _http
          .sendWithRetry(() => _http.client.get(url))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = jsonDecode(response.body);
        if (raw is! Map) {
          _lastError = 'Unexpected response format from swap service.';
          return null;
        }
        final data = Map<String, dynamic>.from(raw);
        return _parseQuote(data);
      }

      _lastError = AppErrorUtils.backendMessage(
        response.body,
        fallback: 'Unable to fetch Solana swap quote right now.',
      );
      return null;
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to fetch Solana swap quote right now.',
      );
      debugPrint('SolanaSwapService.getQuote error: $e');
      return null;
    }
  }

  /// Submit the signed transaction to the backend, which forwards it to
  /// Jupiter /swap/v2/execute. Returns the Solana transaction signature
  /// on success, or null on failure.
  Future<String?> executeSwap({
    required String signedTransactionBase64,
    required String requestId,
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/jupiter/execute');
      final payload = {
        'signedTransaction': signedTransactionBase64,
        'requestId': requestId,
      };

      final response = await _http
          .sendWithRetry(
            () => _http.client.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            ),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = jsonDecode(response.body);
        if (raw is Map) {
          final data = Map<String, dynamic>.from(raw);
          final txHash =
              data['txid']?.toString() ??
              data['signature']?.toString() ??
              data['transactionHash']?.toString() ??
              data['txHash']?.toString();
          if (txHash != null && txHash.isNotEmpty) {
            return txHash;
          }
        }
        _lastError = 'Swap submitted but no transaction signature returned.';
        return null;
      }

      _lastError = AppErrorUtils.backendMessage(
        response.body,
        fallback: 'Solana swap execution failed.',
      );
      return null;
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Solana swap execution failed.',
      );
      debugPrint('SolanaSwapService.executeSwap error: $e');
      return null;
    }
  }

  SolanaSwapQuote? _parseQuote(Map<String, dynamic> data) {
    final swapTx =
        data['swapTransaction']?.toString() ??
        data['transaction']?.toString() ??
        data['serializedTransaction']?.toString();
    if (swapTx == null || swapTx.isEmpty) {
      _lastError =
          'Swap quote response was missing the unsigned transaction. Please try again.';
      return null;
    }

    final requestId =
        data['requestId']?.toString() ?? data['request_id']?.toString() ?? '';

    final outAmount =
        data['outAmount']?.toString() ??
        data['amountOut']?.toString() ??
        data['toAmount']?.toString() ??
        '0';

    final outDecimals = (data['toDecimals'] as num?)?.toInt() ?? 9;
    final outAmountNum = double.tryParse(outAmount) ?? 0.0;
    final outAmountFormatted = _formatTokenAmount(outAmountNum, outDecimals);

    final feeUsd =
        (data['networkFeeUsd'] as num?)?.toDouble() ??
        (data['networkFee'] as num?)?.toDouble() ??
        0.0;
    final platformFeeUsd = (data['platformFeeUsd'] as num?)?.toDouble() ?? 0.0;
    final platformFeeBps = (data['platformFeeBps'] as num?)?.toInt() ?? 100;

    return SolanaSwapQuote(
      amountOutFormatted: outAmountFormatted,
      amountOutRaw: outAmount,
      networkFeeUsd: feeUsd,
      platformFeeUsd: platformFeeUsd,
      platformFeeBps: platformFeeBps,
      swapTransaction: swapTx,
      requestId: requestId,
    );
  }

  String _formatTokenAmount(double rawBaseUnits, int decimals) {
    if (decimals <= 0) return rawBaseUnits.toStringAsFixed(0);
    final value = rawBaseUnits / math.pow(10, decimals);
    final displayDecimals = decimals > 6 ? 6 : decimals;
    return value.toStringAsFixed(displayDecimals);
  }
}
