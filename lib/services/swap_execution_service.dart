import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart';

import '../config/app_environment.dart';
import '../models/token.dart';
import '../utils/app_error_utils.dart';
import 'blockchain_service.dart';
import 'swap_service.dart';
import 'swap_quote_safety.dart';
import 'wallet_service.dart';
import 'http_client_service.dart';
import 'zerox_gasless_executor.dart';

class SwapExecutionResult {
  final bool success;
  final String? transactionHash;
  final String? tradeHash;
  final String? analyticsEventId;
  final String? error;

  const SwapExecutionResult({
    required this.success,
    this.transactionHash,
    this.tradeHash,
    this.analyticsEventId,
    this.error,
  });
}

class SwapExecutionService {
  final WalletService _walletService;
  final HttpClientService _httpClientService = HttpClientService();
  late final ZeroXGaslessExecutor _gaslessExecutor;

  SwapExecutionService({
    WalletService? walletService,
    SwapService? swapService, // Kept constructor sig for compatibility
  }) : _walletService = walletService ?? WalletService() {
    _gaslessExecutor = ZeroXGaslessExecutor(walletService: _walletService);
  }

  /// Broadcasts a freshly committed quote prepared by the backend.
  Future<SwapExecutionResult> execute({
    required SwapQuote quote,
    required Token fromToken,
    required Token toToken,
    required String fromAmountWei,
    required double expectedToAmount,
    required int slippageBps,
    required BlockchainService blockchain,
    required String recipientAddress,
    required bool isGasless,
  }) async {
    try {
      if (isGasless) {
        return await _executeFusion(
          fromToken: fromToken,
          toToken: toToken,
          fromAmountWei: fromAmountWei,
          expectedToAmount: expectedToAmount,
          slippageBps: slippageBps,
          blockchain: blockchain,
          walletAddress: recipientAddress,
        );
      } else {
        return await _executeStandard(
          quote: quote,
          fromToken: fromToken,
          toToken: toToken,
          fromAmountWei: fromAmountWei,
          expectedToAmount: expectedToAmount,
          slippageBps: slippageBps,
          blockchain: blockchain,
        );
      }
    } catch (e) {
      debugPrint('Swap execution failed: $e');
      return SwapExecutionResult(
        success: false,
        error: AppErrorUtils.userMessage(
          e,
          fallback: 'Swap execution failed. Please try again.',
        ),
      );
    }
  }

  Future<SwapExecutionResult> _executeStandard({
    required SwapQuote quote,
    required Token fromToken,
    required Token toToken,
    required String fromAmountWei,
    required double expectedToAmount,
    required int slippageBps,
    required BlockchainService blockchain,
  }) async {
    // The swap screen refreshes this firm quote immediately before execution
    // (and once more after an approval transaction). Reusing that exact quote
    // avoids a second backend request and an RPC health probe on the critical
    // path while keeping the approved calldata and displayed output aligned.
    final client = Web3Client(
      blockchain.activeChain.rpcUrl,
      _httpClientService.client,
    );
    try {
      if (quote.txTo == null || quote.txTo!.isEmpty) {
        throw Exception(
          'Swap quote was missing executable transaction fields. Please refresh the quote and try again.',
        );
      }
      final toAddress = EthereumAddress.fromHex(quote.txTo!);

      final gasPriceStr = quote.txGasPrice;
      final gasPrice = gasPriceStr != null ? _parseBigInt(gasPriceStr) : null;
      if (gasPrice == null) {
        throw Exception(
          'Swap quote was missing executable transaction fields. Please refresh the quote and try again.',
        );
      }

      final dataStr = quote.txData;
      if (dataStr == null) {
        throw Exception(
          'Swap quote was missing executable transaction fields. Please refresh the quote and try again.',
        );
      }
      final dataBytes = hexToBytes(dataStr.replaceFirst('0x', ''));

      final valueStr = quote.txValue;
      final valueWei = valueStr != null ? _parseBigInt(valueStr) : null;
      if (valueWei == null) {
        throw Exception(
          'Swap quote was missing executable transaction fields. Please refresh the quote and try again.',
        );
      }

      // SECURITY: do not blindly sign/broadcast backend-supplied calldata. We
      // cannot fully decode arbitrary router calldata client-side, but we can
      // enforce two strong invariants that bound what the transaction can do:
      //
      //  1. Native value invariant — for a native (gas-token) sale the tx must
      //     send exactly the amount being sold; for an ERC-20 sale the router
      //     pulls tokens via allowance and the tx must send zero native value.
      //     This stops a tampered/compromised response from draining native
      //     funds the user never intended to spend.
      //  2. Minimum output — the freshly quoted output must still clear the
      //     slippage floor of the amount the user approved, so the trade can't
      //     be silently executed at a far worse rate than was displayed.
      final sellAmountWei = _parseBigInt(fromAmountWei) ?? BigInt.zero;
      if (_isNativeToken(fromToken)) {
        if (valueWei != sellAmountWei) {
          throw Exception(
            'Swap transaction value does not match the amount you are selling. Aborting for your safety; please refresh the quote.',
          );
        }
      } else if (valueWei != BigInt.zero) {
        throw Exception(
          'Swap transaction unexpectedly sends native funds for a token sale. Aborting for your safety; please refresh the quote.',
        );
      }

      final quotedOut = _parseBigInt(quote.minAmountOutWei);
      // Fail CLOSED: if the response carries no parseable output amount we
      // cannot enforce the slippage floor, so refuse rather than sign a trade
      // at an unknown rate. (Previously this check was skipped when the field
      // was absent, letting a tampered response execute at any rate.)
      if (expectedToAmount > 0) {
        if (quotedOut == null) {
          throw Exception(
            'The swap quote is missing its output amount and cannot be safely executed. Please refresh the quote and try again.',
          );
        }
        final floor = _minAcceptableOutBaseUnits(
          expectedToAmount: expectedToAmount,
          decimals: toToken.decimals,
          slippageBps: slippageBps,
        );
        if (quotedOut < floor) {
          throw Exception(
            'The current swap rate is worse than the quote you approved. Please refresh the quote and try again.',
          );
        }
      }

      final tx = Transaction(
        to: toAddress,
        data: dataBytes,
        value: EtherAmount.inWei(valueWei),
        gasPrice: EtherAmount.inWei(gasPrice),
        maxGas: _parseInt(quote.txGas),
      );

      final credentials = await _walletService.getCredentials();

      // 3. Broadcast
      final txHash = await client.sendTransaction(
        credentials,
        tx,
        chainId: blockchain.activeChain.chainId,
        fetchChainIdFromNetworkId: false,
      );

      return SwapExecutionResult(
        success: true,
        transactionHash: txHash,
        analyticsEventId: quote.analyticsEventId,
      );
    } finally {
      // client.dispose() intentionally removed — HttpClient is a shared singleton.
    }
  }

