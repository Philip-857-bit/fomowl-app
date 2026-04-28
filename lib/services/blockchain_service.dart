import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_environment.dart';
import '../models/token.dart';
import '../models/chain.dart';
import '../models/network_entry.dart';
import '../models/token_standard.dart';
import '../models/token_market_data.dart';
import 'blockchain/blockchain_catalog.dart';
import 'blockchain/solana_catalog.dart';
import 'blockchain/tron_catalog.dart';
import 'rpc_service.dart';
import 'token_price_service.dart';
import 'storage_service.dart';
import 'wallet_backend_auth_service.dart';
import 'http_client_service.dart';
import 'blockchain/token_portfolio_module.dart';
import 'home_snapshot_service.dart';

class _CircuitBreakerState {
  int failureCount = 0;
  DateTime? lastFailureTime;
  Duration currentBackoff;
  final int failureThreshold;

  _CircuitBreakerState({
    this.currentBackoff = const Duration(seconds: 30),
    this.failureThreshold = 3,
  });

  bool isOpen() {
    if (lastFailureTime == null) return false;
    final elapsed = DateTime.now().difference(lastFailureTime!);
    if (elapsed >= currentBackoff) {
      return false;
    }
    return failureCount >= failureThreshold;
  }

  void recordFailure(Duration maxBackoff) {
    failureCount++;
    lastFailureTime = DateTime.now();
    currentBackoff = Duration(
      seconds: (currentBackoff.inSeconds * 2)
          .clamp(30, maxBackoff.inSeconds)
          .toInt(),
    );
  }

  void reset(Duration initialBackoff) {
    failureCount = 0;
    lastFailureTime = null;
    currentBackoff = initialBackoff;
  }
}

class _PerformanceMetrics {
  int totalDiscoveryCalls = 0;
  int successfulDiscoveryCalls = 0;
  int failedDiscoveryCalls = 0;
  final List<Duration> priceRefreshLatencies = [];
  int priceRefreshCount = 0;
  int tokenMismatchCount = 0;
  int registryFallbackCount = 0;
  final Map<String, int> endpointFailureCount = {};

  double get discoverySuccessRate => totalDiscoveryCalls == 0
      ? 0.0
      : (successfulDiscoveryCalls / totalDiscoveryCalls) * 100;

  Duration get avgPriceRefreshLatency {
    if (priceRefreshLatencies.isEmpty) return Duration.zero;
    final total = priceRefreshLatencies.fold<Duration>(
      Duration.zero,
      (sum, d) => sum + d,
    );
    return total ~/ priceRefreshLatencies.length;
  }

  void recordDiscoveryCall({
    required bool success,
    required bool usedFallback,
  }) {
    totalDiscoveryCalls++;
    if (success) {
      successfulDiscoveryCalls++;
    } else {
      failedDiscoveryCalls++;
    }
    if (usedFallback) {
      registryFallbackCount++;
    }
  }

  void recordPriceRefresh({required Duration latency}) {
    priceRefreshCount++;
    if (priceRefreshLatencies.length >= 100) {
      priceRefreshLatencies.removeAt(0);
    }
    priceRefreshLatencies.add(latency);
  }

  void recordTokenMismatch() {
    tokenMismatchCount++;
  }

  void recordEndpointFailure(String endpoint) {
    endpointFailureCount[endpoint] = (endpointFailureCount[endpoint] ?? 0) + 1;
  }

