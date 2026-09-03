import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_environment.dart';
import '../utils/app_error_utils.dart';
import 'http_client_service.dart';
import 'secure_store.dart';

/// A single Jupiter Trigger V2 limit order summary.
class SolanaLimitOrder {
  /// V2 order UUID.
  final String orderId;

  /// Legacy field alias — kept for backward compat with UI that references it.
  String get orderAccount => orderId;

  final String inputMint;
  final String outputMint;

  /// Initial deposited input amount in smallest units.
  final String inputAmount;

  /// Remaining (unfilled) input amount in smallest units.
  final String remainingInputAmount;

  /// Expected output amount — V2 does not return this; derived client-side
  /// when possible, otherwise '0'.
  final String expectedOutputAmount;

  /// V2 orderState: pending | open | executing | filled | pending_withdraw |
  /// cancelled | expired | failed.
  final String status;

  /// Expiry as a unix timestamp in seconds (normalized from V2 milliseconds).
  final int? expiredAt;

  /// Trigger price in USD.
  final double? triggerPriceUsd;

  /// Trigger condition: above | below.
  final String? triggerCondition;

  const SolanaLimitOrder({
    required this.orderId,
    required this.inputMint,
    required this.outputMint,
    required this.inputAmount,
    required this.remainingInputAmount,
    required this.expectedOutputAmount,
    required this.status,
    this.expiredAt,
    this.triggerPriceUsd,
    this.triggerCondition,
  });

  factory SolanaLimitOrder.fromJson(Map<String, dynamic> json) {
    final initialInput =
        json['initialInputAmount']?.toString() ??
        json['inputAmount']?.toString() ??
        json['inAmount']?.toString() ??
        '0';
    return SolanaLimitOrder(
      orderId:
          json['id']?.toString() ??
          json['orderId']?.toString() ??
          json['orderAccount']?.toString() ??
          '',
      inputMint: json['inputMint']?.toString() ?? '',
      outputMint: json['outputMint']?.toString() ?? '',
      inputAmount: initialInput,
      remainingInputAmount:
          json['remainingInputAmount']?.toString() ?? initialInput,
      expectedOutputAmount:
          json['expectedOutputAmount']?.toString() ??
          json['outAmount']?.toString() ??
          '0',
      status:
          json['orderState']?.toString() ??
          json['status']?.toString() ??
          'open',
      expiredAt: _normalizeEpochSeconds(json['expiresAt'] ?? json['expiredAt']),
      triggerPriceUsd: (json['triggerPriceUsd'] as num?)?.toDouble(),
      triggerCondition: json['triggerCondition']?.toString(),
    );
  }

  /// V2 reports `expiresAt` in milliseconds; legacy used seconds.
  static int? _normalizeEpochSeconds(Object? raw) {
    final value = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '');
    if (value == null || value <= 0) return null;
    // Anything above ~Nov 2286 in seconds must be milliseconds.
    return value > 9999999999 ? value ~/ 1000 : value;
  }
}

/// Result from the V2 deposit/craft step — returns an unsigned deposit
/// transaction. The caller signs it but must NOT broadcast it: the signed
/// bytes are passed to [SolanaLimitService.confirmOrder] as `depositSignedTx`
/// and Jupiter broadcasts the deposit itself.
class SolanaLimitDepositResult {
  /// The base64-encoded unsigned deposit transaction.
  final String transaction;

  /// The deposit request ID — needed for [SolanaLimitService.confirmOrder].
  final String depositRequestId;

  const SolanaLimitDepositResult({
    required this.transaction,
    required this.depositRequestId,
  });
}

/// Result from cancelOrder (step 1 of 2) — returns an unsigned withdrawal
/// transaction that the client must sign and pass to
/// [SolanaLimitService.confirmCancel] (NOT broadcast directly).
class SolanaLimitOrderTxResult {
  /// The base64-encoded unsigned transaction.
  final String transaction;

  /// Cancel request ID to forward to confirmCancel.
  final String requestId;

  /// The order identifier.
  final String? orderAccount;

  const SolanaLimitOrderTxResult({
    required this.transaction,
    required this.requestId,
    this.orderAccount,
  });
}

