import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/bitcoin_network_data.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/currency_controller.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_send_service.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_network_service.dart';
import 'package:fomowl_wallet/screens/wallet/send_token_screen.dart';
import 'package:fomowl_wallet/utils/value_formatter.dart';
import 'package:fomowl_wallet/widgets/amount_input_mode_toggle.dart';
import 'helpers/test_fonts.dart';

class FiatChain extends BlockchainService {
  FiatChain(this.key, this.prices);
  String key;
  String scope = '0xwallet';
  List<Token> prices;
  @override
  String get activeNetworkKey => key;
  @override
  String get activeWalletAddress => scope;
  @override
  List<Token> get tokens => prices;
  @override
  Future<double> getEthBalance(String address) async => 10;
  @override
  Future<BigInt> getNativeBalanceBaseUnits(String address) async =>
      BigInt.from(1000000000);
  void refreshPrices(List<Token> values) {
    prices = values;
    notifyListeners();
  }

  void changeWallet(String value) {
    scope = value;
    notifyListeners();
  }
}

class FiatWallet extends WalletService {
  @override
  Future<String?> getCurrentWalletAddress() async => '0xwallet';
  @override
  Future<String?> getWalletAddressForFamily(ChainFamily family) async =>
      '0xwallet';
}

class DeferredFiatWallet extends FiatWallet {
  final solana = Completer<String?>();
  @override
  Future<String?> getWalletAddressForFamily(ChainFamily family) =>
      family == ChainFamily.solana
      ? solana.future
      : super.getWalletAddressForFamily(family);
}

class FiatCurrency extends CurrencyController {
  String code = 'USD';
  String? rate = '1';
  @override
  String get currencyCode => code;
  @override
  String? get amountInputUsdRate => rate;
  void change(String next, String? nextRate) {
    code = next;
    rate = nextRate;
    ValueFormatter.setCurrencyCode(next);
    notifyListeners();
  }
}

class FiatFees extends Fake implements BitcoinNetworkApi {
  @override
  Future<BitcoinFeeRates> fetchFeeRates(BitcoinProductNetwork network) async =>
      BitcoinFeeRates.fromJson({
        'economy': 1,
        'normal': 1,
        'priority': 1,
        'minimum': 1,
        'stale': false,
      });
}

class FiatBitcoinSend extends BitcoinSendService {
  FiatBitcoinSend() : super(network: FiatFees());
  BigInt? amount;
  @override
  Future<BitcoinPreparedTransfer> prepareTransfer(
    String identity,
    BitcoinProductNetwork productNetwork,
    String recipient,
    BigInt value, {
    BitcoinPurpose? purpose,
    BitcoinFeeTier feeTier = BitcoinFeeTier.normal,
    bool feeTierWasSelected = false,
    bool rbf = true,
    bool Function()? isCurrent,
  }) async {
    amount = value;
    throw StateError('Synthetic preparation stops before custody');
  }

  @override
  Future<BigInt> maximumAmount(
    String identity,
    BitcoinProductNetwork productNetwork,
    String recipient, {
    BitcoinPurpose? purpose,
    BitcoinFeeTier feeTier = BitcoinFeeTier.normal,
    bool rbf = true,
    bool Function()? isCurrent,
  }) async => BigInt.from(123456789);
}

