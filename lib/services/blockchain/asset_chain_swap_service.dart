import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';

import '../../utils/amount_utils.dart';
import '../http_client_service.dart';
import '../swap_service.dart';
import 'blockchain_catalog.dart';

/// Transaction execution plan for Asset Chain Uniswap-V3 swap transactions.
class AssetChainSwapPlan {
  final String to;
  final BigInt value;
  final String data;

  const AssetChainSwapPlan({
    required this.to,
    required this.value,
    required this.data,
  });
}

/// Represents a candidate Uniswap-V3 pool discovered via UniswapV3Factory.
class AssetChainPoolCandidate {
  final String poolAddress;
  final int fee;
  final String token0;
  final String token1;

  const AssetChainPoolCandidate({
    required this.poolAddress,
    required this.fee,
    this.token0 = '',
    this.token1 = '',
  });
}

/// Quotation result from simulating a swap across a specific pool candidate.
class AssetChainQuoteResult {
  final BigInt amountOut;
  final int fee;
  final String poolAddress;
  final BigInt? gasEstimate;
  final bool usedFallback;

  const AssetChainQuoteResult({
    required this.amountOut,
    required this.fee,
    required this.poolAddress,
    this.gasEstimate,
    this.usedFallback = false,
  });
}

/// Service providing Uniswap-V3 fork pool discovery, quoting simulation,
/// and calldata generation on Asset Chain Mainnet (42420) and Testnet (42421).
class AssetChainSwapService {
  // --- Contract Deployment Constants ---
  static const String mainnetRouterAddress =
      '0xec2b2209d710d4283b5d1e29441df0dbb9cee5c3';
  static const String mainnetFactoryAddress =
      '0xa9d53862d01190e78ddaf924a8f497b4f8bb5163';
  static const String mainnetQuoterAddress =
      '0xe83e6B8e8E3ec15D5cbF84cf2B2B44D19A203257';
  static const String mainnetWrwaAddress =
      '0x2584D40B5553E81Bb9deC0b6CD1a2E504AAB1709';

  static const String testnetRouterAddress =
      '0x365C8Bd36a27128A230B1CE8f7027d7a9e5A8f82';
  static const String testnetFactoryAddress =
      '0xf509c3FbbBa099cD5D949C6621C218B3E52670F8';
  static const String testnetQuoterAddress =
      '0x740aC3204dB2AA93cd7D5a320e8374Ef63d24dbf';
  static const String testnetWrwaAddress =
      '0x0FA7527F1050bb9F9736828B689c652AB2c483ef';

  // --- Contract Function Selectors ---
  static const String exactInputSingleSelector = '0x414bf389';
  static const String multicallSelector = '0xac9650d8';
  static const String unwrapWeth9Selector = '0x49404b7c';
  static const String refundEthSelector = '0x12210e8a';
  static const String getPoolSelector = '0x1698ee82';
  static const String quoteExactInputSingleSelector = '0xc6a5026a';
  static const String slot0Selector = '0x3850c7bd';

  static const String nativeSentinel =
      '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

  static const List<int> supportedFeeTiers = [100, 500, 3000, 10000];

  final Web3Client? _injectedClient;
  final Web3Client Function(String rpcUrl)? _web3ClientFactory;
  final HttpClientService _httpClient;
  String? _lastError;

  AssetChainSwapService({
    Web3Client? web3Client,
    Web3Client Function(String rpcUrl)? web3ClientFactory,
    HttpClientService? httpClientService,
  }) : _injectedClient = web3Client,
       _web3ClientFactory = web3ClientFactory,
       _httpClient = httpClientService ?? HttpClientService();

  String? get lastError => _lastError;

  // --- Network Resolution Helpers ---

  static String resolveRouterAddress(int chainId) {
    if (chainId == 42420) return mainnetRouterAddress;
    if (chainId == 42421) return testnetRouterAddress;
    throw ArgumentError('Unsupported chainId for Asset Chain: $chainId');
  }

  static String resolveFactoryAddress(int chainId) {
    if (chainId == 42420) return mainnetFactoryAddress;
    if (chainId == 42421) return testnetFactoryAddress;
    throw ArgumentError('Unsupported chainId for Asset Chain: $chainId');
  }

  static String resolveQuoterAddress(int chainId) {
    if (chainId == 42420) return mainnetQuoterAddress;
    if (chainId == 42421) return testnetQuoterAddress;
    throw ArgumentError('Unsupported chainId for Asset Chain: $chainId');
  }

