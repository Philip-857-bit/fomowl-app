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
  final double networkFeeNative;
  final double networkFeeUsd;
  final double platformFeeUsd;
  final int platformFeeBps;
  final String platformFeeAmountRaw;
  final String? platformFeeRecipient;
  final String? analyticsEventId;

  /// Unsigned Tron transaction JSON returned by SunSwap / the backend.
  /// Contains a `raw_data_hex` field that must be signed.
  final Map<String, dynamic>? unsignedTx;
  final Map<String, dynamic>? approvalTx;
  final Map<String, dynamic>? feeTx;
  final Map<String, dynamic>? permitTypedData;
  final Map<String, dynamic>? finalizePayload;

  const TronSwapQuote({
    required this.amountOutFormatted,
    required this.amountOutRaw,
    required this.networkFeeNative,
    required this.networkFeeUsd,
    required this.platformFeeUsd,
    required this.platformFeeBps,
    required this.platformFeeAmountRaw,
    required this.unsignedTx,
    this.platformFeeRecipient,
    this.approvalTx,
    this.feeTx,
    this.permitTypedData,
    this.finalizePayload,
    this.analyticsEventId,
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
    int toTokenDecimals = 6,
    double? sellAmountUsd,
    int slippageBps = 50,
  }) async {
    _lastError = null;
    try {
      final queryParams = <String, String>{
        'chainId': 'tron',
        'src': fromToken,
        'dst': toToken,
        'amount': amountSun,
        'taker': walletAddress,
        'slippageBps': '$slippageBps',
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
        return _parseQuote(data, toTokenDecimals: toTokenDecimals);
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
  Future<String?> broadcastSignedTx(
    Map<String, dynamic> signedTx, {
    String networkKey = 'tron:mainnet',
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.blockchain(
        '/networks/${Uri.encodeComponent(networkKey)}/broadcast',
      );
      final response = await _http
          .sendWithRetry(
            () => _http.client.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'signedTransactionJson': signedTx}),
            ),
            maxRetries: 1,
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

  Future<Map<String, dynamic>?> finalizePermitSwap({
    required Map<String, dynamic> payload,
    required String signature,
  }) async {
    _lastError = null;
    try {
      final response = await _http
          .sendWithRetry(
            () => _http.client.post(
              AppEnvironment.swap('/tron/finalize'),
              headers: const {'content-type': 'application/json'},
              body: jsonEncode({...payload, 'signature': signature}),
            ),
            maxRetries: 1,
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _lastError = AppErrorUtils.backendMessage(
          response.body,
          fallback: 'Unable to authorize this TRON swap.',
        );
        return null;
      }
      final raw = jsonDecode(response.body);
      if (raw is! Map || raw['transaction'] is! Map) {
        _lastError = 'The authorized TRON transaction was incomplete.';
        return null;
      }
      return Map<String, dynamic>.from(raw['transaction'] as Map);
    } catch (error) {
      _lastError = AppErrorUtils.userMessage(
        error,
        fallback: 'Unable to authorize this TRON swap.',
      );
      return null;
    }
  }

  TronSwapQuote? _parseQuote(
    Map<String, dynamic> data, {
    required int toTokenDecimals,
  }) {
    final tx = data['transaction'];
    final permit2 = data['permit2'];
    final finalizePayload = data['finalizePayload'];
    if (tx == null && (permit2 is! Map || finalizePayload is! Map)) {
      _lastError =
          'Swap quote response was missing its authorization data. Please try again.';
      return null;
    }

    final unsignedTx = tx is Map ? Map<String, dynamic>.from(tx) : null;

    if (unsignedTx != null &&
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

    final outDecimals = toTokenDecimals.clamp(0, 36);
    final outAmountNum = double.tryParse(outAmount) ?? 0.0;
    final outAmountFormatted = _formatTokenAmount(outAmountNum, outDecimals);

    final feeUsd =
        (data['networkFeeUsd'] as num?)?.toDouble() ??
        (data['networkFee'] as num?)?.toDouble() ??
        0.0;
    final feeNative = (data['networkFeeNative'] as num?)?.toDouble() ?? 0.0;
    final platformFeeUsd = (data['platformFeeUsd'] as num?)?.toDouble() ?? 0.0;
    final platformFeeBps = (data['platformFeeBps'] as num?)?.toInt() ?? 100;
    final approvalTx = _optionalTransaction(data['approvalTransaction']);
    final feeTx = _optionalTransaction(data['feeTransaction']);
    if (data['approvalTransaction'] != null && approvalTx == null) {
      _lastError =
          'Swap approval response was not signable. Please refresh the quote.';
      return null;
    }
    if (data['feeTransaction'] != null && feeTx == null) {
      _lastError =
          'Swap fee response was not signable. Please refresh the quote.';
      return null;
    }

    return TronSwapQuote(
      amountOutFormatted: outAmountFormatted,
      amountOutRaw: outAmount,
      networkFeeNative: feeNative,
      networkFeeUsd: feeUsd,
      platformFeeUsd: platformFeeUsd,
      platformFeeBps: platformFeeBps,
      platformFeeAmountRaw: data['feeAmount']?.toString() ?? '0',
      platformFeeRecipient: data['feeRecipient']?.toString(),
      unsignedTx: unsignedTx,
      approvalTx: approvalTx,
      feeTx: feeTx,
      permitTypedData: permit2 is Map && permit2['typedData'] is Map
          ? Map<String, dynamic>.from(permit2['typedData'] as Map)
          : null,
      finalizePayload: finalizePayload is Map
          ? Map<String, dynamic>.from(finalizePayload)
          : null,
      analyticsEventId:
          data['analyticsEventId']?.toString() ??
          data['analytics_event_id']?.toString(),
    );
  }

  Map<String, dynamic>? _optionalTransaction(Object? value) {
    if (value == null) return null;
    if (value is! Map) return null;
    final transaction = Map<String, dynamic>.from(value);
    if (transaction['raw_data_hex'] == null &&
        transaction['rawDataHex'] == null) {
      return null;
    }
    return transaction;
  }

  String _formatTokenAmount(double rawBaseUnits, int decimals) {
    if (decimals <= 0) return rawBaseUnits.toStringAsFixed(0);
    final value = rawBaseUnits / math.pow(10, decimals);
    final displayDecimals = decimals > 6 ? 6 : decimals;
    return value.toStringAsFixed(displayDecimals);
  }
}
