import '../../models/chain.dart';

/// Canonical EVM chain metadata and symbol/logo mapping helpers.
class BlockchainCatalog {
  static const String backendRpcBase =
      'https://fomowl-backend.onrender.com/api/blockchain';

  static const List<EvmChain> builtInChains = [
    EvmChain(
      name: 'Ethereum',
      symbol: 'ETH',
      chainId: 1,
      rpcUrl: '$backendRpcBase/1/rpc',
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://etherscan.io',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/info/logo.png',
    ),
    EvmChain(
      name: 'BNB Smart Chain',
      symbol: 'BNB',
      chainId: 56,
      rpcUrl: '$backendRpcBase/56/rpc',
      coinGeckoId: 'binancecoin',
      explorerUrl: 'https://bscscan.com',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/smartchain/info/logo.png',
    ),
    EvmChain(
      name: 'Polygon',
      symbol: 'MATIC',
      chainId: 137,
      rpcUrl: '$backendRpcBase/137/rpc',
      coinGeckoId: 'matic-network',
      explorerUrl: 'https://polygonscan.com',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/polygon/info/logo.png',
    ),
    EvmChain(
      name: 'Arbitrum One',
      symbol: 'ETH',
      chainId: 42161,
      rpcUrl: '$backendRpcBase/42161/rpc',
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://arbiscan.io',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/arbitrum/info/logo.png',
    ),
    EvmChain(
      name: 'Optimism',
      symbol: 'ETH',
      chainId: 10,
      rpcUrl: '$backendRpcBase/10/rpc',
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://optimistic.etherscan.io',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/optimism/info/logo.png',
    ),
    EvmChain(
      name: 'Base',
      symbol: 'ETH',
      chainId: 8453,
      rpcUrl: '$backendRpcBase/8453/rpc',
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://basescan.org',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/base/info/logo.png',
    ),
    EvmChain(
      name: 'ZkSync Era',
      symbol: 'ETH',
      chainId: 324,
      rpcUrl: '$backendRpcBase/324/rpc',
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://explorer.zksync.io',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/zksync/info/logo.png',
    ),
    EvmChain(
      name: 'Avalanche C-Chain',
      symbol: 'AVAX',
      chainId: 43114,
      rpcUrl: '$backendRpcBase/43114/rpc',
      coinGeckoId: 'avalanche-2',
      explorerUrl: 'https://snowtrace.io',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/avalanchec/info/logo.png',
    ),
    EvmChain(
      name: 'Fantom',
      symbol: 'FTM',
      chainId: 250,
      rpcUrl: '$backendRpcBase/250/rpc',
      coinGeckoId: 'fantom',
      explorerUrl: 'https://ftmscan.com',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/fantom/info/logo.png',
    ),
    EvmChain(
      name: 'Gnosis',
      symbol: 'XDAI',
      chainId: 100,
      rpcUrl: '$backendRpcBase/100/rpc',
      coinGeckoId: 'xdai',
      explorerUrl: 'https://gnosisscan.io',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/xdai/info/logo.png',
    ),
    EvmChain(
      name: 'Klaytn',
      symbol: 'KLAY',
      chainId: 8217,
      rpcUrl: '$backendRpcBase/8217/rpc',
      coinGeckoId: 'klay-token',
      explorerUrl: 'https://scope.klaytn.com',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/klaytn/info/logo.png',
    ),
    EvmChain(
      name: 'Aurora',
      symbol: 'ETH',
      chainId: 1313161554,
      rpcUrl: '$backendRpcBase/1313161554/rpc',
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://explorer.mainnet.aurora.dev',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/aurora/info/logo.png',
    ),
  ];

  static String? iconUrlForSymbol(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'ETH':
        return 'https://cryptologos.cc/logos/ethereum-eth-logo.png';
      case 'BNB':
        return 'https://cryptologos.cc/logos/bnb-bnb-logo.png';
      case 'MATIC':
        return 'https://cryptologos.cc/logos/polygon-matic-logo.png';
      case 'USDC':
        return 'https://cryptologos.cc/logos/usd-coin-usdc-logo.png';
      case 'USDT':
        return 'https://cryptologos.cc/logos/tether-usdt-logo.png';
      default:
        return null;
    }
  }

  static String? inferCoinGeckoIdFromSymbol(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'ETH':
        return 'ethereum';
      case 'BNB':
        return 'binancecoin';
      case 'MATIC':
        return 'matic-network';
      case 'AVAX':
        return 'avalanche-2';
      case 'FTM':
        return 'fantom';
      case 'XDAI':
      case 'DAI':
        return 'xdai';
      case 'KLAY':
        return 'klay-token';
      case 'CRO':
        return 'crypto-com-chain';
      default:
        return null;
    }
  }

  static String? defaultChainLogoUrl(int chainId) {
    final blockchainName = switch (chainId) {
      1 => 'ethereum',
      56 => 'smartchain',
      137 => 'polygon',
      42161 => 'arbitrum',
      10 => 'optimism',
      8453 => 'base',
      324 => 'zksync',
      43114 => 'avalanchec',
      250 => 'fantom',
      100 => 'xdai',
      8217 => 'klaytn',
      1313161554 => 'aurora',
      _ => null,
    };
    if (blockchainName == null) return null;
    return 'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/$blockchainName/info/logo.png';
  }
}
