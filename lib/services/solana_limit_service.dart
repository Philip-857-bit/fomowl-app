import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../config/app_environment.dart';
import '../utils/app_error_utils.dart';
import 'http_client_service.dart';

/// A single Jupiter Trigger V2 limit order summary.
class SolanaLimitOrder {
  /// V2 uses orderId (unique identifier for the order).
  /// Falls back to orderAccount for backward compatibility.
  final String orderId;

  /// Legacy field alias — kept for backward compat with UI that references it.
  String get orderAccount => orderId;

  final String inputMint;
  final String outputMint;
  final String inputAmount;
  final String expectedOutputAmount;
  final String status;
  final int? expiredAt;

  /// Trigger price in USD (V2-specific).
  final double? triggerPriceUsd;

  const SolanaLimitOrder({
    required this.orderId,
    required this.inputMint,
    required this.outputMint,
    required this.inputAmount,
    required this.expectedOutputAmount,
    required this.status,
    this.expiredAt,
    this.triggerPriceUsd,
  });

  factory SolanaLimitOrder.fromJson(Map<String, dynamic> json) {
    return SolanaLimitOrder(
      orderId:
          json['orderId']?.toString() ??
          json['orderAccount']?.toString() ??
          json['id']?.toString() ??
          '',
      inputMint: json['inputMint']?.toString() ?? '',
      outputMint: json['outputMint']?.toString() ?? '',
      inputAmount:
          json['inputAmount']?.toString() ??
          json['inAmount']?.toString() ??
          '0',
      expectedOutputAmount:
          json['expectedOutputAmount']?.toString() ??
          json['outAmount']?.toString() ??
          '0',
      status: json['status']?.toString() ?? 'active',
      expiredAt: (json['expiredAt'] as num?)?.toInt(),
      triggerPriceUsd: (json['triggerPriceUsd'] as num?)?.toDouble(),
    );
  }
}

/// Result from the V2 deposit/craft step — returns an unsigned deposit transaction
/// that the client must sign and submit on-chain. After submission, the caller
/// must call [SolanaLimitService.confirmOrder] to finalize the limit order.
class SolanaLimitDepositResult {
  /// The base64-encoded unsigned deposit transaction.
  final String transaction;

  /// The deposit request ID — needed for [confirmOrder].
  final String depositRequestId;

  const SolanaLimitDepositResult({
    required this.transaction,
    required this.depositRequestId,
  });
}

/// Result from cancelOrder — returns an unsigned cancel transaction
/// that the client must sign and broadcast.
class SolanaLimitOrderTxResult {
  /// The base64-encoded unsigned transaction.
  final String transaction;

  /// Jupiter requestId to forward on execute.
  final String requestId;

  /// The order identifier (V2: orderId, legacy: orderAccount).
  final String? orderAccount;

  const SolanaLimitOrderTxResult({
    required this.transaction,
    required this.requestId,
    this.orderAccount,
  });
}

/// Service for Jupiter Trigger V2 limit orders on Solana.
///
/// V2 uses a two-step create flow:
///   1. [createOrder] → returns [SolanaLimitDepositResult] (deposit tx)
///   2. Caller signs & submits the deposit transaction on-chain
///   3. [confirmOrder] → sends deposit request ID + trigger parameters
///      to finalize the limit order
///
/// Cancelling:
///   1. [cancelOrder] → returns [SolanaLimitOrderTxResult] (cancel tx)
///   2. Caller signs & submits the cancel transaction on-chain
class SolanaLimitService {
  SolanaLimitService({HttpClientService? httpClientService})
    : _http = httpClientService ?? HttpClientService();

  final HttpClientService _http;
  String? _lastError;

  String? get lastError => _lastError;

  /// Step 1: POST /api/swap/jupiter/limit/create
  ///
  /// Calls the backend which proxies to Jupiter Trigger V2 `/deposit/craft`.
  /// Returns a [SolanaLimitDepositResult] with the unsigned deposit transaction
  /// and a depositRequestId for step 2.
  Future<SolanaLimitDepositResult?> createOrder({
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
        'inAmount': inputAmountLamports,
        'outAmount': expectedOutputAmountLamports,
        'maker': walletAddress,
        // V2 required fields — backend auto-injects these as defaults,
        // but we send them explicitly for clarity.
        'orderType': 'price',
        'orderSubType': 'single',
        ?'expiredAt': expiredAt,
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
          _lastError = 'Deposit response missing transaction.';
          return null;
        }
        final depositRequestId =
            data['depositRequestId']?.toString() ??
            data['requestId']?.toString() ??
            '';
        if (depositRequestId.isEmpty) {
          _lastError = 'Deposit response missing depositRequestId.';
          return null;
        }
        return SolanaLimitDepositResult(
          transaction: tx,
          depositRequestId: depositRequestId,
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

  /// Step 2: POST /api/swap/jupiter/limit/confirm
  ///
  /// After the deposit transaction has been signed and submitted on-chain,
  /// call this to finalize the limit order with trigger parameters.
  /// Proxies to Jupiter Trigger V2 `POST /orders/price`.
  Future<Map<String, dynamic>?> confirmOrder({
    required String depositRequestId,
    required String inputMint,
    required String outputMint,
    required String inputAmountLamports,
    required String expectedOutputAmountLamports,
    required double triggerPriceUsd,
    int? slippageBps,
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/jupiter/limit/confirm');
      final body = <String, dynamic>{
        'depositRequestId': depositRequestId,
        'inputMint': inputMint,
        'outputMint': outputMint,
        'inAmount': inputAmountLamports,
        'outAmount': expectedOutputAmountLamports,
        'triggerPriceUsd': triggerPriceUsd,
        'orderType': 'single',
        ?'slippageBps': slippageBps,
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
        if (raw is Map) {
          return Map<String, dynamic>.from(raw);
        }
        return {};
      }

      _lastError = AppErrorUtils.backendMessage(
        response.body,
        fallback: 'Unable to confirm Solana limit order right now.',
      );
      return null;
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to confirm Solana limit order right now.',
      );
      debugPrint('SolanaLimitService.confirmOrder error: $e');
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
    required String orderId,
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/jupiter/limit/cancel');
      // V2 uses orderId; backend alias also accepts orderAccount
      final payload = {'orderId': orderId};

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
          orderAccount: orderId,
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
