import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/token.dart';
import '../models/chain.dart';
import 'rpc_service.dart';
import 'token_price_service.dart';

/// Blockchain Service — Shared ChangeNotifier Provider
/// Manages active chain, custom chains, and all blockchain interactions.
/// Now delegates core RPC and Price logic to specialized services.
class BlockchainService extends ChangeNotifier {
  // Dependencies
  RpcService? _rpcService;
  TokenPriceService? _priceService;

  // Configuration Constants
  static const String _backendRpcBase = 'https://fomowl-backend.onrender.com/api/blockchain';
  static const List<String> _backendDiscoveryBases = [
    'https://fomowl-backend.onrender.com/api/blockchain',
  ];
  static const Duration _backendDiscoveryTimeout = Duration(seconds: 8);

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

  // State
  List<EvmChain> _customChains = [];
  EvmChain _activeChain = builtInChains[0];
  final Map<int, List<CustomTokenDefinition>> _customTokens = {};
  List<Token> _walletTokens = [];
  final Map<String, DateTime> _backendDiscoveryBackoffUntil = {};

  // Getters
  List<EvmChain> get allChains => [...builtInChains, ..._customChains];
  List<EvmChain> get customChains => _customChains;
  EvmChain get activeChain => _activeChain;
  List<CustomTokenDefinition> get customTokensForActiveChain =>
      List.unmodifiable(_customTokens[_activeChain.chainId] ?? []);

  List<Token> get tokens {
    if (_walletTokens.isNotEmpty) return _walletTokens;
    return [
      Token(
        symbol: activeChain.symbol,
        name: activeChain.name,
        balance: 0.0,
        valueUsd: 0.0,
        changePercent24h: 0.0,
        imageUrl: _getIconUrl(activeChain.symbol),
        coinGeckoId: activeChain.coinGeckoId.isNotEmpty ? activeChain.coinGeckoId : null,
      ),
    ];
  }

  /// Update dependencies from ProxyProvider
  void updateDependencies(RpcService rpc, TokenPriceService price) {
    _rpcService = rpc;
    _priceService = price;
  }

  /// Initialize — load persisted chains and active chain from storage
  Future<void> init() async {
    await _loadCustomChains();
    await _loadActiveChain();
    await _loadCustomTokens();
  }

  void refresh() {
    _walletTokens = [];
    notifyListeners();
  }

  // ─── CHAIN MANAGEMENT ───────────────────────────

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

  void setActiveChain(EvmChain chain) {
    _activeChain = chain;
    refresh();
    _saveActiveChain();
  }

  void setActiveChainByChainId(int chainId) {
    _activeChain = allChains.firstWhere(
      (c) => c.chainId == chainId,
      orElse: () => builtInChains[0],
    );
    refresh();
    _saveActiveChain();
  }

  Future<bool> addCustomChain(EvmChain chain) async {
    if (allChains.any((c) => c.chainId == chain.chainId)) return false;
    _customChains.add(chain);
    await _saveCustomChains();
    notifyListeners();
    return true;
  }

  Future<void> removeCustomChain(int chainId) async {
    _customChains.removeWhere((c) => c.chainId == chainId);
    if (_activeChain.chainId == chainId) {
      _activeChain = builtInChains[0];
      await _saveActiveChain();
    }
    await _saveCustomChains();
    notifyListeners();
  }

  // ─── RPC DELEGATION ─────────────────────────────

  Future<dynamic> _rpcCall(String method, List<dynamic> params) async {
    if (_rpcService == null) return null;
    return _rpcService!.rpcCall(
      chainId: _activeChain.chainId,
      primaryRpcUrl: _activeChain.rpcUrl,
      method: method,
      params: params,
    );
  }

  Future<bool> testRpcUrl(String rpcUrl) async {
    if (_rpcService == null) return false;
    return _rpcService!.testRpcUrl(rpcUrl);
  }

  // ─── GAS ESTIMATION ──────────────────────────────

  Future<double> getGasPrice() async {
    final result = await _rpcCall('eth_gasPrice', []);
    if (result != null) {
      final gasPriceWei = BigInt.parse((result as String).substring(2), radix: 16);
      return gasPriceWei.toDouble() / 1e9;
    }
    return 20.0;
  }

