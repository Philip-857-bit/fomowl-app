import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web3dart/web3dart.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/l10n/app_localizations_en.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/evm_fee_quote.dart';
import 'package:fomowl_wallet/models/evm_outbound_transaction.dart';
import 'package:fomowl_wallet/screens/transaction/history_transaction_details_sheet.dart';
import 'package:fomowl_wallet/services/evm_outbound_store.dart';
import 'package:fomowl_wallet/services/non_evm_receipt_service.dart';
import 'package:fomowl_wallet/services/wallet_history_service.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';
import 'package:fomowl_wallet/widgets/advanced_transaction_details.dart';
import 'package:fomowl_wallet/widgets/transaction_protocol_details.dart';
import 'helpers/bitcoin_memory_store.dart';
import 'helpers/test_fonts.dart';
import 'evm_outbound_store_test.dart' as evm;
import 'evm_fee_options_test.dart' as fee;
import 'non_evm_receipt_service_test.dart' as native;

const chain = EvmChain(
  name: 'Ethereum',
  symbol: 'ETH',
  chainId: 1,
  rpcUrl: 'https://rpc.example',
);

class ReceiptWallet extends WalletService {
  int calls = 0;
  TransactionReceipt? response;
  final store = EvmOutboundStore(MemoryStore());
  @override
  EvmOutboundStore get evmOutbound => store;
  @override
  Future<TransactionReceipt?> getTransactionReceipt({
    required String txHash,
    required String rpcUrl,
  }) async {
    calls++;
    return response;
  }
}

