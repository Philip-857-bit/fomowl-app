import 'dart:typed_data';

import '../../config/app_environment.dart';
import '../../models/chain.dart';
import 'embedded_chain_logos.dart';

/// Canonical EVM chain metadata and symbol/logo mapping helpers.
class BlockchainCatalog {
  /// Ethereum Layer-2 networks whose native-token icon should carry a compact
  /// chain badge. L1s and sidechains (Ethereum, BNB, Polygon PoS, Avalanche)
  /// are intentionally excluded.
  static const Set<int> ethereumLayer2BadgeChainIds = {
    10, // OP Mainnet
    169, // Manta Pacific
    130, // Unichain
    324, // zkSync Era
    480, // World Chain
    2741, // Abstract
    4663, // Robinhood Chain
    5000, // Mantle
    1088, // Metis
    8453, // Base
    1135, // Lisk
    33139, // ApeChain
    34443, // Mode
    42220, // Celo
    42161, // Arbitrum One
    57073, // Ink
    59144, // Linea
    81457, // Blast
    98866, // Plume
    534352, // Scroll
  };

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
    // Network metadata verified against Asset Chain's official EVM registry.
    EvmChain(
      name: 'Asset Chain',
      symbol: 'RWA',
      chainId: 42420,
      rpcUrl: AppEnvironment.blockchain('/42420/rpc').toString(),
      explorerUrl: 'https://scan.assetchain.org',
      // Official network icon from Asset Chain explorer.
      logoUrl: 'https://scan.assetchain.org/assets/configs/network_icon.png',
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
      logoUrl:
          'https://cdn.robinhood.com/assets/generated_assets/hoodchain_docsite/rh_favicon_152.png',
    ),
    EvmChain(
      name: 'Unichain',
      symbol: 'ETH',
      chainId: 130,
      rpcUrl: AppEnvironment.blockchain('/130/rpc').toString(),
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://uniscan.xyz',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/info/logo.png',
    ),
    EvmChain(
      name: 'Monad',
      symbol: 'MON',
      chainId: 143,
      rpcUrl: AppEnvironment.blockchain('/143/rpc').toString(),
      coinGeckoId: 'monad',
      explorerUrl: 'https://monadvision.com',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/monad/info/logo.png',
    ),
    EvmChain(
      name: 'Sonic',
      symbol: 'S',
      chainId: 146,
      rpcUrl: AppEnvironment.blockchain('/146/rpc').toString(),
      coinGeckoId: 'sonic-3',
      explorerUrl: 'https://sonicscan.org',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/sonic/info/logo.png',
    ),
    EvmChain(
      name: 'World Chain',
      symbol: 'ETH',
      chainId: 480,
      rpcUrl: AppEnvironment.blockchain('/480/rpc').toString(),
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://worldscan.org',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/info/logo.png',
    ),
    EvmChain(
      name: 'HyperEVM',
      symbol: 'HYPE',
      chainId: 999,
      rpcUrl: AppEnvironment.blockchain('/999/rpc').toString(),
      coinGeckoId: 'hyperliquid',
      explorerUrl: 'https://hyperevmscan.io',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/hyperevm/info/logo.png',
    ),
    EvmChain(
      name: 'Abstract',
      symbol: 'ETH',
      chainId: 2741,
      rpcUrl: AppEnvironment.blockchain('/2741/rpc').toString(),
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://abscan.org',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/info/logo.png',
    ),
    EvmChain(
      name: 'Mantle',
      symbol: 'MNT',
      chainId: 5000,
      rpcUrl: AppEnvironment.blockchain('/5000/rpc').toString(),
      coinGeckoId: 'mantle',
      explorerUrl: 'https://mantlescan.xyz',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/mantle/info/logo.png',
    ),
    EvmChain(
      name: 'ApeChain',
      symbol: 'APE',
      chainId: 33139,
      rpcUrl: AppEnvironment.blockchain('/33139/rpc').toString(),
      coinGeckoId: 'apecoin',
      explorerUrl: 'https://apescan.io',
      logoUrl: 'https://cryptologos.cc/logos/apecoin-ape-ape-logo.png',
    ),
    EvmChain(
      name: 'Mode',
      symbol: 'ETH',
      chainId: 34443,
      rpcUrl: AppEnvironment.blockchain('/34443/rpc').toString(),
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://explorer.mode.network',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/info/logo.png',
    ),
    EvmChain(
      name: 'Ink',
      symbol: 'ETH',
      chainId: 57073,
      rpcUrl: AppEnvironment.blockchain('/57073/rpc').toString(),
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://explorer.inkonchain.com',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/info/logo.png',
    ),
    EvmChain(
      name: 'Linea',
      symbol: 'ETH',
      chainId: 59144,
      rpcUrl: AppEnvironment.blockchain('/59144/rpc').toString(),
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://lineascan.build',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/linea/info/logo.png',
    ),
    EvmChain(
      name: 'Berachain',
      symbol: 'BERA',
      chainId: 80094,
      rpcUrl: AppEnvironment.blockchain('/80094/rpc').toString(),
      coinGeckoId: 'berachain-bera',
      explorerUrl: 'https://berascan.com',
      logoUrl: 'https://assets.coingecko.com/coins/images/25235/small/BERA.png',
    ),
    EvmChain(
      name: 'Blast',
      symbol: 'ETH',
      chainId: 81457,
      rpcUrl: AppEnvironment.blockchain('/81457/rpc').toString(),
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://blastscan.io',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/blast/info/logo.png',
    ),
    EvmChain(
      name: 'Plasma',
      symbol: 'XPL',
      chainId: 9745,
      rpcUrl: AppEnvironment.blockchain('/9745/rpc').toString(),
      coinGeckoId: 'plasma',
      explorerUrl: 'https://plasmascan.to',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/plasma/info/logo.png',
    ),
    EvmChain(
      name: 'Lisk',
      symbol: 'ETH',
      chainId: 1135,
      rpcUrl: AppEnvironment.blockchain('/1135/rpc').toString(),
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://blockscout.lisk.com',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/info/logo.png',
    ),
    EvmChain(
      name: 'Celo',
      symbol: 'CELO',
      chainId: 42220,
      rpcUrl: AppEnvironment.blockchain('/42220/rpc').toString(),
      coinGeckoId: 'celo',
      explorerUrl: 'https://celoscan.io',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/celo/info/logo.png',
    ),
    EvmChain(
      name: 'Cronos',
      symbol: 'CRO',
      chainId: 25,
      rpcUrl: AppEnvironment.blockchain('/25/rpc').toString(),
      coinGeckoId: 'crypto-com-chain',
      explorerUrl: 'https://cronoscan.com',
      logoUrl: 'https://assets.relay.link/icons/25/light.png',
    ),
    EvmChain(
      name: 'Manta Pacific',
      symbol: 'ETH',
      chainId: 169,
      rpcUrl: AppEnvironment.blockchain('/169/rpc').toString(),
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://pacific-explorer.manta.network',
      logoUrl: 'https://assets.relay.link/icons/169/light.png',
    ),
    EvmChain(
      name: 'Metis',
      symbol: 'METIS',
      chainId: 1088,
      rpcUrl: AppEnvironment.blockchain('/1088/rpc').toString(),
      coinGeckoId: 'metis-token',
      explorerUrl: 'https://explorer.metis.io',
      logoUrl: 'https://assets.relay.link/icons/1088/light.png',
    ),
    EvmChain(
      name: 'Sei',
      symbol: 'SEI',
      chainId: 1329,
      rpcUrl: AppEnvironment.blockchain('/1329/rpc').toString(),
      coinGeckoId: 'sei-network',
      explorerUrl: 'https://seitrace.com',
      logoUrl: 'https://assets.relay.link/icons/1329/light.png',
    ),
    EvmChain(
      name: 'Arc',
      symbol: 'USDC',
      chainId: 5042,
      rpcUrl: AppEnvironment.blockchain('/5042/rpc').toString(),
      coinGeckoId: 'usd-coin',
      explorerUrl: 'https://explorer.arc.io',
      logoUrl:
          'https://d2xo500swnpgl1.cloudfront.net/uploads/arc/Gradual-Arc-icon-43ee6ca5-45c5-404d-ac1b-f54f93c51f06-1761315436123.png',
    ),
    EvmChain(
      name: 'Plume',
      symbol: 'PLUME',
      chainId: 98866,
      rpcUrl: AppEnvironment.blockchain('/98866/rpc').toString(),
      coinGeckoId: 'plume',
      explorerUrl: 'https://explorer.plume.org',
      logoUrl: 'https://assets.relay.link/icons/98866/light.png',
    ),
    EvmChain(
      name: 'Scroll',
      symbol: 'ETH',
      chainId: 534352,
      rpcUrl: AppEnvironment.blockchain('/534352/rpc').toString(),
      coinGeckoId: 'ethereum',
      explorerUrl: 'https://scrollscan.com',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/scroll/info/logo.png',
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
      case 'APE':
        return 'https://cryptologos.cc/logos/apecoin-ape-ape-logo.png';
      case 'MNT':
        return 'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/mantle/info/logo.png';
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
      case 'CRO':
        return 'crypto-com-chain';
      case 'METIS':
        return 'metis-token';
      case 'SEI':
        return 'sei-network';
      case 'PLUME':
        return 'plume';
      case 'APE':
        return 'apecoin';
      case 'MNT':
        return 'mantle';
      case 'BERA':
        return 'berachain-bera';
      case 'S':
        return 'sonic-3';
      case 'MON':
        return 'monad';
      case 'HYPE':
        return 'hyperliquid';
      case 'XPL':
        return 'plasma';
      case 'CELO':
        return 'celo';
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
      1313161554 => 'aurora',
      143 => 'monad',
      146 => 'sonic',
      999 => 'hyperevm',
      5000 => 'mantle',
      59144 => 'linea',
      81457 => 'blast',
      534352 => 'scroll',
      9745 => 'plasma',
      42220 => 'celo',
      _ => null,
    };
    if (chainId == 4663) {
      return 'https://cdn.robinhood.com/assets/generated_assets/hoodchain_docsite/rh_favicon_152.png';
    }
    if (chainId == 33139) {
      return 'https://cryptologos.cc/logos/apecoin-ape-ape-logo.png';
    }
    if (chainId == 5042) {
      return 'https://d2xo500swnpgl1.cloudfront.net/uploads/arc/Gradual-Arc-icon-43ee6ca5-45c5-404d-ac1b-f54f93c51f06-1761315436123.png';
    }
    const relayLogoChainIds = {25, 169, 1088, 1329, 98866};
    if (relayLogoChainIds.contains(chainId)) {
      return 'https://assets.relay.link/icons/$chainId/light.png';
    }
    if (blockchainName == null) return null;
    return 'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/$blockchainName/info/logo.png';
  }

  /// In-memory embedded logo bytes for networks where runtime code patches
  /// may not include newly created binary assets.
  static Uint8List? embeddedChainLogoBytes(int chainId) =>
      EmbeddedChainLogos.forChainId(chainId);

  /// Logos bundled with the app for chains that do not have a stable entry in
  /// the shared Trust Wallet asset repository.
  static String? localChainLogoAsset(int chainId) => switch (chainId) {
    130 => 'assets/images/chains/unichain.webp',
    143 => 'assets/images/chains/monad.png',
    146 => 'assets/images/chains/sonic.png',
    480 => 'assets/images/chains/worldchain.webp',
    999 => 'assets/images/chains/hyperevm.png',
    2741 => 'assets/images/chains/abstract.webp',
    4663 => 'assets/images/chains/robinhood_chain.png',
    5000 => 'assets/images/chains/mantle.png',
    5042 => 'assets/images/chains/arc.png',
    9745 => 'assets/images/chains/plasma.png',
    33139 => 'assets/images/chains/apechain.webp',
    34443 => 'assets/images/chains/mode.webp',
    57073 => 'assets/images/chains/ink.webp',
    59144 => 'assets/images/chains/linea.png',
    80094 => 'assets/images/chains/berachain.png',
    81457 => 'assets/images/chains/blast.png',
    534352 => 'assets/images/chains/scroll.png',
    1135 => 'assets/images/chains/lisk.webp',
    42220 => 'assets/images/chains/celo.png',
    42420 => 'assets/images/chains/assetchain.png',
    _ => null,
  };

  /// Looks up a built-in EVM chain by its chainId.
  static EvmChain? findChain(int chainId) {
    for (final chain in builtInChains) {
      if (chain.chainId == chainId) return chain;
    }
    return null;
  }
}
