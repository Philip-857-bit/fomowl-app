import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../config/app_environment.dart';
import '../utils/app_error_utils.dart';
import 'http_client_service.dart';

/// Quote result from the backend SunSwap endpoint for Tron.
class TronSwapQuote {
  final String amountOutFormatted;
  final String amountOutRaw;
  final double networkFeeUsd;
  final double platformFeeUsd;
  final int platformFeeBps;

  /// Unsigned Tron transaction JSON returned by SunSwap / the backend.
  /// Contains a `raw_data_hex` field that must be signed.
  final Map<String, dynamic> unsignedTx;

  const TronSwapQuote({
    required this.amountOutFormatted,
    required this.amountOutRaw,
    required this.networkFeeUsd,
    required this.platformFeeUsd,
    required this.platformFeeBps,
    required this.unsignedTx,
  });

  double get platformFeePercent => platformFeeBps / 100.0;
}

/// Thin service that wraps the backend SunSwap endpoints for Tron.
///
/// Flow:
///   1. [getQuote] → returns [TronSwapQuote] (includes unsigned tx)
///   2. Caller signs [TronSwapQuote.unsignedTx] with Tron secp256k1 key
///   3. [broadcastSignedTx] → POSTs the signed tx back to the backend
///      which forwards it to the Tron full-node broadcast endpoint
class TronSwapService {
  TronSwapService({HttpClientService? httpClientService})
    : _http = httpClientService ?? HttpClientService();

  final HttpClientService _http;
  String? _lastError;

  String? get lastError => _lastError;

  /// Fetch a SunSwap quote for a Tron token pair.
  ///
  /// [fromToken] and [toToken] are TRC-20 contract addresses or
  /// the special string "T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb" for TRX.
  Future<TronSwapQuote?> getQuote({
    required String fromToken,
    required String toToken,
    required String amountSun,
    required String walletAddress,
    int slippageBps = 50,
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/quote', {
        'chainId': 'tron',
        'src': fromToken,
        'dst': toToken,
        'amount': amountSun,
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
        fallback: 'Unable to fetch Tron swap quote right now.',
      );
      return null;
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to fetch Tron swap quote right now.',
      );
      debugPrint('TronSwapService.getQuote error: $e');
      return null;
    }
  }

  /// Broadcast a signed Tron transaction.
  ///
  /// [signedTx] must be the original unsigned tx JSON map with the
  /// `signature` list appended (as returned by [WalletService.signTronTransactionRaw]).
  /// Returns the Tron txid on success.
  Future<String?> broadcastSignedTx(Map<String, dynamic> signedTx) async {
    _lastError = null;
    try {
      final url = AppEnvironment.blockchain('/networks/tron:mainnet/broadcast');
      final response = await _http
          .sendWithRetry(
            () => _http.client.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'transaction': signedTx}),
            ),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = jsonDecode(response.body);
        if (raw is Map) {
          final data = Map<String, dynamic>.from(raw);
          final txid =
              data['txid']?.toString() ??
              data['txHash']?.toString() ??
              data['transactionHash']?.toString() ??
              data['id']?.toString();
          if (txid != null && txid.isNotEmpty) {
            return txid;
          }
        }
        _lastError = 'Transaction broadcast succeeded but no txid returned.';
        return null;
      }

      _lastError = AppErrorUtils.backendMessage(
        response.body,
        fallback: 'Tron transaction broadcast failed.',
      );
      return null;
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Tron transaction broadcast failed.',
      );
      debugPrint('TronSwapService.broadcastSignedTx error: $e');
      return null;
    }
  }

  TronSwapQuote? _parseQuote(Map<String, dynamic> data) {
    final tx = data['transaction'];
    if (tx == null) {
      _lastError =
          'Swap quote response was missing the unsigned transaction. Please try again.';
      return null;
    }

    final unsignedTx = tx is Map
        ? Map<String, dynamic>.from(tx)
        : <String, dynamic>{};

    if (unsignedTx.isEmpty ||
        (unsignedTx['raw_data_hex'] == null &&
            unsignedTx['rawDataHex'] == null)) {
      _lastError =
          'Swap quote response is missing raw_data_hex. Please try again.';
      return null;
    }

    final outAmount =
        data['outAmount']?.toString() ??
        data['amountOut']?.toString() ??
        data['toAmount']?.toString() ??
        '0';

    final outDecimals = (data['toDecimals'] as num?)?.toInt() ?? 6;
    final outAmountNum = double.tryParse(outAmount) ?? 0.0;
    final outAmountFormatted = _formatTokenAmount(outAmountNum, outDecimals);

    final feeUsd =
        (data['networkFeeUsd'] as num?)?.toDouble() ??
        (data['networkFee'] as num?)?.toDouble() ??
        0.0;
    final platformFeeUsd = (data['platformFeeUsd'] as num?)?.toDouble() ?? 0.0;
    final platformFeeBps = (data['platformFeeBps'] as num?)?.toInt() ?? 100;

    return TronSwapQuote(
      amountOutFormatted: outAmountFormatted,
      amountOutRaw: outAmount,
      networkFeeUsd: feeUsd,
      platformFeeUsd: platformFeeUsd,
      platformFeeBps: platformFeeBps,
      unsignedTx: unsignedTx,
    );
  }

  String _formatTokenAmount(double rawBaseUnits, int decimals) {
    if (decimals <= 0) return rawBaseUnits.toStringAsFixed(0);
    final value = rawBaseUnits / math.pow(10, decimals);
    final displayDecimals = decimals > 6 ? 6 : decimals;
    return value.toStringAsFixed(displayDecimals);
  }
}
