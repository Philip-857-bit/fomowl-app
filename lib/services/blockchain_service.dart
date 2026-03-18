import 'package:flutter/foundation.dart';
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
import 'http_client_service.dart';
import 'blockchain/token_portfolio_module.dart';

/// Blockchain Service — Shared ChangeNotifier Provider
/// Manages active chain, custom chains, and all blockchain interactions.
/// Now delegates core RPC and Price logic to specialized services.
class BlockchainService extends ChangeNotifier {
  // Dependencies
  RpcService? _rpcService;
  TokenPriceService? _priceService;
  final HttpClientService _httpClientService = HttpClientService();
  late final TokenPortfolioModule _tokenPortfolioModule;

  // Configuration Constants
  static const Duration _backendDiscoveryTimeout = Duration(seconds: 15);
  static const Duration _walletTokensCacheTtl = Duration(seconds: 25);
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
  final Map<String, _WalletTokensCacheEntry> _walletTokensCache = {};
  final Map<String, Future<List<Token>>> _walletTokensInFlight = {};
  final Map<String, DateTime> _backendDiscoveryBackoffUntil = {};
  Timer? _livePriceTimer;
  final Set<String> _trackedPriceIds = {};
  Duration _livePriceInterval = const Duration(seconds: 10);
  bool _isLivePriceTicking = false;
  bool _initialized = false;

  String _lastDiscoverySource = 'unknown';
  bool _lastDiscoveryPartialFailure = false;
  int _lastDiscoveryTokenCount = 0;
  String? _lastDiscoveryMessage;

  BlockchainService() {
    _tokenPortfolioModule = TokenPortfolioModule(
      getTokenPrices: getTokenPrices,
      getTokenBalance: getTokenBalance,
      resolveIconUrl: BlockchainCatalog.iconUrlForSymbol,
    );
  }

  // Getters
  List<EvmChain> get allChains => [...builtInChains, ..._customChains];
  List<EvmChain> get customChains => _customChains;
  EvmChain get activeChain => _activeChain;
  List<CustomTokenDefinition> get customTokensForActiveChain =>
      List.unmodifiable(_customTokens[_activeChain.chainId] ?? []);