  static String resolveWrwaAddress(int chainId) {
    if (chainId == 42420) return mainnetWrwaAddress;
    if (chainId == 42421) return testnetWrwaAddress;
    throw ArgumentError('Unsupported chainId for Asset Chain: $chainId');
  }

  static bool isNativeAddress(String? address) {
    if (address == null || address.isEmpty) return true;
    final normalized = address.trim().toLowerCase();
    return normalized == nativeSentinel;
  }

  // --- Slippage & Math Calculations ---

  /// Calculates minimum output floor given expected [quotedOut] and [slippageBps] basis points.
  /// Validates bounds: throws [ArgumentError] if [slippageBps] < 0 or >= 10000.
  static BigInt calculateAmountOutMinimum(BigInt quotedOut, int slippageBps) {
    if (slippageBps < 0 || slippageBps >= 10000) {
      throw ArgumentError(
        'slippageBps must be in range [0, 9999], got $slippageBps',
      );
    }
    return quotedOut * BigInt.from(10000 - slippageBps) ~/ BigInt.from(10000);
  }

  /// Calculates approximate output from pool slot0 sqrtPriceX96 when QuoterV2 reverts.
  static BigInt calculateAmountOutFromSlot0({
    required String tokenIn,
    required String tokenOut,
    required BigInt amountIn,
    required int fee,
    required BigInt sqrtPriceX96,
  }) {
    if (sqrtPriceX96 <= BigInt.zero ||
        amountIn <= BigInt.zero ||
        fee < 0 ||
        fee >= 1000000) {
      return BigInt.zero;
    }
    final amountInWithFee =
        amountIn * BigInt.from(1000000 - fee) ~/ BigInt.from(1000000);
    final isToken0 =
        tokenIn.trim().toLowerCase().compareTo(tokenOut.trim().toLowerCase()) <
        0;
    final sqrtPriceSquared = sqrtPriceX96 * sqrtPriceX96;
    final shift192 = BigInt.one << 192;

    final amountOut = isToken0
        ? (amountInWithFee * sqrtPriceSquared) >> 192
        : (amountInWithFee * shift192) ~/ sqrtPriceSquared;
    if (amountOut.bitLength > 256 || amountOut < BigInt.zero) {
      return BigInt.zero;
    }
    return amountOut;
  }

  // --- ABI Calldata Encoders ---

  /// Encodes `exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))` (selector `0x414bf389`).
  static String encodeExactInputSingle({
    required String tokenIn,
    required String tokenOut,
    required int fee,
    required String recipient,
    required BigInt deadline,
    required BigInt amountIn,
    required BigInt amountOutMinimum,
    BigInt? sqrtPriceLimitX96,
  }) {
    final buffer = StringBuffer('0x414bf389');
    buffer.write(_padAddress(tokenIn));
    buffer.write(_padAddress(tokenOut));
    buffer.write(_padUint(BigInt.from(fee)));
    buffer.write(_padAddress(recipient));
    buffer.write(_padUint(deadline));
    buffer.write(_padUint(amountIn));
    buffer.write(_padUint(amountOutMinimum));
    buffer.write(_padUint(sqrtPriceLimitX96 ?? BigInt.zero));
    return buffer.toString().toLowerCase();
  }

  /// Encodes `unwrapWETH9(uint256,address)` (selector `0x49404b7c`).
  static String encodeUnwrapWETH9({
    required BigInt amountMinimum,
    required String recipient,
  }) {
    final buffer = StringBuffer('0x49404b7c');
    buffer.write(_padUint(amountMinimum));
    buffer.write(_padAddress(recipient));
    return buffer.toString().toLowerCase();
  }

  /// Encodes `refundETH()` (selector `0x12210e8a`).
  static String encodeRefundETH() {
    return '0x12210e8a';
  }

