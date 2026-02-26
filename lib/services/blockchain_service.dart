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
  static const String _backendRpcBase = 'https://fomowl-backend.onrender.com/api/blockchain';

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
        coinGeckoId: activeChain.coinGeckoId.isNotEmpty ? activeChain.coinGeckoId : null,
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
        _customChains = list.map((e) => EvmChain.fromJson(e as Map<String, dynamic>)).toList();
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
      final Map<String, dynamic> data = jsonDecode(jsonStr) as Map<String, dynamic>;
      data.forEach((key, value) {
        final chainId = int.tryParse(key);
        if (chainId == null) return;
        final list = (value as List)
            .map((entry) => CustomTokenDefinition.fromJson(entry as Map<String, dynamic>))
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
      final data = _customTokens.map((key, value) => MapEntry(
            key.toString(),
            value.map((t) => t.toJson()).toList(),
          ));
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
      final response = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'eth_chainId',
          'params': [],
          'id': 1,
        }),
      ).timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ─── RPC HELPERS ─────────────────────────────────

  String get _rpcUrl => _activeChain.rpcUrl;

  Future<dynamic> _rpcCall(String method, List<dynamic> params) async {
    try {
      final response = await http.post(
        Uri.parse(_rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': method,
          'params': params,
          'id': 1,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) {
          debugPrint('RPC error: ${data['error']}');
          return null;
        }
        return data['result'];
      }
    } catch (e) {
      debugPrint('RPC call failed ($method): $e');
    }
    return null;
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
    final totalFeeUsd = totalFeeNative * nativePriceUsd;
    return {
      'gasGwei': gasPriceGwei,
      'gasLimitUnits': gasLimit.toDouble(),
      'totalFeeEth': totalFeeNative,
      'totalFeeUsd': totalFeeUsd,
    };
  }

  // ─── PRICE DATA ──────────────────────────────────

