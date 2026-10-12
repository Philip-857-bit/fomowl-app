import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/evm_fee_quote.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/currency_controller.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';
import 'package:fomowl_wallet/screens/wallet/transfer_confirmation_screen.dart';
import 'package:fomowl_wallet/screens/wallet/widgets/transfer_confirmation/confirm_button.dart';
import 'package:fomowl_wallet/screens/wallet/widgets/transfer_confirmation/transaction_details_card.dart';
import 'helpers/test_fonts.dart';
import 'evm_fee_options_test.dart' as fixtures;

class Chain extends BlockchainService {
  @override
  String get activeNetworkKey => 'evm:1';
  @override
  Future<Map<String, double>> getTokenPrices(List<String> ids) async => {};
}

class Wallet extends WalletService {
  final response = Completer<EvmFeeQuotes>();
  EvmFeeQuotes? refreshed;
  int calls = 0;
  @override
  Future<String?> getWalletAddressForFamily(ChainFamily family) async =>
      '0x1111111111111111111111111111111111111111';
  @override
  Future<EvmFeeQuotes> quoteTransferFees({
    required int chainId,
    required String fromAddress,
    required String toAddress,
    required BigInt amountInBaseUnits,
    required String rpcUrl,
    String? tokenAddress,
  }) {
    calls++;
    return calls > 1 && refreshed != null
        ? Future.value(refreshed!)
        : response.future;
  }
}

Future<void> mount(WidgetTester tester, Wallet wallet) async {
  tester.view.physicalSize = const Size(480, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<BlockchainService>(create: (_) => Chain()),
        ChangeNotifierProvider<CurrencyController>(
          create: (_) => CurrencyController(),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: RouteSettings(
            arguments: {
              'networkKey': 'evm:1',
              'toAddress': '0x2222222222222222222222222222222222222222',
              'amountBaseUnits': BigInt.one,
              'amount': '0.000000000000000001',
            },
          ),
          builder: (_) => TransferConfirmationScreen(walletService: wallet),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(installTestFonts);
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
    'confirmation waits for quote and changes primary fee with selected tier',
    (tester) async {
      final wallet = Wallet();
      await mount(tester, wallet);
      expect(
        tester.widget<ConfirmButton>(find.byType(ConfirmButton)).enabled,
        isFalse,
      );
      final quote = fixtures.quotes();
      wallet.response.complete(quote);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ConfirmButton>(find.byType(ConfirmButton)).enabled,
        isTrue,
      );
      expect(
        tester
            .widget<TransactionDetailsCard>(find.byType(TransactionDetailsCard))
            .speedValue,
        'Normal',
      );
      expect(find.text('Gas limit'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('evm-fee-tier-priority')),
      );
      await tester.tap(find.byKey(const Key('evm-fee-tier-priority')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TransactionDetailsCard>(find.byType(TransactionDetailsCard))
            .speedValue,
        'Priority',
      );
    },
  );
  testWidgets('expired approval refreshes fees and requires another review', (
    tester,
  ) async {
    final wallet = Wallet();
    await mount(tester, wallet);
    wallet.refreshed = fixtures.quotes();
    wallet.response.complete(
      fixtures.quotes(
        quotedAt: DateTime.now().subtract(const Duration(seconds: 31)),
      ),
    );
    await tester.pumpAndSettle();
    tester.widget<ConfirmButton>(find.byType(ConfirmButton)).onPressed();
    await tester.pumpAndSettle();
    expect(wallet.calls, 2);
    expect(
      find.text(
        'Network fees changed. Review the updated fee and confirm again.',
      ),
      findsOneWidget,
    );
    expect(find.byType(TransferConfirmationScreen), findsOneWidget);
    expect(
      tester.widget<ConfirmButton>(find.byType(ConfirmButton)).isLoading,
      isFalse,
    );
  });
  testWidgets('invalid fee response keeps confirmation disabled', (
    tester,
  ) async {
    final wallet = Wallet();
    await mount(tester, wallet);
    wallet.response.completeError(
      const EvmFeeQuoteException('Invalid network fee response'),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<ConfirmButton>(find.byType(ConfirmButton)).enabled,
      isFalse,
    );
    expect(find.byKey(const Key('evm-fee-tier-normal')), findsNothing);
  });
  testWidgets('equal fees omit meaningless primary Speed row', (tester) async {
    final wallet = Wallet();
    await mount(tester, wallet);
    wallet.response.complete(fixtures.quotes(equal: true));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TransactionDetailsCard>(find.byType(TransactionDetailsCard))
          .speedValue,
      isNull,
    );
    expect(find.byKey(const Key('evm-fee-tiers-equal')), findsOneWidget);
  });
}
