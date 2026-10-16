import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'helpers/test_fonts.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_account_history.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/screens/transaction/bitcoin_transaction_details_sheet.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/services/wallet_history_service.dart';
import 'bitcoin_history_service_test.dart' show row, address, hash;

class DetailsNetwork extends Fake implements BitcoinNetworkApi {
  bool confirmed;
  bool found = true;
  int calls = 0;
  bool outage = false;
  DetailsNetwork(this.confirmed);
  @override
  Future<BitcoinTransactionStatus> fetchTransactionStatus(
    BitcoinProductNetwork network,
    String txid,
  ) async {
    calls++;
    expect(txid, hash);
    if (outage) throw const BitcoinNetworkException(500);
    return BitcoinTransactionStatus.fromJson({
      'status': confirmed ? 'confirmed' : 'pending',
      'confirmed': confirmed,
      'found': confirmed || found,
      'confirmations': confirmed ? 2 : 0,
      'blockHeight': confirmed ? 100 : null,
      'blockHash': confirmed ? '22' * 32 : null,
      'timestamp': confirmed ? 100 : null,
    });
  }
}

WalletHistoryEntry entry({bool chainData = true}) => WalletHistoryEntry(
  id: hash,
  walletAddress: '0xwallet',
  networkName: 'Bitcoin',
  networkKey: 'bitcoin:mainnet',
  eventType: 'send',
  title: 'Bitcoin',
  message: '',
  isIncoming: false,
  createdAt: DateTime.utc(2026),
  source: 'bitcoin-chain',
  txHash: hash,
  amount: 0.00000001,
  bitcoin: chainData
      ? BitcoinAccountHistoryEntry(
          BitcoinProductNetwork.mainnet,
          BitcoinHistoryTransaction.fromJson(row([address(0), address(40)])),
          {address(0), address(40)},
        )
      : null,
);
void main() {
  setUp(installTestFonts);
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final found in [false, true]) {
    testWidgets(
      'receipt shows Submitted only with acceptance evidence (found=$found)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BitcoinTransactionDetailsSheet(
                entry: entry(chainData: false),
                network: BitcoinProductNetwork.testnet4,
                api: DetailsNetwork(false)..found = found,
                onOpenExplorer: (_) async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Submitted'), found ? findsOneWidget : findsNothing);
        expect(find.text('Confirmed'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'pending receipt refreshes to confirmed without reopening; stops polling',
    (tester) async {
      final api = DetailsNetwork(false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BitcoinTransactionDetailsSheet(
              entry: entry(),
              network: BitcoinProductNetwork.mainnet,
              api: api,
              onOpenExplorer: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TRANSACTION DETAILS'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('Confirmed'), findsNothing);
      api.confirmed = true;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('Confirmed'), findsOneWidget);
      expect(api.calls, 2);
      await tester.pump(const Duration(seconds: 30));
      expect(api.calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Bitcoin details show live confirmations, exact wallet delta and no gas fields',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BitcoinTransactionDetailsSheet(
              entry: entry(),
              network: BitcoinProductNetwork.mainnet,
              api: DetailsNetwork(true),
              onOpenExplorer: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('2'), findsNothing);
      expect(find.text(hash), findsNothing);
      expect(find.text('0.0000004 BTC'), findsOneWidget);
      expect(find.text('0.0000001 BTC (10 sats)'), findsOneWidget);
      final advanced = find.byKey(
        const Key('advanced-transaction-details-toggle'),
      );
      await tester.scrollUntilVisible(
        advanced,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(advanced);
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(find.text(hash), findsOneWidget);
      expect(find.text('Gas used'), findsNothing);
      expect(find.textContaining('Gwei'), findsNothing);
      await tester.tap(advanced);
      await tester.pumpAndSettle();
      expect(find.text('2'), findsNothing);
    },
  );
  testWidgets(
    'one satoshi remains visible and testnet explorer link uses the explicit network',
    (tester) async {
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BitcoinTransactionDetailsSheet(
              entry: entry(chainData: false),
              network: BitcoinProductNetwork.testnet4,
              api: DetailsNetwork(false),
              onOpenExplorer: (url) async {
                opened = url;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0.00000001 BTC'), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('View in explorer'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('View in explorer'));
      expect(opened, 'https://mempool.space/testnet4/tx/$hash');
    },
  );
  testWidgets(
    'provider outage shows unavailable status rather than transaction failure',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BitcoinTransactionDetailsSheet(
              entry: entry(),
              network: BitcoinProductNetwork.mainnet,
              api: DetailsNetwork(false)..outage = true,
              onOpenExplorer: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Latest transaction status is unavailable.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Failed'), findsNothing);
      expect(
        find.text('Latest transaction status is unavailable.'),
        findsOneWidget,
      );
    },
  );
}
