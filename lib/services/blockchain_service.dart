import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/token.dart';

/// EVM Chain configuration
class EvmChain {
  final String name;
  final String symbol;
  final int chainId;
  final String rpcUrl;
  final String coinGeckoId;
  final String? explorerUrl;
  final bool isCustom;

  const EvmChain({
    required this.name,
    required this.symbol,
    required this.chainId,
    required this.rpcUrl,
    required this.coinGeckoId,
    this.explorerUrl,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'symbol': symbol,
    'chainId': chainId,
    'rpcUrl': rpcUrl,
    'coinGeckoId': coinGeckoId,
    'explorerUrl': explorerUrl,
    'isCustom': isCustom,
  };

  factory EvmChain.fromJson(Map<String, dynamic> json) => EvmChain(
    name: json['name'] as String,
    symbol: json['symbol'] as String,
    chainId: json['chainId'] as int,
    rpcUrl: json['rpcUrl'] as String,
    coinGeckoId: json['coinGeckoId'] as String? ?? '',
    explorerUrl: json['explorerUrl'] as String?,
    isCustom: json['isCustom'] as bool? ?? true,
  );
}

/// Blockchain Service — Shared ChangeNotifier Provider
/// Manages active chain, custom chains, and all blockchain interactions
class BlockchainService extends ChangeNotifier {
  // Built-in EVM chains (Supports all 1inch v5.2 natively using backend JSON-RPC proxy)
  static const String _backendRpcBase =
      'https://fomowl-backend.onrender.com/api/blockchain';
  static const List<String> _backendDiscoveryBases = [
    'https://fomowl-backend.onrender.com/api/blockchain',
  ];
  static const Duration _backendDiscoveryTimeout = Duration(seconds: 8);
  static const Duration _backendDiscoveryBaseCooldown = Duration(minutes: 5);
  static const Map<int, List<String>> _publicRpcFallbacks = {
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

  static const List<EvmChain> builtInChains = [
    EvmChain(
      name: 'Ethereum',
      symbol: 'ETH',
      chainId: 1,
      rpcUrl: '$_backendRpcBase/1/rpc',
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://etherscan.io',
    ),
    EvmChain(
      name: 'BNB Smart Chain',
      symbol: 'BNB',
      chainId: 56,
      rpcUrl: '$_backendRpcBase/56/rpc',
      coinGeckoId: 'binancecoin',
      explorerUrl: 'https://bscscan.com',
    ),
    EvmChain(
      name: 'Polygon',
      symbol: 'MATIC',
      chainId: 137,
      rpcUrl: '$_backendRpcBase/137/rpc',
      coinGeckoId: 'matic-network',
      explorerUrl: 'https://polygonscan.com',
    ),
    EvmChain(
      name: 'Arbitrum One',
      symbol: 'ETH',
      chainId: 42161,
      rpcUrl: '$_backendRpcBase/42161/rpc',
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://arbiscan.io',
    ),
    EvmChain(
      name: 'Optimism',
      symbol: 'ETH',
      chainId: 10,
      rpcUrl: '$_backendRpcBase/10/rpc',
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://optimistic.etherscan.io',
    ),
    EvmChain(
      name: 'Base',
      symbol: 'ETH',
      chainId: 8453,
      rpcUrl: '$_backendRpcBase/8453/rpc',
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://basescan.org',
    ),
    EvmChain(
      name: 'ZkSync Era',
      symbol: 'ETH',
      chainId: 324,
      rpcUrl: '$_backendRpcBase/324/rpc',
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://explorer.zksync.io',
    ),
    EvmChain(
      name: 'Avalanche C-Chain',
      symbol: 'AVAX',
      chainId: 43114,
      rpcUrl: '$_backendRpcBase/43114/rpc',
      coinGeckoId: 'avalanche-2',
      explorerUrl: 'https://snowtrace.io',
    ),
    EvmChain(
      name: 'Fantom',
      symbol: 'FTM',
      chainId: 250,
      rpcUrl: '$_backendRpcBase/250/rpc',
      coinGeckoId: 'fantom',
      explorerUrl: 'https://ftmscan.com',
    ),
    EvmChain(
      name: 'Gnosis',
      symbol: 'XDAI',
      chainId: 100,
      rpcUrl: '$_backendRpcBase/100/rpc',
      coinGeckoId: 'xdai',
      explorerUrl: 'https://gnosisscan.io',
    ),
    EvmChain(
      name: 'Klaytn',
      symbol: 'KLAY',
      chainId: 8217,
      rpcUrl: '$_backendRpcBase/8217/rpc',
      coinGeckoId: 'klay-token',
      explorerUrl: 'https://scope.klaytn.com',
    ),
    EvmChain(
      name: 'Aurora',
      symbol: 'ETH',
      chainId: 1313161554,
      rpcUrl: '$_backendRpcBase/1313161554/rpc',
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://explorer.mainnet.aurora.dev',
    ),
  ];

  // Storage keys
  static const String _keyCustomChains = 'custom_evm_chains';
  static const String _keyActiveChainId = 'active_chain_id';
  static const String _keyCustomTokens = 'custom_tokens_v1';

  // All chains (built-in + custom)
  List<EvmChain> _customChains = [];
  EvmChain _activeChain = builtInChains[0];
  final Map<int, List<CustomTokenDefinition>> _customTokens = {};

  List<EvmChain> get allChains => [...builtInChains, ..._customChains];
  List<EvmChain> get customChains => _customChains;
  EvmChain get activeChain => _activeChain;
  List<CustomTokenDefinition> get customTokensForActiveChain =>
      List.unmodifiable(_customTokens[_activeChain.chainId] ?? []);

  // CoinGecko API for token prices
  static const String priceApiBase = 'https://api.coingecko.com/api/v3';

  List<Token> _walletTokens = [];
  final Map<String, _CachedChartData> _priceHistoryCache = {};
  final Map<String, _CachedMarketData> _tokenMarketDataCache = {};
  final Map<String, DateTime> _backendDiscoveryBackoffUntil = {};
  static const Duration _priceHistoryCacheTtl = Duration(minutes: 2);
  static const Duration _tokenMarketDataCacheTtl = Duration(minutes: 2);

  // Getter for tokens matching the active chain
  List<Token> get tokens {
    if (_walletTokens.isNotEmpty) return _walletTokens;
    return [
      Token(
        symbol: activeChain.symbol,
        name: activeChain.name,
        balance: 0.0,
        valueUsd: 0.0,
        changePercent24h: 0.0,
        imageUrl: 'https://cryptologos.cc/logos/ethereum-eth-logo.png',
        coinGeckoId: activeChain.coinGeckoId.isNotEmpty
            ? activeChain.coinGeckoId
            : null,
      ),
    ];
  }

  /// Initialize — load persisted chains and active chain from storage
  Future<void> init() async {
    await _loadCustomChains();
    await _loadActiveChain();
    await _loadCustomTokens();
  }

  Future<void> _loadCustomChains() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyCustomChains);
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        _customChains = list
            .map((e) => EvmChain.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading custom chains: $e');
    }
  }

