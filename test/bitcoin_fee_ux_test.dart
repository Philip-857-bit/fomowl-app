@Tags(['ffi'])
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'helpers/test_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_account_store.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_protected_record.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_send_service.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/currency_controller.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';
import 'package:fomowl_wallet/screens/wallet/send_token_screen.dart';
import 'package:fomowl_wallet/screens/wallet/widgets/send/bitcoin_fee_tier_selector.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'bitcoin_confirmation_test.dart' show transfer;
import 'bitcoin_send_input_test.dart' show twoFormats, SnapshotWallet;
import 'helpers/bitcoin_memory_store.dart';

class MutableFees extends Fake implements BitcoinNetworkApi {
  BitcoinFeeRates fees;
  MutableFees(int economy, int normal, int priority)
    : fees = rates(economy, normal, priority);
  static BitcoinFeeRates rates(int economy, int normal, int priority) =>
      BitcoinFeeRates.fromJson({
        'economy': economy,
        'normal': normal,
        'priority': priority,
        'minimum': 1,
        'stale': false,
      });
  @override
  Future<BitcoinFeeRates> fetchFeeRates(BitcoinProductNetwork network) async =>
      fees;
}

class BitcoinSendChain extends BlockchainService {
  @override
  String get activeNetworkKey => 'bitcoin:mainnet';
  @override
  String get activeWalletAddress => '0xwallet';
  @override
  Future<BigInt> getNativeBalanceBaseUnits(String walletAddress) async =>
      BigInt.from(100000);
}

class NoActiveWallet extends WalletService {
  @override
  Future<String?> getCurrentWalletAddress() async => null;
}

class ActiveSendWallet extends WalletService {
  @override
  Future<String?> getCurrentWalletAddress() async => '0xwallet';
}

class RecordingPreparation extends BitcoinSendService {
  final BitcoinPreparedTransfer fixture;
  BitcoinFeeTier? receivedTier;
  bool? receivedSelection;
  Completer<BitcoinPreparedTransfer>? pending;
  int calls = 0;
  bool Function()? current;
  RecordingPreparation(this.fixture, BitcoinNetworkApi api)
    : super(network: api);
  @override
  Future<BitcoinPreparedTransfer> prepareTransfer(
    String identity,
    BitcoinProductNetwork productNetwork,
    String recipient,
    BigInt amount, {
    BitcoinPurpose? purpose,
    BitcoinFeeTier feeTier = BitcoinFeeTier.normal,
    bool feeTierWasSelected = false,
    bool rbf = true,
    bool Function()? isCurrent,
  }) async {
    calls++;
    current = isCurrent;
    receivedTier = feeTier;
    receivedSelection = feeTierWasSelected;
    expect(isCurrent?.call(), isTrue);
    return pending == null ? fixture : pending!.future;
  }
}

