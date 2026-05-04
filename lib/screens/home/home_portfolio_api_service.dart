import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../config/app_environment.dart';
import '../../models/chain.dart';
import '../../models/token.dart';
import '../../services/blockchain/blockchain_catalog.dart';
import '../../services/http_client_service.dart';
import 'home_portfolio_data.dart';
import 'home_portfolio_snapshot_service.dart';

class HomePortfolioApiService {
  HomePortfolioApiService({HttpClientService? httpClientService})
    : _httpClientService = httpClientService ?? HttpClientService();

  final HttpClientService _httpClientService;

  Future<HomeAggregatedPortfolioSnapshot> fetchPortfolio(
    String walletAddress, {
    bool sync = false,
  }) async {
    final normalizedAddress = walletAddress.trim().toLowerCase();
    final response = await _httpClientService.sendWithRetry(
      () => _httpClientService.client.get(
        AppEnvironment.blockchain('/portfolio/$normalizedAddress', {
          'sync': '$sync',
        }),
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Portfolio request failed with HTTP ${response.statusCode}',
      );
    }

    return parseResponse(response.body);
  }

  @visibleForTesting
  static HomeAggregatedPortfolioSnapshot parseResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid portfolio response payload');
    }

    final rawSections = decoded['sections'] as List? ?? const [];
    final sections = rawSections.whereType<Map>().map((entry) {
      final section = entry.map((key, value) => MapEntry('$key', value));
      final chainId = (section['chainId'] as num?)?.toInt() ?? 0;
      final chainName = section['chainName'] as String? ?? 'Unknown Chain';
      final chainLogoUrl = section['chainLogoUrl'] as String?;
      final tokens = (section['tokens'] as List? ?? const [])
          .whereType<Map>()
          .map((token) {
            final mapped = token.map((key, value) => MapEntry('$key', value));
            return Token(
              symbol: mapped['symbol'] as String? ?? '',
              name: mapped['name'] as String? ?? '',
              contractAddress: mapped['contractAddress'] as String?,
              balance: (mapped['balance'] as num?)?.toDouble() ?? 0,
              valueUsd: (mapped['valueUsd'] as num?)?.toDouble() ?? 0,
              priceUsd: (mapped['priceUsd'] as num?)?.toDouble() ?? 0,
              changePercent24h:
                  (mapped['changePercent24h'] as num?)?.toDouble() ?? 0,
              decimals: (mapped['decimals'] as num?)?.toInt() ?? 18,
              imageUrl: mapped['imageUrl'] as String?,
              coinGeckoId: mapped['coinGeckoId'] as String?,
              isCertified: mapped['isCertified'] == true,
              // PATCH: Preserve backend price source metadata for DEX badges.
              priceSource:
                  mapped['priceSource'] as String? ??
                  mapped['price_source'] as String? ??
                  'Unknown',
              // PATCH: Preserve backend DEX liquidity metadata.
              liquidityUsd:
                  (mapped['liquidityUsd'] as num?)?.toDouble() ??
                  (mapped['liquidity_usd'] as num?)?.toDouble(),
              // PATCH: Preserve backend DEX-only marker.
              isDexOnly:
                  mapped['isDexOnly'] == true || mapped['is_dex_only'] == true,
            );
          })
          .toList();

      return HomePortfolioSection(
        chain: _resolveChain(
          chainId: chainId,
          chainName: chainName,
          chainLogoUrl: chainLogoUrl,
        ),
        tokens: tokens,
      );
    }).toList();

    return HomeAggregatedPortfolioSnapshot(
      walletAddress: decoded['walletAddress'] as String? ?? '',
      sections: sections,
      timestamp:
          DateTime.tryParse(decoded['snapshotAt'] as String? ?? '') ??
          DateTime.now(),
      source: decoded['source'] as String? ?? 'network',
      isStale: decoded['isStale'] == true,
      partialFailure: decoded['partialFailure'] == true,
      chainsPending: (decoded['chainsPending'] as List? ?? const [])
          .map((value) => (value as num).toInt())
          .toList(),
    );
  }

  static EvmChain _resolveChain({
    required int chainId,
    required String chainName,
    required String? chainLogoUrl,
  }) {
    for (final chain in BlockchainCatalog.builtInChains) {
      if (chain.chainId != chainId) {
        continue;
      }
      return EvmChain(
        name: chainName.isEmpty ? chain.name : chainName,
        symbol: chain.symbol,
        chainId: chain.chainId,
        rpcUrl: chain.rpcUrl,
        coinGeckoId: chain.coinGeckoId,
        explorerUrl: chain.explorerUrl,
        logoUrl: chainLogoUrl ?? chain.logoUrl,
        isCustom: chain.isCustom,
      );
    }

    return EvmChain(
      name: chainName,
      symbol: '',
      chainId: chainId,
      rpcUrl: AppEnvironment.blockchain('/$chainId/rpc').toString(),
      logoUrl: chainLogoUrl,
      isCustom: false,
    );
  }
}
