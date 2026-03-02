import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// Swap Quote Model
class SwapQuote {
  final String amountOutWei;
  final String amountOutFormatted;
  final double networkFeeUsd;
  final double networkFeeNative;
  final String allowanceTarget;

  SwapQuote({
    required this.amountOutWei,
    required this.amountOutFormatted,
    required this.networkFeeUsd,
    required this.networkFeeNative,
    required this.allowanceTarget,
  });
}

/// Swap Service
/// Routes all swap intents through the secure Rust backend aggregating 1inch V5.2 and Fusion.
class SwapService {
  static const String _backendApiBase =
      'https://fomowl-backend.onrender.com/api/swap';
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
  static const Set<int> supportedGaslessChainIds = {1, 10, 137, 8453, 42161};
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

      final url = Uri.parse(
        '$_backendApiBase/$endpoint',
      ).replace(queryParameters: queryParams);

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final liquidityAvailable = data['liquidityAvailable'] == true;
        if (!liquidityAvailable) {
          _lastError =
              'No route found for this token pair on the selected network.';
          return null;
        }

        // 0x response
        final dstAmountWei = data['buyAmount']?.toString() ?? '0';
        final dstAmount = BigInt.tryParse(dstAmountWei) ?? BigInt.zero;
        if (dstAmount <= BigInt.zero) {
          _lastError =
              'No route found for this token pair on the selected network.';
          return null;
        }
        final allowanceTarget = data['allowanceTarget']?.toString() ?? '';

        // Convert wei to simple formatted string for UI
        final estimate = dstAmount.toDouble();
        final rawDecimals = data['tokenMetadata']?['buyToken']?['decimals'];
        final decimals = rawDecimals is int
            ? rawDecimals
            : int.tryParse(rawDecimals?.toString() ?? '') ?? buyTokenDecimals;
        final formatted = (estimate / math.pow(10, decimals)).toStringAsFixed(
          6,
        );

        return SwapQuote(
          amountOutWei: dstAmountWei,
          amountOutFormatted: formatted,
          networkFeeUsd: (data['networkFeeUsd'] as num?)?.toDouble() ?? 0.0,
          networkFeeNative:
              (data['networkFeeNative'] as num?)?.toDouble() ?? 0.0,
          allowanceTarget: allowanceTarget,
        );
      } else {
        _lastError = response.body;
        debugPrint('Backend Swap Quote Error: ${response.body}');
        return null;
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('SwapService Exception: $e');
      return null;
    }
  }
}