  Future<Map<String, double>> estimateGasFee({double nativePriceUsd = 0}) async {
    final gasPriceGwei = await getGasPrice();
    const gasLimit = 21000;
    final totalFeeWei = gasPriceGwei * 1e9 * gasLimit;
    final totalFeeNative = totalFeeWei / 1e18;
    return {
      'gasGwei': gasPriceGwei,
      'gasLimitUnits': gasLimit.toDouble(),
      'totalFeeEth': totalFeeNative,
      'totalFeeUsd': totalFeeNative * nativePriceUsd,
    };
  }

  // ─── PRICE DATA DELEGATION ───────────────────────

  Future<List<double>> getPriceHistory(String coinId, {int days = 7}) async {
    if (_priceService == null) return [];
    return _priceService!.getPriceHistory(coinId, days: days);
  }

  Future<List<double>> getPriceHistoryForTimeframe(String coinId, String timeframe) async {
    if (_priceService == null) return [];
    if (timeframe == '5M') {
      return _priceService!.getPriceHistoryRange(
        coinId,
        window: const Duration(minutes: 5),
      );
    }
    if (timeframe == '1H') {
      return _priceService!.getPriceHistoryRange(
        coinId,
        window: const Duration(hours: 1),
      );
    }

    int days = 7;
    switch (timeframe) {
      case '1D': days = 1; break;
      case '1W': days = 7; break;
      case '1M': days = 30; break;
      case '1Y': days = 365; break;
    }
    return getPriceHistory(coinId, days: days);
  }

  Future<Map<String, double>> getTokenPrices(List<String> tokenIds) async {
    if (_priceService == null) return {};
    return _priceService!.getTokenPrices(tokenIds);
  }

  Future<TokenMarketData?> getTokenMarketData(String coinId) async {
    if (_priceService == null) return null;
    final data = await _priceService!.getTokenMarketData(coinId);
    if (data == null) return null;
    return TokenMarketData(
      priceUsd: data.priceUsd,
      marketCapUsd: data.marketCapUsd,
      totalSupply: data.totalSupply,
      circulatingSupply: data.circulatingSupply,
      genesisDate: data.genesisDate,
    );
  }

  // ─── BALANCE FETCHING ────────────────────────────

  Future<double> getNativeBalance(String address) async {
    final result = await _rpcCall('eth_getBalance', [address, 'latest']);
    if (result != null) {
      final balanceWei = BigInt.parse((result as String).substring(2), radix: 16);
      return balanceWei.toDouble() / 1e18;
    }
    return 0.0;
  }

  Future<double> getEthBalance(String address) => getNativeBalance(address);

