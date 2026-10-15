import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import '../models/bitcoin_bridge_quote.dart' as bitcoin;
import '../utils/app_error_utils.dart';
import 'http_client_service.dart';
import 'wallet_backend_auth_service.dart';

/// A single executable transaction extracted from a Relay quote step.
/// The client signs and broadcasts these itself, in order.
///
/// EVM steps carry calldata (`to`/`data`/`value`). Solana-origin steps carry
/// raw [instructionsJson] + [lookupTableAddresses] instead — the client
/// compiles them into a v0 transaction via the native Rust builder.
class BridgeStepTx {
  final String stepId;
  final String description;
  final String to;
  final String data;
  final BigInt value;
  final int chainId;
  final BigInt? maxFeePerGas;
  final BigInt? maxPriorityFeePerGas;

  /// Relay instruction array (JSON-encoded) for Solana-origin steps.
  final String? instructionsJson;

  /// Address lookup tables referenced by the Solana instructions.
  final List<String> lookupTableAddresses;

  /// JSON-encoded unsigned FullNode transaction for a TRON-origin deposit.
  final String? tronTransactionJson;
  final String? solanaTransferTo;
  final BigInt? solanaTransferAmount;
  final String? solanaTokenMint;

  const BridgeStepTx({
    required this.stepId,
    required this.description,
    required this.to,
    required this.data,
    required this.value,
    required this.chainId,
    this.maxFeePerGas,
    this.maxPriorityFeePerGas,
    this.instructionsJson,
    this.lookupTableAddresses = const [],
    this.tronTransactionJson,
    this.solanaTransferTo,
    this.solanaTransferAmount,
    this.solanaTokenMint,
  });

  bool get isSolana => instructionsJson != null;
  bool get isTron => tronTransactionJson != null;
  bool get isSolanaTransfer => solanaTransferTo != null;
}

/// Blockhash + resolved lookup tables needed to compile a Solana-origin step.
class SolanaBridgeContext {
  final String blockhash;

  /// JSON array of `{key, addresses}` objects, ready for the Rust builder.
  final String lookupTablesJson;

  const SolanaBridgeContext({
    required this.blockhash,
    required this.lookupTablesJson,
  });
}

/// Parsed cross-chain bridge quote from the backend Relay proxy.
class BridgeQuote {
  final int originChainId;
  final int destinationChainId;
  final String amountIn;
  final String amountOut;

  /// USD value of the output, when Relay provides it.
  final double amountOutUsd;

  /// Relayer (bridge) service fee in USD.
  final double? bridgeFeeUsd;

  /// Estimated origin-chain gas in USD. Null means the provider did not quote it.
  final double? gasFeeUsd;

  /// Provider selected by Owllet's route engine.
  final String routeProvider;

  /// Owllet platform fee.
  final int? platformFeeBps;
  final double? platformFeeUsd;

  /// Slippage encoded by the backend after any bounded simulation retry.
  final int? effectiveSlippageBps;

  /// Estimated completion time in seconds.
  final int? timeEstimateSeconds;

  final String requestId;
  final List<BridgeStepTx> steps;
  final bool committed;
  final DateTime? deadline;
  final bitcoin.BitcoinBridgeQuote? bitcoinQuote;

  const BridgeQuote({
    required this.originChainId,
    required this.destinationChainId,
    required this.amountIn,
    required this.amountOut,
    required this.amountOutUsd,
    required this.bridgeFeeUsd,
    required this.gasFeeUsd,
    required this.routeProvider,
    required this.platformFeeBps,
    required this.platformFeeUsd,
    required this.effectiveSlippageBps,
    required this.timeEstimateSeconds,
    required this.requestId,
    required this.steps,
    required this.committed,
    required this.deadline,
    this.bitcoinQuote,
  });

  /// Dry previews can begin execution because the wallet commits them after
  /// the user taps Bridge. Committed quotes must already contain signable
  /// steps.
  bool get canBeginExecution =>
      !committed ||
      steps.isNotEmpty ||
      (bitcoinQuote?.committed == true && bitcoinQuote?.depositAddress != null);

  String get arrivalLabel {
    if (bitcoinQuote != null) {
      return 'Depends on Bitcoin confirmations';
    }
    final seconds = timeEstimateSeconds;
    if (seconds == null || seconds <= 0) return '~minutes';
    if (seconds < 60) return '~$seconds sec';
    final minutes = (seconds / 60).ceil();
    return '~$minutes min';
  }

