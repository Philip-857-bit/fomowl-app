import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/token.dart';

/// Model representing a captured state of the user's portfolio on the Home screen.
class HomePortfolioSnapshot {
  final String walletAddress;
  final int chainId;
  final String walletName;
  final double totalBalance;
  final List<Token> tokens;
  final DateTime timestamp;

  const HomePortfolioSnapshot({
    required this.walletAddress,
    required this.chainId,
    required this.walletName,
    required this.totalBalance,
    required this.tokens,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'walletAddress': walletAddress,
    'chainId': chainId,
    'walletName': walletName,
    'totalBalance': totalBalance,
    'tokens': tokens.map(_tokenToJson).toList(),
    'timestamp': timestamp.toIso8601String(),
  };

  factory HomePortfolioSnapshot.fromJson(Map<String, dynamic> json) {
    return HomePortfolioSnapshot(
      walletAddress: json['walletAddress'] ?? '',
      chainId: json['chainId'] ?? 0,
      walletName: json['walletName'] ?? '',
      totalBalance: (json['totalBalance'] ?? 0.0).toDouble(),
      tokens: (json['tokens'] as List? ?? [])
          .map((t) => _tokenFromJson(t as Map<String, dynamic>))
          .toList(),
      timestamp: (() {
        final raw = json['timestamp']?.toString();
        if (raw == null || raw.isEmpty) {
          return DateTime.fromMillisecondsSinceEpoch(0);
        }
        return DateTime.parse(raw);
      })(),
    );
  }

  bool get isStale => DateTime.now().difference(timestamp).inHours > 24;
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
);

/// Service to persist and retrieve the Home portfolio snapshot for instant-after-unlock UX.
class HomeSnapshotService {
  static const String _prefix = 'home_snapshot_';

  String _getKey(int chainId, String walletAddress) =>
      '$_prefix${chainId}_${walletAddress.toLowerCase()}';

  Future<void> saveSnapshot(HomePortfolioSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getKey(snapshot.chainId, snapshot.walletAddress);
      await prefs.setString(key, jsonEncode(snapshot.toJson()));
    } catch (e) {
      debugPrint('Error saving home snapshot: $e');
    }
  }

  Future<HomePortfolioSnapshot?> loadSnapshot(
    int chainId,
    String walletAddress,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getKey(chainId, walletAddress);
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      final snapshot = HomePortfolioSnapshot.fromJson(decoded);
      if (snapshot.isStale) {
        await prefs.remove(key);
        return null;
      }
      return snapshot;
    } catch (e) {
      debugPrint('Error loading home snapshot: $e');
      return null;
    }
  }

  Future<void> clearAllSnapshots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('clearAllSnapshots failed: $e');
    }
  }
}
