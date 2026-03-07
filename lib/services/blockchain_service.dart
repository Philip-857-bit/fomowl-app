import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_environment.dart';
import '../models/token.dart';
import '../models/chain.dart';
import '../models/token_market_data.dart';
import 'blockchain/blockchain_catalog.dart';
import 'rpc_service.dart';
import 'token_price_service.dart';
import 'storage_service.dart';
import 'wallet_backend_auth_service.dart';

/// Blockchain Service — Shared ChangeNotifier Provider
/// Manages active chain, custom chains, and all blockchain interactions.
/// Now delegates core RPC and Price logic to specialized services.
class BlockchainService extends ChangeNotifier {
  // Dependencies
  RpcService? _rpcService;
  TokenPriceService? _priceService;

  // Configuration Constants
  static const Duration _backendDiscoveryTimeout = Duration(seconds: 8);
  final StorageService _storageService = StorageService();
  final WalletBackendAuthService _walletBackendAuthService =
      WalletBackendAuthService();

  static List<EvmChain> get builtInChains => BlockchainCatalog.builtInChains;

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
  bool _initialized = false;

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
        imageUrl:
            activeChain.logoUrl ??
            BlockchainCatalog.iconUrlForSymbol(activeChain.symbol),
        coinGeckoId: activeChain.coinGeckoId,
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
    if (_initialized) return;
    try {
      await _loadCustomChains();
      await _loadActiveChain();
      await _loadCustomTokens();
      await _hydrateNetworkSettingsFromBackend();
      _initialized = true;
    } catch (e) {
      debugPrint('BlockchainService initialization failed: $e');
      _initialized = false;
    }
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
            .map(_normalizeCustomChain)
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
    unawaited(_syncNetworkSettingsToBackend());
  }

  void setActiveChainByChainId(int chainId) {
    _activeChain = allChains.firstWhere(
      (c) => c.chainId == chainId,
      orElse: () => builtInChains[0],
    );
    refresh();
    _saveActiveChain();
    unawaited(_syncNetworkSettingsToBackend());
  }

  Future<bool> addCustomChain(EvmChain chain) async {
    if (allChains.any((c) => c.chainId == chain.chainId)) return false;
    _customChains.add(_normalizeCustomChain(chain));
    await _saveCustomChains();
    unawaited(_syncNetworkSettingsToBackend());
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
    unawaited(_syncNetworkSettingsToBackend());
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
      final gasPriceWei = BigInt.parse(
        (result as String).substring(2),
        radix: 16,
      );
      return _scaledBigIntToDouble(gasPriceWei, 9);
    }
    return 20.0;
  }

  Future<Map<String, dynamic>> estimateGasFee({
    double nativePriceUsd = 0,
  }) async {
    final gasPriceGwei = await getGasPrice();
    const gasLimit = 21000;
    final gasPriceWei = BigInt.parse(
      (gasPriceGwei * 1000000000).round().toString(),
    );
    final totalFeeWei = gasPriceWei * BigInt.from(gasLimit);
    final totalFeeNative = _scaledBigIntToDouble(totalFeeWei, 18);
    return {
      'gasGwei': gasPriceGwei,
      'gasLimitUnits': gasLimit.toDouble(),
      'totalFeeEth': totalFeeNative,
      'totalFeeUsd': totalFeeNative * nativePriceUsd,
      'totalFeeWei': totalFeeWei,
    };
  }

  // ─── PRICE DATA DELEGATION ───────────────────────

  Future<List<double>> getPriceHistory(String coinId, {int days = 7}) async {
    if (_priceService == null) return [];
    return _priceService!.getPriceHistory(coinId, days: days);
  }

  Future<List<double>> getPriceHistoryForTimeframe(
    String coinId,
    String timeframe,
  ) async {
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
      case '1D':
        days = 1;
        break;
      case '1W':
        days = 7;
        break;
      case '1M':
        days = 30;
        break;
      case '1Y':
        days = 365;
        break;
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
    final balanceWei = await getNativeBalanceBaseUnits(address);
    return _scaledBigIntToDouble(balanceWei, 18);
  }

  Future<BigInt> getNativeBalanceBaseUnits(String address) async {
    final result = await _rpcCall('eth_getBalance', [address, 'latest']);
    if (result != null) {
      return BigInt.parse((result as String).substring(2), radix: 16);
    }
    return BigInt.zero;
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
      return _scaledBigIntToDouble(balance, decimals);
    }
    return 0.0;
  }

  Future<CustomTokenDefinition?> detectTokenByContract(
    String contractAddress,
  ) async {
    final normalized = contractAddress.trim();
    final addressRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');
    if (!addressRegex.hasMatch(normalized)) return null;

    final symbol = await _ethCallString(normalized, '0x95d89b41');
    final name = await _ethCallString(normalized, '0x06fdde03');
    final decimalsRaw = await _ethCallUint(normalized, '0x313ce567');

    int? decimals;
    if (decimalsRaw != null) {
      if (decimalsRaw >= BigInt.zero && decimalsRaw <= BigInt.from(255)) {
        decimals = decimalsRaw.toInt();
      } else {
        debugPrint('Invalid decimals value: $decimalsRaw');
        return null;
      }
    }

    if (symbol == null || symbol.isEmpty || decimals == null) return null;

    return CustomTokenDefinition(
      symbol: symbol.toUpperCase(),
      name: (name == null || name.isEmpty) ? symbol.toUpperCase() : name,
      address: normalized,
      decimals: decimals,
      coinGeckoId: null,
      imageUrl: null,
    );
  }

  Future<String?> _ethCallString(
    String contractAddress,
    String methodId,
  ) async {
    final result = await _rpcCall('eth_call', [
      {'to': contractAddress, 'data': methodId},
      'latest',
    ]);
    if (result is! String || !result.startsWith('0x') || result.length <= 2) {
      return null;
    }
    return _decodeStringResult(result);
  }

  Future<BigInt?> _ethCallUint(String contractAddress, String methodId) async {
    final result = await _rpcCall('eth_call', [
      {'to': contractAddress, 'data': methodId},
      'latest',
    ]);
    if (result is! String || !result.startsWith('0x') || result.length <= 2) {
      return null;
    }
    final hex = result.substring(2);
    if (hex.isEmpty) return null;
    try {
      return BigInt.parse(hex, radix: 16);
    } catch (_) {
      return null;
    }
  }

  String? _decodeStringResult(String rawHexResult) {
    final hex = rawHexResult.startsWith('0x')
        ? rawHexResult.substring(2)
        : rawHexResult;
    if (hex.isEmpty) return null;

    if (hex.length >= 192) {
      try {
        final offset = int.parse(hex.substring(0, 64), radix: 16);
        final lengthPos = offset * 2;
        if (lengthPos + 64 <= hex.length) {
          final strLen = int.parse(
            hex.substring(lengthPos, lengthPos + 64),
            radix: 16,
          );
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
      // --- Enrich discovered tokens with CoinGecko prices when backend omits them ---
      final enriched = await _enrichTokensWithPrices(discoveredTokens);

      // Merge custom tokens that weren't discovered by the backend.
      final customTokens = _customTokens[_activeChain.chainId] ?? const [];
      final merged = List<Token>.from(enriched);
      for (final custom in customTokens) {
        final alreadyInList = merged.any(
          (t) =>
              (t.contractAddress ?? '').toLowerCase() ==
              custom.address.toLowerCase(),
        );
        if (alreadyInList) continue;
        final bal = await getTokenBalance(
          walletAddress,
          custom.address,
          custom.decimals,
        );
        final priceIds = <String>[];
        if (custom.coinGeckoId != null && custom.coinGeckoId!.isNotEmpty) {
          priceIds.add(custom.coinGeckoId!);
        }
        final prices = priceIds.isNotEmpty
            ? await getTokenPrices(priceIds)
            : <String, double>{};
        final price =
            (custom.coinGeckoId == null || custom.coinGeckoId!.isEmpty)
            ? 0.0
            : (prices[custom.coinGeckoId] ?? 0.0);
        final change =
            (custom.coinGeckoId == null || custom.coinGeckoId!.isEmpty)
            ? 0.0
            : (prices['${custom.coinGeckoId}_change'] ?? 0.0);
        merged.add(
          Token(
            symbol: custom.symbol,
            name: custom.name,
            contractAddress: custom.address,
            balance: bal,
            valueUsd: bal * price,
            priceUsd: price,
            changePercent24h: change,
            decimals: custom.decimals,
            imageUrl: custom.imageUrl,
            coinGeckoId: custom.coinGeckoId,
          ),
        );
      }
      _walletTokens = merged;
      notifyListeners();
      return merged;
    }

    final tokens = <Token>[];
    try {
      final nativeBalance = await getNativeBalance(walletAddress);
      final priceIds = <String>[];
      final activeCoinGeckoId = _activeChain.coinGeckoId;
      if (activeCoinGeckoId != null && activeCoinGeckoId.isNotEmpty) {
        priceIds.add(activeCoinGeckoId);
      }

      final builtInTokens = _getWellKnownTokens(_activeChain.chainId);
      final customTokens = _customTokens[_activeChain.chainId] ?? const [];
      for (var t in builtInTokens) {
        if (t['coinGeckoId'] != null && t['coinGeckoId']!.isNotEmpty) {
          priceIds.add(t['coinGeckoId']!);
        }
      }
      for (final t in customTokens) {
        if (t.coinGeckoId != null && t.coinGeckoId!.isNotEmpty) {
          priceIds.add(t.coinGeckoId!);
        }
      }

      final prices = await getTokenPrices(priceIds);
      final nativePrice =
          (activeCoinGeckoId == null || activeCoinGeckoId.isEmpty)
          ? 0.0
          : (prices[activeCoinGeckoId] ?? 0.0);

      tokens.add(
        Token(
          symbol: _activeChain.symbol,
          name: _activeChain.name,
          balance: nativeBalance,
          valueUsd: nativeBalance * nativePrice,
          priceUsd: nativePrice,
          changePercent24h:
              (activeCoinGeckoId == null || activeCoinGeckoId.isEmpty)
              ? 0.0
              : (prices['${activeCoinGeckoId}_change'] ?? 0.0),
          imageUrl:
              _activeChain.logoUrl ??
              BlockchainCatalog.iconUrlForSymbol(_activeChain.symbol),
          coinGeckoId: activeCoinGeckoId,
        ),
      );

      for (var tDef in builtInTokens) {
        final parsedDecimals = int.tryParse(tDef['decimals'] ?? '') ?? 18;
        final bal = await getTokenBalance(
          walletAddress,
          tDef['address']!,
          parsedDecimals,
        );
        if (bal > 0) {
          final p = prices[tDef['coinGeckoId']] ?? 0;
          tokens.add(
            Token(
              symbol: tDef['symbol']!,
              name: tDef['name']!,
              contractAddress: tDef['address'],
              balance: bal,
              valueUsd: bal * p,
              priceUsd: p,
              changePercent24h: prices['${tDef['coinGeckoId']}_change'] ?? 0,
              decimals: parsedDecimals,
              imageUrl:
                  tDef['imageUrl'] ??
                  BlockchainCatalog.iconUrlForSymbol(tDef['symbol']!),
              coinGeckoId: tDef['coinGeckoId'],
            ),
          );
        }
      }

      // Added tokens should appear in wallet/home even when balance is zero.
      for (final custom in customTokens) {
        final address = custom.address;
        final alreadyAdded = tokens.any(
          (t) =>
              (t.contractAddress ?? '').toLowerCase() == address.toLowerCase(),
        );
        if (alreadyAdded) continue;
        final bal = await getTokenBalance(
          walletAddress,
          address,
          custom.decimals,
        );
        final price =
            (custom.coinGeckoId == null || custom.coinGeckoId!.isEmpty)
            ? 0.0
            : (prices[custom.coinGeckoId] ?? 0.0);
        final change =
            (custom.coinGeckoId == null || custom.coinGeckoId!.isEmpty)
            ? 0.0
            : (prices['${custom.coinGeckoId}_change'] ?? 0.0);
        tokens.add(
          Token(
            symbol: custom.symbol,
            name: custom.name,
            contractAddress: custom.address,
            balance: bal,
            valueUsd: bal * price,
            priceUsd: price,
            changePercent24h: change,
            decimals: custom.decimals,
            imageUrl: custom.imageUrl,
            coinGeckoId: custom.coinGeckoId,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching tokens: $e');
    }

    _walletTokens = tokens;
    notifyListeners();
    return tokens;
  }

  Future<List<Token>> searchTokensFromBackend(
    String query, {
    int limit = 30,
  }) async {
    final trimmed = query.trim();
    final safeLimit = limit.clamp(1, 100);
    final parsed = <Token>[];

    final discoveryBases = [AppEnvironment.blockchain('').toString()];
    for (final base in discoveryBases) {
      final normalizedBase = base.endsWith('/')
          ? base.substring(0, base.length - 1)
          : base;
      final url = Uri.parse(
        '$normalizedBase/${_activeChain.chainId}/token-search',
      ).replace(queryParameters: {'q': trimmed, 'limit': '$safeLimit'});

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
          if (symbol.isEmpty || name.isEmpty || contractAddress == null) {
            continue;
          }

          parsed.add(
            Token(
              symbol: symbol,
              name: name,
              contractAddress: contractAddress,
              balance: 0,
              valueUsd: 0,
              priceUsd: _toDouble(entry['priceUsd']),
              changePercent24h: _toDouble(entry['changePercent24h']),
              // Prefer backend decimals when available to avoid display errors.
              decimals: _toInt(entry['decimals']) ?? 18,
              coinGeckoId: (entry['id'] as String?)?.trim(),
              imageUrl: (entry['imageUrl'] as String?)?.trim(),
            ),
          );
        }
        if (parsed.isNotEmpty) return parsed;
      } catch (_) {
        continue;
      }
    }
    return parsed;
  }

  // ─── BACKEND DISCOVERY (Kept here for simplicity) ──

  Future<List<Token>?> _fetchWalletTokensFromBackend(
    String walletAddress,
  ) async {
    final now = DateTime.now();
    final discoveryBases = [AppEnvironment.blockchain('').toString()];
    for (final base in discoveryBases) {
      final backoff = _backendDiscoveryBackoffUntil[base];
      if (backoff != null && now.isBefore(backoff)) continue;

      final normalizedBase = base.endsWith('/')
          ? base.substring(0, base.length - 1)
          : base;
      final url = Uri.parse(
        '$normalizedBase/${_activeChain.chainId}/wallet-tokens/$walletAddress',
      );
      try {
        final response = await http.get(url).timeout(_backendDiscoveryTimeout);
        if (response.statusCode == 200) {
          _backendDiscoveryBackoffUntil.remove(base);
          return _parseBackendDiscoveredTokens(response.body);
        }
        _backendDiscoveryBackoffUntil[base] = DateTime.now().add(
          const Duration(seconds: 30),
        );
      } catch (e) {
        debugPrint('Backend discovery failed for $base: $e');
        _backendDiscoveryBackoffUntil[base] = DateTime.now().add(
          const Duration(seconds: 45),
        );
      }
    }
    return null;
  }

  List<Token>? _parseBackendDiscoveredTokens(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final list = data['tokens'] as List<dynamic>? ?? [];
      return list
          .map(
            (e) => Token(
              symbol: e['symbol'] ?? '',
              name: e['name'] ?? '',
              contractAddress: e['contractAddress'],
              balance: _toDouble(e['balance']),
              valueUsd: _toDouble(e['valueUsd']),
              priceUsd: _toDouble(e['priceUsd']),
              changePercent24h: _toDouble(e['changePercent24h']),
              decimals: _toInt(e['decimals']) ?? 18,
              imageUrl: e['imageUrl'],
              coinGeckoId: e['coinGeckoId'],
            ),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Batch-fetches CoinGecko prices for tokens missing price data and
  /// returns a new list with enriched price/value fields.
  Future<List<Token>> _enrichTokensWithPrices(List<Token> tokens) async {
    // Collect coinGeckoIds that need pricing
    final priceIds = <String>{};
    final nativeCgId = _activeChain.coinGeckoId;
    if (nativeCgId != null && nativeCgId.isNotEmpty) {
      priceIds.add(nativeCgId);
    }
    for (final t in tokens) {
      if (t.priceUsd > 0 && t.valueUsd > 0) continue; // already has price
      final cgId = t.coinGeckoId;
      if (cgId != null && cgId.isNotEmpty) {
        priceIds.add(cgId);
      }
    }
    if (priceIds.isEmpty) return tokens;

    final prices = await getTokenPrices(priceIds.toList());

    return tokens.map((t) {
      if (t.priceUsd > 0 && t.valueUsd > 0) return t; // already priced
      // Derive coinGeckoId — use token's own or fallback to chain native
      final cgId = (t.coinGeckoId != null && t.coinGeckoId!.isNotEmpty)
          ? t.coinGeckoId!
          : (t.contractAddress == null && nativeCgId != null
                ? nativeCgId
                : null);
      if (cgId == null) return t;

      final price = prices[cgId] ?? 0.0;
      final change = prices['${cgId}_change'] ?? t.changePercent24h;
      if (price == 0) return t;

      return Token(
        symbol: t.symbol,
        name: t.name,
        contractAddress: t.contractAddress,
        balance: t.balance,
        valueUsd: t.balance * price,
        priceUsd: price,
        changePercent24h: change,
        decimals: t.decimals,
        imageUrl: t.imageUrl,
        coinGeckoId: t.coinGeckoId,
      );
    }).toList();
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
          _customTokens[chainId] = (v as List)
              .map((e) => CustomTokenDefinition.fromJson(e))
              .toList();
        }
      });
    } catch (e) {
      debugPrint('Error loading custom tokens: $e');
    }
  }

  Future<void> _saveCustomTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _customTokens.map(
        (k, v) => MapEntry(k.toString(), v.map((t) => t.toJson()).toList()),
      );
      await prefs.setString(_keyCustomTokens, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving custom tokens: $e');
    }
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
        {
          'symbol': 'USDC',
          'name': 'USD Coin',
          'address': '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
          'decimals': '6',
          'coinGeckoId': 'usd-coin',
          'imageUrl': 'https://cryptologos.cc/logos/usd-coin-usdc-logo.png',
        },
        {
          'symbol': 'USDT',
          'name': 'Tether',
          'address': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
          'decimals': '6',
          'coinGeckoId': 'tether',
          'imageUrl': 'https://cryptologos.cc/logos/tether-usdt-logo.png',
        },
      ]);
    }
    return tokens;
  }

  EvmChain _normalizeCustomChain(EvmChain chain) {
    final inferredCoinId =
        (chain.coinGeckoId == null || chain.coinGeckoId!.isEmpty)
        ? BlockchainCatalog.inferCoinGeckoIdFromSymbol(chain.symbol)
        : chain.coinGeckoId;
    final inferredLogo = (chain.logoUrl == null || chain.logoUrl!.isEmpty)
        ? BlockchainCatalog.defaultChainLogoUrl(chain.chainId)
        : chain.logoUrl;
    return EvmChain(
      name: chain.name,
      symbol: chain.symbol,
      chainId: chain.chainId,
      rpcUrl: chain.rpcUrl,
      coinGeckoId: inferredCoinId,
      explorerUrl: chain.explorerUrl,
      logoUrl: inferredLogo,
      isCustom: chain.isCustom,
    );
  }

  Future<void> _syncNetworkSettingsToBackend() async {
    try {
      final walletAddress = await _storageService.getWalletAddress();
      if (walletAddress == null || walletAddress.isEmpty) return;
      final sessionToken = await _walletBackendAuthService.ensureWalletSession(
        walletAddress,
      );
      final payload = {
        'walletAddress': walletAddress,
        'selectedChainId': _activeChain.chainId,
        'customNetworks': _customChains.map((c) => c.toJson()).toList(),
      };
      await http
          .post(
            AppEnvironment.settings('/networks'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $sessionToken',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // best effort sync
    }
  }

  Future<void> _hydrateNetworkSettingsFromBackend() async {
    try {
      final walletAddress = await _storageService.getWalletAddress();
      if (walletAddress == null || walletAddress.isEmpty) return;
      final sessionToken = await _walletBackendAuthService.ensureWalletSession(
        walletAddress,
      );
      final encoded = Uri.encodeComponent(walletAddress);
      final response = await http
          .get(
            AppEnvironment.settings('/networks/$encoded'),
            headers: {'Authorization': 'Bearer $sessionToken'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final custom = data['customNetworks'] as List<dynamic>? ?? const [];
      final selected = _toInt(data['selectedChainId']);

      final parsedCustom = custom
          .whereType<Map<String, dynamic>>()
          .map(EvmChain.fromJson)
          .map(_normalizeCustomChain)
          .where((c) => c.isCustom)
          .toList();

      if (parsedCustom.isNotEmpty) {
        _customChains = parsedCustom;
        await _saveCustomChains();
      }

      if (selected != null) {
        _activeChain = allChains.firstWhere(
          (c) => c.chainId == selected,
          orElse: () => _activeChain,
        );
        await _saveActiveChain();
      }
    } catch (_) {
      // keep local settings on backend errors
    }
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  double _scaledBigIntToDouble(BigInt value, int decimals) {
    if (value == BigInt.zero) return 0.0;
    final negative = value.isNegative;
    final abs = value.abs().toString();
    if (decimals <= 0) {
      return double.tryParse('${negative ? '-' : ''}$abs') ?? 0.0;
    }
    if (abs.length <= decimals) {
      final frac = abs.padLeft(decimals, '0').substring(0, min(decimals, 12));
      final s = '${negative ? '-' : ''}0.$frac';
      return double.tryParse(s) ?? 0.0;
    }
    final intPart = abs.substring(0, abs.length - decimals);
    final fracRaw = abs.substring(abs.length - decimals);
    final frac = fracRaw.substring(0, min(fracRaw.length, 12));
    final s = frac.isEmpty
        ? '${negative ? '-' : ''}$intPart'
        : '${negative ? '-' : ''}$intPart.$frac';
    return double.tryParse(s) ?? 0.0;
  }

  String _padAddress(String addr) => addr.startsWith('0x')
      ? addr.substring(2).padLeft(64, '0')
      : addr.padLeft(64, '0');

  // Necessary for backward compatibility with some screens
  Future<String?> sendRawTransaction(String signedTxHex) async {
    final res = await _rpcCall('eth_sendRawTransaction', [signedTxHex]);
    return res as String?;
  }
}
