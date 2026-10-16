import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/screens/wallet/transfer_confirmation_screen.dart';
import 'package:fomowl_wallet/screens/wallet/widgets/transfer_confirmation/amount_summary.dart';
import 'package:fomowl_wallet/screens/wallet/widgets/transfer_confirmation/transaction_details_card.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/currency_controller.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';
import 'helpers/test_fonts.dart';

class _Chain extends BlockchainService {
  @override
  Future<Map<String, double>> getTokenPrices(List<String> ids) async => {};
}

class _Wallet extends WalletService {
  @override
  Future<String?> getWalletAddressForFamily(ChainFamily family) async =>
      family == ChainFamily.solana
      ? '11111111111111111111111111111111'
      : 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb';
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUp(installTestFonts);
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final network in ['solana:mainnet', 'tron:mainnet']) {
    testWidgets(
      '$network confirmation keeps exact amount and honest fee details',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final solana = network.startsWith('solana:');
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<BlockchainService>(
                create: (_) => _Chain(),
              ),
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
                    'networkKey': network,
                    'toAddress': solana
                        ? '11111111111111111111111111111111'
                        : 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb',
                    'amountBaseUnits': BigInt.from(
                      solana ? 1000000000 : 1000000,
                    ),
                    'amount':
                        '999', // Display must use the integer transfer amount.
                  },
                ),
                builder: (_) =>
                    TransferConfirmationScreen(walletService: _Wallet()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<AmountSummary>(find.byType(AmountSummary)).amountText,
          '1',
        );
        final card = tester.widget<TransactionDetailsCard>(
          find.byType(TransactionDetailsCard),
        );
        expect(
          card.gasValue,
          solana ? '≈ 0.000005 SOL' : 'Calculated by network',
        );
        expect(
          card.maxTotalDisplay,
          solana ? '≈ 1.000005 SOL' : '1 TRX + Network Fee',
        );
        expect(card.totalLabel, solana ? 'Estimated total' : 'Total');
        expect(find.text('Network resources'), findsNothing);
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
        expect(
          find.text(solana ? 'Estimated network fee' : 'Network resources'),
          findsOneWidget,
        );
        expect(find.textContaining('Gwei'), findsNothing);
        expect(find.text('Gas limit'), findsNothing);
        expect(find.text('Transaction nonce'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
