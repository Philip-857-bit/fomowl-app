@Tags(['ffi'])
library;

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_native_crypto.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_account_store.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_protected_record.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_send_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_signing_service.dart';
import 'package:fomowl_wallet/services/wallet_vault_service.dart';
import 'package:fomowl_wallet/src/rust/api/bitcoin_transaction.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'bitcoin_send_input_test.dart'
    show twoFormats, SnapshotWallet, FixedFees;
import 'helpers/bitcoin_memory_store.dart';

class ObservedSigner implements BitcoinSigningAccount {
  final BitcoinSigningAccount inner;
  final void Function() onClose;
  ObservedSigner(this.inner, this.onClose);
  @override
  Future<BitcoinHdAccountMetadata> accountInfo() => inner.accountInfo();
  @override
  Future<SignedBitcoinTransactionDto> signTransaction(
    BitcoinTransactionPlanDto plan,
  ) => inner.signTransaction(plan);
  @override
  Future<String> signPsbt(String psbt) => inner.signPsbt(psbt);
  @override
  Future<void> close() async {
    await inner.close();
    onClose();
  }
}

class ObservedCrypto extends NativeBitcoinCrypto {
  int opens = 0;
  int closes = 0;
  void Function()? afterClose;
  @override
  Future<BitcoinSigningAccount> openAccount(
    BitcoinHdAccountMetadata account,
    String ciphertext,
    Uint8List key,
  ) async {
    opens++;
    return ObservedSigner(
      await super.openAccount(account, ciphertext, key),
      () {
        closes++;
        afterClose?.call();
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => RustLib.init());
  setUp(WalletVaultService.unlock);
  tearDown(WalletVaultService.lockAll);
  late BitcoinAccountStore store;
  late ObservedCrypto crypto;
  late BitcoinPreparedTransfer prepared;
  Future<void> initialize(BitcoinPurpose purpose) async {
    store = BitcoinAccountStore(MemoryStore());
    crypto = ObservedCrypto();
    final snapshot = await twoFormats(500, 1200);
    final account = snapshot.discovery.state.accounts[purpose]!.metadata;
    final seed = await crypto.mnemonicToSeed(
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    );
    final key = Uint8List.fromList(List.filled(32, 7));
    try {
      final sealed = await crypto.sealSeedAccount(
        seed,
        account.network,
        0,
        purpose,
        key,
      );
      final slot = BitcoinAccountSlot(
        walletIdentity: '0xwallet',
        network: account.network,
        accountIndex: 0,
        purpose: purpose,
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
    final planner = BitcoinSendService(
      wallet: SnapshotWallet(snapshot),
      network: FixedFees(),
      store: store,
    );
    final plan = await crypto.plan(
      account,
      await planner.ownedInputs(snapshot, purpose),
      [
        BitcoinRecipientDto(
          address: snapshot.discovery.ownership.keys.first,
          amountSat: BigInt.from(350),
        ),
      ],
      BigInt.one,
      0,
      true,
    );
    prepared = BitcoinPreparedTransfer(
      walletIdentity: '0xwallet',
      network: account.network,
      purpose: purpose,
      plan: plan,
    );
  }

  test(
    'authenticated BIP84 and BIP86 signing closes opaque custody and verifies the result',
    () async {
      for (final purpose in BitcoinPurpose.values) {
        await initialize(purpose);
        final signed = await BitcoinSigningService(
          store: store,
          crypto: crypto,
        ).sign(prepared, authenticate: () async => true, isCurrent: () => true);
        expect(signed.transaction.txid, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(signed.transaction.feeSat, prepared.plan.feeSat);
        expect(crypto.opens, 1);
        expect(crypto.closes, 1);
        expect(signed.checkAuthorization, returnsNormally);
        await WalletVaultService.lockAll();
        expect(signed.checkAuthorization, throwsStateError);
        WalletVaultService.unlock();
        expect(signed.checkAuthorization, throwsStateError);
        expect(
          signed.transaction.vbytes <= prepared.plan.estimatedVbytes,
          isTrue,
        );
      }
    },
  );
  test('authentication cancellation never opens custody', () async {
    await initialize(BitcoinPurpose.bip84);
    await expectLater(
      BitcoinSigningService(
        store: store,
        crypto: crypto,
      ).sign(prepared, authenticate: () async => false, isCurrent: () => true),
      throwsStateError,
    );
    expect(crypto.opens, 0);
  });
  test('context change while closing rejects the late signed result', () async {
    await initialize(BitcoinPurpose.bip84);
    var current = true;
    crypto.afterClose = () => current = false;
    await expectLater(
      BitcoinSigningService(store: store, crypto: crypto).sign(
        prepared,
        authenticate: () async => true,
        isCurrent: () => current,
      ),
      throwsStateError,
    );
    expect(crypto.closes, 1);
  });
  test('lock after authentication prevents opening custody', () async {
    await initialize(BitcoinPurpose.bip84);
    await expectLater(
      BitcoinSigningService(store: store, crypto: crypto).sign(
        prepared,
        authenticate: () async {
          await WalletVaultService.lockAll();
          return true;
        },
        isCurrent: () => true,
      ),
      throwsStateError,
    );
    expect(crypto.opens, 0);
  });
}