  Future<double> getTokenBalance(String walletAddress, String tokenAddress, int decimals) async {
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

  Future<CustomTokenDefinition?> detectTokenByContract(String contractAddress) async {
    final normalized = contractAddress.trim();
    final addressRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');
    if (!addressRegex.hasMatch(normalized)) return null;

    final symbol = await _ethCallString(normalized, '0x95d89b41');
    final name = await _ethCallString(normalized, '0x06fdde03');
    final decimalsRaw = await _ethCallUint(normalized, '0x313ce567');
    final decimals = decimalsRaw?.toInt();

    if (symbol == null || symbol.isEmpty || decimals == null) return null;

    return CustomTokenDefinition(
      symbol: symbol.toUpperCase(),
      name: (name == null || name.isEmpty) ? symbol.toUpperCase() : name,
      address: normalized,
      decimals: decimals,
      coinGeckoId: null,
    );
  }

  Future<String?> _ethCallString(String contractAddress, String methodId) async {
    final result = await _rpcCall('eth_call', [
      {'to': contractAddress, 'data': methodId},
      'latest',
    ]);
    if (result is! String || !result.startsWith('0x') || result.length <= 2) return null;
    return _decodeStringResult(result);
  }

  Future<BigInt?> _ethCallUint(String contractAddress, String methodId) async {
    final result = await _rpcCall('eth_call', [
      {'to': contractAddress, 'data': methodId},
      'latest',
    ]);
    if (result is! String || !result.startsWith('0x') || result.length <= 2) return null;
    final hex = result.substring(2);
    if (hex.isEmpty) return null;
    try {
      return BigInt.parse(hex, radix: 16);
    } catch (_) {
      return null;
    }
  }

  String? _decodeStringResult(String rawHexResult) {
    final hex = rawHexResult.startsWith('0x') ? rawHexResult.substring(2) : rawHexResult;
    if (hex.isEmpty) return null;

    if (hex.length >= 192) {
      try {
        final offset = int.parse(hex.substring(0, 64), radix: 16);
        final lengthPos = offset * 2;
        if (lengthPos + 64 <= hex.length) {
          final strLen = int.parse(hex.substring(lengthPos, lengthPos + 64), radix: 16);
          final dataStart = lengthPos + 64;
          final dataEnd = dataStart + (strLen * 2);
          if (strLen > 0 && dataEnd <= hex.length) {
            return _hexToUtf8(hex.substring(dataStart, dataEnd));
          }
        }
      } catch (_) {}
    }

    final bytes32 = hex.substring(0, hex.length >= 64 ? 64 : hex.length);
    return _hexToUtf8(bytes32);
  }

  String? _hexToUtf8(String hex) {
    if (hex.isEmpty) return null;
    final bytes = <int>[];
    for (var i = 0; i + 1 < hex.length; i += 2) {
      final byte = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (byte == null || byte == 0) continue;
      bytes.add(byte);
    }
    if (bytes.isEmpty) return null;
    try {
      return utf8.decode(bytes).trim();
    } catch (_) {
      return String.fromCharCodes(bytes).trim();
    }
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
    try {
      final nativeBalance = await getNativeBalance(walletAddress);
      final priceIds = <String>[];
      if (_activeChain.coinGeckoId.isNotEmpty) priceIds.add(_activeChain.coinGeckoId);
      
      final wellKnown = _getWellKnownTokens(_activeChain.chainId);
      for (var t in wellKnown) {
        if (t['coinGeckoId'] != null && t['coinGeckoId']!.isNotEmpty) {
          priceIds.add(t['coinGeckoId']!);
        }
      }

      final prices = await getTokenPrices(priceIds);
      final nativePrice = prices[_activeChain.coinGeckoId] ?? 0;

      tokens.add(Token(
        symbol: _activeChain.symbol,
        name: _activeChain.name,
        balance: nativeBalance,
        valueUsd: nativeBalance * nativePrice,
        priceUsd: nativePrice,
        changePercent24h: prices['${_activeChain.coinGeckoId}_change'] ?? 0,
        imageUrl: _getIconUrl(_activeChain.symbol),
        coinGeckoId: _activeChain.coinGeckoId,
      ));

      for (var tDef in wellKnown) {
        final bal = await getTokenBalance(walletAddress, tDef['address']!, int.parse(tDef['decimals']!));
        if (bal > 0) {
          final p = prices[tDef['coinGeckoId']] ?? 0;
          tokens.add(Token(
            symbol: tDef['symbol']!,
            name: tDef['name']!,
            contractAddress: tDef['address'],
            balance: bal,
            valueUsd: bal * p,
            priceUsd: p,
            changePercent24h: prices['${tDef['coinGeckoId']}_change'] ?? 0,
            decimals: int.parse(tDef['decimals']!),
            imageUrl: _getIconUrl(tDef['symbol']!),
            coinGeckoId: tDef['coinGeckoId'],
          ));
        }
      }
    } catch (e) {
      debugPrint('Error fetching tokens: $e');
    }

    _walletTokens = tokens;
    notifyListeners();
    return tokens;
  }

  Future<List<Token>> searchTokensFromBackend(String query, {int limit = 30}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final safeLimit = limit.clamp(1, 100);
    final parsed = <Token>[];

    for (final base in _backendDiscoveryBases) {
      final url = Uri.parse('$base/${_activeChain.chainId}/token-search').replace(
        queryParameters: {'q': trimmed, 'limit': '$safeLimit'},
      );

      try {
        final response = await http.get(url).timeout(_backendDiscoveryTimeout);
        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['tokens'] as List<dynamic>? ?? const [];
        for (final entry in list) {
          if (entry is! Map<String, dynamic>) continue;
          final symbol = (entry['symbol'] as String?)?.trim() ?? '';
          final name = (entry['name'] as String?)?.trim() ?? '';
          final contractAddress = (entry['contractAddress'] as String?)?.trim();
          if (symbol.isEmpty || name.isEmpty || contractAddress == null) continue;

          parsed.add(Token(
            symbol: symbol,
            name: name,
            contractAddress: contractAddress,
            balance: 0,
            valueUsd: 0,
            priceUsd: _toDouble(entry['priceUsd']),
            changePercent24h: _toDouble(entry['changePercent24h']),
            decimals: 18,
            coinGeckoId: (entry['id'] as String?)?.trim(),
          ));
        }
        if (parsed.isNotEmpty) return parsed;
      } catch (_) { continue; }
    }
    return parsed;
  }

  // ─── BACKEND DISCOVERY (Kept here for simplicity) ──

  Future<List<Token>?> _fetchWalletTokensFromBackend(String walletAddress) async {
    final now = DateTime.now();
    for (final base in _backendDiscoveryBases) {
      final backoff = _backendDiscoveryBackoffUntil[base];
      if (backoff != null && now.isBefore(backoff)) continue;

      final url = Uri.parse('$base/${_activeChain.chainId}/wallet-tokens/$walletAddress');
      try {
        final response = await http.get(url).timeout(_backendDiscoveryTimeout);
        if (response.statusCode == 200) {
          return _parseBackendDiscoveredTokens(response.body);
        }
      } catch (e) {
        debugPrint('Backend discovery failed for $base: $e');
      }
    }
    return null;
  }

  List<Token>? _parseBackendDiscoveredTokens(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final list = data['tokens'] as List<dynamic>? ?? [];
      return list.map((e) => Token(
        symbol: e['symbol'] ?? '',
        name: e['name'] ?? '',
        contractAddress: e['contractAddress'],
        balance: _toDouble(e['balance']),
        valueUsd: _toDouble(e['valueUsd']),
        priceUsd: _toDouble(e['priceUsd']),
        changePercent24h: _toDouble(e['changePercent24h']),
        decimals: e['decimals'] ?? 18,
        imageUrl: e['imageUrl'],
        coinGeckoId: e['coinGeckoId'],
      )).toList();
    } catch (_) { return null; }
  }

