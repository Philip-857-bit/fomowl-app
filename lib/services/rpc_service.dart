import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'base_service.dart';

/// Service for handling JSON-RPC calls to various chains
class RpcService extends BaseService {
  int _nextRequestId = 1;

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
    
    for (final rpcUrl in candidates) {
      try {
        final response = await http.post(
          Uri.parse(rpcUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'method': method,
            'params': params,
            'id': requestId,
          }),
        ).timeout(timeout);

        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Correlation check
        if (data['id'] != requestId) {
          debugPrint('RPC ID mismatch: expected $requestId, got ${data['id']}');
          continue;
        }

        if (data['error'] != null) {
          debugPrint('RPC error ($method @ $rpcUrl): ${data['error']}');
          continue;
        }
        
        return data['result'];
      } catch (e) {
        debugPrint('RPC call failed ($method @ $rpcUrl): $e');
      }
    }
    return null;
  }

  /// Test an RPC URL for connectivity
  Future<bool> testRpcUrl(String rpcUrl) async {
    final requestId = _nextRequestId++;
    try {
      final response = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'eth_chainId',
          'params': [],
          'id': requestId,
        }),
      ).timeout(const Duration(seconds: 8));
      
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
      return false;
    }
  }
}