// Top-level function for Isolate
List<double> _parsePriceHistory(String responseBody) {
  try {
    final data = jsonDecode(responseBody);
    final prices = data['prices'] as List;
    return prices.map<double>((p) => (p[1] as num).toDouble()).toList();
  } catch(e) {
    return [];
  }
}

  Future<List<double>> getPriceHistory(String coinId, {int days = 7}) async {
    try {
      final url = '$priceApiBase/coins/$coinId/market_chart?vs_currency=usd&days=$days';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return await compute(_parsePriceHistory, response.body);
      }
    } catch (e) {
      debugPrint('Error fetching price history: $e');
    }
    return [];
  }

  Future<Map<String, double>> getTokenPrices(List<String> tokenIds) async {
    if (tokenIds.isEmpty) return {};
    try {
      final ids = tokenIds.join(',');
      final url = '$priceApiBase/simple/price?ids=$ids&vs_currencies=usd&include_24hr_change=true';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final prices = <String, double>{};
        data.forEach((key, value) {
          if (value is Map && value['usd'] != null) {
            prices[key] = (value['usd'] as num).toDouble();
            if (value['usd_24h_change'] != null) {
              prices['${key}_change'] = (value['usd_24h_change'] as num).toDouble();
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
    try {
      final url = '$priceApiBase/coins/$coinId?localization=false&tickers=false&community_data=false&developer_data=false&sparkline=false';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final marketData = data['market_data'] as Map<String, dynamic>?;
        if (marketData == null) return null;

        double? toDouble(dynamic value) {
          if (value == null) return null;
          if (value is num) return value.toDouble();
          if (value is String && value.isNotEmpty) return double.tryParse(value);
          return null;
        }

        final marketCapMap = marketData['market_cap'] as Map<String, dynamic>?;
        final currentPriceMap = marketData['current_price'] as Map<String, dynamic>?;
        return TokenMarketData(
          priceUsd: toDouble(currentPriceMap?['usd']),
          marketCapUsd: toDouble(marketCapMap?['usd']),
          totalSupply: toDouble(marketData['total_supply']),
          circulatingSupply: toDouble(marketData['circulating_supply']),
          genesisDate: data['genesis_date'] as String?,
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

  Future<int> getTransactionCount(String address) async {
    final result = await _rpcCall('eth_getTransactionCount', [address, 'latest']);
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

      tokens.add(Token(
        symbol: chain.symbol,
        name: chain.name,
        balance: nativeBalance,
        valueUsd: nativeBalance * nativePrice,
        priceUsd: nativePrice,
        changePercent24h: nativeChange,
        imageUrl: _getIconUrl(chain.symbol),
        coinGeckoId: chain.coinGeckoId.isNotEmpty ? chain.coinGeckoId : null,
      ));

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
      tokens.add(Token(
        symbol: chain.symbol,
        name: chain.name,
        balance: 0,
        valueUsd: 0,
        changePercent24h: 0,
        coinGeckoId: chain.coinGeckoId.isNotEmpty ? chain.coinGeckoId : null,
      ));
    }

    _walletTokens = tokens;
    notifyListeners();
    return tokens;
  }

  List<Map<String, String>> _getWellKnownTokens(int chainId) {
    List<Map<String, String>> tokens;
    switch (chainId) {
      case 1:
        tokens = [
          {'symbol': 'USDC', 'name': 'USD Coin', 'address': '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', 'decimals': '6', 'coinGeckoId': 'usd-coin'},
          {'symbol': 'USDT', 'name': 'Tether', 'address': '0xdAC17F958D2ee523a2206206994597C13D831ec7', 'decimals': '6', 'coinGeckoId': 'tether'},
        ];
        break;
      case 56:
        tokens = [
          {'symbol': 'USDC', 'name': 'USD Coin', 'address': '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d', 'decimals': '18', 'coinGeckoId': 'usd-coin'},
          {'symbol': 'USDT', 'name': 'Tether', 'address': '0x55d398326f99059fF775485246999027B3197955', 'decimals': '18', 'coinGeckoId': 'tether'},
        ];
        break;
      case 137:
        tokens = [
          {'symbol': 'USDC', 'name': 'USD Coin', 'address': '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359', 'decimals': '6', 'coinGeckoId': 'usd-coin'},
          {'symbol': 'USDT', 'name': 'Tether', 'address': '0xc2132D05D31c914a87C6611C10748AEb04B58e8F', 'decimals': '6', 'coinGeckoId': 'tether'},
        ];
        break;
      case 42161:
        tokens = [
          {'symbol': 'USDC', 'name': 'USD Coin', 'address': '0xaf88d065e77c8cC2239327C5EDb3A432268e5831', 'decimals': '6', 'coinGeckoId': 'usd-coin'},
          {'symbol': 'USDT', 'name': 'Tether', 'address': '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9', 'decimals': '6', 'coinGeckoId': 'tether'},
        ];
      default:
        tokens = [];
    }
    final custom = _customTokens[chainId] ?? [];
    tokens.addAll(custom.map((t) => {
          'symbol': t.symbol,
          'name': t.name,
          'address': t.address,
          'decimals': t.decimals.toString(),
          'coinGeckoId': t.coinGeckoId ?? '',
        }));
    return tokens;
  }

  Future<bool> addCustomToken({
    required int chainId,
    required CustomTokenDefinition token,
  }) async {
    final list = _customTokens.putIfAbsent(chainId, () => []);
    if (list.any((t) => t.address.toLowerCase() == token.address.toLowerCase())) {
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
      case 'ETH': return 'https://cryptologos.cc/logos/ethereum-eth-logo.png';
      case 'BNB': return 'https://cryptologos.cc/logos/bnb-bnb-logo.png';
      case 'MATIC': return 'https://cryptologos.cc/logos/polygon-matic-logo.png';
      case 'AVAX': return 'https://cryptologos.cc/logos/avalanche-avax-logo.png';
      case 'FTM': return 'https://cryptologos.cc/logos/fantom-ftm-logo.png';
      case 'USDC': return 'https://cryptologos.cc/logos/usd-coin-usdc-logo.png';
      case 'USDT': return 'https://cryptologos.cc/logos/tether-usdt-logo.png';
      default: return null;
    }
  }

  String _padAddress(String address) {
    final addr = address.startsWith('0x') ? address.substring(2) : address;
    return addr.padLeft(64, '0');
  }
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