  // ─── HELPERS ─────────────────────────────────────

  Future<void> _loadCustomTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyCustomTokens);
      if (jsonStr == null) return;
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      data.forEach((k, v) {
        final chainId = int.tryParse(k);
        if (chainId != null) {
          _customTokens[chainId] = (v as List).map((e) => CustomTokenDefinition.fromJson(e)).toList();
        }
      });
    } catch (e) { debugPrint('Error loading custom tokens: $e'); }
  }

  Future<void> _saveCustomTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _customTokens.map((k, v) => MapEntry(k.toString(), v.map((t) => t.toJson()).toList()));
      await prefs.setString(_keyCustomTokens, jsonEncode(data));
    } catch (e) { debugPrint('Error saving custom tokens: $e'); }
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

  List<Map<String, String>> _getWellKnownTokens(int chainId) {
    final List<Map<String, String>> tokens = [];
    if (chainId == 1) {
      tokens.addAll([
        {'symbol': 'USDC', 'name': 'USD Coin', 'address': '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', 'decimals': '6', 'coinGeckoId': 'usd-coin'},
        {'symbol': 'USDT', 'name': 'Tether', 'address': '0xdAC17F958D2ee523a2206206994597C13D831ec7', 'decimals': '6', 'coinGeckoId': 'tether'},
      ]);
    }
    final custom = _customTokens[chainId] ?? [];
    tokens.addAll(custom.map((t) => {'symbol': t.symbol, 'name': t.name, 'address': t.address, 'decimals': t.decimals.toString(), 'coinGeckoId': t.coinGeckoId ?? ''}));
    return tokens;
  }

  String? _getIconUrl(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'ETH': return 'https://cryptologos.cc/logos/ethereum-eth-logo.png';
      case 'BNB': return 'https://cryptologos.cc/logos/bnb-bnb-logo.png';
      case 'MATIC': return 'https://cryptologos.cc/logos/polygon-matic-logo.png';
      case 'USDC': return 'https://cryptologos.cc/logos/usd-coin-usdc-logo.png';
      case 'USDT': return 'https://cryptologos.cc/logos/tether-usdt-logo.png';
      default: return null;
    }
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  String _padAddress(String addr) => addr.startsWith('0x') ? addr.substring(2).padLeft(64, '0') : addr.padLeft(64, '0');

  // Necessary for backward compatibility with some screens
  Future<String?> sendRawTransaction(String signedTxHex) async {
    final res = await _rpcCall('eth_sendRawTransaction', [signedTxHex]);
    return res as String?;
  }
}

// Local models for TokenPriceData to keep compatibility
class TokenMarketData {
  final double? priceUsd;
  final double? marketCapUsd;
  final double? totalSupply;
  final double? circulatingSupply;
  final String? genesisDate;
  const TokenMarketData({this.priceUsd, this.marketCapUsd, this.totalSupply, this.circulatingSupply, this.genesisDate});
}