  Map<String, dynamic> toJson() => {
    'totalDiscoveryCalls': totalDiscoveryCalls,
    'successfulDiscoveryCalls': successfulDiscoveryCalls,
    'failedDiscoveryCalls': failedDiscoveryCalls,
    'discoverySuccessRate': '${discoverySuccessRate.toStringAsFixed(1)}%',
    'priceRefreshCount': priceRefreshCount,
    'avgPriceRefreshLatencyMs': avgPriceRefreshLatency.inMilliseconds,
    'tokenMismatchCount': tokenMismatchCount,
    'registryFallbackCount': registryFallbackCount,
    'endpointFailures': endpointFailureCount,
  };
}

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
  static const Duration _walletTokensCacheTtl = Duration(minutes: 2);
  static const Duration _jitterMax = Duration(milliseconds: 100);
  static const int _circuitBreakerFailureThreshold = 3;
  static const Duration _circuitBreakerInitialBackoff = Duration(seconds: 30);
  static const Duration _circuitBreakerMaxBackoff = Duration(minutes: 10);
  final StorageService _storageService = StorageService();
  final HomeSnapshotService _homeSnapshotService = HomeSnapshotService();

  final WalletBackendAuthService _walletBackendAuthService =
      WalletBackendAuthService();

  static List<EvmChain> get builtInChains => BlockchainCatalog.builtInChains;

  // Storage keys
  static const String _keyCustomChains = 'custom_evm_chains';
  static const String _keyActiveChainId = 'active_chain_id';
  static const String _keyActiveNetworkKey = 'active_network_key';
  static const String _keyCustomTokens = 'custom_tokens_v1';

  // State
  List<EvmChain> _customChains = [];
  EvmChain _activeChain = builtInChains[0];
  String _activeNetworkKeyOverride = ''; // non-empty only for Solana/Tron
  Set<ChainFamily> _enabledFamilies = {ChainFamily.evm};
  final Map<int, List<CustomTokenDefinition>> _customTokens = {};
  List<Token> _walletTokens = [];
  final Map<String, _WalletTokensCacheEntry> _walletTokensCache = {};
  final Map<String, WalletTokenState> _walletTokenStates = {};
  final Map<String, Future<List<Token>>> _walletTokensInFlight = {};
  final Map<String, DateTime> _backendDiscoveryBackoffUntil = {};
  Timer? _livePriceTimer;
  final Map<String, Set<String>> _trackedPriceIdsByScope = {};
  final Map<String, Duration> _livePriceIntervalsByScope = {};
  Duration _livePriceInterval = const Duration(seconds: 10);
  bool _isLivePriceTicking = false;
  bool _initialized = false;

  // Circuit Breaker State
  final Map<String, _CircuitBreakerState> _circuitBreakers = {};
  final _PerformanceMetrics _metrics = _PerformanceMetrics();

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

  Duration _getJitter() {
    final random = Random();
    return Duration(
      milliseconds: random.nextInt(_jitterMax.inMilliseconds + 1),
    );
  }

  Duration _calculateBackoffWithJitter(int attemptNumber) {
    final exponent = (attemptNumber - 1).clamp(0, 10);
    final baseBackoff = Duration(seconds: 1 << exponent);
    return baseBackoff + _getJitter();
  }

  // Getters
  List<EvmChain> get allChains => [...builtInChains, ..._customChains];
  List<EvmChain> get customChains => _customChains;
  EvmChain get activeChain => _activeChain;
  String get activeNetworkKey => _activeNetworkKeyOverride.isNotEmpty
      ? _activeNetworkKeyOverride
      : _activeChain.networkKey;
  ChainFamily get activeFamily => NetworkKey.familyOf(activeNetworkKey);
  Set<ChainFamily> get enabledFamilies => Set.unmodifiable(_enabledFamilies);

  /// Ordered network entries for the selector, filtered by enabled families.
  /// Order: ETH(1), BNB(56), Base(8453), Solana, Tron, Polygon(137),
  ///        Arbitrum(42161), Optimism(10), then any other enabled EVM chains.
  List<NetworkEntry> get networkEntries {
    const priorityChainIds = [1, 56, 8453, 137, 42161, 10];
    final entries = <NetworkEntry>[];

    if (_enabledFamilies.contains(ChainFamily.evm)) {
      // Priority EVM chains first, in defined order.
      for (final id in priorityChainIds) {
        final chain = allChains.firstWhere(
          (c) => c.chainId == id,
          orElse: () => EvmChain(name: '', symbol: '', chainId: -1, rpcUrl: ''),
        );
        if (chain.chainId != -1) entries.add(EvmNetworkEntry(chain));
      }
      // Solana and Tron slots appear after Base (index 2) in the fixed order.
      // We insert them after Base by post-processing below.
    }

    if (_enabledFamilies.contains(ChainFamily.solana)) {
      entries.add(SolanaNetworkEntry(SolanaCatalog.mainnet));
    }

    if (_enabledFamilies.contains(ChainFamily.tron)) {
      entries.add(TronNetworkEntry(TronCatalog.mainnet));
    }

    if (_enabledFamilies.contains(ChainFamily.evm)) {
      // Remaining enabled EVM chains not in priority list.
      for (final chain in allChains) {
        if (!priorityChainIds.contains(chain.chainId)) {
          entries.add(EvmNetworkEntry(chain));
        }
      }
    }

    // Re-order: ensure Solana and Tron appear after Base(8453).
    final solanaIdx = entries.indexWhere((e) => e is SolanaNetworkEntry);
    final baseIdx = entries.indexWhere(
      (e) => e is EvmNetworkEntry && e.chain.chainId == 8453,
    );

    NetworkEntry? solanaEntry;
    NetworkEntry? tronEntry;
    if (solanaIdx != -1) {
      solanaEntry = entries.removeAt(solanaIdx);
    }
    final newTronIdx = entries.indexWhere((e) => e is TronNetworkEntry);
    if (newTronIdx != -1) {
      tronEntry = entries.removeAt(newTronIdx);
    }

    var insertAt = baseIdx != -1 ? baseIdx + 1 : entries.length;
    if (tronEntry != null) {
      entries.insert(insertAt, tronEntry);
    }
    if (solanaEntry != null) {
      entries.insert(insertAt, solanaEntry);
    }

    return entries;
  }

  List<CustomTokenDefinition> get customTokensForActiveChain =>
      List.unmodifiable(_customTokens[_activeChain.chainId] ?? []);

  String get lastDiscoverySource => _lastDiscoverySource;
  bool get lastDiscoveryPartialFailure => _lastDiscoveryPartialFailure;
  int get lastDiscoveryTokenCount => _lastDiscoveryTokenCount;
  String? get lastDiscoveryMessage => _lastDiscoveryMessage;

  /// Get performance metrics for observability (for logging/debugging)
  Map<String, dynamic> get performanceMetrics => _metrics.toJson();

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
        networkKey: activeChain.networkKey,
        tokenStandard: TokenStandard.native,
      ),
    ];
  }

  WalletTokenState getWalletTokenState(String walletAddress, {int? chainId}) {
    final effectiveChainId = chainId ?? _activeChain.chainId;
    final cacheKey = _walletTokenStateKey(effectiveChainId, walletAddress);
    return _walletTokenStates[cacheKey] ??
        WalletTokenState(
          tokens: getCachedWalletTokens(
            walletAddress,
            chainId: effectiveChainId,
          ),
          source: 'none',
          isLoading: false,
          isStale: false,
        );
  }

  List<Token> getCachedWalletTokens(String walletAddress, {int? chainId}) {
    final effectiveChainId = chainId ?? _activeChain.chainId;
    final cacheKey = _walletTokenStateKey(effectiveChainId, walletAddress);
    final state = _walletTokenStates[cacheKey];
    if (state != null && state.tokens.isNotEmpty) {
      return List<Token>.from(state.tokens);
    }
    final cached = _walletTokensCache[cacheKey];
    if (cached != null && cached.tokens.isNotEmpty) {
      return List<Token>.from(cached.tokens);
    }
    if (_activeChain.chainId == effectiveChainId && _walletTokens.isNotEmpty) {
      return List<Token>.from(_walletTokens);
    }
    return const [];
  }

  String _walletTokenStateKey(int chainId, String walletAddress) =>
      '$chainId:${walletAddress.toLowerCase()}';

  /// For non-EVM families the chainId is meaningless; use the networkKey instead.
  String _walletTokenStateKeyForNetwork(
    String networkKey,
    String walletAddress,
  ) => '$networkKey:${walletAddress.toLowerCase()}';

  void _setWalletTokenState(
    String cacheKey,
    WalletTokenState state, {
    required int chainId,
    bool notify = false,
  }) {
    _walletTokenStates[cacheKey] = state;
    if (_activeChain.chainId == chainId) {
      _walletTokens = List<Token>.from(state.tokens);
    }
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _syncHomeSnapshotForWallet(
    String walletAddress,
    int chainId,
    List<Token> tokens,
  ) async {
    final existing = await _homeSnapshotService.loadSnapshot(
      chainId,
      walletAddress,
    );
    if (existing == null) {
      return;
    }
    final totalBalance = tokens.fold<double>(
      0,
      (sum, token) => sum + token.totalValueUsd,
    );
    await _homeSnapshotService.saveSnapshot(
      HomePortfolioSnapshot(
        walletAddress: existing.walletAddress,
        chainId: existing.chainId,
        walletName: existing.walletName,
        totalBalance: totalBalance,
        tokens: tokens,
        timestamp: DateTime.now(),
      ),
    );
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

      _initialized = true;
      debugPrint('[OWLLET] BlockchainService: Local init SUCCESS.');
      notifyListeners();

      // Do not block first paint on a best-effort backend settings fetch.
      unawaited(_hydrateNetworkSettingsAfterInit());
    } catch (e) {
      debugPrint('[OWLLET] BlockchainService: Init FAILED with error: $e');
      _initialized = false;
      notifyListeners();
    }
  }

  Future<void> _hydrateNetworkSettingsAfterInit() async {
    debugPrint('[OWLLET] BlockchainService: Hydrating from backend...');
    final beforeChainId = _activeChain.chainId;
    final beforeCustomCount = _customChains.length;
    await _hydrateNetworkSettingsFromBackend();
    if (beforeChainId != _activeChain.chainId ||
        beforeCustomCount != _customChains.length) {
      debugPrint(
        '[OWLLET] BlockchainService: Backend hydration updated chains.',
      );
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
      final networkKey = prefs.getString(_keyActiveNetworkKey);
      final family = NetworkKey.familyOf(networkKey);
      if (family == ChainFamily.solana || family == ChainFamily.tron) {
        _activeNetworkKeyOverride = networkKey!;
      } else {
        _activeNetworkKeyOverride = '';
        final chainId =
            NetworkKey.evmChainIdOf(networkKey) ??
            prefs.getInt(_keyActiveChainId);
        if (chainId != null) {
          _activeChain = allChains.firstWhere(
            (c) => c.chainId == chainId,
            orElse: () => builtInChains[0],
          );
        }
      }

      // Load enabled families; default to evm-only for existing users.
      final saved = await _storageService.getEnabledChainFamilies();
      _enabledFamilies = saved ?? {ChainFamily.evm};
      // Ensure the active family is always in the enabled set.
      _enabledFamilies.add(NetworkKey.familyOf(activeNetworkKey));
    } catch (e) {
      debugPrint('Error loading active chain: $e');
    }
  }

  Future<void> _saveActiveChain() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_activeNetworkKeyOverride.isNotEmpty) {
        await prefs.setString(_keyActiveNetworkKey, _activeNetworkKeyOverride);
      } else {
        await prefs.setInt(_keyActiveChainId, _activeChain.chainId);
        await prefs.setString(_keyActiveNetworkKey, _activeChain.networkKey);
      }
    } catch (e) {
      debugPrint('Error saving active chain: $e');
    }
  }

  @visibleForTesting
  Future<void> loadActiveNetworkForTest() => _loadActiveChain();

  @visibleForTesting
  Future<void> saveActiveNetworkForTest() => _saveActiveChain();

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

  void setActiveNetworkKey(String networkKey) {
    final family = NetworkKey.familyOf(networkKey);
    if (family == ChainFamily.solana || family == ChainFamily.tron) {
      _activeNetworkKeyOverride = networkKey;
      refresh();
      _saveActiveChain();
      return;
    }
    _activeNetworkKeyOverride = '';
    final chainId = NetworkKey.evmChainIdOf(networkKey);
    if (chainId != null) {
      setActiveChainByChainId(chainId);
    }
  }

  Future<void> setEnabledFamilies(Set<ChainFamily> families) async {
    if (families.isEmpty) return;
    _enabledFamilies = Set.of(families);
    // If current active family is no longer enabled, switch to first available.
    if (!_enabledFamilies.contains(activeFamily)) {
      final firstFamily = _enabledFamilies.first;
      final defaultKey = switch (firstFamily) {
        ChainFamily.solana => NetworkKey.solana('mainnet-beta'),
        ChainFamily.tron => NetworkKey.tron('mainnet'),
        ChainFamily.evm => NetworkKey.evm(builtInChains[0].chainId),
      };
      setActiveNetworkKey(defaultKey);
    }
    await _storageService.setEnabledChainFamilies(_enabledFamilies);
    notifyListeners();
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
        final decoded = jsonDecode(response.body);
        final asMap = _asMap(decoded);
        if (asMap != null) {
          return asMap;
        }
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

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, entryValue) => MapEntry('$key', entryValue));
    }
    return null;
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
    String scope = 'default',
  }) {
    final trackedIds = tokens
        .map((t) => t.coinGeckoId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    if (trackedIds.isEmpty) {
      _trackedPriceIdsByScope.remove(scope);
      _livePriceIntervalsByScope.remove(scope);
      _reconfigureLivePriceTimer();
      return;
    }

    _trackedPriceIdsByScope[scope] = trackedIds;
    _livePriceIntervalsByScope[scope] = interval;
    _reconfigureLivePriceTimer();
  }

  void clearLivePriceTracking({String scope = 'default'}) {
    _trackedPriceIdsByScope.remove(scope);
    _livePriceIntervalsByScope.remove(scope);
    _reconfigureLivePriceTimer();
  }

  /// Refresh prices for given tokens — use in confirmation screens before signing
  /// Ensures latest quotes before user executes swap or transfer
  Future<void> refreshPricesBeforeConfirmation(List<Token> tokens) async {
    if (tokens.isEmpty) return;
    final coinIds = tokens
        .map((t) => t.coinGeckoId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    if (coinIds.isEmpty) return;

    try {
      final prices = await getTokenPrices(coinIds);
      if (prices.isEmpty) return;

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

        return token.copyWith(
          valueUsd: token.balance * nextPrice,
          priceUsd: nextPrice,
          changePercent24h: nextChange,
        );
      }).toList();

      _walletTokens = updated;
      notifyListeners();
    } catch (_) {
      // If refresh fails, proceed with existing prices
    }
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

      final decoded = jsonDecode(response.body);
      final data = _asMap(decoded);
      if (data == null) return null;
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

    final backendSearchResults = await searchTokensFromBackend(
      normalized,
      limit: 12,
    );
    for (final token in backendSearchResults) {
      if ((token.contractAddress ?? '').toLowerCase() !=
          normalized.toLowerCase()) {
        continue;
      }
      if (token.symbol.trim().isEmpty || token.decimals <= 0) {
        continue;
      }
      return CustomTokenDefinition(
        symbol: token.symbol.toUpperCase(),
        name: token.name,
        address: normalized,
        decimals: token.decimals,
        coinGeckoId: token.coinGeckoId,
        imageUrl:
            token.imageUrl ??
            _buildTrustWalletTokenLogoUrl(_activeChain.chainId, normalized),
      );
    }

    final backendDetails = await _fetchBackendTokenMetadata(normalized);
    if (backendDetails != null) {
      return backendDetails;
    }

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
      imageUrl: _buildTrustWalletTokenLogoUrl(_activeChain.chainId, normalized),
    );
  }

  Future<CustomTokenDefinition?> _fetchBackendTokenMetadata(
    String contractAddress,
  ) async {
    final url = AppEnvironment.blockchain(
      '/${_activeChain.chainId}/token-details/$contractAddress',
    );

    try {
      final response = await _httpClientService
          .sendWithRetry(() => _httpClientService.client.get(url))
          .timeout(_backendDiscoveryTimeout);
      if (response.statusCode != 200) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      final data = _asMap(decoded);
      if (data == null) {
        return null;
      }
      final symbol = (data['symbol'] as String?)?.trim() ?? '';
      final name = (data['name'] as String?)?.trim() ?? '';
      final decimals = (_toInt(data['decimals']) ?? 0).clamp(0, 255);
      if (symbol.isEmpty || decimals <= 0) {
        return null;
      }
      return CustomTokenDefinition(
        symbol: symbol.toUpperCase(),
        name: name.isEmpty ? symbol.toUpperCase() : name,
        address: contractAddress,
        decimals: decimals,
        coinGeckoId: (data['coinGeckoId'] as String?)?.trim(),
        imageUrl: (data['imageUrl'] as String?)?.trim().isNotEmpty == true
            ? (data['imageUrl'] as String?)?.trim()
            : _buildTrustWalletTokenLogoUrl(
                _activeChain.chainId,
                contractAddress,
              ),
      );
    } catch (_) {
      return null;
    }
  }

  String? _buildTrustWalletTokenLogoUrl(int chainId, String contractAddress) {
    final normalized = contractAddress.trim().toLowerCase();
    final folder = switch (chainId) {
      1 => 'ethereum',
      56 => 'smartchain',
      137 => 'polygon',
      42161 => 'arbitrum',
      10 => 'optimism',
      8453 => 'base',
      43114 => 'avalanchec',
      250 => 'fantom',
      100 => 'xdai',
      _ => null,
    };
    if (folder == null || normalized.length != 42) {
      return null;
    }
    return 'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/$folder/assets/$normalized/logo.png';
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

  Future<List<Token>> fetchWalletTokens(
    String walletAddress, {
    int? chainId,
    bool forceRefresh = false,
  }) async {
    // For non-EVM families, use the full activeNetworkKey; chainId is irrelevant.
    final effectiveNetworkKey =
        (activeFamily != ChainFamily.evm && chainId == null)
        ? activeNetworkKey
        : NetworkKey.evm(chainId ?? _activeChain.chainId);
    final requestedChainId = chainId ?? _activeChain.chainId;
    // Non-EVM chains must use a network-key-based cache key to avoid colliding
    // with an EVM chain that happens to share the same numeric chainId slot.
    final cacheKey = (activeFamily != ChainFamily.evm && chainId == null)
        ? _walletTokenStateKeyForNetwork(effectiveNetworkKey, walletAddress)
        : _walletTokenStateKey(requestedChainId, walletAddress);
    final now = DateTime.now();
    final existingState = _walletTokenStates[cacheKey];

    final cached = _walletTokensCache[cacheKey];
    if (!forceRefresh &&
        cached != null &&
        now.difference(cached.fetchedAt) < _walletTokensCacheTtl) {
      _setWalletTokenState(
        cacheKey,
        WalletTokenState(
          tokens: List<Token>.from(cached.tokens),
          source: 'cache',
          isLoading: false,
          isStale: false,
          lastUpdatedAt: cached.fetchedAt,
          message: null,
        ),
        chainId: requestedChainId,
        notify: true,
      );
      return cached.tokens;
    }

    final inFlight = _walletTokensInFlight[cacheKey];
    if (forceRefresh && inFlight != null) {
      await inFlight;
    } else if (inFlight != null) {
      if (existingState != null && !existingState.isLoading) {
        _setWalletTokenState(
          cacheKey,
          existingState.copyWith(isLoading: true),
          chainId: requestedChainId,
          notify: true,
        );
      }
      return inFlight;
    }

    _setWalletTokenState(
      cacheKey,
      WalletTokenState(
        tokens: List<Token>.from(
          existingState?.tokens ?? cached?.tokens ?? const [],
        ),
        source: existingState?.source ?? (cached != null ? 'cache' : 'none'),
        isLoading: true,
        isStale: existingState?.isStale ?? (cached != null),
        lastUpdatedAt: existingState?.lastUpdatedAt ?? cached?.fetchedAt,
        message: existingState?.message,
      ),
      chainId: requestedChainId,
      notify: true,
    );

    final future = _fetchWalletTokensFresh(
      walletAddress,
      cacheKey,
      requestedChainId,
      requestedNetworkKey: effectiveNetworkKey,
    );
    _walletTokensInFlight[cacheKey] = future;
    future.whenComplete(() => _walletTokensInFlight.remove(cacheKey));
    return future;
  }

  Future<List<Token>> refreshWalletTokens(
    String walletAddress, {
    int? chainId,
  }) {
    return fetchWalletTokens(
      walletAddress,
      chainId: chainId,
      forceRefresh: true,
    );
  }

  void applyOptimisticSwap({
    required String walletAddress,
    required int chainId,
    required Token fromToken,
    required Token toToken,
    required String fromAmountText,
    required String toAmountText,
  }) {
    final cacheKey = _walletTokenStateKey(chainId, walletAddress);
    final now = DateTime.now();
    final fromAmount = _parseOptimisticTokenAmount(fromAmountText);
    final toAmount = _parseOptimisticTokenAmount(toAmountText);
    if (fromAmount <= 0 && toAmount <= 0) {
      return;
    }

    final existingTokens = getCachedWalletTokens(
      walletAddress,
      chainId: chainId,
    );
    final updatedTokens = _applyOptimisticSwapToTokens(
      existingTokens,
      fromToken: fromToken,
      toToken: toToken,
      fromAmount: fromAmount,
      toAmount: toAmount,
    );

    _walletTokensCache[cacheKey] = _WalletTokensCacheEntry(
      tokens: List<Token>.from(updatedTokens),
      fetchedAt: now,
    );

    final existingState = _walletTokenStates[cacheKey];
    _setWalletTokenState(
      cacheKey,
      (existingState ??
              const WalletTokenState(
                tokens: [],
                source: 'optimistic',
                isLoading: false,
                isStale: true,
              ))
          .copyWith(
            tokens: updatedTokens,
            source: 'optimistic',
            isLoading: false,
            isStale: true,
            lastUpdatedAt: now,
            message: 'Refreshing wallet balances...',
          ),
      chainId: chainId,
      notify: true,
    );

    unawaited(
      _syncHomeSnapshotForWallet(walletAddress, chainId, updatedTokens),
    );
  }

  List<Token> _applyOptimisticSwapToTokens(
    List<Token> source, {
    required Token fromToken,
    required Token toToken,
    required double fromAmount,
    required double toAmount,
  }) {
    final next = List<Token>.from(source);

    if (fromAmount > 0) {
      final fromIndex = next.indexWhere(
        (token) => _tokensMatch(token, fromToken),
      );
      if (fromIndex >= 0) {
        final current = next[fromIndex];
        final nextBalance = max(0.0, current.balance - fromAmount);
        next[fromIndex] = _copyTokenWithBalance(current, nextBalance);
      }
    }

    if (toAmount > 0) {
      final toIndex = next.indexWhere((token) => _tokensMatch(token, toToken));
      if (toIndex >= 0) {
        final current = next[toIndex];
        next[toIndex] = _copyTokenWithBalance(
          current,
          current.balance + toAmount,
        );
      } else {
        next.add(_copyTokenWithBalance(toToken, toAmount));
      }
    }

    return next;
  }

  bool _tokensMatch(Token a, Token b) {
    final aAddress = (a.contractAddress ?? '').trim().toLowerCase();
    final bAddress = (b.contractAddress ?? '').trim().toLowerCase();
    if (aAddress.isNotEmpty || bAddress.isNotEmpty) {
      return aAddress.isNotEmpty && aAddress == bAddress;
    }
    return a.symbol.trim().toLowerCase() == b.symbol.trim().toLowerCase();
  }

  Token _copyTokenWithBalance(Token token, double nextBalance) {
    final nextUnitPrice = token.unitPriceUsd;
    return token.copyWith(
      balance: nextBalance,
      valueUsd: nextUnitPrice > 0
          ? nextBalance * nextUnitPrice
          : token.valueUsd,
    );
  }

  double _parseOptimisticTokenAmount(String rawValue) {
    final normalized = rawValue.trim().replaceAll(',', '');
    if (normalized.isEmpty) {
      return 0.0;
    }
    return double.tryParse(normalized) ?? 0.0;
  }

  Future<List<Token>> _fetchWalletTokensFresh(
    String walletAddress,
    String cacheKey,
    int requestedChainId, {
    String? requestedNetworkKey,
  }) async {
    final effectiveNetworkKey =
        requestedNetworkKey ?? NetworkKey.evm(requestedChainId);
    final effectiveFamily = NetworkKey.familyOf(effectiveNetworkKey);
    final isNonEvm =
        effectiveFamily == ChainFamily.solana ||
        effectiveFamily == ChainFamily.tron;

    final previousState = _walletTokenStates[cacheKey];
    final previousTokens = List<Token>.from(
      previousState?.tokens ?? _walletTokensCache[cacheKey]?.tokens ?? const [],
    );
    final discovered = await _fetchWalletTokensFromBackend(
      walletAddress,
      requestedChainId,
      networkKey: effectiveNetworkKey,
    );
    if (discovered != null) {
      _lastDiscoverySource = discovered.source;
      _lastDiscoveryPartialFailure = discovered.partialFailure;
      _lastDiscoveryTokenCount = discovered.tokenCount;
      _lastDiscoveryMessage = discovered.message;

      // --- Enrich discovered tokens with CoinGecko prices when backend omits them ---
      final String? nativeCoinGeckoId;
      if (effectiveFamily == ChainFamily.solana) {
        nativeCoinGeckoId = 'solana';
      } else if (effectiveFamily == ChainFamily.tron) {
        nativeCoinGeckoId = 'tron';
      } else {
        nativeCoinGeckoId = allChains
            .firstWhere(
              (chain) => chain.chainId == requestedChainId,
              orElse: () => _activeChain,
            )
            .coinGeckoId;
      }

      final enriched = await _tokenPortfolioModule.enrichTokensWithPrices(
        discovered.tokens,
        nativeCoinGeckoId: nativeCoinGeckoId,
      );

      // Merge custom tokens that weren't discovered by the backend.
      final customTokens = _customTokens[requestedChainId] ?? const [];
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
              walletAddress: walletAddress,
              existing: merged,
              knownTokens: _getWellKnownTokens(
                requestedChainId,
                networkKey: effectiveNetworkKey,
              ),
            );
        if (supplemental.isNotEmpty) {
          merged.addAll(supplemental);
        }
      }

      final nextTokens = merged.isEmpty && previousTokens.isNotEmpty
          ? previousTokens
          : merged;
      final nextMessage = merged.isEmpty && previousTokens.isNotEmpty
          ? (discovered.message ??
                'Using cached wallet tokens because the latest backend refresh returned no token entries.')
          : discovered.message;
      final nextStale =
          (merged.isEmpty && previousTokens.isNotEmpty) ||
          discovered.partialFailure;
      final fetchedAt = DateTime.now();
      _walletTokensCache[cacheKey] = _WalletTokensCacheEntry(
        tokens: List<Token>.from(nextTokens),
        fetchedAt: fetchedAt,
      );
      _setWalletTokenState(
        cacheKey,
        WalletTokenState(
          tokens: List<Token>.from(nextTokens),
          source: discovered.source,
          isLoading: false,
          isStale: nextStale,
          lastUpdatedAt: fetchedAt,
          message: nextMessage,
        ),
        chainId: requestedChainId,
        notify: true,
      );
      unawaited(
        _syncHomeSnapshotForWallet(walletAddress, requestedChainId, nextTokens),
      );
      return nextTokens;
    }

    // Non-EVM families (Solana, Tron) have no local RPC fallback — the backend
    // adapter is the only data source. Return whatever we already cached.
    if (isNonEvm) {
      final fetchedAt = DateTime.now();
      final fallbackTokens = previousTokens.isNotEmpty
          ? previousTokens
          : const <Token>[];
      _walletTokensCache[cacheKey] = _WalletTokensCacheEntry(
        tokens: List<Token>.from(fallbackTokens),
        fetchedAt: fetchedAt,
      );
      _setWalletTokenState(
        cacheKey,
        WalletTokenState(
          tokens: List<Token>.from(fallbackTokens),
          source: 'fallback',
          isLoading: false,
          isStale: fallbackTokens.isNotEmpty,
          lastUpdatedAt: fetchedAt,
          message: fallbackTokens.isNotEmpty
              ? 'Using cached tokens — backend temporarily unavailable.'
              : null,
        ),
        chainId: requestedChainId,
        notify: true,
      );
      unawaited(
        _syncHomeSnapshotForWallet(
          walletAddress,
          requestedChainId,
          fallbackTokens,
        ),
      );
      return fallbackTokens;
    }

    final tokens = <Token>[];
    try {
      final nativeBalance = await getNativeBalance(walletAddress);
      final priceIds = <String>[];
      final requestedChain = allChains.firstWhere(
        (chain) => chain.chainId == requestedChainId,
        orElse: () => _activeChain,
      );
      final activeCoinGeckoId = requestedChain.coinGeckoId;
      if (activeCoinGeckoId != null && activeCoinGeckoId.isNotEmpty) {
        priceIds.add(activeCoinGeckoId);
      }

      final builtInTokens = _getWellKnownTokens(requestedChainId);
      final customTokens = _customTokens[requestedChainId] ?? const [];
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
          symbol: requestedChain.symbol,
          name: requestedChain.name,
          balance: nativeBalance,
          valueUsd: nativeBalance * nativePrice,
          priceUsd: nativePrice,
          changePercent24h:
              (activeCoinGeckoId == null || activeCoinGeckoId.isEmpty)
              ? 0.0
              : (prices['${activeCoinGeckoId}_change'] ?? 0.0),
          imageUrl:
              requestedChain.logoUrl ??
              BlockchainCatalog.iconUrlForSymbol(requestedChain.symbol),
          coinGeckoId: activeCoinGeckoId,
          isCertified: true,
          networkKey: requestedChain.networkKey,
          tokenStandard: TokenStandard.native,
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
              networkKey: NetworkKey.evm(requestedChainId),
              tokenStandard: TokenStandard.erc20,
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
            networkKey: custom.networkKey ?? NetworkKey.evm(requestedChainId),
            tokenStandard: custom.tokenStandard,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching tokens: $e');
    }

    var finalTokens = tokens;
    String? fallbackMessage;
    var isStale = false;
    if (previousTokens.isNotEmpty && finalTokens.length <= 1) {
      finalTokens = previousTokens;
      fallbackMessage =
          'Using cached wallet tokens while the latest live refresh is incomplete.';
      isStale = true;
    }
    final fetchedAt = DateTime.now();
    _walletTokensCache[cacheKey] = _WalletTokensCacheEntry(
      tokens: List<Token>.from(finalTokens),
      fetchedAt: fetchedAt,
    );
    _setWalletTokenState(
      cacheKey,
      WalletTokenState(
        tokens: List<Token>.from(finalTokens),
        source: 'fallback',
        isLoading: false,
        isStale: isStale,
        lastUpdatedAt: fetchedAt,
        message: fallbackMessage,
      ),
      chainId: requestedChainId,
      notify: true,
    );
    unawaited(
      _syncHomeSnapshotForWallet(walletAddress, requestedChainId, finalTokens),
    );
    return finalTokens;
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

        final decoded = jsonDecode(response.body);
        // Accept both {"tokens":[...]} style maps and bare [...] arrays.
        List<dynamic> list = const [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map<String, dynamic>) {
          // Try several common wrapper keys in order of likelihood.
          for (final key in const ['tokens', 'results', 'data', 'items']) {
            final candidate = decoded[key];
            if (candidate is List) {
              list = candidate;
              break;
            }
          }
        }
        for (final entry in list) {
          if (entry is! Map<String, dynamic>) continue;
          final symbol = (entry['symbol'] as String?)?.trim() ?? '';
          final name = (entry['name'] as String?)?.trim() ?? '';
          final contractAddress = (entry['contractAddress'] as String?)?.trim();
          // Allow native tokens (no contract address) through the filter.
          if (symbol.isEmpty || name.isEmpty) {
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
              networkKey:
                  _asTrimmedString(entry['networkKey']) ??
                  NetworkKey.evm(_activeChain.chainId),
              tokenStandard: TokenStandardCodec.fromWireValue(
                _asTrimmedString(entry['tokenStandard']),
              ),
            ),
          );
        }
        if (parsed.isNotEmpty) {
          return _deduplicateSearchTokens(parsed).take(safeLimit).toList();
        }
      } catch (_) {
        continue;
      }
    }
    return _localTokenSearchFallback(trimmed, safeLimit);
  }

  List<Token> _localTokenSearchFallback(String query, int limit) {
    final normalized = query.toLowerCase();
    final customTokens = (_customTokens[_activeChain.chainId] ?? const [])
        .map(
          (token) => Token(
            symbol: token.symbol,
            name: token.name,
            contractAddress: token.address,
            balance: 0,
            valueUsd: 0,
            changePercent24h: 0,
            decimals: token.decimals,
            imageUrl: token.imageUrl,
            coinGeckoId: token.coinGeckoId,
            isCertified: false,
            networkKey:
                token.networkKey ?? NetworkKey.evm(_activeChain.chainId),
            tokenStandard: token.tokenStandard,
          ),
        )
        .toList();
    final candidates = _deduplicateSearchTokens([
      ..._walletTokens,
      ...customTokens,
      ...customTokensForActiveChain.map(
        (token) => Token(
          symbol: token.symbol,
          name: token.name,
          contractAddress: token.address,
          balance: 0,
          valueUsd: 0,
          changePercent24h: 0,
          decimals: token.decimals,
          imageUrl: token.imageUrl,
          coinGeckoId: token.coinGeckoId,
          isCertified: false,
          networkKey: token.networkKey ?? NetworkKey.evm(_activeChain.chainId),
          tokenStandard: token.tokenStandard,
        ),
      ),
    ]);

    final filtered = candidates.where((token) {
      if (normalized.isEmpty) {
        return true;
      }
      return token.symbol.toLowerCase().contains(normalized) ||
          token.name.toLowerCase().contains(normalized) ||
          (token.contractAddress?.toLowerCase().contains(normalized) ?? false);
    }).toList();
    return filtered.take(limit).toList();
  }

  List<Token> _deduplicateSearchTokens(List<Token> tokens) {
    final seen = <String>{};
    final result = <Token>[];
    for (final token in tokens) {
      final key =
          (token.contractAddress?.trim().isNotEmpty == true
                  ? token.contractAddress
                  : token.symbol)
              ?.toLowerCase();
      if (key == null || !seen.add(key)) {
        continue;
      }
      result.add(token);
    }
    return result;
  }

  // ─── BACKEND DISCOVERY WITH CIRCUIT BREAKER ───────

  Future<_BackendWalletTokensResponse?> _fetchWalletTokensFromBackend(
    String walletAddress,
    int chainId, {
    String? networkKey,
  }) async {
    final now = DateTime.now();
    final discoveryBases = [AppEnvironment.blockchain('').toString()];

    for (final base in discoveryBases) {
      // Circuit breaker check
      final breaker = _circuitBreakers.putIfAbsent(
        'discovery_$base',
        () => _CircuitBreakerState(
          currentBackoff: _circuitBreakerInitialBackoff,
          failureThreshold: _circuitBreakerFailureThreshold,
        ),
      );

      if (breaker.isOpen()) {
        debugPrint('Circuit breaker OPEN for discovery endpoint $base');
        continue;
      }

      final backoff = _backendDiscoveryBackoffUntil[base];
      if (backoff != null && now.isBefore(backoff)) continue;

      final normalizedBase = base.endsWith('/')
          ? base.substring(0, base.length - 1)
          : base;
      final resolvedNetworkKey = networkKey ?? NetworkKey.evm(chainId);
      final urls = _walletTokenDiscoveryUris(
        normalizedBase,
        resolvedNetworkKey,
        chainId,
        walletAddress,
      );

      for (var i = 0; i < urls.length; i++) {
        final url = urls[i];
        final isLastUrl = i == urls.length - 1;
        try {
          final response = await _httpClientService
              .sendWithRetry(() => _httpClientService.client.get(url))
              .timeout(_backendDiscoveryTimeout);

          if (response.statusCode == 200) {
            _backendDiscoveryBackoffUntil.remove(base);
            breaker.reset(_circuitBreakerInitialBackoff);
            final result = _parseBackendDiscoveredTokens(response.body);
            _metrics.recordDiscoveryCall(
              success: true,
              usedFallback: result?.source != 'alchemy',
            );
            return result;
          }

          if (!isLastUrl) {
            continue;
          }

          // Non-200 response
          breaker.recordFailure(_circuitBreakerMaxBackoff);
          _metrics.recordEndpointFailure('discovery_$base');
          _backendDiscoveryBackoffUntil[base] = DateTime.now().add(
            _calculateBackoffWithJitter(breaker.failureCount),
          );
        } catch (e) {
          if (!isLastUrl) {
            debugPrint('Canonical backend discovery failed for $url: $e');
            continue;
          }
          debugPrint('Backend discovery failed for $base: $e');
          breaker.recordFailure(_circuitBreakerMaxBackoff);
          _metrics.recordEndpointFailure('discovery_$base');
          _backendDiscoveryBackoffUntil[base] = DateTime.now().add(
            _calculateBackoffWithJitter(breaker.failureCount),
          );
        }
      }
    }

    _metrics.recordDiscoveryCall(success: false, usedFallback: false);
    return null;
  }

  @visibleForTesting
  List<Uri> walletTokenDiscoveryUrisForTest(
    String normalizedBase,
    int chainId,
    String walletAddress,
  ) {
    return _walletTokenDiscoveryUris(
      normalizedBase,
      NetworkKey.evm(chainId),
      chainId,
      walletAddress,
    );
  }

  List<Uri> _walletTokenDiscoveryUris(
    String normalizedBase,
    String networkKey,
    int chainId,
    String walletAddress,
  ) {
    final encodedNetworkKey = Uri.encodeComponent(networkKey);
    final uris = [
      Uri.parse(
        '$normalizedBase/networks/$encodedNetworkKey/wallet-tokens/$walletAddress',
      ),
    ];
    // For EVM, also try the legacy numeric chainId path as a fallback.
    if (NetworkKey.familyOf(networkKey) == ChainFamily.evm) {
      uris.add(
        Uri.parse('$normalizedBase/$chainId/wallet-tokens/$walletAddress'),
      );
    }
    return uris;
  }

  @visibleForTesting
  List<Token>? parseBackendDiscoveredTokensForTest(String body) {
    return _parseBackendDiscoveredTokens(body)?.tokens;
  }

  _BackendWalletTokensResponse? _parseBackendDiscoveredTokens(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final list = data['tokens'] as List<dynamic>? ?? [];
      final discovery = data['discovery'] as Map<String, dynamic>? ?? const {};
      final payloadNetworkKey =
          _asTrimmedString(data['networkKey']) ??
          NetworkKey.evm(_toInt(data['chainId']) ?? _activeChain.chainId);

      final tokens = list.map((entry) {
        final e = _asMap(entry) ?? const <String, dynamic>{};
        final contractAddress = _asTrimmedString(e['contractAddress']);
        final tokenStandard = TokenStandardCodec.fromWireValue(
          _asTrimmedString(e['tokenStandard']) ??
              (contractAddress == null ? 'native' : 'erc20'),
        );
        return Token(
          symbol: e['symbol']?.toString() ?? '',
          name: e['name']?.toString() ?? '',
          contractAddress: contractAddress,
          balance: _toDouble(e['balance']),
          valueUsd: _toDouble(e['valueUsd']),
          priceUsd: _toDouble(e['priceUsd']),
          changePercent24h: _toDouble(e['changePercent24h']),
          decimals: _toInt(e['decimals']) ?? 18,
          imageUrl: _asTrimmedString(e['imageUrl']),
          coinGeckoId: _asTrimmedString(e['coinGeckoId']),
          isCertified: e['isCertified'] == true,
          networkKey: _asTrimmedString(e['networkKey']) ?? payloadNetworkKey,
          tokenStandard: tokenStandard,
        );
      }).toList();

      final expectedCount = _toInt(discovery['tokenCount']) ?? tokens.length;
      if (expectedCount != tokens.length) {
        _metrics.recordTokenMismatch();
      }

      return _BackendWalletTokensResponse(
        tokens: tokens,
        source: (discovery['source'] as String?)?.trim().isNotEmpty == true
            ? (discovery['source'] as String)
            : 'unknown',
        partialFailure: discovery['partialFailure'] == true,
        tokenCount: expectedCount,
        message: (discovery['message'] as String?)?.trim(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshTrackedTokenPrices() async {
    final trackedIds = _effectiveTrackedPriceIds;
    if (_isLivePriceTicking || trackedIds.isEmpty || _walletTokens.isEmpty) {
      return;
    }

    _isLivePriceTicking = true;
    final startTime = DateTime.now();

    try {
      final prices = await getTokenPrices(trackedIds.toList());
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
        return token.copyWith(
          valueUsd: token.balance * nextPrice,
          priceUsd: nextPrice,
          changePercent24h: nextChange,
        );
      }).toList();

      if (changed) {
        _walletTokens = updated;
        notifyListeners();
      }

      // Record latency metric
      final latency = DateTime.now().difference(startTime);
      _metrics.recordPriceRefresh(latency: latency);
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

  Set<String> get _effectiveTrackedPriceIds {
    final merged = <String>{};
    for (final ids in _trackedPriceIdsByScope.values) {
      merged.addAll(ids);
    }
    return merged;
  }

  void _reconfigureLivePriceTimer() {
    final trackedIds = _effectiveTrackedPriceIds;
    if (trackedIds.isEmpty) {
      _stopLivePriceTimer();
      return;
    }

    final interval = _livePriceIntervalsByScope.values.isEmpty
        ? const Duration(seconds: 10)
        : _livePriceIntervalsByScope.values.reduce((a, b) => a <= b ? a : b);

    _livePriceInterval = interval;
    _livePriceTimer?.cancel();

    final jitter = _getJitter();
    Future.delayed(jitter, () {
      if (_effectiveTrackedPriceIds.isNotEmpty) {
        unawaited(_refreshTrackedTokenPrices());
      }
    });

    _livePriceTimer = Timer.periodic(_livePriceInterval, (_) {
      unawaited(_refreshTrackedTokenPrices());
    });
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
    _applyCustomTokenMutationToLocalState(chainId, addedToken: token);
    unawaited(_syncWalletTokenSnapshotsForChain(chainId));
    notifyListeners();
    return true;
  }

  Future<void> removeCustomToken(int chainId, String address) async {
    final list = _customTokens[chainId];
    if (list == null) return;
    list.removeWhere((t) => t.address.toLowerCase() == address.toLowerCase());
    await _saveCustomTokens();
    _applyCustomTokenMutationToLocalState(chainId, removedAddress: address);
    unawaited(_syncWalletTokenSnapshotsForChain(chainId));
    notifyListeners();
  }

  void _applyCustomTokenMutationToLocalState(
    int chainId, {
    CustomTokenDefinition? addedToken,
    String? removedAddress,
  }) {
    if (addedToken == null &&
        (removedAddress == null || removedAddress.trim().isEmpty)) {
      return;
    }

    final now = DateTime.now();
    final updatedCacheEntries = <String, _WalletTokensCacheEntry>{};
    for (final entry in _walletTokensCache.entries) {
      if (!entry.key.startsWith('$chainId:')) {
        continue;
      }

      var nextTokens = List<Token>.from(entry.value.tokens);
      if (addedToken != null) {
        nextTokens = _upsertCustomTokenIntoList(nextTokens, addedToken);
      }
      if (removedAddress != null && removedAddress.trim().isNotEmpty) {
        nextTokens = _removeCustomTokenFromList(nextTokens, removedAddress);
      }

      updatedCacheEntries[entry.key] = _WalletTokensCacheEntry(
        tokens: nextTokens,
        fetchedAt: now,
      );
    }

    if (updatedCacheEntries.isNotEmpty) {
      _walletTokensCache.addAll(updatedCacheEntries);
    }

    final updatedStates = <String, WalletTokenState>{};
    for (final entry in _walletTokenStates.entries) {
      if (!entry.key.startsWith('$chainId:')) {
        continue;
      }

      var nextTokens = List<Token>.from(entry.value.tokens);
      if (addedToken != null) {
        nextTokens = _upsertCustomTokenIntoList(nextTokens, addedToken);
      }
      if (removedAddress != null && removedAddress.trim().isNotEmpty) {
        nextTokens = _removeCustomTokenFromList(nextTokens, removedAddress);
      }

      updatedStates[entry.key] = entry.value.copyWith(
        tokens: nextTokens,
        lastUpdatedAt: now,
      );
    }

    if (updatedStates.isNotEmpty) {
      _walletTokenStates.addAll(updatedStates);
    }

    if (_activeChain.chainId != chainId) {
      return;
    }

    var currentTokens = _walletTokens.isNotEmpty
        ? List<Token>.from(_walletTokens)
        : List<Token>.from(tokens);
    if (addedToken != null) {
      currentTokens = _upsertCustomTokenIntoList(currentTokens, addedToken);
    }
    if (removedAddress != null && removedAddress.trim().isNotEmpty) {
      currentTokens = _removeCustomTokenFromList(currentTokens, removedAddress);
    }
    _walletTokens = currentTokens;
  }

  Future<void> _syncWalletTokenSnapshotsForChain(int chainId) async {
    for (final entry in _walletTokenStates.entries) {
      if (!entry.key.startsWith('$chainId:')) {
        continue;
      }
      final separatorIndex = entry.key.indexOf(':');
      if (separatorIndex <= 0 || separatorIndex >= entry.key.length - 1) {
        continue;
      }
      final walletAddress = entry.key.substring(separatorIndex + 1);
      await _syncHomeSnapshotForWallet(
        walletAddress,
        chainId,
        entry.value.tokens,
      );
    }
  }

  List<Token> _upsertCustomTokenIntoList(
    List<Token> source,
    CustomTokenDefinition token,
  ) {
    final normalizedAddress = token.address.toLowerCase();
    if (source.any(
      (existing) =>
          (existing.contractAddress ?? '').toLowerCase() == normalizedAddress,
    )) {
      return List<Token>.from(source);
    }

    final next = List<Token>.from(source);
    next.add(
      Token(
        symbol: token.symbol,
        name: token.name,
        contractAddress: token.address,
        balance: 0,
        valueUsd: 0,
        priceUsd: 0,
        changePercent24h: 0,
        decimals: token.decimals,
        imageUrl: token.imageUrl,
        coinGeckoId: token.coinGeckoId,
        isCertified: false,
        networkKey: token.networkKey ?? NetworkKey.evm(_activeChain.chainId),
        tokenStandard: token.tokenStandard,
      ),
    );
    return next;
  }

  List<Token> _removeCustomTokenFromList(List<Token> source, String address) {
    final normalizedAddress = address.toLowerCase();
    return source.where((token) {
      final contractAddress = (token.contractAddress ?? '').toLowerCase();
      if (contractAddress != normalizedAddress) {
        return true;
      }
      return token.balance > 0;
    }).toList();
  }

  List<Map<String, String>> _getWellKnownTokens(
    int chainId, {
    String? networkKey,
  }) {
    final key = networkKey ?? NetworkKey.evm(chainId);
    final family = NetworkKey.familyOf(key);

    if (family == ChainFamily.solana) {
      return [
        {
          'symbol': 'USDC',
          'name': 'USD Coin',
          'address': 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
          'decimals': '6',
          'coinGeckoId': 'usd-coin',
        },
        {
          'symbol': 'USDT',
          'name': 'Tether',
          'address': 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB',
          'decimals': '6',
          'coinGeckoId': 'tether',
        },
      ];
    }

    if (family == ChainFamily.tron) {
      return [
        {
          'symbol': 'USDT',
          'name': 'Tether',
          'address': 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
          'decimals': '6',
          'coinGeckoId': 'tether',
        },
        {
          'symbol': 'USDC',
          'name': 'USD Coin',
          'address': 'TEkxiTehnzSmSe2XqrBj4w32RUN966rdz8',
          'decimals': '6',
          'coinGeckoId': 'usd-coin',
        },
      ];
    }

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
      // Use the override key when on Solana/Tron, otherwise use the EVM chain key.
      final selectedNetworkKey = _activeNetworkKeyOverride.isNotEmpty
          ? _activeNetworkKeyOverride
          : _activeChain.networkKey;
      final payload = {
        'walletAddress': walletAddress,
        'selectedChainId': _activeChain.chainId,
        'selectedNetworkKey': selectedNetworkKey,
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
      final selectedNetworkKey = data['selectedNetworkKey']?.toString();
      final selected =
          NetworkKey.evmChainIdOf(selectedNetworkKey) ??
          _toInt(data['selectedChainId']);

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

  String? _asTrimmedString(dynamic v) {
    final text = v?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
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

class WalletTokenState {
  final List<Token> tokens;
  final String source;
  final bool isLoading;
  final bool isStale;
  final DateTime? lastUpdatedAt;
  final String? message;

  const WalletTokenState({
    required this.tokens,
    required this.source,
    required this.isLoading,
    required this.isStale,
    this.lastUpdatedAt,
    this.message,
  });

  WalletTokenState copyWith({
    List<Token>? tokens,
    String? source,
    bool? isLoading,
    bool? isStale,
    DateTime? lastUpdatedAt,
    String? message,
  }) {
    return WalletTokenState(
      tokens: tokens ?? this.tokens,
      source: source ?? this.source,
      isLoading: isLoading ?? this.isLoading,
      isStale: isStale ?? this.isStale,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      message: message ?? this.message,
    );
  }
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
