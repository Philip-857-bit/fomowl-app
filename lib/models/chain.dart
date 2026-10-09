import 'token_standard.dart';

enum ChainFamily { evm, solana, tron, bitcoin }

extension ChainFamilyCodec on ChainFamily {
  String get wireValue => switch (this) {
    ChainFamily.evm => 'evm',
    ChainFamily.solana => 'solana',
    ChainFamily.tron => 'tron',
    ChainFamily.bitcoin => 'bitcoin',
  };

  static ChainFamily fromWireValue(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'solana' => ChainFamily.solana,
      'tron' => ChainFamily.tron,
      'bitcoin' => ChainFamily.bitcoin,
      _ => ChainFamily.evm,
    };
  }
}

class NetworkKey {
  const NetworkKey._();

  static String evm(int chainId) => 'evm:$chainId';

  static String solana(String cluster) => 'solana:${_solanaNetworkId(cluster)}';

  static String tron(String networkId) => 'tron:${networkId.trim()}';

  static String bitcoin(String networkId) {
    final id = networkId.trim().toLowerCase();
    if (id != 'mainnet' && id != 'testnet4') {
      throw const FormatException('Unsupported Bitcoin network');
    }
    return 'bitcoin:$id';
  }

  static String? bitcoinNetworkIdOf(String? networkKey) {
    final key = networkKey?.trim().toLowerCase();
    return switch (key) {
      'bitcoin:mainnet' => 'mainnet',
      'bitcoin:testnet4' => 'testnet4',
      _ => null,
    };
  }

  static ChainFamily familyOf(String? networkKey) {
    final trimmed = networkKey?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return ChainFamily.evm;
    }
    return ChainFamilyCodec.fromWireValue(trimmed.split(':').first);
  }

  static int? evmChainIdOf(String? networkKey) {
    final parts = networkKey?.trim().split(':') ?? const [];
    if (parts.length != 2 || parts[0].toLowerCase() != 'evm') {
      return null;
    }
    return int.tryParse(parts[1]);
  }

  static String _solanaNetworkId(String cluster) {
    final normalized = cluster.trim().toLowerCase();
    return normalized == 'mainnet-beta' ? 'mainnet' : normalized;
  }
}

/// Dedicated compatibility IDs for legacy UI token buckets only; never EVM chain IDs.
class BitcoinLegacyUiIds {
  static const mainnet = -840;
  static const testnet4 = -841;
  static int forNetworkKey(String key) => switch (key) {
    'bitcoin:mainnet' => mainnet,
    'bitcoin:testnet4' => testnet4,
    _ => throw const FormatException('Invalid Bitcoin network'),
  };
  static String networkKey(int id) => switch (id) {
    mainnet => NetworkKey.bitcoin('mainnet'),
    testnet4 => NetworkKey.bitcoin('testnet4'),
    _ => throw const FormatException('Invalid Bitcoin compatibility ID'),
  };
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

  String get networkKey => switch (family) {
    ChainFamily.solana => NetworkKey.solana('mainnet'),
    ChainFamily.tron => NetworkKey.tron('mainnet'),
    ChainFamily.evm => NetworkKey.evm(chainId),
    ChainFamily.bitcoin => BitcoinLegacyUiIds.networkKey(chainId),
  };

  Map<String, dynamic> toJson() => {
    'name': name,
    'symbol': symbol,
    'chainId': chainId,
    'networkKey': networkKey,
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
    chainId:
        (json['chainId'] as num?)?.toInt() ??
        NetworkKey.evmChainIdOf(json['networkKey'] as String?) ??
        1,
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
  String get networkId => cluster == 'mainnet-beta' ? 'mainnet' : cluster;
  String get networkKey => NetworkKey.solana(cluster);

  Map<String, dynamic> toJson() => {
    'name': name,
    'symbol': symbol,
    'networkKey': networkKey,
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
    cluster:
        json['cluster'] as String? ??
        _solanaClusterFromNetworkKey(json['networkKey'] as String?),
    rpcUrl: json['rpcUrl'] as String,
    coinGeckoId: json['coinGeckoId'] as String?,
    explorerUrl: json['explorerUrl'] as String?,
    logoUrl: json['logoUrl'] as String?,
    family: ChainFamilyCodec.fromWireValue(json['family'] as String?),
  );
}

class TronChain {
  final String name;
  final String symbol;
  final String networkId;
  final String rpcUrl;
  final String? coinGeckoId;
  final String? explorerUrl;
  final String? logoUrl;
  final ChainFamily family;

  const TronChain({
    required this.name,
    required this.symbol,
    required this.networkId,
    required this.rpcUrl,
    this.coinGeckoId,
    this.explorerUrl,
    this.logoUrl,
    this.family = ChainFamily.tron,
  });

