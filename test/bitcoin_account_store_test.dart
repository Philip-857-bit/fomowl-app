import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/wallet_account.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_account_store.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_protected_record.dart';
import 'helpers/bitcoin_memory_store.dart';
import 'package:fomowl_wallet/services/storage_service.dart';

BitcoinAccountSlot slot({
  String identity = '0xabc',
  BitcoinPurpose purpose = BitcoinPurpose.bip84,
}) => BitcoinAccountSlot(
  walletIdentity: identity,
  network: BitcoinProductNetwork.mainnet,
  accountIndex: 0,
  purpose: purpose,
);
ProtectedBitcoinRecord record(BitcoinAccountSlot slot) =>
    ProtectedBitcoinRecord(
      walletIdentity: slot.walletIdentity,
      state: BitcoinPurposeAccountState(
        metadata: BitcoinHdAccountMetadata(
          network: slot.network,
          purpose: slot.purpose,
          accountIndex: slot.accountIndex,
          masterFingerprint: '73c5da0a',
          accountXpub: 'xpub-public-${slot.purpose.number}',
        ),
      ),
      encryptedVault: 'ciphertext-public-fixture',
      wrappingKey: Uint8List.fromList(List.filled(32, 7)),
    );
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'record state/cipher/key write is atomic and manifest precedes custody',
    () async {
      final memory = MemoryStore();
      final store = BitcoinAccountStore(memory);
      final location = slot();
      final candidate = record(location);
      try {
        expect(await store.createIfAbsent(location, candidate), isTrue);
      } finally {
        candidate.dispose();
      }
      expect(memory.writes.first, contains('manifest'));
      expect(memory.writes.last, location.storageKey);
      expect(
        (await store.readState(location))!.metadata.accountXpub,
        'xpub-public-84',
      );
      final restarted = BitcoinAccountStore(memory);
      expect((await restarted.readState(location))!.nextInternal, 0);
      final duplicate = record(location);
      try {
        expect(await restarted.createIfAbsent(location, duplicate), isFalse);
      } finally {
        duplicate.dispose();
      }
      final bytes = await store.withRecord(
        location,
        (loaded) => loaded.wrappingKey,
      );
      expect(bytes, everyElement(0));
    },
  );
  test(
    'concurrent index mutations serialize across wrappers and never roll back',
    () async {
      final memory = MemoryStore();
      final first = BitcoinAccountStore(memory);
      final second = BitcoinAccountStore(memory);
      final location = slot();
      final candidate = record(location);
      await first.createIfAbsent(location, candidate);
      candidate.dispose();
      await Future.wait(
        List.generate(
          20,
          (index) => (index.isEven ? first : second).updateState(
            location,
            (state) => state.advance(nextInternal: state.nextInternal + 1),
          ),
        ),
      );
      expect((await first.readState(location))!.nextInternal, 20);
      await expectLater(
        first.updateState(
          location,
          (state) => BitcoinPurposeAccountState(
            metadata: state.metadata,
            nextInternal: 19,
          ),
        ),
        throwsStateError,
      );
      expect((await second.readState(location))!.nextInternal, 20);
    },
  );
  test(
    'corrupt records and dropped persistence fail without secret-bearing errors',
    () async {
      final memory = MemoryStore();
      final store = BitcoinAccountStore(memory);
      final location = slot();
      memory.values[location.storageKey] = '{secret-wrapping-data';
      await expectLater(
        store.readState(location),
        throwsA(
          isA<FormatException>().having(
            (e) => e.toString(),
            'redacted',
            isNot(contains('secret-wrapping-data')),
          ),
        ),
      );
      final candidate = record(location);
      await expectLater(
        store.createIfAbsent(location, candidate),
        throwsFormatException,
      );
      memory.values.clear();
      memory.dropWrites = true;
      await expectLater(
        store.createIfAbsent(location, candidate),
        throwsStateError,
      );
      memory.dropWrites = false;
      memory.failWrites = true;
      await expectLater(
        store.createIfAbsent(location, candidate),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'redacted',
            isNot(contains('secret-wrapping-data')),
          ),
        ),
      );
      candidate.dispose();
    },
  );
  test(
    'deletion invalidates queued writes, retains retry journal, and restoration starts clean',
    () async {
      final memory = MemoryStore();
      final store = BitcoinAccountStore(memory);
      final location = slot();
      final candidate = record(location);
      await store.createIfAbsent(location, candidate);
      candidate.dispose();
      final pending = store.updateState(
        location,
        (state) => state.advance(nextInternal: 1),
      );
      final rejected = expectLater(pending, throwsStateError);
      await store.deleteWallet(location.walletIdentity);
      await rejected;
      expect(memory.values.containsKey(location.storageKey), isFalse);
      expect(await store.readState(location), isNull);
      final replacement = record(location);
      await expectLater(
        store.createIfAbsent(location, replacement),
        throwsStateError,
      );
      await store.activateWallet(location.walletIdentity);
      await store.createIfAbsent(location, replacement);
      replacement.dispose();
      memory.dropDeletes = true;
      await expectLater(
        store.deleteWallet(location.walletIdentity),
        throwsStateError,
      );
      expect(await store.readState(location), isNull);
      memory.dropDeletes = false;
      await store.activateWallet(location.walletIdentity);
      expect(memory.values.containsKey(location.storageKey), isFalse);
    },
  );
  test(
    'wallet rename preserves capability and HD keys; removal/reset delete custody',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final memory = MemoryStore();
      final storage = StorageService(
        secureStore: memory,
        sharedPreferences: prefs,
      );
      await storage.saveWallet(
        address: '0xabc',
        privateKey: 'public-fixture',
        walletName: 'Original',
        origin: WalletOrigin.derived,
        derivationIndex: 0,
      );
      await storage.saveWallet(
        address: '0xdef',
        privateKey: 'public-fixture',
        walletName: 'Other',
        origin: WalletOrigin.imported,
      );
      await storage.setWalletBitcoinSupport('0xabc', true);
      final location = slot();
      final candidate = record(location);
      await storage.bitcoinAccounts.createIfAbsent(location, candidate);
      candidate.dispose();
      final original = memory.values[location.storageKey];
      await storage.renameWallet('0xabc', 'Renamed');
      expect(
        (await storage.getWalletAccounts())
            .firstWhere((wallet) => wallet.address == '0xabc')
            .supportsBitcoin,
        isTrue,
      );
      expect(memory.values[location.storageKey], original);
      await storage.removeWalletAccount('0xabc');
      expect(memory.values.containsKey(location.storageKey), isFalse);
      await storage.clearAll();
      expect(memory.values, isEmpty);
    },
  );
  test(
    'protected codec rejects transplanted identities and never prints wrapping bytes',
    () async {
      final memory = MemoryStore();
      final store = BitcoinAccountStore(memory);
      final original = record(slot());
      expect(original.toString(), isNot(contains('070707')));
      memory.values[slot(identity: '0xdef').storageKey] = original.encode();
      await expectLater(
        store.readState(slot(identity: '0xdef')),
        throwsFormatException,
      );
      final raw = jsonDecode(original.encode()) as Map<String, dynamic>;
      await expectLater(
        Future(
          () => ProtectedBitcoinRecord.decode(
            jsonEncode({...raw, 'revision': -1}),
          ),
        ),
        throwsFormatException,
      );
      original.dispose();
    },
  );
}
