import 'dart:typed_data';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_account_store.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_native_crypto.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_protected_record.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_signing_service.dart';
import '../bitcoin_confirmation_test.dart' show transfer;
import 'bitcoin_memory_store.dart';

Future<BitcoinSignedTransfer> signedFixture() async {
  final prepared = await transfer();
  const crypto = NativeBitcoinCrypto();
  final seed = await crypto.mnemonicToSeed(
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
  );
  final key = Uint8List.fromList(List.filled(32, 7));
  final store = BitcoinAccountStore(MemoryStore());
  try {
    final sealed = await crypto.sealSeedAccount(
      seed,
      prepared.network,
      0,
      BitcoinPurpose.bip84,
      key,
    );
    final slot = BitcoinAccountSlot(
      walletIdentity: '0xwallet',
      network: prepared.network,
      accountIndex: 0,
      purpose: BitcoinPurpose.bip84,
    );
    final record = ProtectedBitcoinRecord(
      walletIdentity: slot.walletIdentity,
      state: BitcoinPurposeAccountState(metadata: sealed.metadata),
      encryptedVault: sealed.encryptedVault,
      wrappingKey: Uint8List.fromList(key),
    );
    await store.createIfAbsent(slot, record);
    record.dispose();
  } finally {
    seed.fillRange(0, seed.length, 0);
    key.fillRange(0, key.length, 0);
  }
  return BitcoinSigningService(
    store: store,
  ).sign(prepared, authenticate: () async => true, isCurrent: () => true);
}