  String get lastDiscoverySource => _lastDiscoverySource;
  bool get lastDiscoveryPartialFailure => _lastDiscoveryPartialFailure;
  int get lastDiscoveryTokenCount => _lastDiscoveryTokenCount;
  String? get lastDiscoveryMessage => _lastDiscoveryMessage;

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
    notifyListeners();
  }

  /// Initialize — load persisted chains and active chain from storage
  Future<void> init() async {
    if (_initialized) {
      debugPrint('[OWLLET] BlockchainService: Already initialized.');
      return;
    }
    debugPrint('[OWLLET] BlockchainService: Starting initialization...');
    try {
      debugPrint('[OWLLET] BlockchainService: Loading custom chains...');
      await _loadCustomChains();

      debugPrint('[OWLLET] BlockchainService: Loading active chain...');
      await _loadActiveChain();

      debugPrint('[OWLLET] BlockchainService: Loading custom tokens...');
      await _loadCustomTokens();

      debugPrint('[OWLLET] BlockchainService: Hydrating from backend...');
      await _hydrateNetworkSettingsFromBackend();

      _initialized = true;
      debugPrint('[OWLLET] BlockchainService: Init SUCCESS.');
      notifyListeners();
    } catch (e) {
      debugPrint('[OWLLET] BlockchainService: Init FAILED with error: $e');
      _initialized = false;
      notifyListeners();
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

  Future<Map<String, dynamic>> getGasPriceData() async {
    final url = AppEnvironment.blockchain('/${_activeChain.chainId}/gas-price');
    try {
      final response = await _httpClientService
          .sendWithRetry(() => _httpClientService.client.get(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Failed to fetch gas price from backend: $e');
    }

    // Fallback to raw RPC if backend fails
    final result = await _rpcCall('eth_gasPrice', []);
    if (result is String &&
        result.startsWith('0x') &&
        RegExp(r'^[0-9a-fA-F]+$').hasMatch(result.substring(2))) {
      final gasPriceWei = BigInt.parse(result.substring(2), radix: 16);
      return {
        'gasPrice': gasPriceWei.toString(),
        'gasPriceInGwei': _scaledBigIntToDouble(gasPriceWei, 9).toString(),
      };
    }
    return {'gasPrice': '20000000000', 'gasPriceInGwei': '20.0'};
  }

  Future<double> getGasPrice() async {
    final data = await getGasPriceData();
    return double.tryParse(data['gasPriceInGwei']?.toString() ?? '20.0') ??
        20.0;
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

  void setLivePriceTrackingForTokens(
    List<Token> tokens, {
    Duration interval = const Duration(seconds: 10),
  }) {
    _trackedPriceIds
      ..clear()
      ..addAll(
        tokens
            .map((t) => t.coinGeckoId)
            .whereType<String>()
            .where((id) => id.isNotEmpty),
      );

    if (_trackedPriceIds.isEmpty) {
      _stopLivePriceTimer();
      return;
    }

    _livePriceInterval = interval;
    _livePriceTimer?.cancel();
    _livePriceTimer = Timer.periodic(_livePriceInterval, (_) {
      unawaited(_refreshTrackedTokenPrices());
    });
    unawaited(_refreshTrackedTokenPrices());
  }

  void clearLivePriceTracking() {
    _trackedPriceIds.clear();
    _stopLivePriceTimer();
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

  Future<TokenMarketData?> getBackendTokenMarketData(
    String contractAddress,
  ) async {
    final normalized = contractAddress.trim();
    final addressRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');
    if (!addressRegex.hasMatch(normalized)) return null;

    final url = AppEnvironment.blockchain(
      '/${_activeChain.chainId}/token-details/$normalized',
    );

    try {
      final response = await _httpClientService
          .sendWithRetry(() => _httpClientService.client.get(url))
          .timeout(_backendDiscoveryTimeout);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return TokenMarketData(
        priceUsd: _toDouble(data['priceUsd']),
        marketCapUsd: _nullableDouble(data['marketCapUsd']),
        totalSupply: null,
        circulatingSupply: null,
        genesisDate: (data['createdAt'] as String?)?.trim(),
      );
    } catch (_) {
      return null;
    }
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
      } catch (e) {
        debugPrint('Error parsing hex as string: $e');
      }
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
    final cacheKey = '${_activeChain.chainId}:${walletAddress.toLowerCase()}';
    final now = DateTime.now();

    final cached = _walletTokensCache[cacheKey];
    if (cached != null &&
        now.difference(cached.fetchedAt) < _walletTokensCacheTtl) {
      _walletTokens = cached.tokens;
      notifyListeners();
      return cached.tokens;
    }

    final inFlight = _walletTokensInFlight[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _fetchWalletTokensFresh(walletAddress, cacheKey);
    _walletTokensInFlight[cacheKey] = future;
    future.whenComplete(() => _walletTokensInFlight.remove(cacheKey));
    return future;
  }

  Future<List<Token>> _fetchWalletTokensFresh(
    String walletAddress,
    String cacheKey,
  ) async {
    final discovered = await _fetchWalletTokensFromBackend(walletAddress);
    if (discovered != null) {
      _lastDiscoverySource = discovered.source;
      _lastDiscoveryPartialFailure = discovered.partialFailure;
      _lastDiscoveryTokenCount = discovered.tokenCount;
      _lastDiscoveryMessage = discovered.message;

      // --- Enrich discovered tokens with CoinGecko prices when backend omits them ---
      final enriched = await _tokenPortfolioModule.enrichTokensWithPrices(
        discovered.tokens,
        nativeCoinGeckoId: _activeChain.coinGeckoId,
      );

      // Merge custom tokens that weren't discovered by the backend.
      final customTokens = _customTokens[_activeChain.chainId] ?? const [];
      final merged = await _tokenPortfolioModule.mergeMissingCustomTokens(
        walletAddress: walletAddress,
        existing: enriched,
        customTokens: customTokens,
      );

      // If backend discovery yielded only native (or near-empty), supplement
      // with a fast local known-token scan so the list does not collapse.
      if (merged.length <= 1) {
        final supplemental = await _tokenPortfolioModule
            .collectSupplementalKnownTokens(
              chainId: _activeChain.chainId,
              walletAddress: walletAddress,
              existing: merged,
              knownTokens: _getWellKnownTokens(_activeChain.chainId),
            );
        if (supplemental.isNotEmpty) {
          merged.addAll(supplemental);
        }
      }

      _walletTokens = merged;
      _walletTokensCache[cacheKey] = _WalletTokensCacheEntry(
        tokens: List<Token>.from(merged),
        fetchedAt: DateTime.now(),
      );
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
          isCertified: true,
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
              isCertified: tDef['isCertified'] == 'true',
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
            isCertified: false,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching tokens: $e');
    }

    _walletTokens = tokens;
    _walletTokensCache[cacheKey] = _WalletTokensCacheEntry(
      tokens: List<Token>.from(tokens),
      fetchedAt: DateTime.now(),
    );
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
        final response = await _httpClientService
            .sendWithRetry(() => _httpClientService.client.get(url))
            .timeout(_backendDiscoveryTimeout);
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
              decimals: (_toInt(entry['decimals']) ?? 0).clamp(0, 255),
              imageUrl: (entry['imageUrl'] as String?)?.trim(),
              coinGeckoId: ((entry['coinGeckoId'] ?? entry['id']) as String?)
                  ?.trim(),
              isCertified:
                  entry['isCertified'] == true || entry['isNative'] == true,
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

  Future<_BackendWalletTokensResponse?> _fetchWalletTokensFromBackend(
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
        final response = await _httpClientService
            .sendWithRetry(() => _httpClientService.client.get(url))
            .timeout(_backendDiscoveryTimeout);
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

  _BackendWalletTokensResponse? _parseBackendDiscoveredTokens(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final list = data['tokens'] as List<dynamic>? ?? [];
      final discovery = data['discovery'] as Map<String, dynamic>? ?? const {};

      final tokens = list
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
              isCertified: e['isCertified'] == true,
            ),
          )
          .toList();

      return _BackendWalletTokensResponse(
        tokens: tokens,
        source: (discovery['source'] as String?)?.trim().isNotEmpty == true
            ? (discovery['source'] as String)
            : 'unknown',
        partialFailure: discovery['partialFailure'] == true,
        tokenCount: _toInt(discovery['tokenCount']) ?? tokens.length,
        message: (discovery['message'] as String?)?.trim(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshTrackedTokenPrices() async {
    if (_isLivePriceTicking ||
        _trackedPriceIds.isEmpty ||
        _walletTokens.isEmpty) {
      return;
    }

    _isLivePriceTicking = true;
    try {
      final prices = await getTokenPrices(_trackedPriceIds.toList());
      if (prices.isEmpty) return;

      bool changed = false;
      final updated = _walletTokens.map((token) {
        final id = token.coinGeckoId;
        if (id == null || id.isEmpty) return token;

        final nextPrice = prices[id];
        if (nextPrice == null || nextPrice <= 0) return token;

        final nextChange = prices['${id}_change'] ?? token.changePercent24h;
        if ((nextPrice - token.priceUsd).abs() < 0.0000001 &&
            (nextChange - token.changePercent24h).abs() < 0.0000001) {
          return token;
        }
        changed = true;
        return Token(
          symbol: token.symbol,
          name: token.name,
          contractAddress: token.contractAddress,
          balance: token.balance,
          valueUsd: token.balance * nextPrice,
          priceUsd: nextPrice,
          changePercent24h: nextChange,
          decimals: token.decimals,
          imageUrl: token.imageUrl,
          coinGeckoId: token.coinGeckoId,
          isCertified: token.isCertified,
        );
      }).toList();

      if (changed) {
        _walletTokens = updated;
        notifyListeners();
      }
    } catch (_) {
      // Keep existing prices when realtime refresh fails.
    } finally {
      _isLivePriceTicking = false;
    }
  }

  void _stopLivePriceTimer() {
    _livePriceTimer?.cancel();
    _livePriceTimer = null;
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
          'isCertified': 'true',
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
      final payload = {
        'walletAddress': walletAddress,
        'selectedChainId': _activeChain.chainId,
        'customNetworks': _customChains.map((c) => c.toJson()).toList(),
      };
      await _walletBackendAuthService
          .sendAuthorized(
            walletAddress,
            (headers) => _httpClientService.sendWithRetry(
              () => _httpClientService.client.post(
                AppEnvironment.settings('/networks'),
                headers: headers,
                body: jsonEncode(payload),
              ),
            ),
            {'Content-Type': 'application/json'},
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
      final encoded = Uri.encodeComponent(walletAddress);
      final response = await _walletBackendAuthService
          .sendAuthorized(
            walletAddress,
            (headers) => _httpClientService.sendWithRetry(
              () => _httpClientService.client.get(
                AppEnvironment.settings('/networks/$encoded'),
                headers: headers,
              ),
            ),
            const {},
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

  double? _nullableDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
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

  @override
  void dispose() {
    _stopLivePriceTimer();
    super.dispose();
  }
}

class _WalletTokensCacheEntry {
  final List<Token> tokens;
  final DateTime fetchedAt;

  const _WalletTokensCacheEntry({
    required this.tokens,
    required this.fetchedAt,
  });
}

class _BackendWalletTokensResponse {
  final List<Token> tokens;
  final String source;
  final bool partialFailure;
  final int tokenCount;
  final String? message;

  const _BackendWalletTokensResponse({
    required this.tokens,
    required this.source,
    required this.partialFailure,
    required this.tokenCount,
    this.message,
  });
}
