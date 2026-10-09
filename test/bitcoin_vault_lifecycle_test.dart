@Tags(['ffi'])
library;

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/wallet_account.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_native_crypto.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_protected_record.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_provisioning_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_wallet_vault_service.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/wallet_vault_service.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'helpers/bitcoin_memory_store.dart';

const mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

class DelayedOpenCrypto extends NativeBitcoinCrypto {
  final started = Completer<void>();
  final release = Completer<void>();
  BitcoinSigningAccount? opened;
  @override
  Future<BitcoinSigningAccount> openAccount(
    BitcoinHdAccountMetadata account,
    String encrypted,
    Uint8List key,
  ) async {
    started.complete();
    await release.future;
    return opened = await super.openAccount(account, encrypted, key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => RustLib.init());
  late StorageService storage;
  late BitcoinAccountSlot slot;
  late BitcoinHdAccountMetadata metadata;
  late BitcoinWalletVaultService vault;
  setUp(() async {
    WalletVaultService.unlock();
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(
      secureStore: MemoryStore(),
      sharedPreferences: await SharedPreferences.getInstance(),
    );
    const crypto = NativeBitcoinCrypto();
    final seed = await crypto.mnemonicToSeed(mnemonic);
    final identity = await crypto.seedWalletIdentity(seed, 0);
    seed.fillRange(0, seed.length, 0);
    await storage.saveWallet(
      address: identity,
      privateKey: 'public-fixture',
      mnemonic: mnemonic,
      origin: WalletOrigin.derived,
      derivationIndex: 0,
    );
    final state = (await BitcoinProvisioningService(
      storage: storage,
    ).ensureWallet(identity))!;
    metadata = state.accounts[BitcoinPurpose.bip84]!.metadata;
    slot = BitcoinAccountSlot(
      walletIdentity: identity,
      network: BitcoinProductNetwork.mainnet,
      accountIndex: 0,
      purpose: BitcoinPurpose.bip84,
    );
    vault = BitcoinWalletVaultService(store: storage.bitcoinAccounts);
  });
  tearDown(WalletVaultService.lockAll);
  test(
    'shared lock closes HD custody and rejects reopening until authenticated unlock',
    () async {
      final signer = await vault.open(slot, metadata);
      expect(BitcoinWalletVaultService.isOpen(signer), isTrue);
      await WalletVaultService.lockAll();
      expect(BitcoinWalletVaultService.isUnlocked, isFalse);
      expect(BitcoinWalletVaultService.isOpen(signer), isFalse);
      await expectLater(signer.accountInfo(), throwsStateError);
      await expectLater(vault.open(slot, metadata), throwsStateError);
      WalletVaultService.unlock();
      final restored = await vault.open(slot, metadata);
      expect(await restored.accountInfo(), metadata);
      await BitcoinWalletVaultService.close(restored);
    },
  );
  test(
    'wallet context invalidation closes both purposes without changing authentication',
    () async {
      final first = await vault.open(slot, metadata);
      final otherSlot = BitcoinAccountSlot(
        walletIdentity: slot.walletIdentity,
        network: slot.network,
        accountIndex: 0,
        purpose: BitcoinPurpose.bip86,
      );
      final otherMetadata = (await storage.bitcoinAccounts.readState(
        otherSlot,
      ))!.metadata;
      final second = await vault.open(otherSlot, otherMetadata);
      await WalletVaultService.invalidateOpenAccounts();
      expect(BitcoinWalletVaultService.isUnlocked, isTrue);
      await expectLater(first.accountInfo(), throwsStateError);
      await expectLater(second.accountInfo(), throwsStateError);
    },
  );
  test(
    'lock during asynchronous open closes the late signer rather than returning custody',
    () async {
      final delayed = DelayedOpenCrypto();
      final service = BitcoinWalletVaultService(
        store: storage.bitcoinAccounts,
        crypto: delayed,
      );
      final opening = service.open(slot, metadata);
      final rejected = expectLater(opening, throwsStateError);
      await delayed.started.future;
      await WalletVaultService.lockAll();
      delayed.release.complete();
      await rejected;
      expect(delayed.opened, isNotNull);
      await expectLater(delayed.opened!.accountInfo(), throwsStateError);
    },
  );
  test(
    'scoped use closes even after failure and refuses results from an expired context',
    () async {
      BitcoinSigningAccount? captured;
      await expectLater(
        vault.withAccount<void>(slot, metadata, (signer) async {
          captured = signer;
          throw StateError('Public fixture operation failed');
        }),
        throwsStateError,
      );
      await expectLater(captured!.accountInfo(), throwsStateError);
      final started = Completer<void>();
      final release = Completer<void>();
      final using = vault.withAccount<int>(slot, metadata, (signer) async {
        started.complete();
        await release.future;
        return 7;
      });
      final rejected = expectLater(using, throwsStateError);
      await started.future;
      await WalletVaultService.invalidateOpenAccounts();
      release.complete();
      await rejected;
    },
  );
  test(
    'restart is locked and a mismatched purpose cannot open the existing vault',
    () async {
      await WalletVaultService.lockAll();
      await expectLater(vault.open(slot, metadata), throwsStateError);
      WalletVaultService.unlock();
      final wrongSlot = BitcoinAccountSlot(
        walletIdentity: slot.walletIdentity,
        network: slot.network,
        accountIndex: 0,
        purpose: BitcoinPurpose.bip86,
      );
      await expectLater(vault.open(wrongSlot, metadata), throwsStateError);
    },
  );
}
