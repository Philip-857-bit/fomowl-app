import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_account_store.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_discovery_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_native_crypto.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_protected_record.dart';
import 'helpers/bitcoin_memory_store.dart';

class PublicCrypto extends Fake implements BitcoinCryptoApi {
  @override
  Future<String> deriveAddress(
    BitcoinHdAccountMetadata account,
    BitcoinKeychain keychain,
    int index,
  ) async => 'bc1q_${account.purpose.number}_${keychain.name}_$index';
}

class ActivityNetwork extends Fake implements BitcoinNetworkApi {
  final bool Function(String) used;
  final seen = <String>[];
  bool incomplete = false;
  void Function()? afterRequest;
  ActivityNetwork(this.used);
  @override
  Future<List<BitcoinAddressActivity>> fetchAccountState(
    String walletIdentity,
    BitcoinProductNetwork network,
    List<String> addresses,
  ) async {
    expect(addresses.length, lessThanOrEqualTo(40));
    expect(addresses.any((value) => value.contains('xpub')), isFalse);
    seen.addAll(addresses);
    afterRequest?.call();
    final values = incomplete
        ? addresses.take(addresses.length - 1)
        : addresses;
    return values
        .map(
          (address) => BitcoinAddressActivity.fromJson({
            'address': address,
            'used': used(address),
            'confirmedBalanceSats': 0,
            'mempoolBalanceSats': 0,
            'txCount': used(address) ? 1 : 0,
            'utxos': [],
          }),
        )
        .toList();
  }
}

Future<BitcoinWalletAccountState> initialize(
  BitcoinAccountStore store, {
  int internal84 = 0,
}) async {
  for (final purpose in BitcoinPurpose.values) {
    final slot = BitcoinAccountSlot(
      walletIdentity: '0xwallet',
      network: BitcoinProductNetwork.mainnet,
      accountIndex: 0,
      purpose: purpose,
    );
    final metadata = BitcoinHdAccountMetadata(
      network: slot.network,
      purpose: purpose,
      accountIndex: 0,
      masterFingerprint: '73c5da0a',
      accountXpub: 'xpub-public-${purpose.number}',
    );
    final candidate = ProtectedBitcoinRecord(
      walletIdentity: slot.walletIdentity,
      state: BitcoinPurposeAccountState(
        metadata: metadata,
        nextInternal: purpose == BitcoinPurpose.bip84 ? internal84 : 0,
      ),
      encryptedVault: 'public-cipher-fixture',
      wrappingKey: Uint8List.fromList(List.filled(32, 7)),
    );
    await store.createIfAbsent(slot, candidate);
    candidate.dispose();
  }
  return (await store.readWalletState(
    '0xwallet',
    BitcoinProductNetwork.mainnet,
    0,
  ))!;
}

void main() {
  test(
    'four independent lanes honor a real gap across batches and all observed activity',
    () async {
      final store = BitcoinAccountStore(MemoryStore());
      final initial = await initialize(store);
      final network = ActivityNetwork(
        (address) =>
            address == 'bc1q_84_receive_18' ||
            address == 'bc1q_84_receive_25' ||
            address == 'bc1q_86_change_0',
      );
      final snapshot = await BitcoinDiscoveryService(
        store: store,
        network: network,
        crypto: PublicCrypto(),
        maximumScanIndex: 100,
      ).scan(initial);
      expect(
        snapshot.state.accounts[BitcoinPurpose.bip84]!.lastUsedExternal,
        25,
      );
      expect(snapshot.state.accounts[BitcoinPurpose.bip84]!.nextExternal, 26);
      expect(
        snapshot.state.accounts[BitcoinPurpose.bip86]!.lastUsedInternal,
        0,
      );
      expect(snapshot.state.accounts[BitcoinPurpose.bip86]!.nextInternal, 1);
      expect(network.seen, contains('bc1q_84_receive_59'));
      for (final purpose in BitcoinPurpose.values) {
        for (final keychain in BitcoinKeychain.values) {
          expect(
            network.seen,
            contains('bc1q_${purpose.number}_${keychain.name}_0'),
          );
        }
      }
      expect(snapshot.ownership['bc1q_84_receive_25']!.addressIndex, 25);
      expect(() => snapshot.activity.clear(), throwsUnsupportedError);
    },
  );
  test(
    'known burned change indices extend discovery beyond an initial empty batch',
    () async {
      final store = BitcoinAccountStore(MemoryStore());
      final initial = await initialize(store, internal84: 41);
      final network = ActivityNetwork((_) => false);
      final snapshot = await BitcoinDiscoveryService(
        store: store,
        network: network,
        crypto: PublicCrypto(),
        maximumScanIndex: 100,
      ).scan(initial);
      expect(network.seen, contains('bc1q_84_change_79'));
      expect(snapshot.state.accounts[BitcoinPurpose.bip84]!.nextInternal, 41);
      expect(snapshot.state.accounts[BitcoinPurpose.bip84]!.nextExternal, 0);
    },
  );
  test('incomplete provider data fails before indices are advanced', () async {
    final store = BitcoinAccountStore(MemoryStore());
    final initial = await initialize(store);
    final network = ActivityNetwork((_) => true)..incomplete = true;
    await expectLater(
      BitcoinDiscoveryService(
        store: store,
        network: network,
        crypto: PublicCrypto(),
      ).scan(initial),
      throwsFormatException,
    );
    expect(
      (await store.readWalletState(
        '0xwallet',
        BitcoinProductNetwork.mainnet,
        0,
      ))!.accounts[BitcoinPurpose.bip84]!.nextExternal,
      0,
    );
  });
  test(
    'bounded scan exhaustion is an error rather than pretending discovery completed',
    () async {
      final store = BitcoinAccountStore(MemoryStore());
      final initial = await initialize(store);
      final network = ActivityNetwork((_) => true);
      await expectLater(
        BitcoinDiscoveryService(
          store: store,
          network: network,
          crypto: PublicCrypto(),
          maximumScanIndex: 60,
        ).scan(initial),
        throwsStateError,
      );
      expect(network.seen.length, 60);
    },
  );
  test(
    'wallet-context change discards late activity and prevents a stale state write',
    () async {
      final store = BitcoinAccountStore(MemoryStore());
      final initial = await initialize(store);
      var current = true;
      final network = ActivityNetwork((_) => true)
        ..afterRequest = () => current = false;
      await expectLater(
        BitcoinDiscoveryService(
          store: store,
          network: network,
          crypto: PublicCrypto(),
        ).scan(initial, isCurrent: () => current),
        throwsStateError,
      );
      expect(
        (await store.readWalletState(
          '0xwallet',
          BitcoinProductNetwork.mainnet,
          0,
        ))!.accounts[BitcoinPurpose.bip84]!.nextExternal,
        0,
      );
    },
  );
}
