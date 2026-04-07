enum ChainFamily { evm, solana }

extension ChainFamilyCodec on ChainFamily {
  String get wireValue => switch (this) {
    ChainFamily.evm => 'evm',
    ChainFamily.solana => 'solana',
  };

  static ChainFamily fromWireValue(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'solana' => ChainFamily.solana,
      _ => ChainFamily.evm,
    };
  }
}

/// EVM Chain configuration
class EvmChain {
  final String name;
  final String symbol;
  final int chainId;
  final String rpcUrl;
  final String? coinGeckoId;
  final String? explorerUrl;
  final String? logoUrl;
  final bool isCustom;
  final ChainFamily family;

  const EvmChain({
    required this.name,
    required this.symbol,
    required this.chainId,
    required this.rpcUrl,
    this.coinGeckoId,
    this.explorerUrl,
    this.logoUrl,
    this.isCustom = false,
    this.family = ChainFamily.evm,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'symbol': symbol,
    'chainId': chainId,
    'rpcUrl': rpcUrl,
    'coinGeckoId': coinGeckoId,
    'explorerUrl': explorerUrl,
    'logoUrl': logoUrl,
    'isCustom': isCustom,
    'family': family.wireValue,
  };

  factory EvmChain.fromJson(Map<String, dynamic> json) => EvmChain(
    name: json['name'] as String,
    symbol: json['symbol'] as String,
    chainId: json['chainId'] as int,
    rpcUrl: json['rpcUrl'] as String,
    coinGeckoId: json['coinGeckoId'] as String?,
    explorerUrl: json['explorerUrl'] as String?,
    logoUrl: json['logoUrl'] as String?,
    isCustom: json['isCustom'] as bool? ?? false,
    family: ChainFamilyCodec.fromWireValue(json['family'] as String?),
  );
}

/// Solana chain metadata scaffold for future multi-family wallet support.
class SolanaChain {
  final String name;
  final String symbol;
  final String cluster;
  final String rpcUrl;
  final String? coinGeckoId;
  final String? explorerUrl;
  final String? logoUrl;
  final ChainFamily family;

  const SolanaChain({
    required this.name,
    required this.symbol,
    required this.cluster,
    required this.rpcUrl,
    this.coinGeckoId,
    this.explorerUrl,
    this.logoUrl,
    this.family = ChainFamily.solana,
  });

  bool get isMainnet => cluster == 'mainnet-beta';

  Map<String, dynamic> toJson() => {
    'name': name,
    'symbol': symbol,
    'cluster': cluster,
    'rpcUrl': rpcUrl,
    'coinGeckoId': coinGeckoId,
    'explorerUrl': explorerUrl,
    'logoUrl': logoUrl,
    'family': family.wireValue,
  };

  factory SolanaChain.fromJson(Map<String, dynamic> json) => SolanaChain(
    name: json['name'] as String,
    symbol: json['symbol'] as String,
    cluster: json['cluster'] as String,
    rpcUrl: json['rpcUrl'] as String,
    coinGeckoId: json['coinGeckoId'] as String?,
    explorerUrl: json['explorerUrl'] as String?,
    logoUrl: json['logoUrl'] as String?,
    family: ChainFamilyCodec.fromWireValue(json['family'] as String?),
  );
}

class CustomTokenDefinition {
  final String symbol;
  final String name;
  final String address;
  final int decimals;
  final String? coinGeckoId;
  final String? imageUrl;

  const CustomTokenDefinition({
    required this.symbol,
    required this.name,
    required this.address,
    required this.decimals,
    this.coinGeckoId,
    this.imageUrl,
  });

  factory CustomTokenDefinition.fromJson(Map<String, dynamic> json) {
    return CustomTokenDefinition(
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      decimals: json['decimals'] as int,
      coinGeckoId: json['coinGeckoId'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name': name,
    'address': address,
    'decimals': decimals,
    'coinGeckoId': coinGeckoId,
    'imageUrl': imageUrl,
  };
}
