@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/wallet_account.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_native_crypto.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_protected_record.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_provisioning_service.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'helpers/bitcoin_memory_store.dart';

const mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

class TrackingCrypto extends NativeBitcoinCrypto {
  int seedReads = 0;
  int seals = 0;
  int opens = 0;
  bool failBip86 = false;
  Uint8List? lastSeed;
  final keys = <Uint8List>[];
  @override
  Future<Uint8List> mnemonicToSeed(String mnemonic) async {
    seedReads++;
    return lastSeed = await super.mnemonicToSeed(mnemonic);
  }

  @override
  Future<Uint8List> wrappingKey() async {
    final key = await super.wrappingKey();
    keys.add(key);
    return key;
  }

  @override
  Future<SealedBitcoinAccount> sealSeedAccount(
    Uint8List seed,
    BitcoinProductNetwork network,
    int index,
    BitcoinPurpose purpose,
    Uint8List key,
  ) {
    if (failBip86 && purpose == BitcoinPurpose.bip86) {
      throw StateError('Simulated interrupted provisioning');
    }
    seals++;
    return super.sealSeedAccount(seed, network, index, purpose, key);
  }

  @override
  Future<BitcoinSigningAccount> openAccount(
    BitcoinHdAccountMetadata account,
    String ciphertext,
    Uint8List key,
  ) {
    opens++;
    return super.openAccount(account, ciphertext, key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => RustLib.init());
  late StorageService storage;
  late MemoryStore memory;
  late TrackingCrypto crypto;
  late String identity;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    memory = MemoryStore();
    crypto = TrackingCrypto();
    storage = StorageService(
      secureStore: memory,
      sharedPreferences: await SharedPreferences.getInstance(),
    );
    final seed = await crypto.mnemonicToSeed(mnemonic);
    identity = await crypto.seedWalletIdentity(seed, 0);
    seed.fillRange(0, seed.length, 0);
    crypto.seedReads = 0;
    await storage.saveWallet(
      address: identity,
      privateKey: 'public-fixture-placeholder',
      mnemonic: mnemonic,
      origin: WalletOrigin.derived,
      derivationIndex: 0,
      seedGroupId: 'seed_fixture',
    );
  });
  test(
    'real seed provisioning seals both purposes and reopens idempotently without reloading seed',
    () async {
      final service = BitcoinProvisioningService(
        storage: storage,
        crypto: crypto,
      );
      final state = (await service.ensureWallet(identity))!;
      expect(state.accounts.length, 2);
      expect(crypto.seals, 2);
      expect(crypto.seedReads, 1);
      expect(
        await crypto.deriveAddress(
          state.accounts[BitcoinPurpose.bip84]!.metadata,
          BitcoinKeychain.receive,
          0,
        ),
        'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      );
      expect(
        await crypto.deriveAddress(
          state.accounts[BitcoinPurpose.bip86]!.metadata,
          BitcoinKeychain.receive,
          0,
        ),
        'bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr',
      );
      final records = Map<String, String>.fromEntries(
        memory.values.entries.where(
          (entry) => entry.key.startsWith('bitcoin_hd_v1_'),
        ),
      );
      expect(records.length, 2);
      expect(crypto.lastSeed, everyElement(0));
      for (final key in crypto.keys) {
        expect(key, everyElement(0));
      }
      final repeated = await BitcoinProvisioningService(
        storage: storage,
        crypto: crypto,
      ).ensureWallet(identity);
      expect(
        repeated!.accounts[BitcoinPurpose.bip84]!.metadata,
        state.accounts[BitcoinPurpose.bip84]!.metadata,
      );
      expect(crypto.seals, 2);
      expect(crypto.seedReads, 1);
      for (final entry in records.entries) {
        expect(memory.values[entry.key], entry.value);
      }
      expect(
        (await storage.getWalletAccounts()).single.supportsBitcoin,
        isTrue,
      );
    },
  );
  test(
    'concurrent provisioning shares one seed/seal operation per account',
    () async {
      final first = BitcoinProvisioningService(
        storage: storage,
        crypto: crypto,
      );
      final second = BitcoinProvisioningService(
        storage: storage,
        crypto: crypto,
      );
      final results = await Future.wait([
        first.ensureWallet(identity),
        second.ensureWallet(identity),
      ]);
      expect(results.every((state) => state!.accounts.length == 2), isTrue);
      expect(crypto.seedReads, 1);
      expect(crypto.seals, 2);
    },
  );

  test(
    'interrupted second purpose resumes without resealing the first or rolling indices back',
    () async {
      final service = BitcoinProvisioningService(
        storage: storage,
        crypto: crypto,
      );
      crypto.failBip86 = true;
      await expectLater(service.ensureWallet(identity), throwsStateError);
      expect(crypto.seals, 1);
      expect(
        (await storage.getWalletAccounts()).single.supportsBitcoin,
        isFalse,
      );
      final location = BitcoinAccountSlot(
        walletIdentity: identity,
        network: BitcoinProductNetwork.mainnet,
        accountIndex: 0,
        purpose: BitcoinPurpose.bip84,
      );
      await storage.bitcoinAccounts.updateState(
        location,
        (state) => state.advance(nextInternal: 3),
      );
      crypto.failBip86 = false;
      final restored = await service.ensureWallet(identity);
      expect(crypto.seals, 2);
      expect(restored!.accounts[BitcoinPurpose.bip84]!.nextInternal, 3);
    },
  );
  test(
    'corrupt authoritative ciphertext fails rather than loading seed or resealing',
    () async {
      final service = BitcoinProvisioningService(
        storage: storage,
        crypto: crypto,
      );
      await service.ensureWallet(identity);
      final location = BitcoinAccountSlot(
        walletIdentity: identity,
        network: BitcoinProductNetwork.mainnet,
        accountIndex: 0,
        purpose: BitcoinPurpose.bip84,
      );
      final raw =
          jsonDecode(memory.values[location.storageKey]!)
              as Map<String, dynamic>;
      raw['encryptedVault'] = 'corrupt';
      memory.values[location.storageKey] = jsonEncode(raw);
      await expectLater(
        service.ensureWallet(identity),
        throwsA(
          predicate(
            (Object error) => error.toString().toLowerCase().contains('vault'),
          ),
        ),
      );
      expect(crypto.seals, 2);
      expect(crypto.seedReads, 1);
      expect(
        jsonDecode(memory.values[location.storageKey]!)['encryptedVault'],
        'corrupt',
      );
    },
  );
  test(
    'private-key imports never provision Bitcoin, even when another seed is stored',
    () async {
      await storage.saveWallet(
        address: '0x1111111111111111111111111111111111111111',
        privateKey: 'public-fixture',
        origin: WalletOrigin.imported,
      );
      final service = BitcoinProvisioningService(
        storage: storage,
        crypto: crypto,
      );
      expect(
        await service.ensureWallet(
          '0x1111111111111111111111111111111111111111',
        ),
        isNull,
      );
      expect(crypto.seals, 0);
      expect(crypto.seedReads, 0);
    },
  );
  test(
    'seed group/account identity mismatch fails before any Bitcoin secret is sealed',
    () async {
      await storage.saveWallet(
        address: '0x2222222222222222222222222222222222222222',
        privateKey: 'public-fixture',
        mnemonic: mnemonic,
        origin: WalletOrigin.derived,
        derivationIndex: 0,
        seedGroupId: 'seed_wrong_identity',
      );
      final service = BitcoinProvisioningService(
        storage: storage,
        crypto: crypto,
      );
      await expectLater(
        service.ensureWallet('0x2222222222222222222222222222222222222222'),
        throwsStateError,
      );
      expect(crypto.seals, 0);
      expect(crypto.lastSeed, everyElement(0));
    },
  );
  test(
    'testnet4 custody uses explicit network metadata and never reuses mainnet records',
    () async {
      final service = BitcoinProvisioningService(
        storage: storage,
        crypto: crypto,
      );
      final main = (await service.ensureWallet(identity))!;
      final test = (await service.ensureWallet(
        identity,
        network: BitcoinProductNetwork.testnet4,
      ))!;
      expect(test.network, BitcoinProductNetwork.testnet4);
      expect(
        test.accounts[BitcoinPurpose.bip84]!.metadata.accountXpub,
        isNot(main.accounts[BitcoinPurpose.bip84]!.metadata.accountXpub),
      );
      expect(
        await crypto.deriveAddress(
          test.accounts[BitcoinPurpose.bip84]!.metadata,
          BitcoinKeychain.receive,
          0,
        ),
        startsWith('tb1q'),
      );
      expect(
        await crypto.deriveAddress(
          test.accounts[BitcoinPurpose.bip86]!.metadata,
          BitcoinKeychain.receive,
          0,
        ),
        startsWith('tb1p'),
      );
      expect(crypto.seals, 4);
    },
  );
}