  /// Encodes `multicall(bytes[])` (selector `0xac9650d8`).
  static String encodeMulticall(List<String> callsHex) {
    final cleanedCalls = callsHex.map((c) {
      var s = c.toLowerCase();
      if (s.startsWith('0x')) s = s.substring(2);
      return s;
    }).toList();

    final n = cleanedCalls.length;
    final buffer = StringBuffer('0xac9650d8');
    // Offset to array = 32 bytes (0x20)
    buffer.write(_padUint(BigInt.from(32)));
    // Array length N
    buffer.write(_padUint(BigInt.from(n)));

    // Calculate offsets relative to array start (after length word)
    var currentOffset = n * 32;
    final elementOffsets = <int>[];
    for (var i = 0; i < n; i++) {
      elementOffsets.add(currentOffset);
      final byteLen = cleanedCalls[i].length ~/ 2;
      final paddedLen = ((byteLen + 31) ~/ 32) * 32;
      currentOffset += 32 + paddedLen;
    }

    // Write element offsets
    for (final offset in elementOffsets) {
      buffer.write(_padUint(BigInt.from(offset)));
    }

    // Write element data (length + padded bytes)
    for (final callHex in cleanedCalls) {
      final byteLen = callHex.length ~/ 2;
      buffer.write(_padUint(BigInt.from(byteLen)));
      final paddedHexLen = ((callHex.length + 63) ~/ 64) * 64;
      buffer.write(callHex.padRight(paddedHexLen, '0'));
    }

    return buffer.toString().toLowerCase();
  }

  /// Encodes `UniswapV3Factory.getPool(address,address,uint24)` (selector `0x1698ee82`).
  static String encodeGetPool({
    required String tokenA,
    required String tokenB,
    required int fee,
  }) {
    final buffer = StringBuffer('0x1698ee82');
    buffer.write(_padAddress(tokenA));
    buffer.write(_padAddress(tokenB));
    buffer.write(_padUint(BigInt.from(fee)));
    return buffer.toString().toLowerCase();
  }

  /// Encodes `QuoterV2.quoteExactInputSingle((address,address,uint256,uint24,uint160))` (selector `0xc6a5026a`).
  static String encodeQuoteExactInputSingle({
    required String tokenIn,
    required String tokenOut,
    required BigInt amountIn,
    required int fee,
    BigInt? sqrtPriceLimitX96,
  }) {
    final buffer = StringBuffer('0xc6a5026a');
    buffer.write(_padAddress(tokenIn));
    buffer.write(_padAddress(tokenOut));
    buffer.write(_padUint(amountIn));
    buffer.write(_padUint(BigInt.from(fee)));
    buffer.write(_padUint(sqrtPriceLimitX96 ?? BigInt.zero));
    return buffer.toString().toLowerCase();
  }

  /// Encodes `slot0()` (selector `0x3850c7bd`).
  static String encodeSlot0() {
    return '0x3850c7bd';
  }

  // --- Transaction Plan Builder ---

  /// Prepares the complete executable swap transaction plan for a given swap route.
  static AssetChainSwapPlan buildSwapTransactionPlan({
    required int chainId,
    required bool isNativeIn,
    required bool isNativeOut,
    required String fromTokenAddress,
    required String toTokenAddress,
    required BigInt amountInWei,
    required BigInt amountOutMinimum,
    required int fee,
    required String recipientAddress,
    BigInt? deadline,
  }) {
    final router = resolveRouterAddress(chainId);
    final wrwa = resolveWrwaAddress(chainId);
    final swapDeadline =
        deadline ??
        BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1200);