  Future<void> _saveCustomChains() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_customChains.map((c) => c.toJson()).toList());
      await prefs.setString(_keyCustomChains, jsonStr);
    } catch (e) {
      debugPrint('Error saving custom chains: $e');
    }
  }

  Future<void> _loadActiveChain() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chainId = prefs.getInt(_keyActiveChainId);
      if (chainId != null) {
        _activeChain = allChains.firstWhere(
          (c) => c.chainId == chainId,
          orElse: () => builtInChains[0],
        );
      }
    } catch (e) {
      debugPrint('Error loading active chain: $e');
    }
  }

  Future<void> _saveActiveChain() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyActiveChainId, _activeChain.chainId);
    } catch (e) {
      debugPrint('Error saving active chain: $e');
    }
  }

  Future<void> _loadCustomTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyCustomTokens);
      if (jsonStr == null) return;
      final Map<String, dynamic> data =
          jsonDecode(jsonStr) as Map<String, dynamic>;
      data.forEach((key, value) {
        final chainId = int.tryParse(key);
        if (chainId == null) return;
        final list = (value as List)
            .map(
              (entry) =>
                  CustomTokenDefinition.fromJson(entry as Map<String, dynamic>),
            )
            .toList();
        _customTokens[chainId] = list;
      });
    } catch (e) {
      debugPrint('Error loading custom tokens: $e');
    }
  }

  Future<void> _saveCustomTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _customTokens.map(
        (key, value) =>
            MapEntry(key.toString(), value.map((t) => t.toJson()).toList()),
      );
      await prefs.setString(_keyCustomTokens, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving custom tokens: $e');
    }
  }

  /// Switch active chain and persist
  void _clearCachedTokens() {
    _walletTokens = [];
  }

  void setActiveChain(EvmChain chain) {
    _activeChain = chain;
    _clearCachedTokens();
    _saveActiveChain();
    notifyListeners();
  }

  void setActiveChainByChainId(int chainId) {
    _activeChain = allChains.firstWhere(
      (c) => c.chainId == chainId,
      orElse: () => builtInChains[0],
    );
    _clearCachedTokens();
    _saveActiveChain();
    notifyListeners();
  }

  /// Add a custom EVM chain
  Future<bool> addCustomChain(EvmChain chain) async {
    // Prevent duplicates
    if (allChains.any((c) => c.chainId == chain.chainId)) {
      return false;
    }
    _customChains.add(chain);
    await _saveCustomChains();
    notifyListeners();
    return true;
  }

  /// Remove a custom chain
  Future<void> removeCustomChain(int chainId) async {
    _customChains.removeWhere((c) => c.chainId == chainId);
    // If the removed chain was active, switch to Ethereum
    if (_activeChain.chainId == chainId) {
      _activeChain = builtInChains[0];
      await _saveActiveChain();
    }
    await _saveCustomChains();
    notifyListeners();
  }

  /// Validate an RPC URL by making a test call
  Future<bool> testRpcUrl(String rpcUrl) async {
    try {
      final response = await http
          .post(
            Uri.parse(rpcUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'eth_chainId',
              'params': [],
              'id': 1,
            }),
          )
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ─── RPC HELPERS ─────────────────────────────────

  String get _rpcUrl => _activeChain.rpcUrl;
  List<String> get _rpcCandidates {
    final candidates = <String>[_rpcUrl];
    final fallbacks = _publicRpcFallbacks[_activeChain.chainId] ?? const [];
    for (final fallback in fallbacks) {
      if (!candidates.contains(fallback)) {
        candidates.add(fallback);
      }
    }
    return candidates;
  }

  Future<dynamic> _rpcCall(String method, List<dynamic> params) async {
    for (final rpcUrl in _rpcCandidates) {
      try {
        final response = await http
            .post(
              Uri.parse(rpcUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'jsonrpc': '2.0',
                'method': method,
                'params': params,
                'id': 1,
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          continue;
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] != null) {
          debugPrint('RPC error ($method @ $rpcUrl): ${data['error']}');
          continue;
        }
        if (rpcUrl != _rpcUrl) {
          debugPrint('RPC fallback in use for $method: $rpcUrl');
        }
        return data['result'];
      } catch (e) {
        debugPrint('RPC call failed ($method @ $rpcUrl): $e');
      }
    }
    return null;
  }

  // ─── GAS ESTIMATION ──────────────────────────────

  Future<double> getGasPrice() async {
    final result = await _rpcCall('eth_gasPrice', []);
    if (result != null) {
      final gasPriceWei = BigInt.parse(
        (result as String).substring(2),
        radix: 16,
      );
      return gasPriceWei.toDouble() / 1e9;
    }
    return 20.0;
  }

  Future<Map<String, double>> estimateGasFee({
    double nativePriceUsd = 0,
  }) async {
    final gasPriceGwei = await getGasPrice();
    const gasLimit = 21000;
    final totalFeeWei = gasPriceGwei * 1e9 * gasLimit;
    final totalFeeNative = totalFeeWei / 1e18;
    final totalFeeUsd = totalFeeNative * nativePriceUsd;
    return {
      'gasGwei': gasPriceGwei,
      'gasLimitUnits': gasLimit.toDouble(),
      'totalFeeEth': totalFeeNative,
      'totalFeeUsd': totalFeeUsd,
    };
  }

  // ─── PRICE DATA ──────────────────────────────────

  // Static parser functions are isolate-safe for compute().
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

  static List<double> _parseOhlcHistory(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      if (data is! List) return [];
      return data
          .whereType<List>()
          .map<double>(
            (p) =>
                (p.length > 4 && p[4] is num) ? (p[4] as num).toDouble() : 0.0,
          )
          .where((v) => v.isFinite && v > 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<double>> getPriceHistory(String coinId, {int days = 7}) async {
    if (coinId.isEmpty) return [];
    final cacheKey = '$coinId:$days';
    final cached = _priceHistoryCache[cacheKey];
    final now = DateTime.now();
    if (cached != null &&
        now.difference(cached.fetchedAt) < _priceHistoryCacheTtl) {
      return cached.values;
    }

    Future<List<double>> fetchMarketChart() async {
      final url =
          '$priceApiBase/coins/$coinId/market_chart?vs_currency=usd&days=$days';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        return compute(BlockchainService._parsePriceHistory, response.body);
      }
      debugPrint(
        'Price history market_chart failed for $coinId ($days d): ${response.statusCode}',
      );
      return [];
    }

    Future<List<double>> fetchOhlcFallback() async {
      final normalizedDays = days <= 1
          ? 1
          : days <= 7
          ? 7
          : days <= 14
          ? 14
          : days <= 30
          ? 30
          : days <= 90
          ? 90
          : days <= 180
          ? 180
          : 365;
      final url =
          '$priceApiBase/coins/$coinId/ohlc?vs_currency=usd&days=$normalizedDays';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        return compute(BlockchainService._parseOhlcHistory, response.body);
      }
      debugPrint(
        'Price history OHLC fallback failed for $coinId ($normalizedDays d): ${response.statusCode}',
      );
      return [];
    }

    try {
      var data = await fetchMarketChart();
      if (data.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 350));
        data = await fetchMarketChart();
      }
      if (data.isEmpty) {
        data = await fetchOhlcFallback();
      }
      if (data.isNotEmpty) {
        _priceHistoryCache[cacheKey] = _CachedChartData(
          values: data,
          fetchedAt: now,
        );
        return data;
      }
    } catch (e) {
      debugPrint('Error fetching price history: $e');
    }
    return [];
  }

  Future<List<double>> getPriceHistoryForTimeframe(
    String coinId,
    String timeframe,
  ) async {
    switch (timeframe) {
      case '5M':
        return _getIntradayPriceHistory(
          coinId,
          duration: const Duration(minutes: 5),
          fallbackTailPoints: 12,
        );
      case '1H':
        return _getIntradayPriceHistory(
          coinId,
          duration: const Duration(hours: 1),
          fallbackTailPoints: 24,
        );
      case '1D':
        return getPriceHistory(coinId, days: 1);
      case '1W':
        return getPriceHistory(coinId, days: 7);
      case '1M':
        return getPriceHistory(coinId, days: 30);
      case '1Y':
        return getPriceHistory(coinId, days: 365);
      default:
        return getPriceHistory(coinId, days: 7);
    }
  }

  Future<List<double>> _getIntradayPriceHistory(
    String coinId, {
    required Duration duration,
    required int fallbackTailPoints,
  }) async {
    if (coinId.isEmpty) return [];
    final now = DateTime.now();
    final from = now.subtract(duration);
    final cacheKey =
        '$coinId:range:${from.millisecondsSinceEpoch ~/ 1000}:${now.millisecondsSinceEpoch ~/ 1000}';
    final cached = _priceHistoryCache[cacheKey];
    if (cached != null &&
        now.difference(cached.fetchedAt) < const Duration(seconds: 30)) {
      return cached.values;
    }

    try {
      final rangeUrl =
          '$priceApiBase/coins/$coinId/market_chart/range?vs_currency=usd&from=${from.millisecondsSinceEpoch ~/ 1000}&to=${now.millisecondsSinceEpoch ~/ 1000}';
      final response = await http
          .get(Uri.parse(rangeUrl))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final rangeData = await compute(
          BlockchainService._parsePriceHistory,
          response.body,
        );
        if (rangeData.length >= 2) {
          _priceHistoryCache[cacheKey] = _CachedChartData(
            values: rangeData,
            fetchedAt: now,
          );
          return rangeData;
        }
      }
    } catch (e) {
      debugPrint('Intraday range fetch failed for $coinId: $e');
    }

    // Fallback: use 1D data and show the tail so 5M/1H tabs always render.
    final dayData = await getPriceHistory(coinId, days: 1);
    if (dayData.isEmpty) return [];
    if (dayData.length <= fallbackTailPoints) return dayData;
    return dayData.sublist(dayData.length - fallbackTailPoints);
  }

  Future<Map<String, double>> getTokenPrices(List<String> tokenIds) async {
    if (tokenIds.isEmpty) return {};
    try {
      final ids = tokenIds.join(',');
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

  Future<TokenMarketData?> getTokenMarketData(String coinId) async {
    if (coinId.isEmpty) return null;
    final now = DateTime.now();
    final cached = _tokenMarketDataCache[coinId];
    if (cached != null &&
        now.difference(cached.fetchedAt) < _tokenMarketDataCacheTtl) {
      return cached.value;
    }

    TokenMarketData? parseTokenMarketFromCoin(Map<String, dynamic> data) {
      final marketData = data['market_data'] as Map<String, dynamic>?;
      if (marketData == null) return null;

      double? toDouble(dynamic value) {
        if (value == null) return null;
        if (value is num) return value.toDouble();
        if (value is String && value.isNotEmpty) return double.tryParse(value);
        return null;
      }

      final marketCapMap = marketData['market_cap'] as Map<String, dynamic>?;
      final currentPriceMap =
          marketData['current_price'] as Map<String, dynamic>?;
      return TokenMarketData(
        priceUsd: toDouble(currentPriceMap?['usd']),
        marketCapUsd: toDouble(marketCapMap?['usd']),
        totalSupply: toDouble(marketData['total_supply']),
        circulatingSupply: toDouble(marketData['circulating_supply']),
        genesisDate: data['genesis_date'] as String?,
      );
    }

    TokenMarketData? parseTokenMarketFromMarkets(List<dynamic> list) {
      if (list.isEmpty || list.first is! Map<String, dynamic>) return null;
      final market = list.first as Map<String, dynamic>;

      double? toDouble(dynamic value) {
        if (value == null) return null;
        if (value is num) return value.toDouble();
        if (value is String && value.isNotEmpty) return double.tryParse(value);
        return null;
      }

      return TokenMarketData(
        priceUsd: toDouble(market['current_price']),
        marketCapUsd: toDouble(market['market_cap']),
        totalSupply: toDouble(market['total_supply']),
        circulatingSupply: toDouble(market['circulating_supply']),
        genesisDate: null,
      );
    }

    try {
      final coinUrl =
          '$priceApiBase/coins/$coinId?localization=false&tickers=false&community_data=false&developer_data=false&sparkline=false';
      for (int attempt = 0; attempt < 2; attempt++) {
        final response = await http
            .get(Uri.parse(coinUrl))
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final parsed = parseTokenMarketFromCoin(data);
          if (parsed != null) {
            _tokenMarketDataCache[coinId] = _CachedMarketData(
              value: parsed,
              fetchedAt: now,
            );
            return parsed;
          }
        } else {
          debugPrint(
            'Token market (coin endpoint) failed for $coinId: ${response.statusCode}',
          );
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final fallbackUrl =
          '$priceApiBase/coins/markets?vs_currency=usd&ids=$coinId&sparkline=false&price_change_percentage=24h';
      final fallbackResponse = await http
          .get(Uri.parse(fallbackUrl))
          .timeout(const Duration(seconds: 12));
      if (fallbackResponse.statusCode == 200) {
        final list = jsonDecode(fallbackResponse.body) as List<dynamic>;
        final parsed = parseTokenMarketFromMarkets(list);
        if (parsed != null) {
          _tokenMarketDataCache[coinId] = _CachedMarketData(
            value: parsed,
            fetchedAt: now,
          );
          return parsed;
        }
      } else {
        debugPrint(
          'Token market (markets fallback) failed for $coinId: ${fallbackResponse.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching token market data: $e');
    }
    return null;
  }

  // ─── BALANCE FETCHING ────────────────────────────

  Future<double> getNativeBalance(String address) async {
    final result = await _rpcCall('eth_getBalance', [address, 'latest']);
    if (result != null) {
      final balanceWei = BigInt.parse(
        (result as String).substring(2),
        radix: 16,
      );
      return balanceWei.toDouble() / 1e18;
    }
    return 0.0;
  }

  Future<double> getEthBalance(String address) => getNativeBalance(address);

  Future<double> getTokenBalance(
    String walletAddress,
    String tokenAddress,
    int decimals,
  ) async {
    final data = '0x70a08231${_padAddress(walletAddress)}';
    final result = await _rpcCall('eth_call', [
      {'to': tokenAddress, 'data': data},
      'latest',
    ]);
    if (result != null) {
      final hexStr = (result as String).substring(2);
      if (hexStr.isEmpty) return 0.0;
      final balance = BigInt.parse(hexStr, radix: 16);
      return balance.toDouble() / pow(10, decimals);
    }
    return 0.0;
  }

  Future<int> getTransactionCount(String address) async {
    final result = await _rpcCall('eth_getTransactionCount', [
      address,
      'latest',
    ]);
    if (result != null) {
      return int.parse((result as String).substring(2), radix: 16);
    }
    return 0;
  }

  Future<String?> sendRawTransaction(String signedTxHex) async {
    final result = await _rpcCall('eth_sendRawTransaction', [signedTxHex]);
    return result as String?;
  }

  // ─── TOKEN LIST ──────────────────────────────────

  Future<List<Token>> fetchWalletTokens(String walletAddress) async {
    final discoveredTokens = await _fetchWalletTokensFromBackend(walletAddress);
    if (discoveredTokens != null && discoveredTokens.isNotEmpty) {
      _walletTokens = discoveredTokens;
      notifyListeners();
      return discoveredTokens;
    }

    final tokens = <Token>[];
    final chain = _activeChain;

    try {
      final nativeBalance = await getNativeBalance(walletAddress);
      final priceIds = <String>{};
      if (chain.coinGeckoId.isNotEmpty) priceIds.add(chain.coinGeckoId);
      final wellKnownTokens = _getWellKnownTokens(chain.chainId);
      for (final tokenDef in wellKnownTokens) {
        final id = tokenDef['coinGeckoId'];
        if (id != null && id.isNotEmpty) {
          priceIds.add(id);
        }
      }
      final prices = await getTokenPrices(priceIds.toList());

      final nativePrice = prices[chain.coinGeckoId] ?? 0;
      final nativeChange = prices['${chain.coinGeckoId}_change'] ?? 0;

      tokens.add(
        Token(
          symbol: chain.symbol,
          name: chain.name,
          balance: nativeBalance,
          valueUsd: nativeBalance * nativePrice,
          priceUsd: nativePrice,
          changePercent24h: nativeChange,
          imageUrl: _getIconUrl(chain.symbol),
          coinGeckoId: chain.coinGeckoId.isNotEmpty ? chain.coinGeckoId : null,
        ),
      );

      final tokenFutures = wellKnownTokens.map((tokenDef) async {
        try {
          final balance = await getTokenBalance(
            walletAddress,
            tokenDef['address']!,
            int.parse(tokenDef['decimals']!),
          );
          if (balance >= 0) {
            final price = prices[tokenDef['coinGeckoId']] ?? 0.0;
            final change = prices['${tokenDef['coinGeckoId']}_change'] ?? 0.0;
            return Token(
              symbol: tokenDef['symbol']!,
              name: tokenDef['name']!,
              contractAddress: tokenDef['address'],
              balance: balance,
              valueUsd: balance * price,
              priceUsd: price,
              changePercent24h: change,
              decimals: int.parse(tokenDef['decimals']!),
              imageUrl: _getIconUrl(tokenDef['symbol']!),
              coinGeckoId: tokenDef['coinGeckoId'],
            );
          }
        } catch (e) {
          debugPrint('Error fetching ${tokenDef['symbol']} balance: $e');
        }
        return null;
      });

      final fetchedTokens = await Future.wait(tokenFutures);
      for (final t in fetchedTokens) {
        if (t != null) tokens.add(t);
      }
    } catch (e) {
      debugPrint('Error fetching wallet tokens: $e');
      tokens.add(
        Token(
          symbol: chain.symbol,
          name: chain.name,
          balance: 0,
          valueUsd: 0,
          changePercent24h: 0,
          coinGeckoId: chain.coinGeckoId.isNotEmpty ? chain.coinGeckoId : null,
        ),
      );
    }

    _walletTokens = tokens;
    notifyListeners();
    return tokens;
  }

  Future<List<Token>?> _fetchWalletTokensFromBackend(
    String walletAddress,
  ) async {
    final now = DateTime.now();
    final errors = <String>[];

    for (final base in _backendDiscoveryBases) {
      final cooldownUntil = _backendDiscoveryBackoffUntil[base];
      if (cooldownUntil != null && now.isBefore(cooldownUntil)) {
        continue;
      }

      final url = Uri.parse(
        '$base/${_activeChain.chainId}/wallet-tokens/$walletAddress',
      );
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final response = await http
              .get(url)
              .timeout(_backendDiscoveryTimeout);
          if (response.statusCode != 200) {
            errors.add('HTTP ${response.statusCode} from $base');
            break;
          }

          final parsedTokens = _parseBackendDiscoveredTokens(response.body);
          if (parsedTokens == null || parsedTokens.isEmpty) {
            return null;
          }
          return parsedTokens;
        } catch (e) {
          final errorText = e.toString();
          errors.add('$base: $errorText');
          if (_isTlsHandshakeError(errorText)) {
            _backendDiscoveryBackoffUntil[base] = DateTime.now().add(
              _backendDiscoveryBaseCooldown,
            );
            break;
          }
          if (attempt == 0) {
            await Future.delayed(const Duration(milliseconds: 250));
          }
        }
      }
    }

    if (errors.isNotEmpty) {
      debugPrint(
        'Wallet token discovery unavailable, using RPC fallback: '
        '${errors.first}',
      );
      if (errors.length > 1) {
        debugPrint('Wallet token discovery attempts: ${errors.join(' | ')}');
      }
    }
    return null;
  }

  List<Token>? _parseBackendDiscoveredTokens(String responseBody) {
    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final tokenList = data['tokens'] as List<dynamic>? ?? const [];
    if (tokenList.isEmpty) {
      return null;
    }

    final parsedTokens = tokenList
        .map<Token?>((entry) {
          if (entry is! Map<String, dynamic>) return null;
          final symbol = (entry['symbol'] as String?)?.trim() ?? '';
          final name = (entry['name'] as String?)?.trim() ?? '';
          if (symbol.isEmpty || name.isEmpty) return null;

          final contractAddress = entry['contractAddress'] as String?;
          final coinGeckoId = entry['coinGeckoId'] as String?;
          final imageUrl = entry['imageUrl'] as String?;

          return Token(
            symbol: symbol,
            name: name,
            contractAddress:
                (contractAddress == null || contractAddress.isEmpty)
                ? null
                : contractAddress,
            balance: _toDouble(entry['balance']),
            valueUsd: _toDouble(entry['valueUsd']),
            priceUsd: _toDouble(entry['priceUsd']),
            changePercent24h: _toDouble(entry['changePercent24h']),
            decimals: (entry['decimals'] is num)
                ? (entry['decimals'] as num).toInt()
                : 18,
            imageUrl: (imageUrl == null || imageUrl.isEmpty) ? null : imageUrl,
            coinGeckoId: (coinGeckoId == null || coinGeckoId.isEmpty)
                ? null
                : coinGeckoId,
          );
        })
        .whereType<Token>()
        .toList();

    return parsedTokens.isEmpty ? null : parsedTokens;
  }

  bool _isTlsHandshakeError(String errorText) {
    final lower = errorText.toLowerCase();
    return lower.contains('handshakeexception') ||
        lower.contains('tlsv1_alert_unrecognized_name') ||
        lower.contains('certificate');
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  List<Map<String, String>> _getWellKnownTokens(int chainId) {
    List<Map<String, String>> tokens;
    switch (chainId) {
      case 1:
        tokens = [
          {
            'symbol': 'USDC',
            'name': 'USD Coin',
            'address': '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
            'decimals': '6',
            'coinGeckoId': 'usd-coin',
          },
          {
            'symbol': 'USDT',
            'name': 'Tether',
            'address': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
            'decimals': '6',
            'coinGeckoId': 'tether',
          },
        ];
        break;
      case 56:
        tokens = [
          {
            'symbol': 'USDC',
            'name': 'USD Coin',
            'address': '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d',
            'decimals': '18',
            'coinGeckoId': 'usd-coin',
          },
          {
            'symbol': 'USDT',
            'name': 'Tether',
            'address': '0x55d398326f99059fF775485246999027B3197955',
            'decimals': '18',
            'coinGeckoId': 'tether',
          },
        ];
        break;
      case 137:
        tokens = [
          {
            'symbol': 'USDC',
            'name': 'USD Coin',
            'address': '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
            'decimals': '6',
            'coinGeckoId': 'usd-coin',
          },
          {
            'symbol': 'USDT',
            'name': 'Tether',
            'address': '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
            'decimals': '6',
            'coinGeckoId': 'tether',
          },
        ];
        break;
      case 42161:
        tokens = [
          {
            'symbol': 'USDC',
            'name': 'USD Coin',
            'address': '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
            'decimals': '6',
            'coinGeckoId': 'usd-coin',
          },
          {
            'symbol': 'USDT',
            'name': 'Tether',
            'address': '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9',
            'decimals': '6',
            'coinGeckoId': 'tether',
          },
        ];
      default:
        tokens = [];
    }
    final custom = _customTokens[chainId] ?? [];
    tokens.addAll(
      custom.map(
        (t) => {
          'symbol': t.symbol,
          'name': t.name,
          'address': t.address,
          'decimals': t.decimals.toString(),
          'coinGeckoId': t.coinGeckoId ?? '',
        },
      ),
    );
    return tokens;
  }

  Future<bool> addCustomToken({
    required int chainId,
    required CustomTokenDefinition token,
  }) async {
    final list = _customTokens.putIfAbsent(chainId, () => []);
    if (list.any(
      (t) => t.address.toLowerCase() == token.address.toLowerCase(),
    )) {
      return false;
    }
    list.add(token);
    await _saveCustomTokens();
    notifyListeners();
    return true;
  }

  Future<void> removeCustomToken(int chainId, String address) async {
    final list = _customTokens[chainId];
    if (list == null) return;
    list.removeWhere((t) => t.address.toLowerCase() == address.toLowerCase());
    await _saveCustomTokens();
    notifyListeners();
  }

  String? _getIconUrl(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'ETH':
        return 'https://cryptologos.cc/logos/ethereum-eth-logo.png';
      case 'BNB':
        return 'https://cryptologos.cc/logos/bnb-bnb-logo.png';
      case 'MATIC':
        return 'https://cryptologos.cc/logos/polygon-matic-logo.png';
      case 'AVAX':
        return 'https://cryptologos.cc/logos/avalanche-avax-logo.png';
      case 'FTM':
        return 'https://cryptologos.cc/logos/fantom-ftm-logo.png';
      case 'USDC':
        return 'https://cryptologos.cc/logos/usd-coin-usdc-logo.png';
      case 'USDT':
        return 'https://cryptologos.cc/logos/tether-usdt-logo.png';
      default:
        return null;
    }
  }

  String _padAddress(String address) {
    final addr = address.startsWith('0x') ? address.substring(2) : address;
    return addr.padLeft(64, '0');
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

class TokenMarketData {
  final double? priceUsd;
  final double? marketCapUsd;
  final double? totalSupply;
  final double? circulatingSupply;
  final String? genesisDate;

  const TokenMarketData({
    this.priceUsd,
    this.marketCapUsd,
    this.totalSupply,
    this.circulatingSupply,
    this.genesisDate,
  });
}

class CustomTokenDefinition {
  final String symbol;
  final String name;
  final String address;
  final int decimals;
  final String? coinGeckoId;

  const CustomTokenDefinition({
    required this.symbol,
    required this.name,
    required this.address,
    required this.decimals,
    this.coinGeckoId,
  });

  factory CustomTokenDefinition.fromJson(Map<String, dynamic> json) {
    return CustomTokenDefinition(
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      decimals: json['decimals'] as int,
      coinGeckoId: json['coinGeckoId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name': name,
    'address': address,
    'decimals': decimals,
    'coinGeckoId': coinGeckoId,
  };
}
