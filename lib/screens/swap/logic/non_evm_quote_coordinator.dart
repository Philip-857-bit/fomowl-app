import 'dart:async';
import 'dart:math' as math;

import '../../../models/token.dart';
import '../../../services/solana_swap_service.dart';
import '../../../services/swap_service.dart';
import '../../../services/tron_swap_service.dart';
import '../../../utils/amount_utils.dart';
import '../swap_screen_helpers.dart';

class NonEvmQuoteResult<T> {
  const NonEvmQuoteResult.success({
    required this.providerQuote,
    required this.swapQuote,
    required this.amountOutFormatted,
    required this.unitRate,
  }) : error = null;

  const NonEvmQuoteResult.failure(this.error)
    : providerQuote = null,
      swapQuote = null,
      amountOutFormatted = '',
      unitRate = 0;

  final T? providerQuote;
  final SwapQuote? swapQuote;
  final String amountOutFormatted;
  final double unitRate;
  final String? error;

  bool get isSuccess => providerQuote != null && swapQuote != null;
}

class NonEvmQuoteCoordinator {
  NonEvmQuoteCoordinator({
    required SolanaSwapService solanaService,
    required TronSwapService tronService,
  }) : _solanaService = solanaService,
       _tronService = tronService;

  static const solNativeMint = 'So11111111111111111111111111111111111111112';
  static const tronNativeAddress = 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb';

  final SolanaSwapService _solanaService;
  final TronSwapService _tronService;

  Future<NonEvmQuoteResult<SolanaSwapQuote>> fetchSolana({
    required Token fromToken,
    required Token toToken,
    required String amountText,
    required String walletAddress,
    required double fromTokenPriceUsd,
    required int slippageBps,
    required Duration timeout,
  }) async {
    final amountRaw = toWeiAmount(amountText, fromToken.decimals);
    if (amountRaw == null || amountRaw == '0') {
      return const NonEvmQuoteResult.failure('Enter a valid amount.');
    }
    final inputAmount =
        double.tryParse(parseDecimalAmount(amountText).toString()) ?? 0;
    try {
      final quote = await _solanaService
          .getQuote(
            fromMint: _assetAddress(fromToken, solNativeMint),
            toMint: _assetAddress(toToken, solNativeMint),
            amountLamports: amountRaw,
            walletAddress: walletAddress,
            sellAmountUsd: _sellAmountUsd(inputAmount, fromTokenPriceUsd),
            slippageBps: slippageBps,
          )
          .timeout(timeout);
      if (quote == null) {
        return NonEvmQuoteResult.failure(
          _solanaService.lastError ?? 'Unable to fetch Solana swap quote.',
        );
      }
      return _success(
        providerQuote: quote,
        amountOutFormatted: quote.amountOutFormatted,
        amountOutRaw: quote.amountOutRaw,
        inputAmount: inputAmount,
        outputDecimals: toToken.decimals,
        slippageBps: slippageBps,
        networkFeeUsd: quote.networkFeeUsd,
        platformFeeBps: quote.platformFeeBps,
        platformFeeUsd: quote.platformFeeUsd,
      );
    } on TimeoutException {
      return const NonEvmQuoteResult.failure(
        'Quote timed out. Please try again.',
      );
    } catch (error) {
      return NonEvmQuoteResult.failure(error.toString());
    }
  }

  Future<NonEvmQuoteResult<TronSwapQuote>> fetchTron({
    required Token fromToken,
    required Token toToken,
    required String amountText,
    required String walletAddress,
    required double fromTokenPriceUsd,
    required int slippageBps,
    required Duration timeout,
  }) async {
    final amountRaw = toWeiAmount(amountText, fromToken.decimals);
    if (amountRaw == null || amountRaw == '0') {
      return const NonEvmQuoteResult.failure('Enter a valid amount.');
    }
    final inputAmount =
        double.tryParse(parseDecimalAmount(amountText).toString()) ?? 0;
    try {
      final quote = await _tronService
          .getQuote(
            fromToken: _assetAddress(fromToken, tronNativeAddress),
            toToken: _assetAddress(toToken, tronNativeAddress),
            amountSun: amountRaw,
            walletAddress: walletAddress,
            sellAmountUsd: _sellAmountUsd(inputAmount, fromTokenPriceUsd),
            slippageBps: slippageBps,
          )
          .timeout(timeout);
      if (quote == null) {
        return NonEvmQuoteResult.failure(
          _tronService.lastError ?? 'Unable to fetch Tron swap quote.',
        );
      }
      return _success(
        providerQuote: quote,
        amountOutFormatted: quote.amountOutFormatted,
        amountOutRaw: quote.amountOutRaw,
        inputAmount: inputAmount,
        outputDecimals: toToken.decimals,
        slippageBps: slippageBps,
        networkFeeUsd: quote.networkFeeUsd,
        platformFeeBps: quote.platformFeeBps,
        platformFeeUsd: quote.platformFeeUsd,
      );
    } on TimeoutException {
      return const NonEvmQuoteResult.failure(
        'Quote timed out. Please try again.',
      );
    } catch (error) {
      return NonEvmQuoteResult.failure(error.toString());
    }
  }
}

NonEvmQuoteResult<T> _success<T>({
  required T providerQuote,
  required String amountOutFormatted,
  required String amountOutRaw,
  required double inputAmount,
  required int outputDecimals,
  required int slippageBps,
  required double networkFeeUsd,
  required int platformFeeBps,
  required double platformFeeUsd,
}) {
  final minimum = applySwapSlippageFloor(
    amountOutRaw,
    slippageBps,
    outputDecimals,
  );
  final outputAmount = double.tryParse(amountOutFormatted) ?? 0;
  return NonEvmQuoteResult.success(
    providerQuote: providerQuote,
    amountOutFormatted: amountOutFormatted,
    unitRate: inputAmount > 0 ? outputAmount / inputAmount : 0,
    swapQuote: SwapQuote(
      amountOutWei: amountOutRaw,
      minAmountOutWei: minimum.raw,
      amountOutFormatted: amountOutFormatted,
      minAmountOutFormatted: minimum.formatted,
      networkFeeNative: 0,
      networkFeeUsd: networkFeeUsd,
      platformFeeBps: platformFeeBps,
      platformFeeUsd: platformFeeUsd,
      allowanceTarget: '',
      allowanceSpender: '',
      needsAllowance: false,
      hasBalanceIssue: false,
      balanceNeeded: null,
      balanceActual: null,
    ),
  );
}

({String raw, String formatted}) applySwapSlippageFloor(
  String amountOutRaw,
  int slippageBps,
  int decimals,
) {
  final outputRaw = BigInt.tryParse(amountOutRaw) ?? BigInt.zero;
  final bps = slippageBps.clamp(0, 10000);
  final minimumRaw = outputRaw * BigInt.from(10000 - bps) ~/ BigInt.from(10000);
  return (
    raw: minimumRaw.toString(),
    formatted: AmountUtils.formatBaseUnits(
      minimumRaw,
      decimals,
      maxFractionDigits: math.min(decimals, 8),
    ),
  );
}

String _assetAddress(Token token, String nativeAddress) {
  final address = token.contractAddress;
  return address != null && address.isNotEmpty ? address : nativeAddress;
}

double? _sellAmountUsd(double amount, double unitPriceUsd) =>
    amount > 0 && unitPriceUsd > 0 ? amount * unitPriceUsd : null;
