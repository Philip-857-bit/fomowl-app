/// EVM Chain configuration
class EvmChain {
  final String name;
  final String symbol;
  final int chainId;
  final String rpcUrl;
  final String? coinGeckoId;
  final String? explorerUrl;
  final bool isCustom;

  const EvmChain({
    required this.name,
    required this.symbol,
    required this.chainId,
    required this.rpcUrl,
    this.coinGeckoId,
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
    coinGeckoId: json['coinGeckoId'] as String?,
    explorerUrl: json['explorerUrl'] as String?,
    isCustom: json['isCustom'] as bool? ?? false,
  );
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
