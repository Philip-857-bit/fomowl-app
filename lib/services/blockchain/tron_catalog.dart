import '../../models/chain.dart';

/// TRON metadata scaffold for family-aware wallet network support.
///
/// Mainnet is the only production-visible network in v1. Test networks are
/// kept here for fixtures and internal validation without wiring them into the
/// active wallet UI.
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

  static const TronChain nile = TronChain(
    name: 'TRON Nile',
    symbol: 'TRX',
    networkId: 'nile',
    rpcUrl: 'https://nile.trongrid.io',
    coinGeckoId: 'tron',
    explorerUrl: 'https://nile.tronscan.org',
    logoUrl:
        'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/tron/info/logo.png',
  );

  static const TronChain shasta = TronChain(
    name: 'TRON Shasta',
    symbol: 'TRX',
    networkId: 'shasta',
    rpcUrl: 'https://api.shasta.trongrid.io',
    coinGeckoId: 'tron',
    explorerUrl: 'https://shasta.tronscan.org',
    logoUrl:
        'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/tron/info/logo.png',
  );

  static const List<TronChain> builtInChains = [mainnet, nile, shasta];
}