/// Service for Jupiter Trigger V2 limit orders on Solana.
///
/// All wallet-scoped Trigger V2 endpoints require a per-wallet JWT obtained by
/// signing an auth challenge (valid 24h). [ensureAuthenticated] runs that flow
/// transparently using the wallet's local key and caches the token in secure
/// storage, so users are never prompted.
///
/// Create flow:
///   1. [ensureAuthenticated]
///   2. [createOrder] → unsigned deposit tx + depositRequestId
///   3. Caller signs the deposit transaction (no broadcast)
///   4. [confirmOrder] with the signed tx — Jupiter broadcasts it and opens
///      the order
///
/// Cancel flow:
///   1. [cancelOrder] → unsigned withdrawal tx + cancelRequestId
///   2. Caller signs the withdrawal transaction (no broadcast)
///   3. [confirmCancel] — Jupiter broadcasts and returns funds
class SolanaLimitService {
  SolanaLimitService({
    HttpClientService? httpClientService,
    SecureStore? secureStore,
  }) : _http = httpClientService ?? HttpClientService(),
       _secureStore = secureStore ?? const FlutterSecureStoreAdapter();

  final HttpClientService _http;
  final SecureStore _secureStore;
  String? _lastError;

  String? get lastError => _lastError;

  /// Jupiter JWTs last 24h; refresh slightly early to avoid edge expiries.
  static const Duration _tokenLifetime = Duration(hours: 23);

  String? _token;
  DateTime? _tokenExpiry;
  String? _tokenWallet;

  static String _tokenStorageKey(String walletAddress) =>
      'jupiter_trigger_jwt_$walletAddress';

