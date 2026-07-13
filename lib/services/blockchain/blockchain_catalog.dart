import '../../config/app_environment.dart';
import '../../models/chain.dart';

/// Canonical EVM chain metadata and symbol/logo mapping helpers.
class BlockchainCatalog {
  static List<EvmChain> get builtInChains => [
    EvmChain(
      name: 'Ethereum',
      symbol: 'ETH',
      chainId: 1,
      rpcUrl: AppEnvironment.blockchain('/1/rpc').toString(),
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://etherscan.io',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/info/logo.png',
    ),
    EvmChain(
      name: 'BNB Smart Chain',
      symbol: 'BNB',
      chainId: 56,
      rpcUrl: AppEnvironment.blockchain('/56/rpc').toString(),
      coinGeckoId: 'binancecoin',
      explorerUrl: 'https://bscscan.com',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/smartchain/info/logo.png',
    ),
    EvmChain(
      name: 'Polygon',
      symbol: 'MATIC',
      chainId: 137,
      rpcUrl: AppEnvironment.blockchain('/137/rpc').toString(),
      coinGeckoId: 'matic-network',
      explorerUrl: 'https://polygonscan.com',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/polygon/info/logo.png',
    ),
    EvmChain(
      name: 'Arbitrum One',
      symbol: 'ETH',
      chainId: 42161,
      rpcUrl: AppEnvironment.blockchain('/42161/rpc').toString(),
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://arbiscan.io',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/arbitrum/info/logo.png',
    ),
    EvmChain(
      name: 'Optimism',
      symbol: 'ETH',
      chainId: 10,
      rpcUrl: AppEnvironment.blockchain('/10/rpc').toString(),
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://optimistic.etherscan.io',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/optimism/info/logo.png',
    ),
    EvmChain(
      name: 'Base',
      symbol: 'ETH',
      chainId: 8453,
      rpcUrl: AppEnvironment.blockchain('/8453/rpc').toString(),
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://basescan.org',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/base/info/logo.png',
    ),
    EvmChain(
      name: 'ZkSync Era',
      symbol: 'ETH',
      chainId: 324,
      rpcUrl: AppEnvironment.blockchain('/324/rpc').toString(),
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://explorer.zksync.io',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/zksync/info/logo.png',
    ),
    EvmChain(
      name: 'Avalanche C-Chain',
      symbol: 'AVAX',
      chainId: 43114,
      rpcUrl: AppEnvironment.blockchain('/43114/rpc').toString(),
      coinGeckoId: 'avalanche-2',
      explorerUrl: 'https://snowtrace.io',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/avalanchec/info/logo.png',
    ),
    EvmChain(
      name: 'Fantom',
      symbol: 'FTM',
      chainId: 250,
      rpcUrl: AppEnvironment.blockchain('/250/rpc').toString(),
      coinGeckoId: 'fantom',
      explorerUrl: 'https://ftmscan.com',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/fantom/info/logo.png',
    ),
    EvmChain(
      name: 'Gnosis',
      symbol: 'XDAI',
      chainId: 100,
      rpcUrl: AppEnvironment.blockchain('/100/rpc').toString(),
      coinGeckoId: 'xdai',
      explorerUrl: 'https://gnosisscan.io',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/xdai/info/logo.png',
    ),
    EvmChain(
      name: 'Klaytn',
      symbol: 'KLAY',
      chainId: 8217,
      rpcUrl: AppEnvironment.blockchain('/8217/rpc').toString(),
      coinGeckoId: 'klay-token',
      explorerUrl: 'https://scope.klaytn.com',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/klaytn/info/logo.png',
    ),
    EvmChain(
      name: 'Aurora',
      symbol: 'ETH',
      chainId: 1313161554,
      rpcUrl: AppEnvironment.blockchain('/1313161554/rpc').toString(),
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://explorer.mainnet.aurora.dev',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/aurora/info/logo.png',
    ),
    EvmChain(
      name: 'Robinhood Chain',
      symbol: 'ETH',
      chainId: 4663,
      rpcUrl: AppEnvironment.blockchain('/4663/rpc').toString(),
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://robinhoodchain.blockscout.com',
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
      case 'SOL':
        return 'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/solana/info/logo.png';
      case 'TRX':
        return 'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/tron/info/logo.png';
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
