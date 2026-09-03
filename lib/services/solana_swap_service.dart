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
  final String? analyticsEventId;

  const SolanaSwapQuote({
    required this.amountOutFormatted,
    required this.amountOutRaw,
    required this.networkFeeUsd,
    required this.platformFeeUsd,
    required this.platformFeeBps,
    required this.swapTransaction,
    required this.requestId,
    this.analyticsEventId,
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
  /// Jupiter /order applies RTSE automatically; sending slippageBps would put
  /// the quote into manual mode and reduce router coverage.
  Future<SolanaSwapQuote?> getQuote({
    required String fromMint,
    required String toMint,
    required String amountLamports,
    required String walletAddress,
    double? sellAmountUsd,
    int slippageBps = 50,
  }) async {
    _lastError = null;
    try {
      final queryParams = <String, String>{
        'chainId': 'solana',
        'src': fromMint,
        'dst': toMint,
        'amount': amountLamports,
        'taker': walletAddress,
      };
      if (sellAmountUsd != null &&
          sellAmountUsd.isFinite &&
          sellAmountUsd > 0) {
        queryParams['sellAmountUsd'] = sellAmountUsd.toString();
      }
      final url = AppEnvironment.swap('/quote', queryParams);

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
    final txData =
        _asStringMap(data['tx_data']) ?? _asStringMap(data['txData']);
    final swapTx = _firstNonEmptyString([
      data['swapTransaction'],
      data['transaction'],
      data['serializedTransaction'],
      txData?['swapTransaction'],
      txData?['transaction'],
      txData?['serializedTransaction'],
    ]);
    if (swapTx == null || swapTx.isEmpty) {
      final providerMessage = _firstNonEmptyString([
        data['message'],
        data['errorMessage'],
        data['error'],
        data['jupiterError'],
        txData?['message'],
        txData?['errorMessage'],
        txData?['error'],
        txData?['jupiterError'],
      ]);
      final rawError = providerMessage == null
          ? 'Swap quote response was missing the unsigned transaction. Please try again.'
          : 'Jupiter swap quote error: $providerMessage';
      _lastError = AppErrorUtils.userMessage(
        rawError,
        fallback: 'Unable to fetch Solana swap quote right now.',
      );
      return null;
    }

    final requestId =
        _firstNonEmptyString([
          data['requestId'],
          data['request_id'],
          txData?['requestId'],
          txData?['request_id'],
        ]) ??
        '';

    final outAmount =
        _firstNonEmptyString([
          data['outAmount'],
          data['amountOut'],
          data['amount_out'],
          data['toAmount'],
          txData?['outAmount'],
          txData?['amountOut'],
          txData?['amount_out'],
        ]) ??
        '0';

    final outDecimals =
        _asInt(data['toDecimals']) ?? _asInt(txData?['toDecimals']) ?? 9;
    final outAmountNum = double.tryParse(outAmount) ?? 0.0;
    final outAmountFormatted = _formatTokenAmount(outAmountNum, outDecimals);

    final feeUsd =
        _asDouble(data['networkFeeUsd']) ??
        _asDouble(data['networkFee']) ??
        _asDouble(txData?['networkFeeUsd']) ??
        _asDouble(txData?['networkFee']) ??
        0.0;
    final platformFeeUsd =
        _asDouble(data['platformFeeUsd']) ??
        _asDouble(data['fee_usd']) ??
        _asDouble(txData?['platformFeeUsd']) ??
        _asDouble(txData?['feeUsd']) ??
        0.0;
    final platformFeeBps =
        _asInt(data['platformFeeBps']) ??
        _asInt(data['fee_bps']) ??
        _asInt(txData?['platformFeeBps']) ??
        _asInt(txData?['feeBps']) ??
        100;

    return SolanaSwapQuote(
      amountOutFormatted: outAmountFormatted,
      amountOutRaw: outAmount,
      networkFeeUsd: feeUsd,
      platformFeeUsd: platformFeeUsd,
      platformFeeBps: platformFeeBps,
      swapTransaction: swapTx,
      requestId: requestId,
      analyticsEventId: _firstNonEmptyString([
        data['analyticsEventId'],
        data['analytics_event_id'],
        txData?['analyticsEventId'],
      ]),
    );
  }

  Map<String, dynamic>? _asStringMap(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  String? _firstNonEmptyString(Iterable<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  int? _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _formatTokenAmount(double rawBaseUnits, int decimals) {
    if (decimals <= 0) return rawBaseUnits.toStringAsFixed(0);
    final value = rawBaseUnits / math.pow(10, decimals);
    final displayDecimals = decimals > 6 ? 6 : decimals;
    return value.toStringAsFixed(displayDecimals);
  }
}
