import '../../models/chain.dart';

/// TRON mainnet metadata for family-aware wallet network support.
class TronCatalog {
  static const TronChain mainnet = TronChain(
    name: 'TRON',
    symbol: 'TRX',
    networkId: 'mainnet',
    rpcUrl: 'https://api.trongrid.io',
    coinGeckoId: 'tron',
    explorerUrl: 'https://tronscan.org',
    logoUrl:
        'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/tron/info/logo.png',
  );

  static const List<TronChain> builtInChains = [mainnet];
}
