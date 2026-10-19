import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_discovery.dart';
import 'bitcoin_account_store.dart';
import 'bitcoin_native_crypto.dart';
import 'bitcoin_protected_record.dart';

/// Receive display never consumes an index. Change is durably reserved before use.
class BitcoinAddressAllocator {
  final BitcoinAccountStore store;
  final BitcoinCryptoApi crypto;
  BitcoinAddressAllocator({
    required this.store,
    this.crypto = const NativeBitcoinCrypto(),
  });
  Future<BitcoinDerivedAddress> currentReceive(BitcoinAccountSlot slot) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final state = await store.readState(slot);
      if (state == null) throw StateError('Bitcoin account is not provisioned');
      final index = state.nextExternal;
      final address = await crypto.deriveAddress(
        state.metadata,
        BitcoinKeychain.receive,
        index,
      );
      final latest = await store.readState(slot);
      if (latest == null || latest.metadata != state.metadata) {
        throw StateError('Bitcoin account context changed');
      }
      if (latest.nextExternal == index) {
        return BitcoinDerivedAddress(
          account: state.metadata,
          keychain: BitcoinKeychain.receive,
          addressIndex: index,
          address: address,
        );
      }
    }
    throw StateError('Bitcoin receive address changed during discovery');
  }

  Future<BitcoinDerivedAddress> reserveChange(BitcoinAccountSlot slot) async {
    late int reserved;
    final state = await store.updateState(slot, (current) {
      reserved = current.nextInternal;
      if (reserved >= 0x7fffffff) {
        throw StateError('Bitcoin change index exhausted');
      }
      return current.advance(nextInternal: reserved + 1);
    });
    // Failure after persistence burns the index; it is deliberately never decremented.
    final address = await crypto.deriveAddress(
      state.metadata,
      BitcoinKeychain.change,
      reserved,
    );
    return BitcoinDerivedAddress(
      account: state.metadata,
      keychain: BitcoinKeychain.change,
      addressIndex: reserved,
      address: address,
    );
  }
}
