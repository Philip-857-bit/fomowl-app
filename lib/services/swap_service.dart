import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../config/app_environment.dart';
import '../utils/amount_utils.dart';
import '../utils/app_error_utils.dart';
import 'cow_limit_order_signing.dart';
import 'http_client_service.dart';

/// Swap Quote Model
class SwapQuote {
  final String amountOutWei;
  final String minAmountOutWei;
  final String amountOutFormatted;
  final String minAmountOutFormatted;
  final double networkFeeUsd;
  final double networkFeeNative;
  final String allowanceTarget;
  final String? allowanceSpender;
  final bool needsAllowance;
  final bool gaslessApprovalAvailable;
  final bool hasBalanceIssue;
  final String? balanceNeeded;
  final String? balanceActual;
  final int platformFeeBps;
  final double platformFeeUsd;
  final String? txTo;
  final String? txData;
  final String? txValue;
  final String? txGas;
  final String? txGasPrice;

  SwapQuote({
    required this.amountOutWei,
    required this.minAmountOutWei,
    required this.amountOutFormatted,
    required this.minAmountOutFormatted,
    required this.networkFeeUsd,
    required this.networkFeeNative,
    required this.allowanceTarget,
    required this.allowanceSpender,
    required this.needsAllowance,
    this.gaslessApprovalAvailable = false,
    required this.hasBalanceIssue,
    required this.balanceNeeded,
    required this.balanceActual,
    this.platformFeeBps = 100,
    this.platformFeeUsd = 0,
    this.txTo,
    this.txData,
    this.txValue,
    this.txGas,
    this.txGasPrice,
  });

  /// Platform fee as a percentage (e.g. 100 BPS = 1.0%)
  double get platformFeePercent => platformFeeBps / 100.0;
}

class LimitOrderResult {
  final String id;
  final String status;
  final String? orderUid;

  const LimitOrderResult({
    required this.id,
    required this.status,
    this.orderUid,
  });

  String? get orderHash => orderUid;
}

class LimitOrderSummary {
  final String id;
  final String walletAddress;
  final int chainId;
  final String sellToken;
  final String buyToken;
  final String sellAmount;
  final String buyAmount;
  final String kind;
  final String targetPrice;
  final int expiry;
  final String status;
  final String? orderUid;
  final String? txHash;

  const LimitOrderSummary({
    required this.id,
    required this.walletAddress,
    required this.chainId,
    required this.sellToken,
    required this.buyToken,
    required this.sellAmount,
    required this.buyAmount,
    required this.kind,
    required this.targetPrice,
    required this.expiry,
    required this.status,
    this.orderUid,
    this.txHash,
  });

  String? get orderHash => orderUid;

  factory LimitOrderSummary.fromJson(Map<String, dynamic> json) {
    return LimitOrderSummary(
      id: json['id']?.toString() ?? '',
      walletAddress: json['walletAddress']?.toString() ?? '',
      chainId: int.tryParse(json['chainId']?.toString() ?? '') ?? 0,
      sellToken: json['sellToken']?.toString() ?? '',
      buyToken: json['buyToken']?.toString() ?? '',
      sellAmount: json['sellAmount']?.toString() ?? '',
      buyAmount: json['buyAmount']?.toString() ?? '',
      kind: (json['kind']?.toString() ?? 'sell').toLowerCase(),
      targetPrice: json['targetPrice']?.toString() ?? '',
      expiry: int.tryParse(json['expiry']?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? '',
      orderUid: json['orderUid']?.toString() ?? json['orderHash']?.toString(),
      txHash: json['txHash']?.toString(),
    );
  }
}

/// Swap Service
/// Routes all swap intents through the secure Rust backend for 0x swap and gasless flows.
class SwapService {
  static const String _permit2Address =
      '0x000000000022d473030f116ddee9f6b43ac78ba3';

  SwapService({HttpClientService? httpClientService})
    : _httpClientService = httpClientService ?? HttpClientService();

  final HttpClientService _httpClientService;

