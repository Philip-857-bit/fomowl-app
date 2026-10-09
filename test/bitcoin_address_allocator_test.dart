import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_account_store.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_address_allocator.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_native_crypto.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_protected_record.dart';
import 'helpers/bitcoin_memory_store.dart';

class AddressCrypto extends Fake implements BitcoinCryptoApi {
  bool fail = false;
  @override
  Future<String> deriveAddress(
    BitcoinHdAccountMetadata account,
    BitcoinKeychain keychain,
    int index,
  ) async {
    if (fail) throw StateError('Public fixture derivation failed');
    return 'bc1q_${account.purpose.number}_${keychain.name}_$index';
  }
}

void main() {
  late BitcoinAccountStore store;
  late BitcoinAccountSlot slot;
  late AddressCrypto crypto;
  late BitcoinAddressAllocator allocator;
  setUp(() async {
    store = BitcoinAccountStore(MemoryStore());
    crypto = AddressCrypto();
    slot = BitcoinAccountSlot(
      walletIdentity: '0xwallet',
      network: BitcoinProductNetwork.mainnet,
      accountIndex: 0,
      purpose: BitcoinPurpose.bip84,
    );
    final record = ProtectedBitcoinRecord(
      walletIdentity: slot.walletIdentity,
      state: BitcoinPurposeAccountState(
        metadata: BitcoinHdAccountMetadata(
          network: slot.network,
          purpose: slot.purpose,
          accountIndex: 0,
          masterFingerprint: '73c5da0a',
          accountXpub: 'xpub-public-fixture',
        ),
      ),
      encryptedVault: 'public-cipher-fixture',
      wrappingKey: Uint8List.fromList(List.filled(32, 7)),
    );
    await store.createIfAbsent(slot, record);
    record.dispose();
    allocator = BitcoinAddressAllocator(store: store, crypto: crypto);
  });
  test('repeated receive display does not consume an address', () async {
    final first = await allocator.currentReceive(slot);
    final second = await allocator.currentReceive(slot);
    expect(first.address, second.address);
    expect(first.addressIndex, 0);
    expect((await store.readState(slot))!.nextExternal, 0);
    await store.updateState(
      slot,
      (state) => state.advance(lastUsedExternal: 0, nextExternal: 1),
    );
    expect((await allocator.currentReceive(slot)).addressIndex, 1);
  });
  test(
    'concurrent change requests reserve distinct persistent indices',
    () async {
      final values = await Future.wait(
        List.generate(20, (_) => allocator.reserveChange(slot)),
      );
      expect(
        values.map((value) => value.addressIndex).toSet(),
        Set.from(List.generate(20, (index) => index)),
      );
      expect(
        values.every((value) => value.keychain == BitcoinKeychain.change),
        isTrue,
      );
      expect((await store.readState(slot))!.nextInternal, 20);
      final restarted = BitcoinAddressAllocator(
        store: BitcoinAccountStore(store.secureStore),
        crypto: crypto,
      );
      expect((await restarted.reserveChange(slot)).addressIndex, 20);
    },
  );
  test(
    'derivation/planning failure never rolls a reserved change index backwards',
    () async {
      crypto.fail = true;
      await expectLater(allocator.reserveChange(slot), throwsStateError);
      expect((await store.readState(slot))!.nextInternal, 1);
      crypto.fail = false;
      expect((await allocator.reserveChange(slot)).addressIndex, 1);
    },
  );
  test('dropped persistence prevents returning a change address', () async {
    final memory = store.secureStore as MemoryStore;
    memory.dropWrites = true;
    await expectLater(allocator.reserveChange(slot), throwsStateError);
    expect((await store.readState(slot))!.nextInternal, 0);
  });
}