  bool _hasValidToken(String walletAddress) {
    return _token != null &&
        _tokenWallet == walletAddress &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!);
  }

  /// Whether a usable session exists (memory or secure storage) without
  /// running the signature flow.
  Future<bool> hasSession(String walletAddress) async {
    if (_hasValidToken(walletAddress)) return true;
    return await _loadStoredToken(walletAddress);
  }

  Future<bool> _loadStoredToken(String walletAddress) async {
    try {
      final raw = await _secureStore.read(key: _tokenStorageKey(walletAddress));
      if (raw == null || raw.isEmpty) return false;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final token = decoded['token']?.toString();
      final expiresAtMs = (decoded['expiresAt'] as num?)?.toInt();
      if (token == null || token.isEmpty || expiresAtMs == null) return false;
      final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAtMs);
      if (!DateTime.now().isBefore(expiry)) return false;
      _token = token;
      _tokenExpiry = expiry;
      _tokenWallet = walletAddress;
      return true;
    } catch (e) {
      debugPrint('SolanaLimitService._loadStoredToken error: $e');
      return false;
    }
  }

  Future<void> _persistToken(String walletAddress) async {
    final token = _token;
    final expiry = _tokenExpiry;
    if (token == null || expiry == null) return;
    try {
      await _secureStore.write(
        key: _tokenStorageKey(walletAddress),
        value: jsonEncode({
          'token': token,
          'expiresAt': expiry.millisecondsSinceEpoch,
        }),
      );
    } catch (e) {
      debugPrint('SolanaLimitService._persistToken error: $e');
    }
  }

  Future<void> _clearSession(String walletAddress) async {
    _token = null;
    _tokenExpiry = null;
    _tokenWallet = null;
    try {
      await _secureStore.delete(key: _tokenStorageKey(walletAddress));
    } catch (_) {}
  }

  Map<String, String> _headers({bool json = false}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  /// Runs the Trigger V2 challenge → sign → verify flow if no valid session
  /// exists. [signMessage] receives the raw challenge bytes and must return a
  /// base58 ed25519 signature from the wallet key (no user prompt needed —
  /// the app holds the key).
  Future<bool> ensureAuthenticated({
    required String walletAddress,
    required Future<String> Function(Uint8List message) signMessage,
  }) async {
    _lastError = null;
    if (_hasValidToken(walletAddress)) return true;
    if (await _loadStoredToken(walletAddress)) return true;

    try {
      final challengeResponse = await _http
          .sendWithRetry(
            () => _http.client.post(
              AppEnvironment.swap('/jupiter/limit/auth/challenge'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'walletPubkey': walletAddress,
                'type': 'message',
              }),
            ),
          )
          .timeout(const Duration(seconds: 15));
      if (challengeResponse.statusCode < 200 ||
          challengeResponse.statusCode >= 300) {
        _lastError = AppErrorUtils.backendMessage(
          challengeResponse.body,
          fallback: 'Unable to authenticate for Solana limit orders.',
        );
        return false;
      }
      final challengeRaw = jsonDecode(challengeResponse.body);
      final challenge = challengeRaw is Map
          ? challengeRaw['challenge']?.toString()
          : null;
      if (challenge == null || challenge.isEmpty) {
        _lastError = 'Authentication challenge was incomplete.';
        return false;
      }

      final signature = await signMessage(
        Uint8List.fromList(utf8.encode(challenge)),
      );

      final verifyResponse = await _http
          .sendWithRetry(
            () => _http.client.post(
              AppEnvironment.swap('/jupiter/limit/auth/verify'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'type': 'message',
                'walletPubkey': walletAddress,
                'signature': signature,
              }),
            ),
          )
          .timeout(const Duration(seconds: 15));
      if (verifyResponse.statusCode < 200 || verifyResponse.statusCode >= 300) {
        _lastError = AppErrorUtils.backendMessage(
          verifyResponse.body,
          fallback: 'Unable to authenticate for Solana limit orders.',
        );
        return false;
      }
      final verifyRaw = jsonDecode(verifyResponse.body);
      final token = verifyRaw is Map ? verifyRaw['token']?.toString() : null;
      if (token == null || token.isEmpty) {
        _lastError = 'Authentication response missing token.';
        return false;
      }

      _token = token;
      _tokenExpiry = DateTime.now().add(_tokenLifetime);
      _tokenWallet = walletAddress;
      await _persistToken(walletAddress);
      return true;
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to authenticate for Solana limit orders.',
      );
      debugPrint('SolanaLimitService.ensureAuthenticated error: $e');
      return false;
    }
  }

  /// Ensures the wallet has a Trigger V2 vault, registering one on first use.
  /// Returns true when a vault exists (or was just created).
  Future<bool> ensureVault({required String walletAddress}) async {
    _lastError = null;
    try {
      final vaultResponse = await _http
          .sendWithRetry(
            () => _http.client.get(
              AppEnvironment.swap('/jupiter/vault'),
              headers: _headers(),
            ),
            retryIf: (response) => response.statusCode >= 500,
          )
          .timeout(const Duration(seconds: 15));
      if (vaultResponse.statusCode >= 200 && vaultResponse.statusCode < 300) {
        return true;
      }
      if (vaultResponse.statusCode != 404 && vaultResponse.statusCode != 403) {
        _lastError = AppErrorUtils.backendMessage(
          vaultResponse.body,
          fallback: 'Unable to prepare the Solana limit order vault.',
        );
        return false;
      }

      final registerResponse = await _http
          .sendWithRetry(
            () => _http.client.get(
              AppEnvironment.swap('/jupiter/vault/register'),
              headers: _headers(),
            ),
            retryIf: (response) => response.statusCode >= 500,
          )
          .timeout(const Duration(seconds: 20));
      if (registerResponse.statusCode >= 200 &&
          registerResponse.statusCode < 300) {
        return true;
      }
      _lastError = AppErrorUtils.backendMessage(
        registerResponse.body,
        fallback: 'Unable to prepare the Solana limit order vault.',
      );
      return false;
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to prepare the Solana limit order vault.',
      );
      debugPrint('SolanaLimitService.ensureVault error: $e');
      return false;
    }
  }

  /// Step 1: POST /api/swap/jupiter/limit/create (proxies V2 /deposit/craft).
  /// Returns the unsigned deposit transaction and the deposit request ID.
  Future<SolanaLimitDepositResult?> createOrder({
    required String inputMint,
    required String outputMint,
    required String inputAmountLamports,
    required String walletAddress,
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/jupiter/limit/create');
      final body = <String, dynamic>{
        'inputMint': inputMint,
        'outputMint': outputMint,
        'userAddress': walletAddress,
        'amount': inputAmountLamports,
        'orderType': 'price',
        'orderSubType': 'single',
      };

      final response = await _http
          .sendWithRetry(
            () => _http.client.post(
              url,
              headers: _headers(json: true),
              body: jsonEncode(body),
            ),
            retryIf: (response) => response.statusCode >= 500,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = jsonDecode(response.body);
        if (raw is! Map) {
          _lastError = 'Unexpected response from limit order service.';
          return null;
        }
        final data = Map<String, dynamic>.from(raw);
        final tx = data['transaction']?.toString();
        if (tx == null || tx.isEmpty) {
          _lastError = 'Deposit response missing transaction.';
          return null;
        }
        final depositRequestId =
            data['requestId']?.toString() ??
            data['depositRequestId']?.toString() ??
            '';
        if (depositRequestId.isEmpty) {
          _lastError = 'Deposit response missing requestId.';
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

  /// Step 2: POST /api/swap/jupiter/limit/confirm (proxies V2 /orders/price).
  ///
  /// [depositSignedTx] is the signed (NOT broadcast) deposit transaction from
  /// [createOrder]; Jupiter submits it on-chain and opens the order.
  /// [expiresAtMs] is required by V2 (milliseconds since epoch).
  Future<Map<String, dynamic>?> confirmOrder({
    required String depositRequestId,
    required String depositSignedTx,
    required String walletAddress,
    required String inputMint,
    required String outputMint,
    required String inputAmountLamports,
    required String triggerMint,
    required String triggerCondition,
    required double triggerPriceUsd,
    required int expiresAtMs,
    int? slippageBps,
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/jupiter/limit/confirm');
      final body = <String, dynamic>{
        'orderType': 'single',
        'depositRequestId': depositRequestId,
        'depositSignedTx': depositSignedTx,
        'userPubkey': walletAddress,
        'inputMint': inputMint,
        'inputAmount': inputAmountLamports,
        'outputMint': outputMint,
        'triggerMint': triggerMint,
        'triggerCondition': triggerCondition,
        'triggerPriceUsd': triggerPriceUsd,
        'expiresAt': expiresAtMs,
        'slippageBps': ?slippageBps,
      };

      final response = await _http
          .sendWithRetry(
            () => _http.client.post(
              url,
              headers: _headers(json: true),
              body: jsonEncode(body),
            ),
            // Never blind-retry order creation: a retry after an ambiguous
            // failure could double-submit the deposit.
            maxRetries: 1,
          )
          .timeout(const Duration(seconds: 30));

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

  /// GET /api/swap/jupiter/limit/orders?state=active|past
  ///
  /// Requires an authenticated session. When no session exists and no
  /// [signMessage] is supplied (passive refresh), returns an empty list
  /// quietly without surfacing an error.
  Future<List<SolanaLimitOrder>> getOrders({
    required String walletAddress,
    String state = 'active',
    Future<String> Function(Uint8List message)? signMessage,
  }) async {
    _lastError = null;

    if (!_hasValidToken(walletAddress) &&
        !await _loadStoredToken(walletAddress)) {
      if (signMessage == null) {
        return [];
      }
      final authenticated = await ensureAuthenticated(
        walletAddress: walletAddress,
        signMessage: signMessage,
      );
      if (!authenticated) return [];
    }

    try {
      final url = AppEnvironment.swap('/jupiter/limit/orders', {
        'state': state,
      });

      var response = await _http
          .sendWithRetry(
            () => _http.client.get(url, headers: _headers()),
            retryIf: (response) => response.statusCode >= 500,
          )
          .timeout(const Duration(seconds: 15));

      // Token may have been revoked upstream — re-auth once if we can.
      if (response.statusCode == 401 && signMessage != null) {
        await _clearSession(walletAddress);
        final authenticated = await ensureAuthenticated(
          walletAddress: walletAddress,
          signMessage: signMessage,
        );
        if (!authenticated) return [];
        response = await _http
            .sendWithRetry(
              () => _http.client.get(url, headers: _headers()),
              retryIf: (r) => r.statusCode >= 500,
            )
            .timeout(const Duration(seconds: 15));
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = jsonDecode(response.body);
        final orders = raw is Map ? raw['orders'] : raw;
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

  /// Step 1 of cancellation: POST /api/swap/jupiter/limit/cancel.
  /// Returns the unsigned withdrawal transaction and the cancel request ID.
  /// Sign the transaction and pass it to [confirmCancel] — do not broadcast.
  Future<SolanaLimitOrderTxResult?> cancelOrder({
    required String orderId,
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/jupiter/limit/cancel');
      final payload = {'orderId': orderId};

      final response = await _http
          .sendWithRetry(
            () => _http.client.post(
              url,
              headers: _headers(json: true),
              body: jsonEncode(payload),
            ),
            retryIf: (response) => response.statusCode >= 500,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = jsonDecode(response.body);
        if (raw is! Map) {
          _lastError = 'Unexpected response from cancel service.';
          return null;
        }
        final data = Map<String, dynamic>.from(raw);
        final tx = data['transaction']?.toString();
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

  /// Step 2 of cancellation: POST /api/swap/jupiter/limit/confirm-cancel with
  /// the signed withdrawal transaction. Jupiter broadcasts it and returns the
  /// funds to the wallet.
  Future<Map<String, dynamic>?> confirmCancel({
    required String orderId,
    required String signedTransaction,
    required String cancelRequestId,
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/jupiter/limit/confirm-cancel');
      final payload = {
        'orderId': orderId,
        'signedTransaction': signedTransaction,
        'cancelRequestId': cancelRequestId,
      };

      final response = await _http
          .sendWithRetry(
            () => _http.client.post(
              url,
              headers: _headers(json: true),
              body: jsonEncode(payload),
            ),
            maxRetries: 1,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = jsonDecode(response.body);
        if (raw is Map) {
          return Map<String, dynamic>.from(raw);
        }
        return {};
      }

      _lastError = AppErrorUtils.backendMessage(
        response.body,
        fallback: 'Unable to finish cancelling the Solana limit order.',
      );
      return null;
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to finish cancelling the Solana limit order.',
      );
      debugPrint('SolanaLimitService.confirmCancel error: $e');
      return null;
    }
  }
}
