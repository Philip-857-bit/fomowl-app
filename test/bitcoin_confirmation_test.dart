@Tags(['ffi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_native_crypto.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_send_service.dart';
import 'package:fomowl_wallet/screens/wallet/bitcoin_transfer_confirmation_screen.dart';
import 'package:fomowl_wallet/src/rust/api/bitcoin_transaction.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'bitcoin_send_input_test.dart'
    show twoFormats, SnapshotWallet, FixedFees;

Future<BitcoinPreparedTransfer> transfer() async {
  final snapshot = await twoFormats(500, 1200);
  final service = BitcoinSendService(
    wallet: SnapshotWallet(snapshot),
    network: FixedFees(),
  );
  final account =
      snapshot.discovery.state.accounts[BitcoinPurpose.bip84]!.metadata;
  final plan = await const NativeBitcoinCrypto().plan(
    account,
    await service.ownedInputs(snapshot, BitcoinPurpose.bip84),
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
  return BitcoinPreparedTransfer(
    walletIdentity: '0xwallet',
    network: account.network,
    purpose: account.purpose,
    plan: plan,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => RustLib.init());
  testWidgets(
    'confirmation presents the immutable native plan and approves that exact object',
    (tester) async {
      final prepared = (await tester.runAsync(transfer))!;
      expect(() => prepared.plan.recipients.clear(), throwsUnsupportedError);
      expect(() => prepared.plan.selectedUtxos.clear(), throwsUnsupportedError);
      BitcoinPreparedTransfer? approved;
      await tester.pumpWidget(
        MaterialApp(
          home: BitcoinTransferConfirmationScreen(
            transfer: prepared,
            onConfirm: (value) async {
              approved = value;
            },
          ),
        ),
      );
      await tester.runAsync(
        () => validateBitcoinTransferPlan(plan: prepared.plan),
      );
      await tester.pumpAndSettle();
      expect(find.text('0.0000035 BTC'), findsOneWidget);
      expect(find.text('1 sat/vB'), findsOneWidget);
      expect(find.text('Native SegWit'), findsOneWidget);
      expect(find.text('Gas price'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('bitcoin-confirm-transfer')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('bitcoin-confirm-transfer')));
      await tester.pumpAndSettle();
      expect(identical(approved, prepared), isTrue);
    },
  );
  testWidgets('altered plan is rejected before approval', (tester) async {
    final prepared = (await tester.runAsync(transfer))!;
    final plan = prepared.plan;
    final corrupt = BitcoinPreparedTransfer(
      walletIdentity: prepared.walletIdentity,
      network: prepared.network,
      purpose: prepared.purpose,
      plan: BitcoinTransactionPlanDto(
        account: plan.account,
        unsignedTxHex: plan.unsignedTxHex,
        selectedUtxos: plan.selectedUtxos,
        recipients: plan.recipients,
        changeIndex: plan.changeIndex,
        rbf: plan.rbf,
        feeRateSatVb: plan.feeRateSatVb,
        recipientTotalSat: plan.recipientTotalSat,
        changeSat: plan.changeSat,
        feeSat: plan.feeSat + BigInt.one,
        estimatedVbytes: plan.estimatedVbytes,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BitcoinTransferConfirmationScreen(
          transfer: corrupt,
          onConfirm: (_) async {
            fail('Invalid plan was approved');
          },
        ),
      ),
    );
    await tester.runAsync(() async {
      await validateBitcoinTransferPlan(plan: plan);
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bitcoin-confirmation-error')), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('bitcoin-confirm-transfer')),
    );
    expect(button.onPressed, isNull);
  });
}