  /// Records analytics only after the UI's transaction monitor has confirmed
  /// the receipt. The backend independently verifies the receipt before
  /// promoting the quote event to a completed swap.
  Future<bool> recordConfirmedSwap({
    required String eventId,
    required int chainId,
    required String transactionHash,
    required String walletAddress,
  }) async {
    // A receipt can be visible to the mobile RPC before it is visible to the
    // backend RPC. Retry transient verification failures so a real swap does
    // not disappear from analytics merely because the nodes were briefly out
    // of sync. This remains fire-and-forget and never blocks the swap UI.
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        final response = await _httpClientService
            .sendWithRetry(
              () => _httpClientService.client.post(
                AppEnvironment.swap('/record'),
                headers: const {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'eventId': eventId,
                  'chainId': chainId,
                  'txHash': transactionHash,
                  'walletAddress': walletAddress,
                }),
              ),
            )
            .timeout(const Duration(seconds: 12));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
        if (response.statusCode != 409 && response.statusCode != 503) {
          debugPrint(
            'Confirmed swap analytics was not recorded: ${response.statusCode}',
          );
          return false;
        }
      } catch (error) {
        if (attempt == 7) {
          // Analytics must never turn a confirmed on-chain swap into a UI
          // failure.
          debugPrint('Confirmed swap analytics was not recorded: $error');
          return false;
        }
      }
      await Future<void>.delayed(Duration(seconds: (attempt + 1).clamp(1, 3)));
    }
    return false;
  }

  Future<SwapExecutionResult> _executeFusion({
    required Token fromToken,
    required Token toToken,
    required String fromAmountWei,
    required double expectedToAmount,
    required int slippageBps,
    required BlockchainService blockchain,
    required String walletAddress,
  }) async {
    try {
      final src = fromToken.contractAddress?.isNotEmpty == true
          ? fromToken.contractAddress!
          : '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
      final dst = toToken.contractAddress?.isNotEmpty == true
          ? toToken.contractAddress!
          : '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

      final rawAmountStr = fromAmountWei;

      // 1. Get Gasless Quote
      final quoteUrl = AppEnvironment.swap('/fusion/quote', {
        'chainId': '${blockchain.activeChain.chainId}',
        'fromTokenAddress': src,
        'toTokenAddress': dst,
        'amount': rawAmountStr,
        'walletAddress': walletAddress,
        'slippageBps': '$slippageBps',
      });

      final quoteResponse = await _httpClientService
          .sendWithRetry(() => _httpClientService.client.get(quoteUrl))
          .timeout(const Duration(seconds: 15));
      if (quoteResponse.statusCode != 200) {
        throw Exception(
          _extractBackendMessage(
            quoteResponse.body,
            'Gasless quote request failed.',
          ),
        );
      }

      final quoteData = _decodeJsonMap(
        quoteResponse.body,
        fallback: 'Gasless quote response was incomplete. Please try again.',
      );
      final blockingMessage = gaslessQuoteBlockingMessage(quoteData);
      if (blockingMessage != null) {
        throw Exception(blockingMessage);
      }

      // SECURITY: enforce the slippage floor before signing the gasless order, so
      // the user can't be made to sign an order that yields far less than the
      // output they approved. (See _executeStandard for the same invariant.)
      final quotedOut = _parseBigInt(
        (quoteData['minBuyAmount'] ?? quoteData['buyAmount'])?.toString(),
      );
      if (expectedToAmount > 0) {
        if (quotedOut == null) {
          throw Exception(
            'The swap quote is missing its output amount and cannot be safely executed. Please refresh the quote and try again.',
          );
        }
        final floor = _minAcceptableOutBaseUnits(
          expectedToAmount: expectedToAmount,
          decimals: toToken.decimals,
          slippageBps: slippageBps,
        );
        if (quotedOut < floor) {
          throw Exception(
            'The current swap rate is worse than the quote you approved. Please refresh the quote and try again.',
          );
        }
      }

      final submitPayload = await _gaslessExecutor.signAndBuildSubmitPayload(
        quoteData: quoteData,
        chainId: blockchain.activeChain.chainId,
      );

      final submitUrl = AppEnvironment.swap(
        '/fusion/order/submit/${blockchain.activeChain.chainId}',
      );

      final submitResponse = await _httpClientService
          .sendWithRetry(
            () => _httpClientService.client.post(
              submitUrl,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(submitPayload),
            ),
            // Submission creates a relayer order. A timed-out successful POST
            // must not be replayed and create a second in-flight order.
            maxRetries: 1,
            retryOnException: false,
          )
          .timeout(const Duration(seconds: 15));

      if (submitResponse.statusCode != 200) {
        throw Exception(
          _extractBackendMessage(
            submitResponse.body,
            'Gasless order submission failed.',
          ),
        );
      }

      final submitData = _decodeJsonMap(
        submitResponse.body,
        fallback: 'Gasless order response was incomplete. Please try again.',
      );
      final String? transactionHash =
          submitData['transactionHash']?.toString() ??
          submitData['txHash']?.toString();
      final String? tradeHash =
          submitData['tradeHash']?.toString() ??
          submitData['hash']?.toString() ??
          submitData['orderHash']?.toString() ??
          submitData['orderId']?.toString();

      if (transactionHash == null && tradeHash == null) {
        throw Exception(
          'Backend submission response did not contain a recognizable hash or ID. Response: ${submitResponse.body}',
        );
      }

      return SwapExecutionResult(
        success: true,
        transactionHash: transactionHash,
        tradeHash: tradeHash,
      );
    } catch (e) {
      debugPrint('Fusion execution failed: $e');
      return SwapExecutionResult(
        success: false,
        error: AppErrorUtils.userMessage(
          e,
          fallback: 'Gasless swap failed. Please try again.',
        ),
      );
    }
  }

  String _extractBackendMessage(String body, String fallback) {
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

  Map<String, dynamic> _decodeJsonMap(String body, {required String fallback}) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw Exception(fallback);
    }

    try {
      final decoded = _asMap(jsonDecode(trimmed));
      if (decoded == null) {
        throw Exception(fallback);
      }
      return decoded;
    } on FormatException {
      throw Exception(fallback);
    }
  }

  /// Sentinel address aggregators use for a chain's native gas token.
  static const String _nativeTokenSentinel =
      '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

  bool _isNativeToken(Token token) {
    final address = token.contractAddress;
    if (address == null || address.isEmpty) {
      return true;
    }
    return address.toLowerCase() == _nativeTokenSentinel;
  }

  /// Minimum destination amount (in base units) the swap must yield, derived
  /// from the output the user approved (`expectedToAmount`, in display units),
  /// the accepted slippage, and a small safety margin to absorb float/quote
  /// rounding so legitimate trades are not rejected.
  static BigInt _minAcceptableOutBaseUnits({
    required double expectedToAmount,
    required int decimals,
    required int slippageBps,
  }) {
    final expectedBase = _displayAmountToBaseUnits(expectedToAmount, decimals);
    final bps = slippageBps.clamp(0, 10000);
    var floor = expectedBase * BigInt.from(10000 - bps) ~/ BigInt.from(10000);
    // Extra 0.5% tolerance for double/quote rounding drift.
    floor = floor * BigInt.from(995) ~/ BigInt.from(1000);
    return floor;
  }

  /// Converts a display amount (e.g. 123.456789) to integer base units for the
  /// given decimals using a string path to avoid double precision loss on large
  /// token amounts.
  static BigInt _displayAmountToBaseUnits(double amount, int decimals) {
    if (!amount.isFinite || amount <= 0) {
      return BigInt.zero;
    }
    final fixed = amount.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final whole = parts.first;
    final frac = parts.length > 1 ? parts[1] : '';
    final fracPadded = frac.padRight(decimals, '0');
    final fracTrimmed = decimals == 0 ? '' : fracPadded.substring(0, decimals);
    return BigInt.tryParse('$whole$fracTrimmed') ?? BigInt.zero;
  }

  /// Parse a numeric string that may be decimal ("1000000") or hex ("0x...").
  static BigInt? _parseBigInt(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
      return BigInt.tryParse(trimmed.substring(2), radix: 16);
    }
    return BigInt.tryParse(trimmed);
  }

  /// Parse an int from decimal or hex string.
  static int? _parseInt(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
      return int.tryParse(trimmed.substring(2), radix: 16);
    }
    return int.tryParse(trimmed);
  }
}
