import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/network_entry.dart';
import 'package:fomowl_wallet/services/blockchain/bitcoin_catalog.dart';

void main() {
  test(
    'Bitcoin has an explicit family and canonical supported network keys',
    () {
      expect(ChainFamilyCodec.fromWireValue('bitcoin'), ChainFamily.bitcoin);
      expect(ChainFamily.bitcoin.wireValue, 'bitcoin');
      expect(NetworkKey.bitcoin('mainnet'), 'bitcoin:mainnet');
      expect(NetworkKey.bitcoin('testnet4'), 'bitcoin:testnet4');
      expect(NetworkKey.familyOf('bitcoin:mainnet'), ChainFamily.bitcoin);
      expect(NetworkKey.evmChainIdOf('bitcoin:mainnet'), isNull);
      expect(NetworkKey.bitcoinNetworkIdOf('bitcoin:testnet4'), 'testnet4');
      for (final network in ['signet', 'regtest', 'testnet3', 'unknown']) {
        expect(() => NetworkKey.bitcoin(network), throwsFormatException);
        expect(NetworkKey.bitcoinNetworkIdOf('bitcoin:$network'), isNull);
      }
    },
  );
  test(
    'native metadata is BTC with eight decimals and no direct provider URL',
    () {
      final chain = BitcoinCatalog.mainnet;
      expect(chain.symbol, 'BTC');
      expect(chain.decimals, 8);
      expect(chain.coinGeckoId, 'bitcoin');
      expect(chain.isMainnet, isTrue);
      expect(chain.toJson().containsKey('rpcUrl'), isFalse);
      final restored = BitcoinChain.fromJson(chain.toJson());
      expect(restored.networkKey, chain.networkKey);
      expect(restored.family, ChainFamily.bitcoin);
      expect(BitcoinCatalog.testnet4.coinGeckoId, isNull);
      expect(BitcoinCatalog.productionChains, [BitcoinCatalog.mainnet]);
      expect(BitcoinCatalog.developerChains, [BitcoinCatalog.testnet4]);
      expect(
        () => BitcoinChain.fromJson({...chain.toJson(), 'networkId': 'signet'}),
        throwsFormatException,
      );
      final entry = BitcoinNetworkEntry(chain);
      expect(entry.networkKey, 'bitcoin:mainnet');
      expect(entry.identitySymbol, 'BTC');
      expect(entry.family, ChainFamily.bitcoin);
    },
  );
}
