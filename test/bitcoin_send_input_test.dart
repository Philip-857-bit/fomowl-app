@Tags(['ffi'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_account_store.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_protected_record.dart';
import 'helpers/bitcoin_memory_store.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_discovery.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/models/bitcoin_wallet_balance.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_native_crypto.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_send_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_wallet_service.dart';
import 'package:fomowl_wallet/src/rust/api/bitcoin_transaction.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'package:fomowl_wallet/utils/bitcoin_amount_utils.dart';

class SnapshotWallet extends Fake implements BitcoinWalletApi {
  final BitcoinWalletSnapshot snapshot;
  SnapshotWallet(this.snapshot);
  @override
  Future<BitcoinWalletSnapshot> refresh(
    String identity,
    BitcoinProductNetwork network, {
    bool force = false,
    bool Function()? isCurrent,
  }) async => snapshot;
}

class FixedFees extends Fake implements BitcoinNetworkApi {
  @override
  Future<BitcoinFeeRates> fetchFeeRates(BitcoinProductNetwork network) async =>
      BitcoinFeeRates.fromJson({
        'economy': 1,
        'normal': 1,
        'priority': 2,
        'minimum': 1,
        'stale': false,
      });
}

Future<BitcoinWalletSnapshot> twoFormats(
  int nativeSats,
  int taprootSats,
) async {
  const crypto = NativeBitcoinCrypto();
  final seed = await crypto.mnemonicToSeed(
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
  );
  final accounts = <BitcoinPurpose, BitcoinPurposeAccountState>{};
  final ownership = <String, BitcoinDerivedAddress>{};
  final activity = <String, BitcoinAddressActivity>{};
  try {
    for (final purpose in BitcoinPurpose.values) {
      final account = await crypto.deriveAccount(
        seed,
        BitcoinProductNetwork.mainnet,
        0,
        purpose,
      );
      final address = await crypto.deriveAddress(
        account,
        BitcoinKeychain.receive,
        0,
      );
      final script = await crypto.deriveScript(
        account,
        BitcoinKeychain.receive,
        0,
      );
      final value = purpose == BitcoinPurpose.bip84 ? nativeSats : taprootSats;
      accounts[purpose] = BitcoinPurposeAccountState(metadata: account);
      ownership[address] = BitcoinDerivedAddress(
        account: account,
        keychain: BitcoinKeychain.receive,
        addressIndex: 0,
        address: address,
      );
      activity[address] = BitcoinAddressActivity.fromJson({
        'address': address,
        'used': true,
        'confirmedBalanceSats': value,
        'mempoolBalanceSats': 0,
        'txCount': 1,
        'utxos': [
          {
            'txid': List.filled(
              64,
              purpose == BitcoinPurpose.bip84 ? '1' : '2',
            ).join(),
            'vout': 0,
            'valueSats': value,
            'address': address,
            'scriptPubkeyHex': script,
            'confirmed': true,
            'blockHeight': 1,
          },
        ],
      });
    }
  } finally {
    seed.fillRange(0, seed.length, 0);
  }
  return BitcoinWalletSnapshot(
    BitcoinDiscoverySnapshot(
      state: BitcoinWalletAccountState(
        walletIdentity: '0xwallet',
        network: BitcoinProductNetwork.mainnet,
        accountIndex: 0,
        accounts: accounts,
      ),
      ownership: ownership,
      activity: activity,
      scannedAt: DateTime.now().toUtc(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => RustLib.init());
  test(
    'purpose selection prefers BIP84, falls back to BIP86 and rejects split funds',
    () async {
      final snapshot = await twoFormats(500, 1200);
      final service = BitcoinSendService(
        wallet: SnapshotWallet(snapshot),
        network: FixedFees(),
        store: BitcoinAccountStore(MemoryStore()),
      );
      final recipient = snapshot.discovery.ownership.keys.first;
      expect(
        await service.selectPurpose(
          snapshot,
          recipient,
          BigInt.from(350),
          BigInt.one,
        ),
        BitcoinPurpose.bip84,
      );
      expect(
        await service.selectPurpose(
          snapshot,
          recipient,
          BigInt.from(700),
          BigInt.one,
        ),
        BitcoinPurpose.bip86,
      );
      await expectLater(
        service.selectPurpose(
          snapshot,
          recipient,
          BigInt.from(1500),
          BigInt.one,
        ),
        throwsA(isA<BitcoinSplitFundsException>()),
      );
      await expectLater(
        service.selectPurpose(
          snapshot,
          recipient,
          BigInt.from(2000),
          BigInt.one,
        ),
        throwsStateError,
      );
      await expectLater(
        service.selectPurpose(
          snapshot,
          recipient,
          BigInt.from(350),
          BigInt.one,
          isCurrent: () => false,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'BTC parsing preserves satoshis and rejects excess precision and ambiguous input',
    () {
      expect(BitcoinAmountUtils.parse('0.00000001'), BigInt.one);
      expect(
        BitcoinAmountUtils.parse('21000000'),
        BigInt.from(2100000000000000),
      );
      for (final input in [
        '0',
        '-1',
        '1e-8',
        '1,000',
        '0.000000001',
        '21000000.00000001',
      ]) {
        expect(() => BitcoinAmountUtils.parse(input), throwsFormatException);
      }
      expect(BitcoinAmountUtils.format(BigInt.from(123456789)), '1.23456789');
    },
  );
  test('recipient guidance distinguishes mainnet from testnet4', () {
    const address = 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';
    expect(
      BitcoinAmountUtils.recipientLooksCompatible(
        address,
        BitcoinProductNetwork.mainnet,
      ),
      isTrue,
    );
    expect(
      BitcoinAmountUtils.recipientLooksCompatible(
        address,
        BitcoinProductNetwork.testnet4,
      ),
      isFalse,
    );
  });
  test(
    'Max uses native fee and dust policy even when half the balance would be dust',
    () async {
      const crypto = NativeBitcoinCrypto();
      final seed = await crypto.mnemonicToSeed(
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      );
      final account = await crypto.deriveAccount(
        seed,
        BitcoinProductNetwork.mainnet,
        0,
        BitcoinPurpose.bip84,
      );
      seed.fillRange(0, seed.length, 0);
      final address = await crypto.deriveAddress(
        account,
        BitcoinKeychain.receive,
        0,
      );
      final script = await crypto.deriveScript(
        account,
        BitcoinKeychain.receive,
        0,
      );
      final snapshot = BitcoinWalletSnapshot(
        BitcoinDiscoverySnapshot(
          state: BitcoinWalletAccountState(
            walletIdentity: '0xwallet',
            network: account.network,
            accountIndex: 0,
            accounts: {
              BitcoinPurpose.bip84: BitcoinPurposeAccountState(
                metadata: account,
              ),
            },
          ),
          ownership: {
            address: BitcoinDerivedAddress(
              account: account,
              keychain: BitcoinKeychain.receive,
              addressIndex: 0,
              address: address,
            ),
          },
          activity: {
            address: BitcoinAddressActivity.fromJson({
              'address': address,
              'used': true,
              'confirmedBalanceSats': 500,
              'mempoolBalanceSats': 0,
              'txCount': 1,
              'utxos': [
                {
                  'txid': List.filled(64, '1').join(),
                  'vout': 0,
                  'valueSats': 500,
                  'address': address,
                  'scriptPubkeyHex': script,
                  'confirmed': true,
                  'blockHeight': 1,
                },
              ],
            }),
          },
          scannedAt: DateTime.now().toUtc(),
        ),
      );
      final store = BitcoinAccountStore(MemoryStore());
      final slot = BitcoinAccountSlot(
        walletIdentity: '0xwallet',
        network: account.network,
        accountIndex: 0,
        purpose: BitcoinPurpose.bip84,
      );
      final record = ProtectedBitcoinRecord(
        walletIdentity: '0xwallet',
        state: BitcoinPurposeAccountState(metadata: account),
        encryptedVault: 'public-fixture',
        wrappingKey: Uint8List(32),
      );
      await store.createIfAbsent(slot, record);
      record.dispose();
      final service = BitcoinSendService(
        store: store,
        wallet: SnapshotWallet(snapshot),
        network: FixedFees(),
      );
      final prepared = await service.prepareTransfer(
        '0xwallet',
        account.network,
        address,
        BigInt.from(350),
      );
      expect(prepared.plan.recipientTotalSat, BigInt.from(350));
      expect(prepared.plan.changeIndex, 0);
      expect(prepared.plan.rbf, isTrue);
      expect((await store.readState(slot))!.nextInternal, 1);
      await expectLater(
        service.prepareTransfer(
          '0xwallet',
          account.network,
          address,
          BigInt.from(501),
          purpose: BitcoinPurpose.bip84,
        ),
        throwsA('Insufficient Bitcoin funds'),
      );
      expect((await store.readState(slot))!.nextInternal, 2);
      await expectLater(
        service.prepareTransfer(
          'other-wallet',
          account.network,
          address,
          BigInt.from(350),
        ),
        throwsStateError,
      );
      expect((await store.readState(slot))!.nextInternal, 2);
      final maximum = await service.maximumAmount(
        '0xwallet',
        account.network,
        address,
      );
      final inputs = await service.ownedInputs(snapshot, BitcoinPurpose.bip84);
      final plan = await crypto.plan(
        account,
        inputs,
        [BitcoinRecipientDto(address: address, amountSat: maximum)],
        BigInt.one,
        0,
        true,
      );
      expect(maximum + plan.feeSat, BigInt.from(500));
      expect(plan.changeSat, BigInt.zero);
      await expectLater(
        crypto.plan(
          account,
          inputs,
          [
            BitcoinRecipientDto(
              address: address,
              amountSat: maximum + BigInt.one,
            ),
          ],
          BigInt.one,
          0,
          true,
        ),
        throwsA('Insufficient Bitcoin funds'),
      );
      await expectLater(
        service.maximumAmount(
          '0xwallet',
          account.network,
          address,
          isCurrent: () => false,
        ),
        throwsStateError,
      );
    },
  );
}
