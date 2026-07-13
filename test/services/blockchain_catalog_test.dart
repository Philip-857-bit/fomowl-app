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
}
