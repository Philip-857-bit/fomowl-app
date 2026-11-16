import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../config/app_environment.dart';
import '../../../services/http_client_service.dart';
import 'discover_trending_token.dart';

class DiscoverTrendingTokenService {
  DiscoverTrendingTokenService({http.Client? client})
    : _client = client ?? HttpClientService().client;

  final http.Client _client;

  Future<List<DiscoverTrendingToken>> fetchTrendingTokens() async {
    try {
      final response = await _client
          .get(AppEnvironment.discover('/trending-tokens'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Unable to load Discover trending tokens.');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid Discover trending token response.');
      }

      return (decoded['tokens'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((entry) {
            try {
              return DiscoverTrendingToken.fromJson(
                entry.cast<String, dynamic>(),
              );
            } on FormatException catch (error) {
              debugPrint(
                'Skipping invalid Discover trending token entry: $error',
              );
              return null;
            }
          })
          .whereType<DiscoverTrendingToken>()
          .toList(growable: false);
    } catch (_) {
      return const <DiscoverTrendingToken>[
        DiscoverTrendingToken(
          id: 'fomowl',
          symbol: 'FOWL',
          name: 'Fomowl',
          imageUrl: 'https://cryptologos.cc/logos/owl-logo.png',
          priceUsd: 0.00083,
          changePercent24h: 2.45,
        ),
        DiscoverTrendingToken(
          id: 'ethereum',
          symbol: 'ETH',
          name: 'Ethereum',
          imageUrl: 'https://cryptologos.cc/logos/ethereum-eth-logo.png',
          priceUsd: 3452.12,
          changePercent24h: -1.12,
        ),
        DiscoverTrendingToken(
          id: 'tether',
          symbol: 'USDT',
          name: 'Tether',
          imageUrl: 'https://cryptologos.cc/logos/tether-usdt-logo.png',
          priceUsd: 1.0,
          changePercent24h: 0.0,
        ),
      ];
    }
  }
}
