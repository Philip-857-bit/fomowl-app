@Tags(['ffi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'helpers/test_fonts.dart';
import 'package:fomowl_wallet/widgets/advanced_transaction_details.dart';
import 'package:fomowl_wallet/utils/bitcoin_amount_utils.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_native_crypto.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_send_service.dart';
import 'package:fomowl_wallet/screens/wallet/bitcoin_transfer_confirmation_screen.dart';
import 'package:fomowl_wallet/src/rust/api/bitcoin_transaction.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'bitcoin_send_input_test.dart'
    show twoFormats, SnapshotWallet, FixedFees;

Future<BitcoinPreparedTransfer> transfer({
  BitcoinPurpose purpose = BitcoinPurpose.bip84,
  bool showFeeTier = false,
}) async {
  final snapshot = await twoFormats(500, 1200);
  final service = BitcoinSendService(
    wallet: SnapshotWallet(snapshot),
    network: FixedFees(),
  );
  final account = snapshot.discovery.state.accounts[purpose]!.metadata;
  final plan = await const NativeBitcoinCrypto().plan(
    account,
    await service.ownedInputs(snapshot, purpose),
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
    requestedFeeTier: BitcoinFeeTier.priority,
    showFeeTier: showFeeTier,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installTestFonts);
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await RustLib.init();
  });
  testWidgets(
    'confirmation presents the immutable native plan and approves that exact object',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('bitcoin-confirm-transfer')),
            )
            .onPressed,
        isNull,
      );
      await tester.runAsync(
        () => validateBitcoinTransferPlan(plan: prepared.plan),
      );
      await tester.pumpAndSettle();
      expect(find.text('0.00000350 BTC', findRichText: true), findsOneWidget);
      expect(
        find.text(prepared.plan.recipients.single.address),
        findsOneWidget,
      );
      expect(find.text('Bitcoin'), findsOneWidget);
      expect(find.text('${prepared.plan.feeSat} sats'), findsOneWidget);
      final fee = BitcoinAmountUtils.format(prepared.plan.feeSat);
      final total = BitcoinAmountUtils.format(
        prepared.plan.recipientTotalSat + prepared.plan.feeSat,
      );
      expect(find.text('${fee.padRight(10, '0')} BTC'), findsOneWidget);
      expect(find.text('${total.padRight(10, '0')} BTC'), findsOneWidget);
      expect(find.text('1 sat/vB'), findsNothing);
      expect(find.text('Native SegWit'), findsNothing);
      expect(find.text('Replace-by-fee'), findsNothing);
      expect(find.text('Speed'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('advanced-transaction-details-toggle')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(
          find.byKey(const Key('advanced-transaction-details-toggle')),
        ),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('advanced-transaction-details-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 sat/vB'), findsOneWidget);
      expect(find.text('Native SegWit'), findsOneWidget);
      expect(find.text('${prepared.plan.estimatedVbytes} vB'), findsOneWidget);
      expect(find.text('Enabled'), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(
          find.byKey(const Key('advanced-transaction-details-toggle')),
        ),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('advanced-transaction-details-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 sat/vB'), findsNothing);
      expect(find.text('Native SegWit'), findsNothing);
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
  testWidgets(
    'Taproot advanced details and meaningful speed are presentation only',
    (tester) async {
      final prepared = (await tester.runAsync(
        () => transfer(purpose: BitcoinPurpose.bip86, showFeeTier: true),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: BitcoinTransferConfirmationScreen(transfer: prepared),
        ),
      );
      await tester.runAsync(
        () => validateBitcoinTransferPlan(plan: prepared.plan),
      );
      await tester.pumpAndSettle();
      expect(find.text('Speed'), findsOneWidget);
      expect(find.text('Priority'), findsOneWidget);
      expect(find.text('Taproot'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('advanced-transaction-details-toggle')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(
          find.byKey(const Key('advanced-transaction-details-toggle')),
        ),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('advanced-transaction-details-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Taproot'), findsOneWidget);
      expect(find.byType(AdvancedTransactionDetails), findsOneWidget);
      expect(find.text('Native SegWit'), findsNothing);
      expect(find.textContaining('xpub'), findsNothing);
    },
  );
}
