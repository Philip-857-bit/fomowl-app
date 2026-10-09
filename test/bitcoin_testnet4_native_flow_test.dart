@Tags(['ffi'])
library;

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_native_crypto.dart';
import 'package:fomowl_wallet/src/rust/api/bitcoin_transaction.dart';
import 'package:fomowl_wallet/src/rust/api/bitcoin_account.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';

// Offline testnet4 fixture: these outpoints do not represent funded coins.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => RustLib.init());
  const crypto = NativeBitcoinCrypto();
  for (final purpose in BitcoinPurpose.values) {
    test('testnet4 $purpose vault → plan → transaction/PSBT → lock', () async {
      final seed = await crypto.mnemonicToSeed(
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      );
      final key = Uint8List.fromList(List.filled(32, 7));
      BitcoinSigningAccount? signer;
      try {
        final sealed = await crypto.sealSeedAccount(
          seed,
          BitcoinProductNetwork.testnet4,
          0,
          purpose,
          key,
        );
        final mainnet = await crypto.deriveAccount(
          seed,
          BitcoinProductNetwork.mainnet,
          0,
          purpose,
        );
        seed.fillRange(0, seed.length, 0);
        final account = sealed.metadata;
        final receive = await crypto.deriveAddress(
          account,
          BitcoinKeychain.receive,
          0,
        );
        expect(
          receive,
          startsWith(purpose == BitcoinPurpose.bip84 ? 'tb1q' : 'tb1p'),
        );
        final recipient = await crypto.deriveAddress(
          account,
          BitcoinKeychain.receive,
          1,
        );
        final change = await crypto.deriveAddress(
          account,
          BitcoinKeychain.change,
          0,
        );
        expect(change, isNot(receive));
        final script = await crypto.deriveScript(
          account,
          BitcoinKeychain.receive,
          0,
        );
        final input = BitcoinUtxoDto(
          txid: '11' * 32,
          vout: 0,
          valueSat: BigInt.from(100000),
          scriptPubkeyHex: script,
          keychain: BitcoinKeychainDto.external_,
          addressIndex: 0,
        );
        signer = await crypto.openAccount(account, sealed.encryptedVault, key);
        expect(await signer.accountInfo(), account);
        for (final rate in [1, 3, 7]) {
          final plan = await crypto.plan(
            account,
            [input],
            [
              BitcoinRecipientDto(
                address: recipient,
                amountSat: BigInt.from(50000),
              ),
            ],
            BigInt.from(rate),
            0,
            true,
          );
          expect(plan.changeSat, greaterThan(BigInt.zero));
          final direct = await signer.signTransaction(plan);
          final verified = await verifyBitcoinTransfer(
            plan: plan,
            rawTransactionHex: direct.rawTransactionHex,
          );
          expect(verified.txid, direct.txid);
          expect(verified.wtxid, direct.wtxid);
          expect(
            direct.feeSat,
            greaterThanOrEqualTo(direct.vbytes * BigInt.from(rate)),
          );
          final psbt = await createBitcoinTransferPsbt(plan: plan);
          final signed = await signer.signPsbt(psbt);
          final finalized = await finalizeBitcoinTransferPsbt(
            psbtBase64: signed,
          );
          expect(finalized.complete, isTrue);
          expect(finalized.rawTransactionHex, direct.rawTransactionHex);
        }
        await signer.close();
        await expectLater(signer.accountInfo(), throwsStateError);
        final reopened = await crypto.openAccount(
          account,
          sealed.encryptedVault,
          key,
        );
        expect(await reopened.accountInfo(), account);
        await reopened.close();
        final wrongRecipient = await crypto.deriveAddress(
          mainnet,
          BitcoinKeychain.receive,
          0,
        );
        await expectLater(
          crypto.plan(
            account,
            [input],
            [
              BitcoinRecipientDto(
                address: wrongRecipient,
                amountSat: BigInt.from(50000),
              ),
            ],
            BigInt.one,
            0,
            true,
          ),
          throwsA(isA<String>()),
        );
      } finally {
        await signer?.close();
        seed.fillRange(0, seed.length, 0);
        key.fillRange(0, key.length, 0);
      }
    });
  }
}
