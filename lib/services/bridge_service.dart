import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../config/app_environment.dart';
import '../utils/app_error_utils.dart';
import 'http_client_service.dart';

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
  });

  bool get isSolana => instructionsJson != null;
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
  final double bridgeFeeUsd;

  /// Estimated origin-chain gas in USD.
  final double gasFeeUsd;

  /// Owllet platform fee.
  final int? platformFeeBps;
  final double? platformFeeUsd;

  /// Estimated completion time in seconds.
  final int? timeEstimateSeconds;

  final String requestId;
  final List<BridgeStepTx> steps;

  const BridgeQuote({
    required this.originChainId,
    required this.destinationChainId,
    required this.amountIn,
    required this.amountOut,
    required this.amountOutUsd,
    required this.bridgeFeeUsd,
    required this.gasFeeUsd,
    required this.platformFeeBps,
    required this.platformFeeUsd,
    required this.timeEstimateSeconds,
    required this.requestId,
    required this.steps,
  });

  String get arrivalLabel {
    final seconds = timeEstimateSeconds;
    if (seconds == null || seconds <= 0) return '~minutes';
    if (seconds < 60) return '~$seconds sec';
    final minutes = (seconds / 60).ceil();
    return '~$minutes min';
  }
}

class BridgeStatus {
  final String status;
  final List<String> txHashes;

  const BridgeStatus({required this.status, required this.txHashes});

  bool get isSuccess => status.toLowerCase() == 'success';
  bool get isFailure {
    final lower = status.toLowerCase();
    return lower == 'failure' || lower == 'failed' || lower == 'refund';
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

  const BridgeCurrency({
    required this.chainId,
    required this.address,
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.isNative,
    this.logoUri,
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
    );
  }
}

/// Service for Relay-powered cross-chain bridging via the Rust backend.
///
/// Flow:
///   1. [getQuote] → fees + ordered [BridgeStepTx] list
///   2. Caller signs and broadcasts each step transaction on its chain
///   3. [getStatus] polled with the quote's requestId until success/failure
class BridgeService {
  BridgeService({HttpClientService? httpClientService})
    : _http = httpClientService ?? HttpClientService();

  final HttpClientService _http;
  String? _lastError;

  String? get lastError => _lastError;

  /// Relay represents native EVM tokens with the zero address.
  static const String nativeCurrency =
      '0x0000000000000000000000000000000000000000';

  /// Relay's chain id for Solana mainnet.
  static const int relaySolanaChainId = 792703809;

  /// Relay represents native SOL with the system program address.
  static const String solanaNativeCurrency = '11111111111111111111111111111111';

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
  }) async {
    _lastError = null;
    try {
      final params = <String, String>{
        'originChainId': '$originChainId',
        'destinationChainId': '$destinationChainId',
        'originCurrency': originCurrency.isEmpty
            ? nativeCurrency
            : originCurrency,
        'destinationCurrency': destinationCurrency.isEmpty
            ? nativeCurrency
            : destinationCurrency,
        'amount': amountWei,
        'user': walletAddress,
        'recipient': recipientAddress ?? walletAddress,
        if (amountUsd != null && amountUsd > 0) 'amountUsd': '$amountUsd',
      };
      final url = AppEnvironment.swap('/cross-chain/quote', params);

      final response = await _http
          .sendWithRetry(
            () => _http.client.get(url),
            retryIf: (r) => r.statusCode >= 500,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _lastError = AppErrorUtils.backendMessage(
          response.body,
          fallback: 'Unable to fetch a bridge quote right now.',
        );
        return null;
      }

      final raw = jsonDecode(response.body);
      if (raw is! Map) {
        _lastError = 'Bridge quote response was incomplete.';
        return null;
      }
      final data = Map<String, dynamic>.from(raw);
      final amountOut = data['amountOut']?.toString() ?? '';
      if (amountOut.isEmpty || amountOut == '0') {
        _lastError =
            'No bridge route is available for this pair right now. Try a different amount or token.';
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
        bridgeFeeUsd: (data['feeUsd'] as num?)?.toDouble() ?? 0.0,
        gasFeeUsd: (data['gasFeeUsd'] as num?)?.toDouble() ?? 0.0,
        platformFeeBps: (data['platformFeeBps'] as num?)?.toInt(),
        platformFeeUsd: (data['platformFeeUsd'] as num?)?.toDouble(),
        timeEstimateSeconds: (data['timeEstimateSeconds'] as num?)?.toInt(),
        requestId: data['requestId']?.toString() ?? '',
        steps: _parseSteps(data['steps']),
      );
    } catch (e) {
      _lastError ??= AppErrorUtils.userMessage(
        e,
        fallback: 'Unable to fetch a bridge quote right now.',
      );
      debugPrint('BridgeService.getQuote error: $e');
      return null;
    }
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

  /// Relay reports the USD value of the output under details.currencyOut.
  static double _readAmountOutUsd(Map<String, dynamic> data) {
    final details = data['details'];
    if (details is! Map) return 0.0;
    final currencyOut = details['currencyOut'];
    if (currencyOut is! Map) return 0.0;
    return double.tryParse(currencyOut['amountUsd']?.toString() ?? '') ?? 0.0;
  }

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
