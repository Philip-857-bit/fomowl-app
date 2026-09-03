import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_environment.dart';
import 'http_client_service.dart';

/// Etherscan V2 API Service
/// Unified multichain explorer API for 60+ EVM chains.
class EtherscanV2Service {
  final HttpClientService _httpClientService;

  EtherscanV2Service(this._httpClientService);

  /// Fetches gas oracle recommendations via backend proxy.
  Future<Map<String, dynamic>?> getGasOracle(int chainId) async {
    final url = AppEnvironment.blockchain('/$chainId/gas-oracle');

    try {
      final response = await _httpClientService
          .sendWithRetry(() => _httpClientService.client.get(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Backend Gas Oracle failed: $e');
    }
    return null;
  }

  /// Fetches unified transaction history (Normal + ERC20) via backend proxy.
  Future<List<dynamic>> getUnifiedHistory(int chainId, String address) async {
    final url = AppEnvironment.blockchain('/$chainId/history/$address');

    try {
      final response = await _httpClientService
          .sendWithRetry(() => _httpClientService.client.get(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Backend Transaction History failed: $e');
    }
    return [];
  }
}
