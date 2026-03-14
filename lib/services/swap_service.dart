import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../config/app_environment.dart';
import '../utils/amount_utils.dart';
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

/// Swap Service
/// Routes all swap intents through the secure Rust backend for 0x swap and gasless flows.
class SwapService {
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
  String? _lastError;

  String? get lastError => _lastError;

  Future<Map<String, dynamic>?> getGaslessStatus({
    required String tradeHash,
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/fusion/status/$tradeHash');
      final response = await _httpClientService
          .sendWithRetry(() => _httpClientService.client.get(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is Map<String, dynamic> ? data : null;
      }
      _lastError = _extractBackendMessage(
        response.body,
        fallback: 'Unable to fetch gasless order status right now.',
      );
      return null;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('SwapService gasless status exception: $e');
      return null;
    }
  }

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
    int slippageBps = 50,
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
      final endpoint = isGasless ? 'fusion/price' : 'price';

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
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final dstAmountWei = data['buyAmount']?.toString() ?? '0';
        final minAmountWei = data['minBuyAmount']?.toString() ?? dstAmountWei;
        final dstAmount = BigInt.tryParse(dstAmountWei) ?? BigInt.zero;
        if (dstAmount <= BigInt.zero) {
          _lastError = _extractProviderError(data);
          return null;
        }
        final hasBalanceIssue = data['hasBalanceIssue'] == true;
        final allowanceTarget = isGasless
            ? '0x000000000022d473030f116ddee9f6b43ac78ba3' // Permit2 Address
            : data['allowanceTarget']?.toString() ??
                  data['allowanceSpender']?.toString() ??
                  '';
        final minAmount = BigInt.tryParse(minAmountWei) ?? dstAmount;

        // Extract decimal precision safely (fallback to swap input decimals if missing)
        final rawDecimals = data['tokenMetadata']?['buyToken']?['decimals'];
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
          allowanceSpender: data['allowanceSpender']?.toString(),
          needsAllowance: data['needsAllowance'] == true,
          hasBalanceIssue: hasBalanceIssue,
          balanceNeeded: data['balanceNeeded']?.toString(),
          balanceActual: data['balanceActual']?.toString(),
          platformFeeBps:
              int.tryParse(data['platformFeeBps']?.toString() ?? '100') ?? 100,
          platformFeeUsd: 0.0,
          txTo: data['transaction']?['to']?.toString(),
          txData: data['transaction']?['data']?.toString(),
          txValue: data['transaction']?['value']?.toString(),
          txGas: data['transaction']?['gas']?.toString(),
          txGasPrice: data['transaction']?['gasPrice']?.toString(),
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
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (e) {
      debugPrint('Error decoding backend message: $e');
    }
    return fallback;
  }
}
