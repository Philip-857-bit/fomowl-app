import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/chain.dart';
import '../../models/token.dart';
import '../../models/token_standard.dart';
import 'home_portfolio_data.dart';

class HomeAggregatedPortfolioSnapshot {
  const HomeAggregatedPortfolioSnapshot({
    required this.walletAddress,
    required this.sections,
    required this.timestamp,
    this.source = 'cache',
    this.isStale = false,
    this.partialFailure = false,
    this.chainsPending = const [],
  });

  final String walletAddress;
  final List<HomePortfolioSection> sections;
  final DateTime timestamp;
  final String source;
  final bool isStale;
  final bool partialFailure;
  final List<int> chainsPending;

  Map<String, dynamic> toJson() => {
    'walletAddress': walletAddress,
    'sections': sections
        .map(
          (section) => {
            'chain': section.chain.toJson(),
            'tokens': section.tokens.map(_tokenToJson).toList(),
          },
        )
        .toList(),
    'timestamp': timestamp.toIso8601String(),
    'source': source,
    'isStale': isStale,
    'partialFailure': partialFailure,
    'chainsPending': chainsPending,
  };

  factory HomeAggregatedPortfolioSnapshot.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List? ?? const [];
    return HomeAggregatedPortfolioSnapshot(
      walletAddress: json['walletAddress'] as String? ?? '',
      sections: rawSections.whereType<Map>().map((entry) {
        final mappedEntry = entry.map((key, value) => MapEntry('$key', value));
        final rawChainJson = mappedEntry['chain'];
        final chainJson = rawChainJson is Map
            ? rawChainJson.map((key, value) => MapEntry('$key', value))
            : const <String, dynamic>{};
        final tokensJson = entry['tokens'] as List? ?? const [];
        return HomePortfolioSection(
          chain: EvmChain.fromJson(chainJson),
          tokens: tokensJson
              .whereType<Map<String, dynamic>>()
              .map(_tokenFromJson)
              .toList(),
        );
      }).toList(),
      timestamp: _parseTimestamp(json['timestamp']),
      source: json['source'] as String? ?? 'cache',
      isStale: json['isStale'] == true,
      partialFailure: json['partialFailure'] == true,
      chainsPending: (json['chainsPending'] as List? ?? const [])
          .map((value) => (value as num).toInt())
          .toList(),
    );
  }

  HomeAggregatedPortfolioSnapshot copyWith({
    String? source,
    bool? isStale,
    bool? partialFailure,
    List<int>? chainsPending,
    List<HomePortfolioSection>? sections,
    DateTime? timestamp,
  }) {
    return HomeAggregatedPortfolioSnapshot(
      walletAddress: walletAddress,
      sections: sections ?? this.sections,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      isStale: isStale ?? this.isStale,
      partialFailure: partialFailure ?? this.partialFailure,
      chainsPending: chainsPending ?? this.chainsPending,
    );
  }

  bool get isExpired =>
      DateTime.now().difference(timestamp) > const Duration(minutes: 5);
}

class HomePortfolioSnapshotService {
  static const String _prefix = 'home_portfolio_snapshot_';

  String _key(String walletAddress) => '$_prefix${walletAddress.toLowerCase()}';

  Future<void> saveSnapshot(HomeAggregatedPortfolioSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(snapshot.walletAddress),
        jsonEncode(snapshot.toJson()),
      );
    } catch (error) {
      debugPrint('Error saving home portfolio snapshot: $error');
    }
  }

  Future<HomeAggregatedPortfolioSnapshot?> loadSnapshot(
    String walletAddress,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(walletAddress));
      if (raw == null || raw.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final snapshot = HomeAggregatedPortfolioSnapshot.fromJson(decoded);
      if (snapshot.isExpired) {
        await prefs.remove(_key(walletAddress));
        return null;
      }
      return snapshot;
    } catch (error) {
      debugPrint('Error loading home portfolio snapshot: $error');
      return null;
    }
  }
}

DateTime _parseTimestamp(Object? rawValue) {
  final raw = rawValue?.toString();
  if (raw == null || raw.isEmpty) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

Map<String, dynamic> _tokenToJson(Token token) => {
  'symbol': token.symbol,
  'name': token.name,
  'contractAddress': token.contractAddress,
  'balance': token.balance,
  'valueUsd': token.valueUsd,
  'priceUsd': token.priceUsd,
  'changePercent24h': token.changePercent24h,
  'decimals': token.decimals,
  'imageUrl': token.imageUrl,
  'coinGeckoId': token.coinGeckoId,
  'isCertified': token.isCertified,
  'networkKey': token.networkKey,
  'tokenStandard': token.effectiveTokenStandard.wireValue,
  // PATCH: Persist price source metadata for DEX badges after reload.
  'priceSource': token.priceSource,
  // PATCH: Persist DEX liquidity metadata after reload.
  'liquidityUsd': token.liquidityUsd,
  // PATCH: Persist DEX-only marker after reload.
  'isDexOnly': token.isDexOnly,
};

Token _tokenFromJson(Map<String, dynamic> json) => Token(
  symbol: json['symbol'] as String? ?? '',
  name: json['name'] as String? ?? '',
  contractAddress: json['contractAddress'] as String?,
  balance: (json['balance'] as num?)?.toDouble() ?? 0,
  valueUsd: (json['valueUsd'] as num?)?.toDouble() ?? 0,
  priceUsd: (json['priceUsd'] as num?)?.toDouble() ?? 0,
  changePercent24h: (json['changePercent24h'] as num?)?.toDouble() ?? 0,
  decimals: (json['decimals'] as num?)?.toInt() ?? 18,
  imageUrl: json['imageUrl'] as String?,
  coinGeckoId: json['coinGeckoId'] as String?,
  isCertified: json['isCertified'] == true,
  networkKey: json['networkKey'] as String?,
  // PATCH: Restore price source metadata for DEX badges after reload.
  priceSource: json['priceSource'] as String? ?? 'Unknown',
  // PATCH: Restore DEX liquidity metadata after reload.
  liquidityUsd: (json['liquidityUsd'] as num?)?.toDouble(),
  // PATCH: Restore DEX-only marker after reload.
  isDexOnly: json['isDexOnly'] == true,
  tokenStandard: TokenStandardCodec.fromWireValue(
    json['tokenStandard'] as String?,
  ),
);
