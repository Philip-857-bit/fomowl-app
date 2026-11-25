import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/runtime_config_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_rollout_service.dart';

class Availability extends Fake implements BitcoinNetworkApi {
  bool availableValue = true;
  bool outage = false;
  Completer<bool>? delayed;
  int calls = 0;
  @override
  Future<bool> available(BitcoinProductNetwork network) async {
    calls++;
    if (outage) throw const BitcoinNetworkException(503);
    if (delayed != null) return delayed!.future;
    return availableValue;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'missing policy defaults enabled while malformed policy fails closed and audience stages remain explicit',
    () {
      final omitted = RuntimePolicySnapshot.fromJson({});
      expect(omitted.bitcoinEnabled, isTrue);
      expect(omitted.bitcoinRolloutStage, 'default');
      final malformed = RuntimePolicySnapshot.fromJson({
        'policy': {
          'features': {'bitcoinEnabled': 'true', 'bitcoinRolloutStage': 123},
        },
      });
      expect(malformed.bitcoinEnabled, isFalse);
      expect(malformed.bitcoinRolloutStage, 'off');
      const internal = RuntimePolicySnapshot(
        bitcoinEnabled: true,
        bitcoinRolloutStage: 'internal',
      );
      expect(
        BitcoinRolloutPolicy.admits(
          internal,
          BitcoinBuildAudience.internal,
          '',
        ),
        isTrue,
      );
      expect(
        BitcoinRolloutPolicy.admits(
          internal,
          BitcoinBuildAudience.production,
          '0xwallet',
        ),
        isFalse,
      );
      const all = RuntimePolicySnapshot(
        bitcoinEnabled: true,
        bitcoinRolloutStage: 'default',
        bitcoinTestnetEnabled: true,
      );
      expect(
        BitcoinRolloutPolicy.admits(
          all,
          BitcoinBuildAudience.production,
          '0xwallet',
        ),
        isTrue,
      );
      expect(all, RuntimePolicySnapshot.fromJson(all.toJson()));
      expect(const RuntimePolicySnapshot(), isNot(all));
    },
  );
  test(
    'controlled cohorts are stable, bounded and do not admit an unknown identity',
    () {
      const cohort = RuntimePolicySnapshot(
        bitcoinEnabled: true,
        bitcoinRolloutStage: 'controlled-production',
        bitcoinRolloutPercent: 50,
      );
      expect(
        BitcoinRolloutPolicy.admits(
          cohort,
          BitcoinBuildAudience.production,
          '',
        ),
        isFalse,
      );
      expect(
        BitcoinRolloutPolicy.admits(
          cohort,
          BitcoinBuildAudience.production,
          '0xABC',
        ),
        BitcoinRolloutPolicy.admits(
          cohort,
          BitcoinBuildAudience.production,
          '0xabc',
        ),
      );
      const none = RuntimePolicySnapshot(
        bitcoinEnabled: true,
        bitcoinRolloutStage: 'controlled-production',
      );
      expect(
        BitcoinRolloutPolicy.admits(
          none,
          BitcoinBuildAudience.production,
          '0xwallet',
        ),
        isFalse,
      );
    },
  );
  test(
    'transient capability outage retains last known admission while explicit off still disables it',
    () async {
      final blockchain = BlockchainService();
      blockchain.setActiveWalletContext(
        address: '0xwallet',
        supportedFamilies: {ChainFamily.evm, ChainFamily.bitcoin},
      );
      final network = Availability();
      final service = BitcoinRolloutService(
        blockchain: blockchain,
        network: network,
        provision: null,
      );
      const on = RuntimePolicySnapshot(
        bitcoinEnabled: true,
        bitcoinRolloutStage: 'default',
        bitcoinTestnetEnabled: true,
      );

      // With no prior successful capability check, an outage remains
      // fail-closed.
      network.outage = true;
      await service.refresh(on);
      expect(blockchain.isBitcoinNetworkAvailable('bitcoin:mainnet'), isFalse);

      // Once availability has been confirmed, a temporary backend/network
      // failure must not make Bitcoin disappear from the app.
      network.outage = false;
      await service.refresh(on);
      expect(blockchain.isBitcoinNetworkAvailable('bitcoin:mainnet'), isTrue);
      expect(blockchain.isBitcoinNetworkAvailable('bitcoin:testnet4'), isFalse);
      network.outage = true;
      await service.refresh(on);
      expect(blockchain.isBitcoinNetworkAvailable('bitcoin:mainnet'), isTrue);

      // An explicit runtime-policy disable is authoritative.
      network.outage = false;
      network.delayed = Completer<bool>();
      final late = service.refresh(on);
      await Future<void>.delayed(Duration.zero);
      await service.refresh(
        const RuntimePolicySnapshot(
          bitcoinEnabled: false,
          bitcoinRolloutStage: 'off',
        ),
      );
      network.delayed!.complete(true);
      await late;
      expect(blockchain.isBitcoinNetworkAvailable('bitcoin:mainnet'), isFalse);

      service.dispose();
      blockchain.dispose();
    },
  );
}