  String get routeProviderLabel {
    final normalized = routeProvider.toLowerCase().replaceAll('-', '_');
    if (normalized.contains('near')) return 'NEAR Intents';
    if (normalized.contains('relay')) return 'Relay';
    return routeProvider.trim().isEmpty ? 'Owllet routing' : routeProvider;
  }
}

class BridgeStatus {
  final String status;
  final List<String> txHashes;
  final String? failureCode;
  final String? failureMessage;
  final String? suggestedAction;

  const BridgeStatus({
    required this.status,
    required this.txHashes,
    this.failureCode,
    this.failureMessage,
    this.suggestedAction,
  });

  bool get isSuccess => status.toLowerCase() == 'success';
  bool get isRefunded {
    final lower = status.toLowerCase();
    return lower == 'refund' || lower == 'refunded';
  }

  bool get isFailure {
    final lower = status.toLowerCase();
    return lower == 'failure' ||
        lower == 'failed' ||
        lower == 'refund' ||
        lower == 'refunded' ||
        lower == 'incomplete_deposit';
  }

  String get userFacingFailureMessage {
    final message = failureMessage?.trim();
    final action = suggestedAction?.trim();
    if (message != null && message.isNotEmpty) {
      if (action != null && action.isNotEmpty) {
        return '$message\n\nWhat you can do: $action';
      }
      return message;
    }
    if (isRefunded) {
      return 'This bridge could not complete and your funds were returned on the origin network.\n\nWhat you can do: Refresh your balance, then request a new quote. If the refund is not visible, contact support with the bridge reference.';
    }
    if (status.toLowerCase() == 'incomplete_deposit') {
      return 'The received amount was below the minimum needed to complete this bridge.\n\nWhat you can do: Check Activity for a refund before trying again, then request a new quote with a larger amount.';
    }
    return 'This bridge could not complete.\n\nWhat you can do: Check Activity for a refund before trying again. If no refund appears, contact support with the bridge reference.';
  }
}

/// A Relay-supported currency a bridge can settle into on the destination chain.
class BridgeCurrency {
  final int chainId;
  final String address;
  final String symbol;
  final String name;
  final int decimals;
  final bool isNative;
  final String? logoUri;
  final double? priceUsd;

  const BridgeCurrency({
    required this.chainId,
    required this.address,
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.isNative,
    this.logoUri,
    this.priceUsd,
  });

  factory BridgeCurrency.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'];
    final isNative = metadata is Map && metadata['isNative'] == true;
    return BridgeCurrency(
      chainId: (json['chainId'] as num?)?.toInt() ?? 0,
      address: json['address']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      decimals: (json['decimals'] as num?)?.toInt() ?? 18,
      isNative: isNative,
      logoUri: metadata is Map ? metadata['logoURI']?.toString() : null,
      priceUsd: _readPositiveDouble(
        json['priceUsd'] ??
            json['usdPrice'] ??
            (metadata is Map
                ? metadata['priceUsd'] ?? metadata['usdPrice']
                : null),
      ),
    );
  }

  static double? _readPositiveDouble(Object? value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }
}

/// Service for Relay-powered cross-chain bridging via the Rust backend.
///
/// Flow:
///   1. [getQuote] → fees + ordered [BridgeStepTx] list
///   2. Caller signs and broadcasts each step transaction on its chain
///   3. [getStatus] polled with the quote's requestId until success/failure
class BridgeService {
  BridgeService({
    HttpClientService? httpClientService,
    WalletBackendAuthService? walletBackendAuthService,
  }) : _http = httpClientService ?? HttpClientService(),
       _walletBackendAuthService =
           walletBackendAuthService ?? WalletBackendAuthService();

  final HttpClientService _http;
  final WalletBackendAuthService _walletBackendAuthService;
  String? _lastError;

  String? get lastError => _lastError;

  /// Relay represents native EVM tokens with the zero address.
  static const String nativeCurrency =
      '0x0000000000000000000000000000000000000000';

  /// Relay's chain id for Solana mainnet.
  static const int relaySolanaChainId = 792703809;
  static const int relayBitcoinChainId = bitcoin.relayBitcoinChainId;
  static const String bitcoinNativeCurrency = bitcoin.relayBitcoinCurrency;

