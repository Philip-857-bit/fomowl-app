import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import '../utils/amount_utils.dart';

/// Swap Quote Model
class SwapQuote {
  final String amountOutWei;
  final String amountOutFormatted;
  final double networkFeeUsd;
  final double networkFeeNative;
  final String allowanceTarget;
  final int platformFeeBps;

  SwapQuote({
    required this.amountOutWei,
    required this.amountOutFormatted,
    required this.networkFeeUsd,
    required this.networkFeeNative,
    required this.allowanceTarget,
    this.platformFeeBps = 100,
  });

  /// Platform fee as a percentage (e.g. 100 BPS = 1.0%)
  double get platformFeePercent => platformFeeBps / 100.0;
}

/// Swap Service
/// Routes all swap intents through the secure Rust backend for 0x swap and gasless flows.
class SwapService {
  SwapService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

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
    1,
    10,
    56,
    137,
    8453,
    42161,
  };
  String? _lastError;

  String? get lastError => _lastError;

  bool isChainSupported(int chainId, {required bool isGasless}) {
    if (isGasless) return supportedGaslessChainIds.contains(chainId);
    return supportedQuoteChainIds.contains(chainId);
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
      final endpoint = isGasless ? 'fusion/quote' : 'quote';

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
      };
      if (isGasless) {
        queryParams['fromTokenAddress'] = src;
        queryParams['toTokenAddress'] = dst;
        queryParams['walletAddress'] = walletAddress!;
      } else {
        queryParams['src'] = src;
        queryParams['dst'] = dst;
      }

      final url = AppEnvironment.swap('/$endpoint', queryParams);

      final response = await _httpClient
          .get(url)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final dstAmountWei = data['buyAmount']?.toString() ?? '0';
        final dstAmount = BigInt.tryParse(dstAmountWei) ?? BigInt.zero;
        if (dstAmount <= BigInt.zero) {
          _lastError = _extractProviderError(data);
          return null;
        }
        final allowanceTarget = data['allowanceTarget']?.toString() ?? '';

        // Convert wei to simple formatted string for UI
        final rawDecimals = data['tokenMetadata']?['buyToken']?['decimals'];
        final decimals = rawDecimals is int
            ? rawDecimals
            : int.tryParse(rawDecimals?.toString() ?? '') ?? buyTokenDecimals;
        final formatted = AmountUtils.formatBaseUnits(
          dstAmount,
          decimals,
          maxFractionDigits: math.min(decimals, 6),
        );

        return SwapQuote(
          amountOutWei: dstAmountWei,
          amountOutFormatted: formatted,
          networkFeeUsd: (data['networkFeeUsd'] as num?)?.toDouble() ?? 0.0,
          networkFeeNative:
              (data['networkFeeNative'] as num?)?.toDouble() ?? 0.0,
          allowanceTarget: allowanceTarget,
          platformFeeBps: (data['platformFeeBps'] as num?)?.toInt() ?? 100,
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
      _lastError = e.toString();
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
        final balanceMessage = balance['description']?.toString();
        if (balanceMessage != null && balanceMessage.isNotEmpty) {
          return balanceMessage;
        }
      }
      final allowance = issues['allowance'];
      if (allowance is Map<String, dynamic>) {
        final allowanceMessage = allowance['description']?.toString();
        if (allowanceMessage != null && allowanceMessage.isNotEmpty) {
          return allowanceMessage;
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
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}
    return fallback;
  }
}