  bool get isMainnet => networkId == 'mainnet';
  String get networkKey => NetworkKey.tron(networkId);

  Map<String, dynamic> toJson() => {
    'name': name,
    'symbol': symbol,
    'networkKey': networkKey,
    'networkId': networkId,
    'rpcUrl': rpcUrl,
    'coinGeckoId': coinGeckoId,
    'explorerUrl': explorerUrl,
    'logoUrl': logoUrl,
    'family': family.wireValue,
  };

  factory TronChain.fromJson(Map<String, dynamic> json) => TronChain(
    name: json['name'] as String,
    symbol: json['symbol'] as String,
    networkId:
        json['networkId'] as String? ??
        _networkIdFromNetworkKey(json['networkKey'] as String?, 'mainnet'),
    rpcUrl: json['rpcUrl'] as String,
    coinGeckoId: json['coinGeckoId'] as String?,
    explorerUrl: json['explorerUrl'] as String?,
    logoUrl: json['logoUrl'] as String?,
    family: ChainFamilyCodec.fromWireValue(json['family'] as String?),
  );
}

/// Bitcoin metadata has no direct provider/RPC URL; public chain facts come from the backend.
class BitcoinChain {
  final String name;
  final String symbol;
  final String networkId;
  final String? coinGeckoId;
  final String explorerUrl;
  final String logoUrl;
  const BitcoinChain({
    required this.name,
    this.symbol = 'BTC',
    required this.networkId,
    this.coinGeckoId = 'bitcoin',
    required this.explorerUrl,
    required this.logoUrl,
  });
  ChainFamily get family => ChainFamily.bitcoin;
  int get decimals => 8;
  bool get isMainnet => networkId == 'mainnet';
  String get networkKey => NetworkKey.bitcoin(networkId);
  Map<String, dynamic> toJson() => {
    'name': name,
    'symbol': symbol,
    'networkId': networkId,
    'networkKey': networkKey,
    'family': family.wireValue,
    'decimals': decimals,
    'coinGeckoId': coinGeckoId,
    'explorerUrl': explorerUrl,
    'logoUrl': logoUrl,
  };
  factory BitcoinChain.fromJson(Map<String, dynamic> json) {
    final id =
        json['networkId'] as String? ??
        NetworkKey.bitcoinNetworkIdOf(json['networkKey'] as String?);
    if (id == null) throw const FormatException('Invalid Bitcoin network');
    NetworkKey.bitcoin(id);
    return BitcoinChain(
      name: json['name'] as String,
      symbol: json['symbol'] as String? ?? 'BTC',
      networkId: id,
      coinGeckoId: json['coinGeckoId'] as String?,
      explorerUrl: json['explorerUrl'] as String,
      logoUrl: json['logoUrl'] as String,
    );
  }
}

class CustomTokenDefinition {
  final String symbol;
  final String name;
  final String address;
  final int decimals;
  final String? coinGeckoId;
  final String? imageUrl;
  final String? networkKey;
  final TokenStandard tokenStandard;
  final bool isCertified;

  const CustomTokenDefinition({
    required this.symbol,
    required this.name,
    required this.address,
    required this.decimals,
    this.coinGeckoId,
    this.imageUrl,
    this.networkKey,
    this.tokenStandard = TokenStandard.erc20,
    this.isCertified = false,
  });

  factory CustomTokenDefinition.fromJson(Map<String, dynamic> json) {
    return CustomTokenDefinition(
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      decimals: json['decimals'] as int,
      coinGeckoId: json['coinGeckoId'] as String?,
      imageUrl: json['imageUrl'] as String?,
      networkKey: json['networkKey'] as String?,
      tokenStandard: TokenStandardCodec.fromWireValue(
        json['tokenStandard'] as String?,
      ),
      isCertified: json['isCertified'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name': name,
    'address': address,
    'decimals': decimals,
    'coinGeckoId': coinGeckoId,
    'imageUrl': imageUrl,
    'networkKey': networkKey,
    'tokenStandard': tokenStandard.wireValue,
    'isCertified': isCertified,
  };
}

String _solanaClusterFromNetworkKey(String? networkKey) {
  final networkId = _networkIdFromNetworkKey(networkKey, 'mainnet');
  return networkId == 'mainnet' ? 'mainnet-beta' : networkId;
}

String _networkIdFromNetworkKey(String? networkKey, String fallback) {
  final parts = networkKey?.trim().split(':') ?? const [];
  if (parts.length != 2 || parts[1].trim().isEmpty) {
    return fallback;
  }
  return parts[1].trim().toLowerCase();
}
