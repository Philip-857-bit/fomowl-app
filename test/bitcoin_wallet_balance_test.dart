import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_wallet_service.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_discovery.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/models/bitcoin_wallet_balance.dart';

BitcoinDiscoverySnapshot fixture({int pending84 = -200, bool unknown = false}) {
  final accounts = <BitcoinPurpose, BitcoinPurposeAccountState>{};
  final ownership = <String, BitcoinDerivedAddress>{};
  final activity = <String, BitcoinAddressActivity>{};
  for (final purpose in BitcoinPurpose.values) {
    final metadata = BitcoinHdAccountMetadata(
      network: BitcoinProductNetwork.mainnet,
      purpose: purpose,
      accountIndex: 0,
      masterFingerprint: '73c5da0a',
      accountXpub: 'xpub-public-${purpose.number}',
    );
    accounts[purpose] = BitcoinPurposeAccountState(metadata: metadata);
    final address = 'bc1q_fixture_${purpose.number}';
    ownership[address] = BitcoinDerivedAddress(
      account: metadata,
      keychain: BitcoinKeychain.receive,
      addressIndex: 0,
      address: address,
    );
    activity[address] = BitcoinAddressActivity.fromJson({
      'address': address,
      'used': true,
      'confirmedBalanceSats': purpose == BitcoinPurpose.bip84 ? 1000 : 2500,
      'mempoolBalanceSats': purpose == BitcoinPurpose.bip84 ? pending84 : 300,
      'txCount': 2,
      'utxos': [],
    });
  }
  if (unknown) ownership.clear();
  return BitcoinDiscoverySnapshot(
    state: BitcoinWalletAccountState(
      walletIdentity: '0xwallet',
      network: BitcoinProductNetwork.mainnet,
      accountIndex: 0,
      accounts: accounts,
    ),
    ownership: ownership,
    activity: activity,
    scannedAt: DateTime.now().toUtc(),
  );
}

class BalanceRepository extends Fake implements BitcoinWalletApi {
  @override
  Future<BitcoinWalletSnapshot> refresh(
    String walletIdentity,
    BitcoinProductNetwork network, {
    bool force = false,
    bool Function()? isCurrent,
  }) async {
    expect(walletIdentity, '0xwallet');
    expect(network, BitcoinProductNetwork.mainnet);
    return BitcoinWalletSnapshot(fixture());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'portfolio reads HD balance using stable wallet identity and BTC price',
    () async {
      final service = BlockchainService(
        bitcoinWallet: BalanceRepository(),
        priceFetcher: (ids) async => {'bitcoin': 100000.0},
      );
      service.setActiveWalletContext(
        address: '0xwallet',
        supportedFamilies: {ChainFamily.evm, ChainFamily.bitcoin},
      );
      await service.setEnabledFamilies({ChainFamily.evm, ChainFamily.bitcoin});
      service.configureBitcoinAvailability(available: true);
      service.setActiveNetworkKey('bitcoin:mainnet');
      expect(
        await service.getNativeBalanceBaseUnits('0xwallet'),
        BigInt.from(3600),
      );
      final tokens = await service.fetchWalletTokens(
        '0xwallet',
        forceRefresh: true,
      );
      expect(tokens, hasLength(1));
      expect(tokens.single.symbol, 'BTC');
      expect(tokens.single.networkKey, 'bitcoin:mainnet');
      expect(tokens.single.balance, closeTo(0.000036, 1e-12));
      expect(tokens.single.valueUsd, closeTo(3.6, 1e-9));
      service.dispose();
    },
  );
  test('aggregates both formats with signed pending deltas in satoshis', () {
    final balance = BitcoinWalletSnapshot(fixture());
    expect(balance.totalSats, BigInt.from(3600));
    expect(balance.balances[BitcoinPurpose.bip84]!.totalSats, BigInt.from(800));
    expect(
      balance.balances[BitcoinPurpose.bip86]!.totalSats,
      BigInt.from(2800),
    );
    expect(balance.spendableSats, BigInt.zero);
    expect(() => balance.balances.clear(), throwsUnsupportedError);
  });
  test('rejects a provider delta that makes an account negative', () {
    expect(
      () => BitcoinWalletSnapshot(fixture(pending84: -1001)),
      throwsFormatException,
    );
  });
  test('rejects activity without locally derived ownership', () {
    expect(
      () => BitcoinWalletSnapshot(fixture(unknown: true)),
      throwsFormatException,
    );
  });
}
