import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/services/blockchain/solana_catalog.dart';
import 'package:fomowl_wallet/services/blockchain/tron_catalog.dart';

void main() {
  group('network keys', () {
    test('builds canonical EVM, Solana, and TRON keys', () {
      expect(NetworkKey.evm(1), 'evm:1');
      expect(SolanaCatalog.mainnet.networkKey, 'solana:mainnet');
      expect(TronCatalog.mainnet.networkKey, 'tron:mainnet');
    });

    test('parses network key families and EVM chain IDs', () {
      expect(NetworkKey.familyOf('evm:56'), ChainFamily.evm);
      expect(NetworkKey.familyOf('solana:mainnet'), ChainFamily.solana);
      expect(NetworkKey.familyOf('tron:mainnet'), ChainFamily.tron);
      expect(NetworkKey.evmChainIdOf('evm:137'), 137);
      expect(NetworkKey.evmChainIdOf('solana:mainnet'), isNull);
    });

    test('serializes chain family metadata', () {
      expect(SolanaCatalog.mainnet.toJson()['family'], 'solana');
      expect(SolanaCatalog.mainnet.toJson()['networkKey'], 'solana:mainnet');
      expect(TronCatalog.mainnet.toJson()['family'], 'tron');
      expect(TronCatalog.mainnet.toJson()['networkKey'], 'tron:mainnet');
    });
  });
}