  static const Set<int> supportedQuoteChainIds = {
    1,
    10,
    56,
    137,
    8453,
    42161,
    43114,
    59144,
    534352,
    5000,
    81457,
    34443,
    480,
    10143,
    130,
    80094,
    57073,
    9745,
    143,
    146,
    2741,
  };
  static const Set<int> supportedGaslessChainIds = {
    1, // Ethereum
    10, // Optimism
    56, // BSC
    137, // Polygon
    250, // Fantom
    1101, // Polygon zkEVM
    8453, // Base
    42161, // Arbitrum
    42220, // Celo
    43114, // Avalanche
    59144, // Linea
  };
  static const Set<int> supportedLimitChainIds = cowSupportedLimitChainIds;
  String? _lastError;

  String? get lastError => _lastError;

  Future<LimitOrderResult?> createLimitOrder({
    required int chainId,
    required String walletAddress,
    required Map<String, dynamic> order,
    required String signature,
    String signingScheme = 'eip712',
    String? targetPrice,
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/limit/orders');
      final optionalFields = targetPrice == null
          ? <String, dynamic>{}
          : <String, dynamic>{'targetPrice': targetPrice};
      final payload = {
        'chainId': chainId,
        'walletAddress': walletAddress,
        'order': order,
        'signature': signature,
        'signingScheme': signingScheme,
        ...optionalFields,
      };

      final response = await _httpClientService
          .sendWithRetry(
            () => _httpClientService.client.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            ),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = _decodeMapBody(
          response.body,
          fallbackMessage: 'Limit order response was incomplete.',
        );
        if (data == null) {
          return null;
        }
        return LimitOrderResult(
          id: data['id']?.toString() ?? '',
          status: data['status']?.toString() ?? '',
          orderUid:
              data['orderUid']?.toString() ?? data['orderHash']?.toString(),
        );
      }

      _lastError = _extractBackendMessage(
        response.body,
        fallback: 'Unable to place limit order right now.',
      );
      return null;
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to place limit order right now.',
      );
      debugPrint('SwapService limit order exception: $e');
      return null;
    }
  }

  Future<List<LimitOrderSummary>> getLimitOrders({
    required String walletAddress,
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/limit/orders', {
        'wallet': walletAddress,
      });
      final response = await _httpClientService
          .sendWithRetry(() => _httpClientService.client.get(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = _decodeMapBody(
          response.body,
          fallbackMessage: 'Limit order response was incomplete.',
        );
        if (data == null) return [];
        final list = data['orders'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map(
                (entry) => LimitOrderSummary.fromJson(
                  entry.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList();
        }
        return [];
      }

      _lastError = _extractBackendMessage(
        response.body,
        fallback: 'Unable to fetch limit orders right now.',
      );
      return [];
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to fetch limit orders right now.',
      );
      debugPrint('SwapService limit order list exception: $e');
      return [];
    }
  }

  Future<bool> cancelLimitOrder({
    required String orderId,
    required String walletAddress,
    required String signature,
    String signingScheme = 'eip712',
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/limit/orders/$orderId/cancel');
      final payload = {
        'walletAddress': walletAddress,
        'signature': signature,
        'signingScheme': signingScheme,
      };
      final response = await _httpClientService
          .sendWithRetry(
            () => _httpClientService.client.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }

      _lastError = _extractBackendMessage(
        response.body,
        fallback: 'Unable to cancel limit order right now.',
      );
      return false;
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to cancel limit order right now.',
      );
      debugPrint('SwapService limit order cancel exception: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getGaslessStatus({
    required String tradeHash,
    required int chainId,
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/fusion/status/$tradeHash', {
        'chainId': '$chainId',
      });
      final response = await _httpClientService
          .sendWithRetry(() => _httpClientService.client.get(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = _decodeMapBody(
          response.body,
          fallbackMessage:
              'Gasless status response was incomplete. Please try again.',
        );
        if (data == null) {
          return null;
        }
        return data;
      }
      _lastError = _extractBackendMessage(
        response.body,
        fallback: 'Unable to fetch gasless order status right now.',
      );
      return null;
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to fetch gasless order status right now.',
      );
      debugPrint('SwapService gasless status exception: $e');
      return null;
    }
  }

  bool isChainSupported(int chainId, {required bool isGasless}) {
    if (isGasless) return supportedGaslessChainIds.contains(chainId);
    return supportedQuoteChainIds.contains(chainId);
  }

  bool isLimitChainSupported(int chainId) {
    return supportedLimitChainIds.contains(chainId);
  }

  /// Get aggregated quote from 0x via backend
  Future<SwapQuote?> get0xQuote({
    required int chainId,
    required String fromTokenAddress,
    required String toTokenAddress,
    required String amountWei,
    required int buyTokenDecimals,
    required bool isGasless,
    String? walletAddress,
    int slippageBps = 50,
    bool useFirmQuote = false,
  }) async {
    _lastError = null;
    if (!isChainSupported(chainId, isGasless: isGasless)) {
      _lastError = isGasless
          ? 'Gasless swaps are not available on this network yet.'
          : 'Swaps are not available on this network yet.';
      return null;
    }

    if (isGasless && (walletAddress == null || walletAddress.isEmpty)) {
      _lastError = 'Wallet not connected';
      return null;
    }

    try {
      final endpoint = isGasless
          ? 'fusion/quote'
          : (useFirmQuote ? 'quote' : 'price');

      // Native ETH/token addresses for 0x (uses WETH/WBNB address implicitly or 0xeeee...)
      final src = fromTokenAddress.isEmpty
          ? '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'
          : fromTokenAddress;
      final dst = toTokenAddress.isEmpty
          ? '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'
          : toTokenAddress;

      final queryParams = <String, String>{
        'chainId': '$chainId',
        'amount': amountWei,
        'slippageBps': '$slippageBps',
      };
      if (isGasless) {
        queryParams['fromTokenAddress'] = src;
        queryParams['toTokenAddress'] = dst;
        if (walletAddress != null && walletAddress.isNotEmpty) {
          queryParams['walletAddress'] = walletAddress;
        }
      } else {
        queryParams['src'] = src;
        queryParams['dst'] = dst;
        if (walletAddress != null && walletAddress.isNotEmpty) {
          queryParams['taker'] = walletAddress;
        }
      }

      final url = AppEnvironment.swap('/$endpoint', queryParams);

      final response = await _httpClientService
          .sendWithRetry(() => _httpClientService.client.get(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = _decodeMapBody(
          response.body,
          fallbackMessage:
              'Swap quote response was incomplete. Please try again.',
        );
        if (data == null) {
          _lastError ??=
              'Swap quote response was incomplete. Please try again.';
          return null;
        }
        final dstAmountWei = data['buyAmount']?.toString() ?? '0';
        final minAmountWei = data['minBuyAmount']?.toString() ?? dstAmountWei;
        final dstAmount = BigInt.tryParse(dstAmountWei) ?? BigInt.zero;
        if (dstAmount <= BigInt.zero) {
          _lastError = _extractProviderError(data);
          return null;
        }
        final issues = _asMap(data['issues']);
        final allowanceIssue = _asMap(issues?['allowance']);
        final rawAllowanceTarget = data['allowanceTarget']?.toString() ?? '';
        final allowanceSpender =
            data['allowanceSpender']?.toString() ??
            allowanceIssue?['spender']?.toString();
        final needsAllowance =
            data['needsAllowance'] == true ||
            allowanceSpender != null && allowanceSpender.isNotEmpty ||
            rawAllowanceTarget.isNotEmpty;
        final hasBalanceIssue = data['hasBalanceIssue'] == true;
        final allowanceTarget = isGasless
            ? (needsAllowance
                  ? (rawAllowanceTarget.isNotEmpty
                        ? rawAllowanceTarget
                        : allowanceSpender?.isNotEmpty == true
                        ? allowanceSpender!
                        : _permit2Address)
                  : '')
            : (rawAllowanceTarget.isNotEmpty
                  ? rawAllowanceTarget
                  : allowanceSpender ?? '');
        final minAmount = BigInt.tryParse(minAmountWei) ?? dstAmount;

        // Extract decimal precision safely (fallback to swap input decimals if missing)
        final tokenMetadata = _asMap(data['tokenMetadata']);
        final buyTokenMeta = _asMap(tokenMetadata?['buyToken']);
        final rawDecimals = buyTokenMeta?['decimals'];
        final decimals = rawDecimals is int
            ? rawDecimals
            : int.tryParse(rawDecimals?.toString() ?? '') ?? buyTokenDecimals;

        final formatted = AmountUtils.formatBaseUnits(
          dstAmount,
          decimals,
          maxFractionDigits: math.min(decimals, 8),
        );
        final minFormatted = AmountUtils.formatBaseUnits(
          minAmount,
          decimals,
          maxFractionDigits: math.min(decimals, 8),
        );
        final transaction = _asMap(data['transaction']);
        return SwapQuote(
          amountOutWei: dstAmountWei,
          minAmountOutWei: minAmountWei,
          amountOutFormatted: formatted,
          minAmountOutFormatted: minFormatted,
          networkFeeUsd:
              double.tryParse(data['networkFeeUsd']?.toString() ?? '0') ?? 0.0,
          networkFeeNative:
              double.tryParse(data['networkFeeNative']?.toString() ?? '0') ??
              0.0,
          allowanceTarget: allowanceTarget,
          allowanceSpender: allowanceSpender,
          needsAllowance: needsAllowance,
          gaslessApprovalAvailable:
              isGasless && _asMap(data['approval']) != null,
          hasBalanceIssue: hasBalanceIssue,
          balanceNeeded: data['balanceNeeded']?.toString(),
          balanceActual: data['balanceActual']?.toString(),
          platformFeeBps:
              int.tryParse(data['platformFeeBps']?.toString() ?? '100') ?? 100,
          platformFeeUsd:
              double.tryParse(data['platformFeeUsd']?.toString() ?? '0') ?? 0.0,
          txTo: transaction?['to']?.toString(),
          txData: transaction?['data']?.toString(),
          txValue: transaction?['value']?.toString(),
          txGas: transaction?['gas']?.toString(),
          txGasPrice: transaction?['gasPrice']?.toString(),
        );
      } else {
        _lastError = _extractBackendMessage(
          response.body,
          fallback: 'Unable to fetch a swap quote right now.',
        );
        debugPrint('Backend Swap Quote Error: ${response.body}');
        return null;
      }
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to fetch a swap quote right now.',
      );
      debugPrint('SwapService Exception: $e');
      return null;
    }
  }

  String _extractProviderError(Map<String, dynamic> data) {
    final message = data['message']?.toString();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    final reason = data['reason']?.toString();
    if (reason != null && reason.isNotEmpty) {
      return reason;
    }
    final issues = data['issues'];
    if (issues is Map<String, dynamic>) {
      final balance = issues['balance'];
      if (balance is Map<String, dynamic>) {
        final expected = balance['expected']?.toString();
        final actual = balance['actual']?.toString();
        final desc = balance['description']?.toString();
        if (expected != null && actual != null) {
          return 'Insufficient balance. Need $expected but only $actual is available.';
        }
        if (desc != null && desc.isNotEmpty) {
          return desc;
        }
      }
      final allowance = issues['allowance'];
      if (allowance is Map<String, dynamic>) {
        final spender = allowance['spender']?.toString();
        if (spender != null && spender.isNotEmpty) {
          return 'Token approval is required before swapping.';
        }
      }
      final simulationIncomplete = issues['simulationIncomplete'] == true;
      if (simulationIncomplete) {
        return 'Quote validation is incomplete. Please try again.';
      }
    }
    return 'No route found for this token pair on the selected network.';
  }

  String _extractBackendMessage(String body, {required String fallback}) {
    return AppErrorUtils.backendMessage(body, fallback: fallback);
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, entryValue) => MapEntry(key.toString(), entryValue),
      );
    }
    return null;
  }

  Map<String, dynamic>? _decodeMapBody(
    String body, {
    required String fallbackMessage,
  }) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      _lastError = fallbackMessage;
      return null;
    }

    try {
      return _asMap(jsonDecode(trimmed));
    } on FormatException {
      _lastError = fallbackMessage;
      return null;
    }
  }
}
