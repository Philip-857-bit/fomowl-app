@Tags(['ffi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/wallet_account.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_native_crypto.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_protected_record.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_provisioning_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_receive_service.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/wallet_vault_service.dart';
import 'package:fomowl_wallet/screens/wallet/widgets/receive/bitcoin_receive_format_selector.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'helpers/bitcoin_memory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => RustLib.init());
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WalletVaultService.unlock();
  });
  tearDown(WalletVaultService.lockAll);
  for (final network in BitcoinProductNetwork.values) {
    testWidgets(
      '$network Receive keeps both formats, defaults to SegWit and toggles without consuming indexes',
      (tester) async {
        final storage = StorageService(secureStore: MemoryStore());
        const crypto = NativeBitcoinCrypto();
        const mnemonic =
            'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
        final identity = (await tester.runAsync(() async {
          final seed = await crypto.mnemonicToSeed(mnemonic);
          try {
            return await crypto.seedWalletIdentity(seed, 0);
          } finally {
            seed.fillRange(0, seed.length, 0);
          }
        }))!;
        await tester.runAsync(() async {
          await storage.saveWallet(
            address: identity,
            privateKey: 'public-fixture-placeholder',
            mnemonic: mnemonic,
            origin: WalletOrigin.derived,
            derivationIndex: 0,
            seedGroupId: 'receive_ux_fixture',
          );
          await BitcoinProvisioningService(
            storage: storage,
          ).ensureWallet(identity, network: network);
        });
        final receive = BitcoinReceiveService(storage: storage);
        var purpose = BitcoinPurpose.bip84;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, update) => BitcoinReceiveFormatSelector(
                  selected: purpose,
                  onChanged: (value) => update(() => purpose = value),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Native SegWit'), findsOneWidget);
        expect(find.text('Taproot'), findsOneWidget);
        expect(
          tester
              .widget<SegmentedButton<BitcoinPurpose>>(
                find.byType(SegmentedButton<BitcoinPurpose>),
              )
              .selected,
          {BitcoinPurpose.bip84},
        );
        final first = (await tester.runAsync(
          () => receive.currentAddress(identity, network),
        ))!;
        expect(
          first.address,
          startsWith(
            network == BitcoinProductNetwork.mainnet ? 'bc1q' : 'tb1q',
          ),
        );
        await tester.tap(find.text('Taproot'));
        await tester.pumpAndSettle();
        final taproot = (await tester.runAsync(
          () => receive.currentAddress(identity, network, purpose: purpose),
        ))!;
        expect(
          taproot.address,
          startsWith(
            network == BitcoinProductNetwork.mainnet ? 'bc1p' : 'tb1p',
          ),
        );
        expect(taproot.address, isNot(first.address));
        await tester.tap(find.text('Native SegWit'));
        await tester.pumpAndSettle();
        final again = (await tester.runAsync(
          () => receive.currentAddress(identity, network, purpose: purpose),
        ))!;
        expect(again.address, first.address);
        expect(again.addressIndex, first.addressIndex);
        for (final type in BitcoinPurpose.values) {
          final state = await tester.runAsync(
            () => storage.bitcoinAccounts.readState(
              BitcoinAccountSlot(
                walletIdentity: identity.toLowerCase(),
                network: network,
                accountIndex: 0,
                purpose: type,
              ),
            ),
          );
          expect(state!.nextExternal, 0);
          expect(state.nextInternal, 0);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
