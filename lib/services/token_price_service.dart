import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'base_service.dart';
import '../models/token_market_data.dart';

/// Service for fetching token prices and market data from CoinGecko
class TokenPriceService extends BaseService {
  static const String priceApiBase = 'https://api.coingecko.com/api/v3';

  final Map<String, _CachedChartData> _priceHistoryCache = {};
  final Map<String, _CachedMarketData> _tokenMarketDataCache = {};

  static const Duration _priceHistoryCacheTtl = Duration(minutes: 2);
  static const Duration _tokenMarketDataCacheTtl = Duration(minutes: 2);

  /// Fetch simple prices and 24h change for a list of token IDs
  Future<Map<String, double>> getTokenPrices(List<String> tokenIds) async {
    if (tokenIds.isEmpty) return {};
    try {
      final ids = tokenIds.map((id) => Uri.encodeComponent(id)).join(',');
      final url =
          '$priceApiBase/simple/price?ids=$ids&vs_currencies=usd&include_24hr_change=true';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final prices = <String, double>{};
        data.forEach((key, value) {
          if (value is Map && value['usd'] != null) {
            prices[key] = (value['usd'] as num).toDouble();
            if (value['usd_24h_change'] != null) {
              prices['${key}_change'] = (value['usd_24h_change'] as num)
                  .toDouble();
            }
          }
        });
        return prices;
      }
    } catch (e) {
      debugPrint('Error fetching token prices: $e');
    }
    return {};
  }

  /// Get price history for a specific timeframe
  Future<List<double>> getPriceHistory(String coinId, {int days = 7}) async {
    if (coinId.isEmpty) return [];
    final cacheKey = '$coinId:$days';
    final cached = _priceHistoryCache[cacheKey];
    final now = DateTime.now();

    if (cached != null &&
        now.difference(cached.fetchedAt) < _priceHistoryCacheTtl) {
      return cached.values;
    }

    try {
      final encodedId = Uri.encodeComponent(coinId);
      final url =
          '$priceApiBase/coins/$encodedId/market_chart?vs_currency=usd&days=$days';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = await compute(_parsePriceHistory, response.body);
        if (data.isNotEmpty) {
          _priceHistoryCache[cacheKey] = _CachedChartData(
            values: data,
            fetchedAt: now,
          );
          return data;
        }
      }
    } catch (e) {
      debugPrint('Error fetching price history for $coinId: $e');
    }
    return [];
  }

  /// Get high-resolution price history for short windows (e.g. 5m, 1h).
  Future<List<double>> getPriceHistoryRange(
    String coinId, {
    required Duration window,
  }) async {
    if (coinId.isEmpty) return [];
    final now = DateTime.now().toUtc();
    final from = now.subtract(window);
    final cacheKey = '$coinId:range:${window.inMinutes}';
    final cached = _priceHistoryCache[cacheKey];
    if (cached != null &&
        now.difference(cached.fetchedAt) < const Duration(seconds: 30)) {
      return cached.values;
    }

    try {
      final encodedId = Uri.encodeComponent(coinId);
      final fromSec = (from.millisecondsSinceEpoch / 1000).floor();
      final toSec = (now.millisecondsSinceEpoch / 1000).floor();
      final url =
          '$priceApiBase/coins/$encodedId/market_chart/range?vs_currency=usd&from=$fromSec&to=$toSec';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = await compute(_parsePriceHistory, response.body);
        if (data.isNotEmpty) {
          _priceHistoryCache[cacheKey] = _CachedChartData(
            values: data,
            fetchedAt: now,
          );
          return data;
        }
      }
    } catch (e) {
      debugPrint('Error fetching range price history for $coinId: $e');
    }
    return [];
  }

  /// Fetch detailed market data for a token
  Future<TokenMarketData?> getTokenMarketData(String coinId) async {
    if (coinId.isEmpty) return null;
    final now = DateTime.now();
    final cached = _tokenMarketDataCache[coinId];

    if (cached != null &&
        now.difference(cached.fetchedAt) < _tokenMarketDataCacheTtl) {
      return cached.value;
    }

    try {
      final encodedId = Uri.encodeComponent(coinId);
      final url =
          '$priceApiBase/coins/$encodedId?localization=false&tickers=false&community_data=false&developer_data=false&sparkline=false';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final marketData = data['market_data'] as Map<String, dynamic>?;

        if (marketData != null) {
          final result = TokenMarketData(
            priceUsd: _toDouble(marketData['current_price']?['usd']),
            marketCapUsd: _toDouble(marketData['market_cap']?['usd']),
            totalSupply: _toDouble(marketData['total_supply']),
            circulatingSupply: _toDouble(marketData['circulating_supply']),
            genesisDate: data['genesis_date'] as String?,
          );
          _tokenMarketDataCache[coinId] = _CachedMarketData(
            value: result,
            fetchedAt: now,
          );
          return result;
        }
      }
    } catch (e) {
      debugPrint('Error fetching market data for $coinId: $e');
    }
    return null;
  }

  static List<double> _parsePriceHistory(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      final prices = data['prices'] as List? ?? const [];
      return prices
          .whereType<List>()
          .map<double>(
            (p) =>
                (p.length > 1 && p[1] is num) ? (p[1] as num).toDouble() : 0.0,
          )
          .where((v) => v.isFinite && v > 0)
          .toList();
    } catch (e) {
      return [];
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class _CachedChartData {
  final List<double> values;
  final DateTime fetchedAt;
  const _CachedChartData({required this.values, required this.fetchedAt});
}

class _CachedMarketData {
  final TokenMarketData value;
  final DateTime fetchedAt;
  const _CachedMarketData({required this.value, required this.fetchedAt});
}
