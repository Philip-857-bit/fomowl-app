import '../../models/chain.dart';

/// Metadata only. Provider transport is exclusively through the Owllet backend.
class BitcoinCatalog {
  static const mainnet = BitcoinChain(
    name: 'Bitcoin',
    networkId: 'mainnet',
    explorerUrl: 'https://mempool.space',
    logoUrl:
        'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/bitcoin/info/logo.png',
  );
  static const testnet4 = BitcoinChain(
    name: 'Bitcoin Testnet4',
    networkId: 'testnet4',
    coinGeckoId: null,
    explorerUrl: 'https://mempool.space/testnet4',
    logoUrl:
        'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/bitcoin/info/logo.png',
  );
  static const productionChains = [mainnet];
  static const developerChains = [testnet4];
  static const builtInChains = [mainnet, testnet4];
}
