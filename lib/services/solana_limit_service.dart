import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../config/app_environment.dart';
import '../utils/app_error_utils.dart';
import 'http_client_service.dart';

/// A single Jupiter Trigger (limit) order summary.
class SolanaLimitOrder {
  final String orderAccount;
  final String inputMint;
  final String outputMint;
  final String inputAmount;
  final String expectedOutputAmount;
  final String status;
  final int? expiredAt;

  const SolanaLimitOrder({
    required this.orderAccount,
    required this.inputMint,
    required this.outputMint,
    required this.inputAmount,
    required this.expectedOutputAmount,
    required this.status,
    this.expiredAt,
  });

  factory SolanaLimitOrder.fromJson(Map<String, dynamic> json) {
    return SolanaLimitOrder(
      orderAccount: json['orderAccount']?.toString() ?? '',
      inputMint: json['inputMint']?.toString() ?? '',
      outputMint: json['outputMint']?.toString() ?? '',
      inputAmount: json['inputAmount']?.toString() ?? '0',
      expectedOutputAmount: json['expectedOutputAmount']?.toString() ?? '0',
      status: json['status']?.toString() ?? 'open',
      expiredAt: (json['expiredAt'] as num?)?.toInt(),
    );
  }
}

/// Result from createOrder / cancelOrder — both return an unsigned transaction
/// that the client must sign and then submit via /api/swap/jupiter/execute.
class SolanaLimitOrderTxResult {
  /// The base64-encoded unsigned transaction.
  final String transaction;

  /// Jupiter requestId to forward on execute.
  final String requestId;

  /// The Solana account that identifies this order (used for cancellation).
  final String? orderAccount;

  const SolanaLimitOrderTxResult({
    required this.transaction,
    required this.requestId,
    this.orderAccount,
  });
}

/// Service for Jupiter Trigger V1 limit orders on Solana.
///
/// Flow for creating a limit order:
///   1. [createOrder] → returns [SolanaLimitOrderTxResult]
///   2. Caller signs [SolanaLimitOrderTxResult.transaction] with Ed25519
///   3. Submit signed tx via [SolanaSwapService.executeSwap]
///      (reuses the same /api/swap/jupiter/execute endpoint)
///
/// Flow for cancelling:
///   1. [cancelOrder] → returns [SolanaLimitOrderTxResult]
///   2. Caller signs the transaction
///   3. Submit via [SolanaSwapService.executeSwap]
class SolanaLimitService {
  SolanaLimitService({HttpClientService? httpClientService})
    : _http = httpClientService ?? HttpClientService();

  final HttpClientService _http;
  String? _lastError;

  String? get lastError => _lastError;

  /// POST /api/swap/jupiter/limit/create
  /// Creates a Jupiter Trigger limit order. Returns an unsigned transaction.
  Future<SolanaLimitOrderTxResult?> createOrder({
    required String inputMint,
    required String outputMint,
    required String inputAmountLamports,
    required String expectedOutputAmountLamports,
    required String walletAddress,
    int? expiredAt,
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/jupiter/limit/create');
      final body = <String, dynamic>{
        'inputMint': inputMint,
        'outputMint': outputMint,
        'maker': walletAddress,
        'params': {
          'makingAmount': inputAmountLamports,
          'takingAmount': expectedOutputAmountLamports,
          if (expiredAt != null) 'expiredAt': '$expiredAt',
        },
        'computeUnitPrice': 'auto',
      };

      final response = await _http
          .sendWithRetry(
            () => _http.client.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            ),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = jsonDecode(response.body);
        if (raw is! Map) {
          _lastError = 'Unexpected response from limit order service.';
          return null;
        }
        final data = Map<String, dynamic>.from(raw);
        final tx =
            data['transaction']?.toString() ??
            data['swapTransaction']?.toString();
        if (tx == null || tx.isEmpty) {
          _lastError = 'Limit order response missing transaction.';
          return null;
        }
        return SolanaLimitOrderTxResult(
          transaction: tx,
          requestId: data['requestId']?.toString() ?? '',
          orderAccount: data['orderAccount']?.toString(),
        );
      }

      _lastError = AppErrorUtils.backendMessage(
        response.body,
        fallback: 'Unable to create Solana limit order right now.',
      );
      return null;
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to create Solana limit order right now.',
      );
      debugPrint('SolanaLimitService.createOrder error: $e');
      return null;
    }
  }

  /// GET `/api/swap/jupiter/limit/orders?user=<wallet>&status=open`
  Future<List<SolanaLimitOrder>> getOrders({
    required String walletAddress,
    String status = 'open',
  }) async {
    _lastError = null;
    try {
      final params = <String, String>{'user': walletAddress};
      if (status.isNotEmpty) {
        params['status'] = status;
      }
      final url = AppEnvironment.swap('/jupiter/limit/orders', params);

      final response = await _http
          .sendWithRetry(() => _http.client.get(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = jsonDecode(response.body);
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map(
                (e) => SolanaLimitOrder.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v)),
                ),
              )
              .toList();
        }
        if (raw is Map) {
          final orders = raw['orders'];
          if (orders is List) {
            return orders
                .whereType<Map>()
                .map(
                  (e) => SolanaLimitOrder.fromJson(
                    e.map((k, v) => MapEntry(k.toString(), v)),
                  ),
                )
                .toList();
          }
        }
        return [];
      }

      _lastError = AppErrorUtils.backendMessage(
        response.body,
        fallback: 'Unable to fetch Solana limit orders right now.',
      );
      return [];
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to fetch Solana limit orders right now.',
      );
      debugPrint('SolanaLimitService.getOrders error: $e');
      return [];
    }
  }

  /// POST /api/swap/jupiter/limit/cancel
  /// Returns an unsigned cancel transaction that must be signed and broadcast.
  Future<SolanaLimitOrderTxResult?> cancelOrder({
    required String orderAccount,
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/jupiter/limit/cancel');
      final payload = {'orderAccount': orderAccount};

      final response = await _http
          .sendWithRetry(
            () => _http.client.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            ),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = jsonDecode(response.body);
        if (raw is! Map) {
          _lastError = 'Unexpected response from cancel service.';
          return null;
        }
        final data = Map<String, dynamic>.from(raw);
        final tx =
            data['transaction']?.toString() ??
            data['swapTransaction']?.toString();
        if (tx == null || tx.isEmpty) {
          _lastError = 'Cancel response missing transaction.';
          return null;
        }
        return SolanaLimitOrderTxResult(
          transaction: tx,
          requestId: data['requestId']?.toString() ?? '',
          orderAccount: orderAccount,
        );
      }

      _lastError = AppErrorUtils.backendMessage(
        response.body,
        fallback: 'Unable to cancel Solana limit order right now.',
      );
      return null;
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to cancel Solana limit order right now.',
      );
      debugPrint('SolanaLimitService.cancelOrder error: $e');
      return null;
    }
  }
}