TransactionReceipt receipt({int id = 1}) => TransactionReceipt(
  transactionHash: Uint8List(32)..[31] = id,
  transactionIndex: 0,
  blockHash: Uint8List(32),
  cumulativeGasUsed: BigInt.from(21000),
  gasUsed: BigInt.from(21000),
  blockNumber: const BlockNum.exact(100),
  status: true,
  from: EthereumAddress.fromHex(evm.sender),
  to: EthereumAddress.fromHex(evm.destination),
  effectiveGasPrice: EtherAmount.inWei(BigInt.from(101)),
);
WalletHistoryEntry history(String network, String hash) => WalletHistoryEntry(
  id: hash,
  walletAddress: evm.sender,
  networkName: network,
  networkKey: network,
  chainId: network.startsWith('evm:') ? 1 : null,
  txHash: hash,
  eventType: 'send',
  title: 'Transfer',
  message: 'Sent',
  isIncoming: false,
  createdAt: DateTime.utc(2026),
  source: 'test-public-receipt',
);
Future<void> mount(
  WidgetTester tester, {
  required String network,
  required String hash,
  required ReceiptWallet wallet,
  NonEvmReceiptService? service,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: HistoryTransactionDetailsSheet(
          entry: history(network, hash),
          chain: chain,
          walletService: wallet,
          explorerUrl: null,
          titleText: 'Transfer',
          messageText: 'Sent',
          amountText: '1 unit',
          timestampText: 'Today',
          networkText: network,
          receiptService: service,
          onOpenExplorer: (_) async {},
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> expand(WidgetTester tester) async {
  final toggle = find.byKey(const Key('advanced-transaction-details-toggle'));
  await tester.scrollUntilVisible(
    toggle,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

void main() {
  setUp(installTestFonts);
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final legacy in [true, false]) {
    test(
      'EVM ${legacy ? 'legacy' : 'type2'} confirmation uses exact typed fee fields',
      () {
        final quote = fee.quotes(legacy: legacy).forTier(EvmFeeTier.normal);
        final rows = TransactionProtocolDetails.evmQuote(
          AppLocalizationsEn(),
          quote,
        );
        expect(
          rows.first.value,
          legacy
              ? AppLocalizationsEn().evmLegacyTransaction
              : AppLocalizationsEn().evmDynamicTransaction,
        );
        expect(rows.map((item) => item.value), contains('23100'));
        expect(
          rows.any((item) => item.label == AppLocalizationsEn().evmBaseFee),
          !legacy,
        );
        expect(
          rows.any((item) => item.label == AppLocalizationsEn().evmMaxFee),
          !legacy,
        );
      },
    );
  }
  testWidgets(
    'EVM receipt keeps nonce and gas under selectable advanced details',
    (tester) async {
      final wallet = ReceiptWallet()..response = receipt();
      await wallet.store.reserve(evm.entry(1));
      await mount(tester, network: 'evm:1', hash: evm.hash(1), wallet: wallet);
      expect(wallet.calls, 1);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Transaction nonce'), findsNothing);
      expect(find.text('Gas used'), findsNothing);
      expect(find.text(evm.hash(1)), findsNothing);
      expect(find.text('0.000000000002121 ETH'), findsOneWidget);
      await expand(tester);
      expect(find.text('Transaction nonce'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('23100'), findsOneWidget);
      expect(find.text('21000'), findsOneWidget);
      expect(find.text(evm.hash(1)), findsOneWidget);
      expect(find.byType(SelectableText), findsWidgets);
      expect(
        (await wallet.store.list(evm.sender)).single.state,
        EvmOutboundState.unknown,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final network in ['solana:mainnet', 'tron:mainnet']) {
    testWidgets('$network shows only its own real receipt resources', (
      tester,
    ) async {
      final solana = network.startsWith('solana:');
      final data = solana ? native.sol() : native.tron();
      if (solana) {
        data['feeLamports'] = '5000';
      }
      final hash = solana ? native.solHash : native.tronHash;
      final wallet = ReceiptWallet();
      final service = NonEvmReceiptService(
        client: MockClient((_) async => http.Response(jsonEncode(data), 200)),
      );
      await mount(
        tester,
        network: network,
        hash: hash,
        wallet: wallet,
        service: service,
      );
      expect(
        wallet.calls,
        0,
      ); // Even when a caller accidentally supplies an EVM chain.
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text(solana ? '0.000005 SOL' : '0.042 TRX'), findsOneWidget);
      expect(
        find.text(solana ? 'Compute units used' : 'Energy used'),
        findsNothing,
      );
      await expand(tester);
      expect(
        find.text(solana ? 'Compute units used' : 'Energy used'),
        findsOneWidget,
      );
      expect(find.text(solana ? '1234' : '100'), findsOneWidget);
      if (!solana) {
        expect(find.text('Bandwidth used'), findsOneWidget);
        expect(find.text('150 TRX'), findsOneWidget);
      }
      expect(find.textContaining('Gwei'), findsNothing);
      expect(find.text('Gas used'), findsNothing);
      expect(find.text('Transaction nonce'), findsNothing);
      expect(find.text(hash), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'mismatched EVM receipt never claims confirmation for another transaction',
    (tester) async {
      final wallet = ReceiptWallet()..response = receipt(id: 2);
      await mount(tester, network: 'evm:1', hash: evm.hash(1), wallet: wallet);
      expect(find.text('Confirmed'), findsNothing);
      expect(find.byType(AdvancedTransactionDetails), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'foreign outbound records and raw calldata do not enter receipt presentation',
    () {
      final l = AppLocalizationsEn();
      final rows = TransactionProtocolDetails.evmReceipt(
        l,
        expectedHash: evm.hash(1),
        chainId: 56,
        nativeSymbol: 'BNB',
        outbound: evm.entry(1),
      );
      expect(rows.any((row) => row.label == l.transactionNonce), isFalse);
      expect(rows.any((row) => row.label == l.evmGasLimit), isFalse);
      expect(rows.map((row) => row.value), isNot(contains('0x')));
    },
  );
  testWidgets('late Solana facts cannot overwrite a different open receipt', (
    tester,
  ) async {
    final first = Completer<http.Response>();
    final secondHash = '3' * 88;
    final wallet = ReceiptWallet();
    final service = NonEvmReceiptService(
      client: MockClient((request) {
        if (request.url.pathSegments.last == native.solHash) {
          return first.future;
        }
        return Future.value(
          http.Response(
            jsonEncode({
              ...native.sol(),
              'transactionHash': secondHash,
              'feeLamports': '7000',
            }),
            200,
          ),
        );
      }),
    );
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The initial future deliberately stays pending; do not pumpAndSettle it.
    await mount(
      tester,
      network: 'solana:mainnet',
      hash: native.solHash,
      wallet: wallet,
      service: service,
      settle: false,
    );
    await mount(
      tester,
      network: 'solana:mainnet',
      hash: secondHash,
      wallet: wallet,
      service: service,
    );
    expect(find.text('0.000007 SOL'), findsOneWidget);
    first.complete(
      http.Response(jsonEncode(native.sol()..['status'] = 0), 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Failed'), findsNothing);
    expect(find.text('0.000007 SOL'), findsOneWidget);
  });
}