Token token(
  String network,
  String symbol,
  int decimals, {
  double price = 2,
  double balance = 10,
  DateTime? updated,
  String? contract,
}) => Token(
  symbol: symbol,
  name: symbol,
  balance: balance,
  valueUsd: 0,
  priceUsd: price,
  priceUpdatedAt: updated,
  changePercent24h: 0,
  decimals: decimals,
  networkKey: network,
  contractAddress: contract,
);
Future<void> openSend(
  WidgetTester tester,
  FiatChain chain,
  Token selected,
  FiatCurrency currency, {
  FiatBitcoinSend? bitcoin,
  WalletService? wallet,
  ValueChanged<Map<String, dynamic>>? submitted,
}) async {
  tester.view.resetPhysicalSize();
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<BlockchainService>.value(value: chain),
        ChangeNotifierProvider<CurrencyController>.value(value: currency),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: RouteSettings(
            name: settings.name,
            arguments: settings.name == '/' ? selected : settings.arguments,
          ),
          builder: (context) {
            if (settings.name == '/transfer-confirmation') {
              submitted?.call(
                Map<String, dynamic>.from(settings.arguments! as Map),
              );
              return const Scaffold(body: Text('Reviewed token amount'));
            }
            return SendTokenScreen(
              walletService: wallet ?? FiatWallet(),
              bitcoinSendService: bitcoin,
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final address = switch (chain.activeFamily) {
    ChainFamily.evm => '0x1111111111111111111111111111111111111111',
    ChainFamily.solana => '11111111111111111111111111111111',
    ChainFamily.tron => 'T${List.filled(33, '1').join()}',
    ChainFamily.bitcoin => 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
  };
  await tester.enterText(find.byType(TextField).first, address);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

Future<void> closeSend(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // Fluttertoast's mocked success schedules a one-second completion timer.
  await tester.pump(const Duration(seconds: 1));
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installTestFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    ValueFormatter.setCurrencyCode('USD');
    ValueFormatter.updateUsdConversionRates({'USD': 1});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('PonnamKarthik/fluttertoast'),
          (_) async => true,
        );
  });
  for (final scenario in [
    ('evm:1', 'ETH', 18),
    ('solana:mainnet', 'SOL', 9),
    ('tron:mainnet', 'TRX', 6),
    ('bitcoin:mainnet', 'BTC', 8),
    ('evm:1', 'USDC', 6),
    ('evm:1', 'ZERO', 0),
  ]) {
    testWidgets(
      '${scenario.$2}: token/fiat input reaches existing execution boundary in exact units',
      (tester) async {
        final selected = token(
          scenario.$1,
          scenario.$2,
          scenario.$3,
          contract: ['USDC', 'ZERO'].contains(scenario.$2)
              ? '0x2222222222222222222222222222222222222222'
              : null,
        );
        final chain = FiatChain(scenario.$1, [selected]);
        final currency = FiatCurrency();
        final bitcoin = FiatBitcoinSend();
        Map<String, dynamic>? submitted;
        await openSend(
          tester,
          chain,
          selected,
          currency,
          bitcoin: bitcoin,
          submitted: (value) => submitted = value,
        );
        final input = find.byKey(const Key('send-amount-input'));
        expect(
          tester
              .widget<AmountInputModeToggle>(find.byType(AmountInputModeToggle))
              .mode,
          AmountInputMode.token,
        );
        await tester.enterText(input, scenario.$3 == 0 ? '1' : '1.25');
        await tester.pump();
        expect(
          find.text(scenario.$3 == 0 ? '≈ \$2.00' : '≈ \$2.50'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('send-amount-mode')));
        await tester.pump();
        expect(tester.widget<TextField>(input).decoration!.suffixText, 'USD');
        await tester.enterText(input, '3.01');
        await tester.pump();
        expect(
          find.text('≈ ${scenario.$3 == 0 ? '1' : '1.505'} ${scenario.$2}'),
          findsOneWidget,
        );
        await tester.tap(find.text('Send').last);
        await tester.pumpAndSettle();
        final expected =
            BigInt.from(1505) *
            BigInt.from(10).pow(scenario.$3) ~/
            BigInt.from(1000);
        if (scenario.$1.startsWith('bitcoin:')) {
          expect(bitcoin.amount, expected);
        } else {
          expect(submitted?['amountBaseUnits'], expected);
          expect(submitted?['amount'], scenario.$3 == 0 ? '1' : '1.505');
        }
        await closeSend(tester);
      },
    );
  }
  testWidgets(
    'switching modes and selected currency preserves 18-decimal token amount',
    (tester) async {
      final selected = token('evm:1', 'ETH', 18);
      final chain = FiatChain('evm:1', [selected]);
      final currency = FiatCurrency();
      Map<String, dynamic>? submitted;
      await openSend(
        tester,
        chain,
        selected,
        currency,
        submitted: (value) => submitted = value,
      );
      final input = find.byKey(const Key('send-amount-input'));
      const exact = '0.123456789123456789';
      await tester.enterText(input, exact);
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('send-amount-mode')));
        await tester.pump();
      }
      currency.change('NGN', '1500');
      await tester.pump();
      expect(tester.widget<TextField>(input).decoration!.suffixText, 'NGN');
      expect(tester.widget<TextField>(input).controller!.text, '370.37');
      await tester.tap(find.byKey(const Key('send-amount-mode')));
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text, exact);
      await tester.tap(find.text('Send').last);
      await tester.pumpAndSettle();
      expect(submitted?['amountBaseUnits'], BigInt.parse('123456789123456789'));
      await closeSend(tester);
    },
  );
  testWidgets(
    'NGN input uses selected rate; price refresh never changes the prepared token amount',
    (tester) async {
      final selected = token('evm:1', 'ETH', 18);
      final chain = FiatChain('evm:1', [selected]);
      final currency = FiatCurrency()..change('NGN', '1500');
      Map<String, dynamic>? submitted;
      await openSend(
        tester,
        chain,
        selected,
        currency,
        submitted: (value) => submitted = value,
      );
      await tester.tap(find.byKey(const Key('send-amount-mode')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('send-amount-input')),
        '3000',
      );
      await tester.pump();
      chain.refreshPrices([token('evm:1', 'ETH', 18, price: 4)]);
      await tester.pump();
      expect(find.text('≈ 1 ETH'), findsOneWidget);
      await tester.tap(find.text('Send').last);
      await tester.pumpAndSettle();
      expect(submitted?['amountBaseUnits'], BigInt.from(10).pow(18));
      await closeSend(tester);
    },
  );
  testWidgets(
    'unavailable/stale/cross-network prices disable fiat and preserve token entry',
    (tester) async {
      final selected = token('evm:1', 'ETH', 18, price: 0);
      final chain = FiatChain('evm:1', [
        token('evm:56', 'ETH', 18, price: 100),
      ]);
      final currency = FiatCurrency();
      await openSend(tester, chain, selected, currency);
      expect(
        tester
            .widget<AmountInputModeToggle>(find.byType(AmountInputModeToggle))
            .enabled,
        isFalse,
      );
      chain.refreshPrices([
        token(
          'evm:1',
          'ETH',
          18,
          updated: DateTime.now().subtract(const Duration(minutes: 31)),
        ),
      ]);
      await tester.pump();
      expect(
        tester
            .widget<AmountInputModeToggle>(find.byType(AmountInputModeToggle))
            .enabled,
        isFalse,
      );
      chain.refreshPrices([token('evm:1', 'ETH', 18)]);
      await tester.pump();
      expect(
        tester
            .widget<AmountInputModeToggle>(find.byType(AmountInputModeToggle))
            .enabled,
        isTrue,
      );
      currency.change('NGN', null);
      await tester.pump();
      expect(
        tester
            .widget<AmountInputModeToggle>(find.byType(AmountInputModeToggle))
            .enabled,
        isFalse,
      );
      await tester.enterText(find.byKey(const Key('send-amount-input')), '1');
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('send-amount-input')))
            .controller!
            .text,
        '1',
      );
      await closeSend(tester);
    },
  );
  testWidgets('Bitcoin MAX preserves exact satoshis through fiat display', (
    tester,
  ) async {
    final selected = token('bitcoin:mainnet', 'BTC', 8);
    final chain = FiatChain('bitcoin:mainnet', [selected]);
    final bitcoin = FiatBitcoinSend();
    await openSend(tester, chain, selected, FiatCurrency(), bitcoin: bitcoin);
    await tester.tap(find.byKey(const Key('send-amount-mode')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-percentage-100')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('send-amount-input')))
          .controller!
          .text,
      '2.46',
    );
    await tester.tap(find.text('Send').last);
    await tester.pumpAndSettle();
    expect(bitcoin.amount, BigInt.from(123456789));
    await closeSend(tester);
  });
  testWidgets(
    'network change resets fiat entry without reinterpreting the old asset',
    (tester) async {
      final selected = token('evm:1', 'ETH', 18);
      final chain = FiatChain('evm:1', [selected]);
      await openSend(tester, chain, selected, FiatCurrency());
      await tester.tap(find.byKey(const Key('send-amount-mode')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('send-amount-input')), '3');
      await tester.pump();
      chain.key = 'solana:mainnet';
      chain.refreshPrices([token('solana:mainnet', 'SOL', 9)]);
      await tester.pumpAndSettle();
      final input = tester.widget<TextField>(
        find.byKey(const Key('send-amount-input')),
      );
      expect(input.controller!.text, isEmpty);
      expect(input.decoration!.suffixText, 'SOL');
      expect(
        tester
            .widget<AmountInputModeToggle>(find.byType(AmountInputModeToggle))
            .mode,
        AmountInputMode.token,
      );
      await closeSend(tester);
    },
  );
  testWidgets(
    'invalid fiat input does not navigate or fall back to the prior token amount',
    (tester) async {
      final selected = token('evm:1', 'ETH', 18);
      Map<String, dynamic>? submitted;
      await openSend(
        tester,
        FiatChain('evm:1', [selected]),
        selected,
        FiatCurrency(),
        submitted: (value) => submitted = value,
      );
      await tester.enterText(find.byKey(const Key('send-amount-input')), '1');
      await tester.pump();
      await tester.tap(find.byKey(const Key('send-amount-mode')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('send-amount-input')),
        '1.001',
      );
      await tester.pump();
      await tester.tap(find.text('Send').last);
      await tester.pumpAndSettle();
      expect(submitted, isNull);
      expect(find.byType(SendTokenScreen), findsOneWidget);
      await closeSend(tester);
    },
  );
  testWidgets('ambiguous commas never become a larger fiat or Bitcoin spend', (
    tester,
  ) async {
    final selected = token('bitcoin:mainnet', 'BTC', 8);
    final bitcoin = FiatBitcoinSend();
    await openSend(
      tester,
      FiatChain('bitcoin:mainnet', [selected]),
      selected,
      FiatCurrency(),
      bitcoin: bitcoin,
    );
    final input = find.byKey(const Key('send-amount-input'));
    await tester.enterText(input, '0,001');
    await tester.pump();
    await tester.tap(find.text('Send').last);
    await tester.pumpAndSettle();
    expect(bitcoin.amount, isNull);
    await tester.tap(find.byKey(const Key('send-amount-mode')));
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    await tester.enterText(input, '1,5');
    await tester.pump();
    await tester.tap(find.text('Send').last);
    await tester.pumpAndSettle();
    expect(bitcoin.amount, isNull);
    await closeSend(tester);
  });
  testWidgets(
    'Solana MAX and percentages keep fee reserve and full base-unit precision in fiat mode',
    (tester) async {
      final selected = token('solana:mainnet', 'SOL', 9);
      final chain = FiatChain('solana:mainnet', [selected]);
      final currency = FiatCurrency();
      Map<String, dynamic>? submitted;
      await openSend(
        tester,
        chain,
        selected,
        currency,
        submitted: (value) => submitted = value,
      );
      await tester.tap(find.byKey(const Key('send-amount-mode')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('send-percentage-25')));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('send-amount-input')))
            .controller!
            .text,
        '5.00',
      );
      await tester.tap(find.byKey(const Key('send-percentage-100')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send').last);
      await tester.pumpAndSettle();
      expect(submitted?['amountBaseUnits'], BigInt.from(9999995000));
      await closeSend(tester);
    },
  );
  for (final scenario in [
    (
      'solana:mainnet',
      'USDC',
      'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1V',
    ),
    (
      'tron:mainnet',
      'USDT',
      'TR7NHqjeKQxGTCi8q8ZY4pL8otgjLj6t',
      'TR7NHqjeKQxGTCi8q8ZY4pL8otgjLj6T',
    ),
  ]) {
    testWidgets(
      '${scenario.$1}: contract price lookup preserves base58 casing',
      (tester) async {
        final selected = token(
          scenario.$1,
          scenario.$2,
          6,
          contract: scenario.$3,
        );
        final wrong = token(
          scenario.$1,
          scenario.$2,
          6,
          contract: scenario.$4,
          price: 100,
        );
        await openSend(
          tester,
          FiatChain(scenario.$1, [wrong, selected]),
          selected,
          FiatCurrency(),
        );
        await tester.enterText(find.byKey(const Key('send-amount-input')), '1');
        await tester.pump();
        expect(find.text(r'≈ $2.00'), findsOneWidget);
        await closeSend(tester);
      },
    );
  }
  testWidgets(
    'EVM price lookup accepts checksum casing without losing price availability',
    (tester) async {
      const address = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';
      final selected = token('evm:1', 'USDC', 6, contract: address, price: 0);
      final cached = token('evm:1', 'USDC', 6, contract: address.toLowerCase());
      await openSend(
        tester,
        FiatChain('evm:1', [cached]),
        selected,
        FiatCurrency(),
      );
      await tester.enterText(find.byKey(const Key('send-amount-input')), '1');
      await tester.pump();
      expect(find.text(r'≈ $2.00'), findsOneWidget);
      expect(
        tester
            .widget<AmountInputModeToggle>(find.byType(AmountInputModeToggle))
            .enabled,
        isTrue,
      );
      await closeSend(tester);
    },
  );
  testWidgets(
    'stale network balance load cannot replace a newer asset or typed amount',
    (tester) async {
      final selected = token('evm:1', 'ETH', 18);
      final chain = FiatChain('evm:1', [selected]);
      final wallet = DeferredFiatWallet();
      await openSend(tester, chain, selected, FiatCurrency(), wallet: wallet);
      chain.key = 'solana:mainnet';
      chain.refreshPrices([token('solana:mainnet', 'SOL', 9)]);
      await tester.pump();
      await tester.pump();
      final input = find.byKey(const Key('send-amount-input'));
      expect(tester.widget<TextField>(input).enabled, isFalse);
      chain.key = 'tron:mainnet';
      chain.refreshPrices([token('tron:mainnet', 'TRX', 6)]);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).decoration!.suffixText, 'TRX');
      await tester.enterText(input, '2');
      await tester.pump();
      wallet.solana.complete('0xwallet');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).decoration!.suffixText, 'TRX');
      expect(tester.widget<TextField>(input).controller!.text, '2');
      await closeSend(tester);
    },
  );
  testWidgets('wallet change clears the previous wallet fiat amount', (
    tester,
  ) async {
    final selected = token('evm:1', 'ETH', 18);
    final chain = FiatChain('evm:1', [selected]);
    await openSend(tester, chain, selected, FiatCurrency());
    await tester.tap(find.byKey(const Key('send-amount-mode')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('send-amount-input')), '20');
    await tester.pump();
    chain.changeWallet('0xother');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('send-amount-input')))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<AmountInputModeToggle>(find.byType(AmountInputModeToggle))
          .mode,
      AmountInputMode.token,
    );
    await closeSend(tester);
  });
}
