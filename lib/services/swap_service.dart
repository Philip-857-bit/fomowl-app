import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Swap Quote Model
class SwapQuote {
  final String amountOutWei;
  final String amountOutFormatted;
  final double estimatedGasUsd;
  final String allowanceTarget;

  SwapQuote({
    required this.amountOutWei,
    required this.amountOutFormatted,
    required this.estimatedGasUsd,
    required this.allowanceTarget,
  });
}

/// Swap Service
/// Routes all swap intents through the secure Rust backend aggregating 1inch V5.2 and Fusion.
class SwapService {
  static const String _backendApiBase = 'https://fomowl-backend.onrender.com/api/swap';

  /// Get aggregated quote from 0x via backend
  Future<SwapQuote?> get0xQuote({
    required int chainId,
    required String fromTokenAddress,
    required String toTokenAddress,
    required String amountWei,
    required bool isGasless,
  }) async {
    try {
      final endpoint = isGasless ? 'fusion/quote' : 'quote';
      
      // Native ETH/token addresses for 0x (uses WETH/WBNB address implicitly or 0xeeee...)
      final src = fromTokenAddress.isEmpty ? '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE' : fromTokenAddress;
      final dst = toTokenAddress.isEmpty ? '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE' : toTokenAddress;

      final url = Uri.parse('$_backendApiBase/$endpoint'
          '?chainId=$chainId'
          '&src=$src'
          '&dst=$dst'
          '&amount=$amountWei');

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // 0x response
        final dstAmountWei = data['buyAmount'] ?? '0';
        final allowanceTarget = data['allowanceTarget'] ?? '';
        
        // Convert wei to simple formatted string for UI
        final double estimate = double.tryParse(dstAmountWei) ?? 0.0;
        final decimals = (data['tokenMetadata']?['buyToken']?['decimals'] ?? 18) as int;
        final formatted = (estimate / (10 * decimals)).toStringAsFixed(4);
        
        return SwapQuote(
          amountOutWei: dstAmountWei,
          amountOutFormatted: formatted,
          estimatedGasUsd: 0.0, 
          allowanceTarget: allowanceTarget,
        );
      } else {
        debugPrint('Backend Swap Quote Error: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('SwapService Exception: $e');
      return null;
    }
  }
}
