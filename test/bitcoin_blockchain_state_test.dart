import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/network_entry.dart';
import 'package:fomowl_wallet/models/token_standard.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Bitcoin selector requires configured availability and an HD-capable wallet',
    () async {
      final service = BlockchainService();
      service.setActiveWalletContext(
        address: '0xwallet',
        supportedFamilies: {ChainFamily.evm, ChainFamily.bitcoin},
      );
      await service.setEnabledFamilies({ChainFamily.evm, ChainFamily.bitcoin});
      expect(service.networkEntries.whereType<BitcoinNetworkEntry>(), isEmpty);
      expect(service.trySetActiveNetworkKey('bitcoin:mainnet'), isFalse);
      service.configureBitcoinAvailability(available: true);
      expect(
        service.networkEntries.whereType<BitcoinNetworkEntry>().map(
          (entry) => entry.networkKey,
        ),
        ['bitcoin:mainnet'],
      );
      expect(service.trySetActiveNetworkKey('bitcoin:mainnet'), isTrue);
      expect(service.activeFamily, ChainFamily.bitcoin);
      expect(service.activeNetworkName, 'Bitcoin');
      expect(service.activeNetworkSymbol, 'BTC');
      expect(service.activeNativeToken.decimals, 8);
      expect(service.activeNativeToken.tokenStandard, TokenStandard.native);
      expect(service.activeNetworkCoinGeckoId, 'bitcoin');
      expect(service.activeTokenStorageChainId, BitcoinLegacyUiIds.mainnet);
      expect(service.customTokensForActiveChain, isEmpty);
      service.configureBitcoinAvailability(available: false);
      expect(service.activeFamily, ChainFamily.evm);
      service.dispose();
    },
  );
  test(
    'testnet4 is developer-controlled and unknown networks never fall through to EVM',
    () async {
      final service = BlockchainService();
      service.setActiveWalletContext(
        address: '0xwallet',
        supportedFamilies: {ChainFamily.evm, ChainFamily.bitcoin},
      );
      await service.setEnabledFamilies({ChainFamily.evm, ChainFamily.bitcoin});
      service.configureBitcoinAvailability(available: true);
      expect(service.trySetActiveNetworkKey('bitcoin:testnet4'), isFalse);
      service.configureBitcoinAvailability(
        available: true,
        testnetEnabled: true,
      );
      expect(service.trySetActiveNetworkKey('bitcoin:testnet4'), isTrue);
      expect(service.activeNetworkName, 'Bitcoin Testnet4');
      expect(service.activeNetworkCoinGeckoId, isNull);
      expect(service.activeTokenStorageChainId, BitcoinLegacyUiIds.testnet4);
      final before = service.activeNetworkKey;
      expect(service.trySetActiveNetworkKey('bitcoin:signet'), isFalse);
      expect(service.activeNetworkKey, before);
      service.dispose();
    },
  );
  test(
    'private-key-only wallets cannot select Bitcoin even when the provider is available',
    () async {
      final service = BlockchainService();
      service.setActiveWalletContext(
        address: '0ximported',
        supportedFamilies: {ChainFamily.evm},
      );
      await service.setEnabledFamilies({ChainFamily.evm, ChainFamily.bitcoin});
      service.configureBitcoinAvailability(
        available: true,
        testnetEnabled: true,
      );
      expect(service.networkEntries.whereType<BitcoinNetworkEntry>(), isEmpty);
      service.setActiveNetworkKey('bitcoin:mainnet');
      expect(service.activeFamily, ChainFamily.evm);
      service.dispose();
    },
  );
}