    if (isNativeIn) {
      // Selling Native RWA:
      // tokenIn = WRWA, value = amountInWei
      // Calldata: multicall([exactInputSingle, refundETH])
      final exactInput = encodeExactInputSingle(
        tokenIn: wrwa,
        tokenOut: toTokenAddress,
        fee: fee,
        recipient: recipientAddress,
        deadline: swapDeadline,
        amountIn: amountInWei,
        amountOutMinimum: amountOutMinimum,
      );
      final refund = encodeRefundETH();
      final data = encodeMulticall([exactInput, refund]);
      return AssetChainSwapPlan(to: router, value: amountInWei, data: data);
    } else if (isNativeOut) {
      // Buying Native RWA:
      // tokenOut = WRWA, recipient = SwapRouter, followed by unwrapWETH9(amountOutMinimum, recipientAddress)
      // value = 0
      final exactInput = encodeExactInputSingle(
        tokenIn: fromTokenAddress,
        tokenOut: wrwa,
        fee: fee,
        recipient: router,
        deadline: swapDeadline,
        amountIn: amountInWei,
        amountOutMinimum: amountOutMinimum,
      );
      final unwrap = encodeUnwrapWETH9(
        amountMinimum: amountOutMinimum,
        recipient: recipientAddress,
      );
      final data = encodeMulticall([exactInput, unwrap]);
      return AssetChainSwapPlan(to: router, value: BigInt.zero, data: data);
    } else {
      // Standard ERC-20 to ERC-20 Swap
      final exactInput = encodeExactInputSingle(
        tokenIn: fromTokenAddress,
        tokenOut: toTokenAddress,
        fee: fee,
        recipient: recipientAddress,
        deadline: swapDeadline,
        amountIn: amountInWei,
        amountOutMinimum: amountOutMinimum,
      );
      return AssetChainSwapPlan(
        to: router,
        value: BigInt.zero,
        data: exactInput,
      );
    }
  }

  // --- Pool Discovery & Quoting Engine ---

  Web3Client _getClient(int chainId) {
    if (_injectedClient != null) return _injectedClient;
    final rpcUrl = chainId == 42421
        ? BlockchainCatalog.defaultPublicRpcUrl(42421)
        : BlockchainCatalog.defaultPublicRpcUrl(42420);
    if (_web3ClientFactory != null) {
      return _web3ClientFactory(rpcUrl);
    }
    return Web3Client(rpcUrl, _httpClient.client);
  }

  /// Discovers active Uniswap-V3 pools across fee tiers for the pair.
  Future<List<AssetChainPoolCandidate>> discoverPools({
    required int chainId,
    required String tokenInAddress,
    required String tokenOutAddress,
  }) async {
    final factoryAddress = resolveFactoryAddress(chainId);
    final client = _getClient(chainId);
    final candidates = <AssetChainPoolCandidate>[];

    for (final fee in supportedFeeTiers) {
      try {
        final calldata = encodeGetPool(
          tokenA: tokenInAddress,
          tokenB: tokenOutAddress,
          fee: fee,
        );
        final rawResponse = await client.callRaw(
          contract: EthereumAddress.fromHex(factoryAddress),
          data: _hexToBytes(calldata),
        );
        final hexResult = _cleanHex(rawResponse);
        if (hexResult.length >= 64) {
          final poolAddr = '0x${hexResult.substring(24, 64)}'.toLowerCase();
          if (poolAddr != '0x0000000000000000000000000000000000000000') {
            candidates.add(
              AssetChainPoolCandidate(
                poolAddress: poolAddr,
                fee: fee,
                token0: tokenInAddress,
                token1: tokenOutAddress,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('AssetChainSwapService: getPool error for fee $fee: $e');
      }
    }
    return candidates;
  }

  /// Evaluates quotes across candidate pools and returns the candidate yielding highest amountOut.
  Future<AssetChainQuoteResult?> getBestQuoteResult({
    required int chainId,
    required String tokenInAddress,
    required String tokenOutAddress,
    required BigInt amountInWei,
    required List<AssetChainPoolCandidate> candidates,
    bool allowSlot0Fallback = false,
  }) async {
    if (candidates.isEmpty) return null;
    final quoterAddress = resolveQuoterAddress(chainId);
    final client = _getClient(chainId);

    AssetChainQuoteResult? bestQuote;

    for (final pool in candidates) {
      BigInt? amountOut;
      BigInt? gasEstimate;
      bool usedFallback = false;

      // 1. Primary Quoter Simulation via IQuoterV2.quoteExactInputSingle
      try {
        final calldata = encodeQuoteExactInputSingle(
          tokenIn: tokenInAddress,
          tokenOut: tokenOutAddress,
          amountIn: amountInWei,
          fee: pool.fee,
        );
        final rawResponse = await client.callRaw(
          contract: EthereumAddress.fromHex(quoterAddress),
          data: _hexToBytes(calldata),
        );
        final hex = _cleanHex(rawResponse);
        if (hex.length >= 64) {
          amountOut = BigInt.tryParse(hex.substring(0, 64), radix: 16);
          if (hex.length >= 256) {
            gasEstimate = BigInt.tryParse(hex.substring(192, 256), radix: 16);
          }
        }
      } catch (e) {
        debugPrint(
          'AssetChainSwapService: QuoterV2 reverted for fee ${pool.fee}: $e.',
        );
      }

      // 2. Slot0 fallback ONLY if explicitly allowed (e.g. for price estimation), NEVER for executable quotes.
      // Failed quoter simulations must be rejected for executable quotes to avoid swaps that revert on chain.
      if (allowSlot0Fallback &&
          (amountOut == null || amountOut <= BigInt.zero)) {
        try {
          final slot0Calldata = encodeSlot0();
          final rawResponse = await client.callRaw(
            contract: EthereumAddress.fromHex(pool.poolAddress),
            data: _hexToBytes(slot0Calldata),
          );
          final hex = _cleanHex(rawResponse);
          if (hex.length >= 64) {
            final sqrtPriceX96 =
                BigInt.tryParse(hex.substring(0, 64), radix: 16) ?? BigInt.zero;
            amountOut = calculateAmountOutFromSlot0(
              tokenIn: tokenInAddress,
              tokenOut: tokenOutAddress,
              amountIn: amountInWei,
              fee: pool.fee,
              sqrtPriceX96: sqrtPriceX96,
            );
            usedFallback = true;
          }
        } catch (e) {
          debugPrint(
            'AssetChainSwapService: slot0 query failed for pool ${pool.poolAddress}: $e',
          );
        }
      }

      if (amountOut != null && amountOut > BigInt.zero) {
        if (bestQuote == null || amountOut > bestQuote.amountOut) {
          bestQuote = AssetChainQuoteResult(
            amountOut: amountOut,
            fee: pool.fee,
            poolAddress: pool.poolAddress,
            gasEstimate: gasEstimate,
            usedFallback: usedFallback,
          );
        }
      }
    }

    return bestQuote;
  }

  /// Entry point for fetching a complete, executable [SwapQuote] on Asset Chain.
  Future<SwapQuote?> getQuote({
    required int chainId,
    required String fromTokenAddress,
    required String toTokenAddress,
    required dynamic amountInWei,
    int buyTokenDecimals = 18,
    String? walletAddress,
    int slippageBps = 50,
    bool useFirmQuote = false,
    BigInt? deadline,
  }) async {
    _lastError = null;

    if (chainId != 42420 && chainId != 42421) {
      _lastError = 'Unsupported chainId for Asset Chain swap: $chainId';
      return null;
    }

    final validSender =
        walletAddress != null &&
        RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(walletAddress) &&
        walletAddress.toLowerCase() !=
            '0x0000000000000000000000000000000000000000';
    if (useFirmQuote && !validSender) {
      _lastError = 'A valid wallet address is required for an executable swap.';
      return null;
    }

    final BigInt parsedAmountInWei;
    if (amountInWei is BigInt) {
      parsedAmountInWei = amountInWei;
    } else if (amountInWei is num) {
      parsedAmountInWei = BigInt.from(amountInWei);
    } else {
      parsedAmountInWei =
          BigInt.tryParse(amountInWei.toString()) ?? BigInt.zero;
    }

    if (parsedAmountInWei <= BigInt.zero) {
      _lastError = 'Swap amount must be greater than zero.';
      return null;
    }

    final isNativeIn = isNativeAddress(fromTokenAddress);
    final isNativeOut = isNativeAddress(toTokenAddress);
    final wrwaAddress = resolveWrwaAddress(chainId);

    final realTokenIn = isNativeIn ? wrwaAddress : fromTokenAddress;
    final realTokenOut = isNativeOut ? wrwaAddress : toTokenAddress;

    if (realTokenIn.trim().toLowerCase() == realTokenOut.trim().toLowerCase()) {
      _lastError = 'Cannot swap token to itself.';
      return null;
    }

    final pools = await discoverPools(
      chainId: chainId,
      tokenInAddress: realTokenIn,
      tokenOutAddress: realTokenOut,
    );

    if (pools.isEmpty) {
      _lastError = 'No liquidity pool found for this pair on Asset Chain.';
      return null;
    }

    final quoteResult = await getBestQuoteResult(
      chainId: chainId,
      tokenInAddress: realTokenIn,
      tokenOutAddress: realTokenOut,
      amountInWei: parsedAmountInWei,
      candidates: pools,
      allowSlot0Fallback:
          false, // Reject failed simulations for executable quotes!
    );

    if (quoteResult == null || quoteResult.amountOut <= BigInt.zero) {
      _lastError =
          'Quoter simulation failed. Insufficient liquidity in pools for this swap amount on Asset Chain.';
      return null;
    }

    final amountOutWei = quoteResult.amountOut;
    final amountOutMinimum = calculateAmountOutMinimum(
      amountOutWei,
      slippageBps,
    );

    AssetChainSwapPlan? plan;

    final formattedOut = AmountUtils.formatBaseUnits(
      amountOutWei,
      buyTokenDecimals,
      maxFractionDigits: math.min(buyTokenDecimals, 8),
    );
    final minFormattedOut = AmountUtils.formatBaseUnits(
      amountOutMinimum,
      buyTokenDecimals,
      maxFractionDigits: math.min(buyTokenDecimals, 8),
    );

    final routerAddress = resolveRouterAddress(chainId);
    BigInt? gasLimit;
    BigInt? gasPrice;
    var needsAllowance = !isNativeIn;
    if (useFirmQuote && validSender) {
      final client = _getClient(chainId);
      try {
        if (!isNativeIn) {
          final allowanceData =
              '0xdd62ed3e${_padAddress(walletAddress)}${_padAddress(routerAddress)}';
          final raw = await client.callRaw(
            contract: EthereumAddress.fromHex(realTokenIn),
            data: _hexToBytes(allowanceData),
          );
          final allowance = BigInt.tryParse(_cleanHex(raw), radix: 16);
          if (allowance == null) throw StateError('Invalid allowance response');
          needsAllowance = allowance < parsedAmountInWei;
        }
        if (!needsAllowance) {
          final candidate = buildSwapTransactionPlan(
            chainId: chainId,
            isNativeIn: isNativeIn,
            isNativeOut: isNativeOut,
            fromTokenAddress: realTokenIn,
            toTokenAddress: realTokenOut,
            amountInWei: parsedAmountInWei,
            amountOutMinimum: amountOutMinimum,
            fee: quoteResult.fee,
            recipientAddress: walletAddress,
            deadline: deadline,
          );
          gasPrice = (await client.getGasPrice()).getInWei;
          final estimated = await client.estimateGas(
            sender: EthereumAddress.fromHex(walletAddress),
            to: EthereumAddress.fromHex(candidate.to),
            value: EtherAmount.inWei(candidate.value),
            data: _hexToBytes(candidate.data),
          );
          if (estimated <= BigInt.zero || gasPrice <= BigInt.zero) {
            throw StateError('Invalid gas estimate');
          }
          gasLimit =
              (estimated * BigInt.from(120) + BigInt.from(99)) ~/
              BigInt.from(100);
          plan = candidate;
        }
      } catch (error) {
        _lastError =
            'Unable to estimate the Asset Chain swap transaction: $error';
        return null;
      }
    }
    final networkFeeNative = gasLimit != null && gasPrice != null
        ? (gasLimit * gasPrice).toDouble() / 1e18
        : 0.0;

    return SwapQuote(
      amountOutWei: amountOutWei.toString(),
      minAmountOutWei: amountOutMinimum.toString(),
      amountOutFormatted: formattedOut,
      minAmountOutFormatted: minFormattedOut,
      networkFeeUsd: 0.0,
      networkFeeNative: networkFeeNative,
      networkFeeUnavailable: plan == null,
      allowanceTarget: isNativeIn ? '' : routerAddress,
      allowanceSpender: isNativeIn ? null : routerAddress,
      needsAllowance: needsAllowance,
      hasBalanceIssue: false,
      balanceNeeded: null,
      balanceActual: null,
      platformFeeBps: 0,
      platformFeeUsd: 0.0,
      txTo: plan?.to,
      txData: plan?.data,
      txValue: plan?.value.toString(),
      txGas: gasLimit?.toString(),
      txGasPrice: gasPrice?.toString(),
      analyticsEventId: null, // Local fallback has no backend DB event ID
    );
  }

  // --- Internal Byte / Hex Utilities ---

  static String _padAddress(String address) {
    var clean = address.trim().toLowerCase();
    if (clean.startsWith('0x')) clean = clean.substring(2);
    return clean.padLeft(64, '0');
  }

  static String _padUint(BigInt value) {
    return value.toRadixString(16).padLeft(64, '0').toLowerCase();
  }

  static Uint8List _hexToBytes(String hex) {
    var clean = hex.trim();
    if (clean.startsWith('0x') || clean.startsWith('0X')) {
      clean = clean.substring(2);
    }
    if (clean.length % 2 != 0) clean = '0$clean';
    final result = Uint8List(clean.length ~/ 2);
    for (var i = 0; i < clean.length; i += 2) {
      result[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  static String _cleanHex(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
      return trimmed.substring(2).toLowerCase();
    }
    return trimmed.toLowerCase();
  }
}
