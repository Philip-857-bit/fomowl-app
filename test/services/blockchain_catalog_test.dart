import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/network_entry.dart';
import 'package:fomowl_wallet/services/blockchain/blockchain_catalog.dart';

void main() {
  test('retired Kaia network is not exposed by the built-in catalog', () {
    expect(
      BlockchainCatalog.builtInChains.any((chain) => chain.chainId == 8217),
      isFalse,
    );
  });

  test('Robinhood Chain uses its bundled official logo', () {
    expect(
      BlockchainCatalog.localChainLogoAsset(4663),
      'assets/images/chains/robinhood_chain.png',
    );

    final robinhood = BlockchainCatalog.builtInChains.singleWhere(
      (chain) => chain.chainId == 4663,
    );
    expect(robinhood.logoUrl, contains('cdn.robinhood.com'));
  });

  test('ApeChain uses its bundled logo and is a selectable L2', () {
    expect(
      BlockchainCatalog.localChainLogoAsset(33139),
      'assets/images/chains/apechain.webp',
    );
    final apechain = BlockchainCatalog.builtInChains.singleWhere(
      (chain) => chain.chainId == 33139,
    );
    expect(apechain.name, 'ApeChain');
    expect(apechain.symbol, 'APE');
    expect(BlockchainCatalog.ethereumLayer2BadgeChainIds, contains(33139));
  });

  test('Celo, Lisk, and Arc are bundled with logos', () {
    expect(
      BlockchainCatalog.localChainLogoAsset(42220),
      'assets/images/chains/celo.png',
    );
    expect(
      BlockchainCatalog.localChainLogoAsset(1135),
      'assets/images/chains/lisk.webp',
    );
    expect(
      BlockchainCatalog.localChainLogoAsset(5042),
      'assets/images/chains/arc.png',
    );
    expect(
      BlockchainCatalog.builtInChains.any((chain) => chain.chainId == 42220),
      isTrue,
    );
    expect(
      BlockchainCatalog.builtInChains.any((chain) => chain.chainId == 1135),
      isTrue,
    );
    expect(
      BlockchainCatalog.builtInChains.any((chain) => chain.chainId == 5042),
      isTrue,
    );
  });

  test(
    'Asset Chain uses its bundled official logo and points to official explorer icon',
    () {
      expect(
        BlockchainCatalog.localChainLogoAsset(42420),
        'assets/images/chains/assetchain.png',
      );
      final assetChain = BlockchainCatalog.builtInChains.singleWhere(
        (chain) => chain.chainId == 42420,
      );
      expect(assetChain.name, 'Asset Chain');
      expect(assetChain.symbol, 'RWA');
      expect(
        assetChain.logoUrl,
        'https://scan.assetchain.org/assets/configs/network_icon.png',
      );
      expect(
        BlockchainCatalog.defaultChainLogoUrl(42420),
        'https://scan.assetchain.org/assets/configs/network_icon.png',
      );
      expect(
        BlockchainCatalog.iconUrlForSymbol('RWA'),
        'https://scan.assetchain.org/assets/configs/network_icon.png',
      );
    },
  );

  test('identifies Ethereum L2 badges without marking L1 chains', () {
    expect(BlockchainCatalog.ethereumLayer2BadgeChainIds, contains(4663));
    expect(BlockchainCatalog.ethereumLayer2BadgeChainIds, contains(8453));
    expect(BlockchainCatalog.ethereumLayer2BadgeChainIds, isNot(contains(56)));
    expect(BlockchainCatalog.ethereumLayer2BadgeChainIds, isNot(contains(1)));
  });

  test('registers the provider-backed EVM expansion with native metadata', () {
    const expected = {
      25: ('Cronos', 'CRO', 'crypto-com-chain'),
      169: ('Manta Pacific', 'ETH', 'ethereum'),
      1088: ('Metis', 'METIS', 'metis-token'),
      1329: ('Sei', 'SEI', 'sei-network'),
      5042: ('Arc', 'USDC', 'usd-coin'),
      98866: ('Plume', 'PLUME', 'plume'),
    };

    for (final entry in expected.entries) {
      final chain = BlockchainCatalog.builtInChains.singleWhere(
        (candidate) => candidate.chainId == entry.key,
      );
      expect(chain.name, entry.value.$1);
      expect(chain.symbol, entry.value.$2);
      expect(chain.coinGeckoId, entry.value.$3);
      expect(chain.rpcUrl, contains('/${entry.key}/rpc'));
      expect(chain.logoUrl, isNotEmpty);
    }
  });

  test('every newly bundled EVM network has a distinct picker identity', () {
    const expected = {
      130: 'UNI',
      143: 'MON',
      146: 'S',
      480: 'WLD',
      999: 'HYPE',
      1135: 'LSK',
      2741: 'ABS',
      4663: 'HOOD',
      25: 'CRO',
      169: 'MANTA',
      1088: 'METIS',
      1329: 'SEI',
      5042: 'ARC',
      98866: 'PLUME',
      5000: 'MNT',
      9745: 'XPL',
      33139: 'APE',
      34443: 'MODE',
      42220: 'CELO',
      57073: 'INK',
      59144: 'LINEA',
      80094: 'BERA',
      81457: 'BLAST',
      534352: 'SCR',
    };

    for (final entry in expected.entries) {
      expect(
        networkIdentitySymbolForKey('evm:${entry.key}', fallback: 'ETH'),
        entry.value,
      );
    }
  });
}