Widget host(Widget child) => MaterialApp(
  theme: ThemeData.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installTestFonts);
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await RustLib.init();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('PonnamKarthik/fluttertoast'),
          (_) async => true,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('PonnamKarthik/fluttertoast'),
          null,
        );
  });
  testWidgets(
    'distinct provider rates show each tier; Normal is initially selected',
    (tester) async {
      final api = MutableFees(1, 3, 7);
      var selected = BitcoinFeeTier.normal;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, update) => BitcoinFeeTierSelector(
              network: BitcoinProductNetwork.mainnet,
              api: api,
              selected: selected,
              onChanged: (value) => update(() => selected = value),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<BitcoinFeeTier>), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<BitcoinFeeTier>>(
              find.byType(SegmentedButton<BitcoinFeeTier>),
            )
            .selected,
        {BitcoinFeeTier.normal},
      );
      for (final choice in [
        (BitcoinFeeTier.economy, 'Economy'),
        (BitcoinFeeTier.priority, 'Priority'),
        (BitcoinFeeTier.normal, 'Normal'),
      ]) {
        await tester.tap(find.text(choice.$2));
        await tester.pumpAndSettle();
        expect(selected, choice.$1);
      }
      expect(find.text('Native SegWit'), findsNothing);
      expect(find.text('Taproot'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'equal rates collapse options and periodic refresh restores distinct choices',
    (tester) async {
      final api = MutableFees(1, 1, 1);
      await tester.pumpWidget(
        host(
          BitcoinFeeTierSelector(
            network: BitcoinProductNetwork.testnet4,
            api: api,
            onChanged: (_) =>
                fail('Equal fees must not offer redundant choices'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bitcoin-equivalent-fees')), findsOneWidget);
      expect(find.byType(SegmentedButton<BitcoinFeeTier>), findsNothing);
      api.fees = MutableFees.rates(1, 3, 7);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<BitcoinFeeTier>), findsOneWidget);
      expect(find.byKey(const Key('bitcoin-equivalent-fees')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Bitcoin Send offers friendly speeds and no source address-format choices',
    (tester) async {
      final blockchain = BitcoinSendChain();
      final currency = CurrencyController();
      final service = BitcoinSendService(network: MutableFees(1, 3, 7));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BlockchainService>.value(value: blockchain),
            ChangeNotifierProvider<CurrencyController>.value(value: currency),
          ],
          child: host(
            SendTokenScreen(
              walletService: NoActiveWallet(),
              bitcoinSendService: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Native SegWit'), findsNothing);
      expect(find.text('Taproot'), findsNothing);
      expect(find.byType(SegmentedButton<BitcoinFeeTier>), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<BitcoinFeeTier>>(
              find.byType(SegmentedButton<BitcoinFeeTier>),
            )
            .selected,
        {BitcoinFeeTier.normal},
      );
      await tester.tap(find.text('Priority'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<BitcoinFeeTier>>(
              find.byType(SegmentedButton<BitcoinFeeTier>),
            )
            .selected,
        {BitcoinFeeTier.priority},
      );
      await tester.pumpWidget(const SizedBox.shrink());
      blockchain.dispose();
      currency.dispose();
    },
  );
  test(
    'friendly tiers reach real preparation; SDK fees and homogeneous purpose remain authoritative',
    () async {
      final snapshot = await twoFormats(100000, 100000);
      final store = BitcoinAccountStore(MemoryStore());
      for (final entry in snapshot.discovery.state.accounts.entries) {
        final record = ProtectedBitcoinRecord(
          walletIdentity: '0xwallet',
          state: entry.value,
          encryptedVault: 'unused-custody-fixture',
          wrappingKey: Uint8List(32),
        );
        try {
          await store.createIfAbsent(
            BitcoinAccountSlot(
              walletIdentity: '0xwallet',
              network: BitcoinProductNetwork.mainnet,
              accountIndex: 0,
              purpose: entry.key,
            ),
            record,
          );
        } finally {
          record.dispose();
        }
      }
      final api = MutableFees(1, 3, 7);
      final service = BitcoinSendService(
        wallet: SnapshotWallet(snapshot),
        network: api,
        store: store,
      );
      final recipient = snapshot.discovery.ownership.keys.first;
      for (final tier in BitcoinFeeTier.values) {
        final prepared = await service.prepareTransfer(
          '0xwallet',
          BitcoinProductNetwork.mainnet,
          recipient,
          BigInt.from(1000),
          feeTier: tier,
          feeTierWasSelected: true,
        );
        expect(prepared.requestedFeeTier, tier);
        expect(prepared.showFeeTier, isTrue);
        expect(prepared.plan.feeRateSatVb, api.fees.rate(tier));
        expect(prepared.purpose, BitcoinPurpose.bip84);
        expect(
          prepared.plan.selectedUtxos.every(
            (utxo) => utxo.txid == List.filled(64, '1').join(),
          ),
          isTrue,
        );
      }
      api.fees = MutableFees.rates(1, 1, 1);
      final equal = await service.prepareTransfer(
        '0xwallet',
        BitcoinProductNetwork.mainnet,
        recipient,
        BigInt.from(1000),
      );
      expect(equal.requestedFeeTier, BitcoinFeeTier.normal);
      expect(equal.showFeeTier, isFalse);
      expect(equal.plan.feeRateSatVb, BigInt.one);
      final priorChoice = await service.prepareTransfer(
        '0xwallet',
        BitcoinProductNetwork.mainnet,
        recipient,
        BigInt.from(1000),
        feeTier: BitcoinFeeTier.priority,
        feeTierWasSelected: true,
      );
      expect(priorChoice.requestedFeeTier, BitcoinFeeTier.priority);
      expect(priorChoice.showFeeTier, isFalse);
    },
  );
  for (final timeout in [false, true]) {
    testWidgets('preparation failure clears loading and allows a fresh attempt '
        '(timeout=$timeout)', (tester) async {
      final prepared = (await tester.runAsync(transfer))!;
      final service = RecordingPreparation(prepared, MutableFees(1, 1, 1))
        ..pending = Completer<BitcoinPreparedTransfer>();
      final blockchain = BitcoinSendChain();
      final currency = CurrencyController();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BlockchainService>.value(value: blockchain),
            ChangeNotifierProvider<CurrencyController>.value(value: currency),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routes: {
              '/transfer-confirmation': (_) =>
                  const Scaffold(body: Text('Prepared confirmation')),
            },
            home: SendTokenScreen(
              walletService: ActiveSendWallet(),
              bitcoinSendService: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '0.00001000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send').last);
      await tester.pump();
      expect(find.byKey(const Key('send-preparing-indicator')), findsOneWidget);
      if (timeout) {
        await tester.pump(const Duration(seconds: 91));
      } else {
        service.pending!.completeError(StateError('private-error-marker'));
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('send-preparing-indicator')), findsNothing);
      expect(
        find.byKey(const Key('bitcoin-preparation-error')),
        findsOneWidget,
      );
      expect(find.textContaining('private-error-marker'), findsNothing);
      expect(service.current!(), isFalse);
      expect(find.text('Prepared confirmation'), findsNothing);
      if (timeout) {
        service.pending!.complete(prepared);
        await tester.pumpAndSettle();
        expect(find.text('Prepared confirmation'), findsNothing);
      }
      service.pending = Completer<BitcoinPreparedTransfer>();
      await tester.tap(find.text('Send').last);
      await tester.pump();
      expect(service.calls, 2);
      expect(find.byKey(const Key('bitcoin-preparation-error')), findsNothing);
      expect(find.byKey(const Key('send-preparing-indicator')), findsOneWidget);
      service.pending!.complete(prepared);
      await tester.pumpAndSettle();
      expect(find.text('Prepared confirmation'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      // Fluttertoast schedules a one-second platform cooldown after an error.
      await tester.pump(const Duration(seconds: 1));
      blockchain.dispose();
      currency.dispose();
    });
  }
  for (final distinct in [true, false]) {
    testWidgets(
      'Send forwards the friendly choice to preparation (distinct=$distinct)',
      (tester) async {
        final prepared = (await tester.runAsync(transfer))!;
        final api = distinct ? MutableFees(1, 3, 7) : MutableFees(1, 1, 1);
        final service = RecordingPreparation(prepared, api)
          ..pending = Completer<BitcoinPreparedTransfer>();
        final blockchain = BitcoinSendChain();
        final currency = CurrencyController();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<BlockchainService>.value(
                value: blockchain,
              ),
              ChangeNotifierProvider<CurrencyController>.value(value: currency),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routes: {
                '/transfer-confirmation': (_) =>
                    const Scaffold(body: Text('Prepared confirmation')),
              },
              home: SendTokenScreen(
                walletService: ActiveSendWallet(),
                bitcoinSendService: service,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).first,
          'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        if (distinct) {
          await tester.tap(find.text('Priority'));
          await tester.pumpAndSettle();
        } else {
          expect(
            find.byKey(const Key('bitcoin-equivalent-fees')),
            findsOneWidget,
          );
        }
        await tester.enterText(find.byType(TextField).first, '0.00001000');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Send').last);
        await tester.pump();
        expect(
          find.byKey(const Key('send-preparing-indicator')),
          findsOneWidget,
        );
        expect(find.text('Prepared confirmation'), findsNothing);
        await tester.tap(find.byKey(const Key('send-preparing-indicator')));
        await tester.pump();
        expect(service.calls, 1);
        service.pending!.complete(prepared);
        await tester.pumpAndSettle();
        expect(
          service.receivedTier,
          distinct ? BitcoinFeeTier.priority : BitcoinFeeTier.normal,
        );
        expect(service.receivedSelection, distinct);
        expect(find.text('Prepared confirmation'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        blockchain.dispose();
        currency.dispose();
      },
    );
  }
}
