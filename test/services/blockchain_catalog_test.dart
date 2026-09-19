import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/blockchain/blockchain_catalog.dart';

void main() {
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

  test('identifies Ethereum L2 badges without marking L1 chains', () {
    expect(BlockchainCatalog.ethereumLayer2BadgeChainIds, contains(4663));
    expect(BlockchainCatalog.ethereumLayer2BadgeChainIds, contains(8453));
    expect(BlockchainCatalog.ethereumLayer2BadgeChainIds, isNot(contains(56)));
    expect(BlockchainCatalog.ethereumLayer2BadgeChainIds, isNot(contains(1)));
  });
}
