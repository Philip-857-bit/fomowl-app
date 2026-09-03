import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'base_service.dart';
import 'http_client_service.dart';

/// Service for handling JSON-RPC calls to various chains
class RpcService extends BaseService {
  int _nextRequestId = 1;
  RpcCallException? _lastError;
  final HttpClientService _httpClientService = HttpClientService();
  static const Duration _resolvedRpcUrlCacheTtl = Duration(minutes: 5);
  final Map<String, _ResolvedRpcUrlCacheEntry> _resolvedRpcUrlCache = {};

  RpcCallException? get lastError => _lastError;

  final Map<int, List<String>> _publicRpcFallbacks = {
    1: ['https://cloudflare-eth.com'],
    56: ['https://bsc-dataseed.binance.org'],
    137: ['https://polygon-rpc.com'],
    42161: ['https://arb1.arbitrum.io/rpc'],
    10: ['https://mainnet.optimism.io'],
    8453: ['https://mainnet.base.org'],
    324: ['https://mainnet.era.zksync.io'],
    43114: ['https://api.avax.network/ext/bc/C/rpc'],
    250: ['https://rpc.ankr.com/fantom'],
    100: ['https://rpc.gnosischain.com'],
    8217: ['https://public-en-cypress.klaytn.net'],
    1313161554: ['https://mainnet.aurora.dev'],
  };

  /// Make a JSON-RPC call with automatic fallback support
  Future<dynamic> rpcCall({
    required int chainId,
    required String primaryRpcUrl,
    required String method,
    required List<dynamic> params,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final candidates = [primaryRpcUrl, ...(_publicRpcFallbacks[chainId] ?? [])];
    final requestId = _nextRequestId++;
    _lastError = null;

    for (final rpcUrl in candidates) {
      try {
        final response = await _httpClientService
            .sendWithRetry(
              () => _httpClientService.client.post(
                Uri.parse(rpcUrl),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'jsonrpc': '2.0',
                  'method': method,
                  'params': params,
                  'id': requestId,
                }),
              ),
            )
            .timeout(timeout);

        if (response.statusCode != 200) {
          _lastError = RpcCallException(
            method: method,
            rpcUrl: rpcUrl,
            message: 'Unexpected HTTP ${response.statusCode}',
          );
          continue;
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Correlation check
        if (data['id'] != requestId) {
          _lastError = RpcCallException(
            method: method,
            rpcUrl: rpcUrl,
            message: 'RPC ID mismatch: expected $requestId, got ${data['id']}',
          );
          debugPrint(_lastError.toString());
          continue;
        }

        if (data['error'] != null) {
          final errorObj = data['error'];
          if (errorObj is String) {
            _lastError = RpcCallException(
              method: method,
              rpcUrl: rpcUrl,
              message: errorObj,
            );
            debugPrint(_lastError.toString());
            continue;
          }
          final error = errorObj as Map<String, dynamic>?;
          _lastError = RpcCallException(
            method: method,
            rpcUrl: rpcUrl,
            code: error?['code'] as int?,
            message: error?['message']?.toString() ?? 'Unknown RPC error',
          );
          debugPrint(_lastError.toString());
          continue;
        }

        return data['result'];
      } catch (e) {
        _lastError = RpcCallException(
          method: method,
          rpcUrl: rpcUrl,
          message: e.toString(),
        );
        debugPrint(_lastError.toString());
      }
    }
    return null;
  }

  /// Test an RPC URL for connectivity
  Future<bool> testRpcUrl(String rpcUrl) async {
    final requestId = _nextRequestId++;
    try {
      final response = await _httpClientService
          .sendWithRetry(
            () => _httpClientService.client.post(
              Uri.parse(rpcUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'jsonrpc': '2.0',
                'method': 'eth_chainId',
                'params': [],
                'id': requestId,
              }),
            ),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return false;

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['jsonrpc'] != '2.0') return false;
        if (data['id'] != requestId) return false;
        if (data['error'] != null) return false;

        final result = data['result'] as String?;
        if (result == null || !result.startsWith('0x')) return false;

        return true;
      } catch (_) {
        return false;
      }
    } catch (e) {
      _lastError = RpcCallException(
        method: 'eth_chainId',
        rpcUrl: rpcUrl,
        message: e.toString(),
      );
      return false;
    }
  }

  Future<int?> getChainIdForRpcUrl(String rpcUrl) async {
    final requestId = _nextRequestId++;
    try {
      final response = await _httpClientService
          .sendWithRetry(
            () => _httpClientService.client.post(
              Uri.parse(rpcUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'jsonrpc': '2.0',
                'method': 'eth_chainId',
                'params': [],
                'id': requestId,
              }),
            ),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        _lastError = RpcCallException(
          method: 'eth_chainId',
          rpcUrl: rpcUrl,
          message: 'Unexpected HTTP ${response.statusCode}',
        );
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['id'] != requestId || data['error'] != null) {
        _lastError = RpcCallException(
          method: 'eth_chainId',
          rpcUrl: rpcUrl,
          message: data['error'] != null
              ? 'RPC error: ${data['error']}'
              : 'RPC ID mismatch: expected $requestId, got ${data['id']}',
        );
        return null;
      }

      final result = data['result']?.toString();
      if (result == null || !result.startsWith('0x')) {
        _lastError = RpcCallException(
          method: 'eth_chainId',
          rpcUrl: rpcUrl,
          message: 'Invalid eth_chainId result: ${data['result']}',
        );
        return null;
      }
      return int.tryParse(result.substring(2), radix: 16);
    } catch (e) {
      _lastError = RpcCallException(
        method: 'eth_chainId',
        rpcUrl: rpcUrl,
        message: e.toString(),
      );
      return null;
    }
  }

  Future<String> resolveWorkingRpcUrl({
    required int chainId,
    required String primaryRpcUrl,
  }) async {
    final cacheKey = '$chainId|$primaryRpcUrl';
    final now = DateTime.now();
    final cached = _resolvedRpcUrlCache[cacheKey];
    if (cached != null) {
      if (cached.rpcUrl.isNotEmpty &&
          now.difference(cached.resolvedAt) < _resolvedRpcUrlCacheTtl) {
        return cached.rpcUrl;
      }
      _resolvedRpcUrlCache.remove(cacheKey);
    }

    final candidates = <String>{
      primaryRpcUrl,
      ...(_publicRpcFallbacks[chainId] ?? const []),
    };
    for (final rpcUrl in candidates) {
      final resolvedChainId = await getChainIdForRpcUrl(rpcUrl);
      if (resolvedChainId == chainId) {
        _resolvedRpcUrlCache[cacheKey] = _ResolvedRpcUrlCacheEntry(
          rpcUrl: rpcUrl,
          resolvedAt: DateTime.now(),
        );
        return rpcUrl;
      }
    }

    return primaryRpcUrl;
  }
}

class _ResolvedRpcUrlCacheEntry {
  const _ResolvedRpcUrlCacheEntry({
    required this.rpcUrl,
    required this.resolvedAt,
  });

  final String rpcUrl;
  final DateTime resolvedAt;
}

class RpcCallException implements Exception {
  const RpcCallException({
    required this.method,
    required this.rpcUrl,
    required this.message,
    this.code,
  });

  final String method;
  final String rpcUrl;
  final String message;
  final int? code;

  @override
  String toString() {
    final codeText = code == null ? '' : ' code=$code';
    return 'RpcCallException(method: $method, rpcUrl: $rpcUrl,$codeText message: $message)';
  }
}