  /// Internal bridge identifier for TRON mainnet. Kept separate from the
  /// 0x Cross Chain provider-specific id (999999999993).
  static const int tronBridgeChainId = 728126428;

  /// Relay represents native SOL with the system program address.
  static const String solanaNativeCurrency = '11111111111111111111111111111111';

  static const String tronNativeCurrency = 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb';

  /// [walletAddress] is the origin-chain signer. [recipientAddress] defaults
  /// to it, but differs when bridging across chain families (e.g. EVM → the
  /// wallet's Solana address).
  Future<BridgeQuote?> getQuote({
    required int originChainId,
    required int destinationChainId,
    required String originCurrency,
    required String destinationCurrency,
    required String amountWei,
    required String walletAddress,
    String? recipientAddress,
    double? amountUsd,
    int? slippageBps,
    bool commit = false,
  }) async {
    _lastError = null;
    final isSameChain = originChainId == destinationChainId;
    final hasBitcoin =
        originChainId == relayBitcoinChainId ||
        destinationChainId == relayBitcoinChainId;
    if (hasBitcoin && isSameChain) {
      _lastError = 'Bitcoin is supported in Bridge only.';
      return null;
    }
    final useSameChainEvmSwap =
        isSameChain &&
        originChainId != tronBridgeChainId &&
        originChainId != relaySolanaChainId &&
        originChainId != 1399811149;
    final routeKind = isSameChain ? 'swap' : 'bridge';
    try {
      final normalizedOrigin = originCurrency.isEmpty
          ? nativeCurrency
          : originCurrency;
      final normalizedDestination = destinationCurrency.isEmpty
          ? nativeCurrency
          : destinationCurrency;
      final params = useSameChainEvmSwap
          ? <String, String>{
              // Same-chain EVM pairs belong to the standard route, whose
              // provider order is 0x -> Relay -> OpenOcean. Sending them to
              // /cross-chain/quote bypassed 0x and made Relay the primary.
              'chainId': '$originChainId',
              'src': _zeroExCurrency(normalizedOrigin),
              'dst': _zeroExCurrency(normalizedDestination),
              'amount': amountWei,
              'taker': walletAddress,
              if (slippageBps != null)
                'slippageBps': '${slippageBps.clamp(1, 5000)}',
            }
          : <String, String>{
              'originChainId': '$originChainId',
              'destinationChainId': '$destinationChainId',
              'originCurrency': normalizedOrigin,
              'destinationCurrency': normalizedDestination,
              'amount': amountWei,
              'user': walletAddress,
              'recipient': recipientAddress ?? walletAddress,
              if (amountUsd != null && amountUsd > 0) 'amountUsd': '$amountUsd',
              if (slippageBps != null)
                'slippageBps': '${slippageBps.clamp(1, 5000)}',
              if (commit) 'commit': 'true',
            };
      final url = AppEnvironment.swap(
        hasBitcoin
            ? '/cross-chain/bitcoin/quote'
            : useSameChainEvmSwap
            ? '/quote'
            : '/cross-chain/quote',
        params,
      );

      final response = await _http
          .sendWithRetry(
            () => _http.client.get(url),
            retryIf: (r) => r.statusCode >= 500,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _lastError = quoteErrorMessage(response.body, isSameChain: isSameChain);
        return null;
      }

      final raw = jsonDecode(response.body);
      if (raw is! Map) {
        _lastError =
            '${routeKind[0].toUpperCase()}${routeKind.substring(1)} quote response was incomplete.';
        return null;
      }
      final data = Map<String, dynamic>.from(raw);
      if (hasBitcoin) {
        final quote = bitcoin.BitcoinBridgeQuote.fromJson(
          data,
          expected: bitcoin.BitcoinBridgeRequest(
            originChainId: originChainId,
            destinationChainId: destinationChainId,
            originCurrency: normalizedOrigin,
            destinationCurrency: normalizedDestination,
            sender: walletAddress,
            recipient: recipientAddress ?? walletAddress,
            amount: BigInt.parse(amountWei),
          ),
          now: DateTime.now().toUtc(),
        );
        if (quote.committed != commit) {
          throw const FormatException('Bridge commitment changed');
        }
        final steps = _parseSteps(quote.originSteps);
        if (commit && !quote.request.bitcoinOrigin && steps.isEmpty) {
          throw const FormatException('Bridge origin steps unavailable');
        }
        double? displayUsd(String field) =>
            double.tryParse(quote.display[field]?.toString() ?? '');
        return BridgeQuote(
          originChainId: originChainId,
          destinationChainId: destinationChainId,
          amountIn: amountWei,
          amountOut: quote.amountOut.toString(),
          amountOutUsd: displayUsd('amountOutUsd') ?? 0,
          bridgeFeeUsd: displayUsd('bridgeFeeUsd'),
          gasFeeUsd: null,
          routeProvider: 'relay',
          platformFeeBps: null,
          platformFeeUsd: displayUsd('platformFeeUsd'),
          effectiveSlippageBps: slippageBps,
          timeEstimateSeconds: null,
          requestId: quote.requestId,
          steps: steps,
          committed: quote.committed,
          deadline: quote.approvalExpiresAt,
          bitcoinQuote: quote,
        );
      }
      final amountOut =
          (useSameChainEvmSwap ? data['buyAmount'] : data['amountOut'])
              ?.toString() ??
          '';
      if (amountOut.isEmpty || amountOut == '0') {
        _lastError =
            'This bridge is not available right now. Try a different amount or token.';
        return null;
      }

      final extra = data['extra'] is Map
          ? Map<String, dynamic>.from(data['extra'] as Map)
          : const <String, dynamic>{};
      final committed = useSameChainEvmSwap
          ? commit
          : (extra['committed'] ?? data['committed']) != false;
      final steps = useSameChainEvmSwap
          ? _parseSameChainSteps(
              data,
              chainId: originChainId,
              sellToken: normalizedOrigin,
              sellAmount: amountWei,
            )
          : _parseSteps(data['steps']);
      if (committed && steps.isEmpty) {
        _lastError =
            'The $routeKind transaction could not be prepared. Please refresh the quote.';
        return null;
      }

      return BridgeQuote(
        originChainId:
            (data['originChainId'] as num?)?.toInt() ?? originChainId,
        destinationChainId:
            (data['destinationChainId'] as num?)?.toInt() ?? destinationChainId,
        amountIn: data['amountIn']?.toString() ?? amountWei,
        amountOut: amountOut,
        amountOutUsd: _readAmountOutUsd(data),
        bridgeFeeUsd: useSameChainEvmSwap
            ? 0
            : (data['feeUsd'] as num?)?.toDouble(),
        gasFeeUsd:
            ((useSameChainEvmSwap ? data['networkFeeUsd'] : data['gasFeeUsd'])
                    as num?)
                ?.toDouble(),
        routeProvider: _readProvider(
          data,
          sameChainDefault: useSameChainEvmSwap,
        ),
        platformFeeBps: (data['platformFeeBps'] as num?)?.toInt(),
        platformFeeUsd: (data['platformFeeUsd'] as num?)?.toDouble(),
        effectiveSlippageBps:
            (data['effectiveSlippageBps'] as num?)?.toInt() ??
            (useSameChainEvmSwap ? slippageBps : null),
        timeEstimateSeconds: (data['timeEstimateSeconds'] as num?)?.toInt(),
        requestId: data['requestId']?.toString() ?? '',
        steps: steps,
        committed: committed,
        deadline: DateTime.tryParse(
          (extra['deadline'] ?? data['deadline'])?.toString() ?? '',
        ),
      );
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to fetch a $routeKind route right now.',
      );
      debugPrint('BridgeService.getQuote error: $e');
      return null;
    }
  }

  Future<BridgeQuote?> commitQuote({
    required int originChainId,
    required int destinationChainId,
    required String originCurrency,
    required String destinationCurrency,
    required String amountWei,
    required String walletAddress,
    String? recipientAddress,
    double? amountUsd,
    int? slippageBps,
  }) => getQuote(
    originChainId: originChainId,
    destinationChainId: destinationChainId,
    originCurrency: originCurrency,
    destinationCurrency: destinationCurrency,
    amountWei: amountWei,
    walletAddress: walletAddress,
    recipientAddress: recipientAddress,
    amountUsd: amountUsd,
    slippageBps: slippageBps,
    commit: true,
  );

  /// Converts the backend's stable quote error contract into user-facing
  /// guidance without exposing Relay/provider diagnostics.
  static String quoteErrorMessage(String? body, {bool isSameChain = false}) {
    final routeKind = isSameChain ? 'swap' : 'bridge';
    final fallback = 'Unable to fetch a $routeKind route right now.';
    if (body != null && body.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['code'] == 'AMOUNT_TOO_LOW') {
          return 'Amount is too low for this $routeKind. Increase the amount and try again.';
        }
        if (decoded is Map && decoded['code'] == 'SLIPPAGE_TOO_LOW') {
          final suggested = (decoded['suggestedSlippageBps'] as num?)?.toInt();
          if (suggested != null && suggested > 0) {
            return 'This token needs at least ${(suggested / 100).toStringAsFixed(2)}% slippage to account for its transfer fee. Increase slippage and request a new quote.';
          }
          return 'This token needs higher slippage to account for its transfer fee. Increase slippage and request a new quote.';
        }
      } catch (_) {
        // Fall through to the shared sanitizer for malformed responses.
      }
    }
    final message = AppErrorUtils.backendMessage(body, fallback: fallback);
    final internalLanguage = RegExp(
      r'\b(provider|relayer|relay|route)\b',
      caseSensitive: false,
    );
    return internalLanguage.hasMatch(message) ? fallback : message;
  }

  /// GET /cross-chain/currencies?chainId=&term= — destination tokens Relay
  /// can settle into on [chainId]. Returns native first, then the rest.
  Future<List<BridgeCurrency>> getDestinationCurrencies({
    required int chainId,
    String? term,
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/cross-chain/currencies', {
        'chainId': '$chainId',
        if (term != null && term.trim().isNotEmpty) 'term': term.trim(),
      });
      final response = await _http
          .sendWithRetry(
            () => _http.client.get(url),
            retryIf: (r) => r.statusCode >= 500,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Distinguish a real failure (e.g. backend without the currencies
        // route, or upstream down) from a genuinely empty list, so the picker
        // can show "couldn't load" + retry instead of a misleading "no tokens".
        _lastError = response.statusCode == 404
            ? 'Token list isn\'t available on this server yet.'
            : AppErrorUtils.backendMessage(
                response.body,
                fallback: 'Couldn\'t load tokens right now.',
              );
        return const [];
      }
      final raw = jsonDecode(response.body);
      // Relay returns an array (sometimes nested arrays) of currency objects.
      final flat = <Map>[];
      void collect(Object? node) {
        if (node is List) {
          for (final item in node) {
            collect(item);
          }
        } else if (node is Map) {
          flat.add(node);
        }
      }

      collect(raw);
      final currencies = flat
          .map(
            (e) => BridgeCurrency.fromJson(
              e.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .where((c) => c.symbol.isNotEmpty)
          .toList();
      currencies.sort((a, b) {
        if (a.isNative != b.isNative) return a.isNative ? -1 : 1;
        return 0;
      });
      return currencies;
    } catch (e) {
      debugPrint('BridgeService.getDestinationCurrencies error: $e');
      return const [];
    }
  }

  /// GET /cross-chain/status?requestId=...
  Future<BridgeStatus?> getStatus({required String requestId}) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/cross-chain/status', {
        'requestId': requestId,
      });
      final response = await _http
          .sendWithRetry(
            () => _http.client.get(url),
            retryIf: (r) => r.statusCode >= 500,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _lastError = AppErrorUtils.backendMessage(
          response.body,
          fallback: 'Unable to fetch bridge status right now.',
        );
        return null;
      }
      final raw = jsonDecode(response.body);
      if (raw is! Map) return null;
      final hashes = <String>[];
      for (final key in ['txHashes', 'inTxHashes']) {
        final list = raw[key];
        if (list is List) {
          hashes.addAll(list.map((e) => e.toString()));
        }
      }
      return BridgeStatus(
        status: raw['status']?.toString() ?? 'pending',
        txHashes: hashes,
        failureCode: raw['failureCode']?.toString(),
        failureMessage: raw['failureMessage']?.toString(),
        suggestedAction: raw['suggestedAction']?.toString(),
      );
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to fetch bridge status right now.',
      );
      debugPrint('BridgeService.getStatus error: $e');
      return null;
    }
  }

  /// Tells NEAR Intents about the origin transaction after this wallet has
  /// signed, broadcast, and confirmed it. Relay routes do not use this call.
  Future<bool> submitNearDeposit({
    required String requestId,
    required String txHash,
  }) async {
    if (!requestId.startsWith('near:')) return true;
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/cross-chain/near-deposit');
      final response = await _http
          .sendWithRetry(
            () => _http.client.post(
              url,
              headers: const {'content-type': 'application/json'},
              body: jsonEncode({'requestId': requestId, 'txHash': txHash}),
            ),
            retryIf: (response) => response.statusCode >= 500,
            maxRetries: 1,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 200 && response.statusCode < 300) return true;
      _lastError = AppErrorUtils.backendMessage(
        response.body,
        fallback: 'Owllet could not continue delivery for this deposit.',
      );
      return false;
    } catch (error) {
      _lastError = AppErrorUtils.userMessage(
        error,
        fallback: 'Owllet could not continue delivery for this deposit.',
      );
      return false;
    }
  }

  /// Relay-supported EVM chain ids, cached for the session. Used to filter
  /// out user-added custom networks that Relay cannot bridge. Returns null
  /// when the list cannot be fetched (callers should then skip filtering).
  static Set<int>? _supportedChainIdsCache;

  Future<Set<int>?> getSupportedChainIds() async {
    final cached = _supportedChainIdsCache;
    if (cached != null) return cached;
    try {
      final url = AppEnvironment.swap('/cross-chain/chains');
      final response = await _http
          .sendWithRetry(
            () => _http.client.get(url),
            retryIf: (r) => r.statusCode >= 500,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final raw = jsonDecode(response.body);
      final chains = raw is Map ? raw['chains'] : raw;
      if (chains is! List) return null;
      final ids = <int>{};
      for (final chain in chains.whereType<Map>()) {
        final id = (chain['id'] as num?)?.toInt();
        if (id != null) ids.add(id);
      }
      if (ids.isEmpty) return null;
      _supportedChainIdsCache = ids;
      return ids;
    } catch (e) {
      debugPrint('BridgeService.getSupportedChainIds error: $e');
      return null;
    }
  }

  /// GET /cross-chain/solana-context — blockhash + resolved lookup tables
  /// for compiling a Solana-origin step client-side.
  Future<SolanaBridgeContext?> getSolanaContext({
    required List<String> lookupTableAddresses,
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/cross-chain/solana-context', {
        if (lookupTableAddresses.isNotEmpty)
          'lookupTables': lookupTableAddresses.join(','),
      });
      final response = await _http
          .sendWithRetry(
            () => _http.client.get(url),
            retryIf: (r) => r.statusCode >= 500,
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _lastError = AppErrorUtils.backendMessage(
          response.body,
          fallback: 'Unable to prepare the Solana bridge transaction.',
        );
        return null;
      }
      final raw = jsonDecode(response.body);
      if (raw is! Map) return null;
      final blockhash = raw['blockhash']?.toString() ?? '';
      if (blockhash.isEmpty) {
        _lastError = 'Solana context response was incomplete.';
        return null;
      }
      return SolanaBridgeContext(
        blockhash: blockhash,
        lookupTablesJson: jsonEncode(raw['lookupTables'] ?? const []),
      );
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to prepare the Solana bridge transaction.',
      );
      debugPrint('BridgeService.getSolanaContext error: $e');
      return null;
    }
  }

  /// POST /cross-chain/solana-broadcast — sends the signed base64 Solana
  /// transaction. Returns the transaction signature.
  Future<String?> broadcastSolanaTransaction({
    required String signedTransaction,
  }) async {
    _lastError = null;
    try {
      final url = AppEnvironment.swap('/cross-chain/solana-broadcast');
      final response = await _http
          .sendWithRetry(
            () => _http.client.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'signedTransaction': signedTransaction}),
            ),
            // Never blind-retry a broadcast — it could double-spend.
            maxRetries: 1,
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _lastError = AppErrorUtils.backendMessage(
          response.body,
          fallback: 'Unable to broadcast the Solana transaction.',
        );
        return null;
      }
      final raw = jsonDecode(response.body);
      final signature = raw is Map ? raw['signature']?.toString() : null;
      if (signature == null || signature.isEmpty) {
        _lastError = 'Broadcast response missing signature.';
        return null;
      }
      return signature;
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to broadcast the Solana transaction.',
      );
      debugPrint('BridgeService.broadcastSolanaTransaction error: $e');
      return null;
    }
  }

  /// POST /cross-chain/record — best-effort log of the platform fee earned on a
  /// completed bridge, so the admin "Bridge Fees" view reflects *executed*
  /// bridges. The backend recomputes the fee from `amountUsd`, so the values
  /// here are facts, not trusted fee figures. Fire-and-forget: never throws and
  /// never blocks the bridge UX.
  Future<void> recordExecutedBridge({
    required int originChainId,
    required int destinationChainId,
    String? walletAddress,
    String? sellToken,
    String? buyToken,
    double? amountUsd,
    String? txHash,
  }) async {
    try {
      final url = AppEnvironment.swap('/cross-chain/record');
      final body = jsonEncode({
        'walletAddress': walletAddress,
        'originChainId': originChainId,
        'destinationChainId': destinationChainId,
        'sellToken': sellToken,
        'buyToken': buyToken,
        'amountUsd': amountUsd,
        'txHash': txHash,
      });
      final normalizedWallet = walletAddress?.trim().toLowerCase();
      final isEvmWallet =
          normalizedWallet != null &&
          RegExp(r'^0x[0-9a-f]{40}$').hasMatch(normalizedWallet);
      Future<http.Response> request(Map<String, String> headers) =>
          _http.client.post(url, headers: headers, body: body);
      final response = isEvmWallet
          ? _walletBackendAuthService.sendAuthorized(
              normalizedWallet,
              request,
              const {'Content-Type': 'application/json'},
            )
          : request(const {'Content-Type': 'application/json'});
      await response.timeout(const Duration(seconds: 10));
    } catch (e) {
      // Analytics only — a failure here must not affect the completed bridge.
      debugPrint('BridgeService.recordExecutedBridge error: $e');
    }
  }

  /// Relay reports the USD value of the output under details.currencyOut.
  static double _readAmountOutUsd(Map<String, dynamic> data) {
    final topLevel = double.tryParse(data['amountOutUsd']?.toString() ?? '');
    if (topLevel != null && topLevel > 0) return topLevel;
    final details = data['details'];
    if (details is! Map) return 0.0;
    final currencyOut = details['currencyOut'];
    if (currencyOut is! Map) return 0.0;
    return double.tryParse(currencyOut['amountUsd']?.toString() ?? '') ?? 0.0;
  }

  static String _readProvider(
    Map<String, dynamic> data, {
    bool sameChainDefault = false,
  }) {
    final protocol =
        (data['protocolUsed'] ?? data['protocol_used'])?.toString().trim() ??
        '';
    if (protocol.isNotEmpty) return protocol;
    final provider = data['provider'];
    if (provider is Map) {
      for (final key in const ['name', 'id', 'provider', 'protocol']) {
        final value = provider[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    final value = provider?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
    return sameChainDefault ? '0x' : 'Owllet routing';
  }

  static String _zeroExCurrency(String currency) {
    if (currency.isEmpty || currency.toLowerCase() == nativeCurrency) {
      return '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
    }
    return currency;
  }

  static List<BridgeStepTx> _parseSameChainSteps(
    Map<String, dynamic> data, {
    required int chainId,
    required String sellToken,
    required String sellAmount,
  }) {
    final transaction = data['transaction'];
    if (transaction is! Map) return const [];
    final to = transaction['to']?.toString() ?? '';
    final callData = transaction['data']?.toString() ?? '';
    if (!_isEvmAddress(to) || !callData.startsWith('0x')) return const [];

    final steps = <BridgeStepTx>[];
    final isNative =
        sellToken.isEmpty ||
        sellToken.toLowerCase() == nativeCurrency ||
        sellToken.toLowerCase() == '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
    final needsAllowance = data['needsAllowance'] == true;
    final spender =
        (data['allowanceSpender'] ?? data['allowanceTarget'])?.toString() ?? '';
    if (!isNative && needsAllowance) {
      final approvalData = _erc20ApprovalData(spender, sellAmount);
      if (!_isEvmAddress(sellToken) || approvalData == null) return const [];
      steps.add(
        BridgeStepTx(
          stepId: 'approve',
          description: 'Approve token',
          to: sellToken,
          data: approvalData,
          value: BigInt.zero,
          chainId: chainId,
        ),
      );
    }

    steps.add(
      BridgeStepTx(
        stepId: 'swap',
        description: 'Swap tokens',
        to: to,
        data: callData,
        value: _parseBigInt(transaction['value']) ?? BigInt.zero,
        chainId: chainId,
        maxFeePerGas: _parseBigInt(transaction['maxFeePerGas']),
        maxPriorityFeePerGas: _parseBigInt(transaction['maxPriorityFeePerGas']),
      ),
    );
    return steps;
  }

  static String? _erc20ApprovalData(String spender, String amount) {
    if (!_isEvmAddress(spender)) return null;
    final parsedAmount = BigInt.tryParse(amount);
    if (parsedAmount == null || parsedAmount <= BigInt.zero) return null;
    final addressWord = spender.substring(2).toLowerCase().padLeft(64, '0');
    final amountWord = parsedAmount.toRadixString(16).padLeft(64, '0');
    return '0x095ea7b3$addressWord$amountWord';
  }

  static bool _isEvmAddress(String value) =>
      RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value);

  /// Parse raw Relay `steps` (as returned by the backend, e.g. the cash-in
  /// saga's /cashin/initiate) into executable [BridgeStepTx]s. Public so the
  /// mini-app host can run the same steps the Bridge tab does.
  static List<BridgeStepTx> parseSteps(Object? rawSteps) =>
      _parseSteps(rawSteps);

  static List<BridgeStepTx> _parseSteps(Object? rawSteps) {
    if (rawSteps is! List) return const [];
    final parsed = <BridgeStepTx>[];
    for (final step in rawSteps.whereType<Map>()) {
      final stepId = step['id']?.toString() ?? '';
      final description = step['description']?.toString() ?? '';
      final items = step['items'];
      if (items is! List) continue;
      for (final item in items.whereType<Map>()) {
        final data = item['data'];
        if (data is! Map) continue;

        if (data['chainType']?.toString() == 'tvm' &&
            data['transaction'] is Map) {
          parsed.add(
            BridgeStepTx(
              stepId: stepId,
              description: description,
              to: data['depositAddress']?.toString() ?? '',
              data: '0x',
              value: BigInt.zero,
              chainId: (data['chainId'] as num?)?.toInt() ?? tronBridgeChainId,
              tronTransactionJson: jsonEncode(data['transaction']),
            ),
          );
          continue;
        }

        if (data['chainType']?.toString() == 'solana-transfer') {
          final to = data['to']?.toString() ?? '';
          final amount = _parseBigInt(data['amount']);
          if (to.isEmpty || amount == null || amount <= BigInt.zero) continue;
          parsed.add(
            BridgeStepTx(
              stepId: stepId,
              description: description,
              to: to,
              data: '0x',
              value: BigInt.zero,
              chainId: (data['chainId'] as num?)?.toInt() ?? relaySolanaChainId,
              solanaTransferTo: to,
              solanaTransferAmount: amount,
              solanaTokenMint: data['tokenMint']?.toString(),
            ),
          );
          continue;
        }

        // Solana-origin steps carry instructions instead of calldata.
        final instructions = data['instructions'];
        if (instructions is List && instructions.isNotEmpty) {
          final tables = data['addressLookupTableAddresses'];
          parsed.add(
            BridgeStepTx(
              stepId: stepId,
              description: description,
              to: '',
              data: '0x',
              value: BigInt.zero,
              chainId: relaySolanaChainId,
              instructionsJson: jsonEncode(instructions),
              lookupTableAddresses: tables is List
                  ? tables.map((e) => e.toString()).toList()
                  : const [],
            ),
          );
          continue;
        }

        final to = data['to']?.toString() ?? '';
        final callData = data['data']?.toString() ?? '0x';
        final chainId = (data['chainId'] as num?)?.toInt();
        if (to.isEmpty || chainId == null) continue;
        parsed.add(
          BridgeStepTx(
            stepId: stepId,
            description: description,
            to: to,
            data: callData,
            value: _parseBigInt(data['value']) ?? BigInt.zero,
            chainId: chainId,
            maxFeePerGas: _parseBigInt(data['maxFeePerGas']),
            maxPriorityFeePerGas: _parseBigInt(data['maxPriorityFeePerGas']),
          ),
        );
      }
    }
    return parsed;
  }

  static BigInt? _parseBigInt(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    if (text.startsWith('0x') || text.startsWith('0X')) {
      return BigInt.tryParse(text.substring(2), radix: 16);
    }
    return BigInt.tryParse(text);
  }
}
