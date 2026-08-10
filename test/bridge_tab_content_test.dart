import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/screens/swap/widgets/bridge_tab_content.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';

Token token(String symbol, String networkKey, {String? address}) => Token(
  symbol: symbol,
  name: symbol,
  contractAddress: address,
  balance: 1,
  valueUsd: 1,
  priceUsd: 1,
  changePercent24h: 0,
  networkKey: networkKey,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bridge origin tokens are scoped to the active chain', () {
    final tokens = [
      token('ETH', 'evm:1'),
      token('USDC', 'evm:8453', address: '0xbase'),
      token('SOL', 'solana:mainnet-beta'),
      token('USDT', 'tron:mainnet', address: 'TR7NH'),
    ];

    final tronTokens = filterBridgeOriginTokens(
      tokens: tokens,
      activeNetworkKey: 'tron:mainnet',
      activeFamily: ChainFamily.tron,
      nativeSymbol: 'TRX',
    );
    final baseTokens = filterBridgeOriginTokens(
      tokens: tokens,
      activeNetworkKey: 'evm:8453',
      activeFamily: ChainFamily.evm,
      nativeSymbol: 'ETH',
    );

    expect(tronTokens.map((item) => item.symbol), ['USDT']);
    expect(baseTokens.map((item) => item.symbol), ['USDC']);
  });

  test('bridge fee and origin network fee placeholders are accurate', () {
    expect(formatBridgeFeeUsd(null), r'$0.00');
    expect(formatBridgeFeeUsd(0), r'$0.00');
    expect(formatBridgeFeeUsd(0.25), r'$0.25');
    expect(hasQuotedOriginNetworkFee(null), isFalse);
    expect(hasQuotedOriginNetworkFee(0), isFalse);
    expect(hasQuotedOriginNetworkFee(0.01), isTrue);
  });

  test(
    'destination USD uses quote or destination metadata, not origin tokens',
    () {
      expect(
        destinationAmountUsd(
          quoteAmountUsd: 19.75,
          amountText: '20',
          destinationSymbol: 'WBTC',
        ),
        19.75,
      );
      expect(
        destinationAmountUsd(
          quoteAmountUsd: 0,
          amountText: '0.001',
          destinationSymbol: 'WBTC',
          destinationPriceUsd: 65000,
        ),
        65,
      );
      expect(
        destinationAmountUsd(
          quoteAmountUsd: 0,
          amountText: '12.5',
          destinationSymbol: 'USDT',
        ),
        12.5,
      );
      expect(
        destinationAmountUsd(
          quoteAmountUsd: 0,
          amountText: '2',
          destinationSymbol: 'SOL',
        ),
        isNull,
      );
    },
  );

  test('Solana and TRON bridge chain controls have catalog logos', () {
    expect(bridgeFamilyLogoUrl(ChainFamily.solana), isNotEmpty);
    expect(bridgeFamilyLogoUrl(ChainFamily.tron), isNotEmpty);
  });

  testWidgets('bridge token modal stays on the active chain', (tester) async {
    final blockchain = _BridgeBlockchainService();
    final tokens = [
      token('ETH', 'evm:1'),
      token('SOL', 'solana:mainnet-beta'),
      Token(
        symbol: 'USDT',
        name: 'TRON Tether',
        contractAddress: 'TR7NH',
        balance: 12,
        valueUsd: 12,
        priceUsd: 1,
        changePercent24h: 0,
        decimals: 6,
        networkKey: 'tron:mainnet',
      ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider<BlockchainService>.value(
        value: blockchain,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: _BridgeSelectorHarness(
              tokens: tokens,
              blockchain: blockchain,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Choose token'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('bridge-family-evm')), findsNothing);
    expect(find.byKey(const ValueKey('bridge-family-solana')), findsNothing);
    expect(find.byKey(const ValueKey('bridge-family-tron')), findsNothing);
    expect(find.text('TRON Tether'), findsOneWidget);
    expect(find.text('ETH'), findsNothing);
    expect(find.text('SOL'), findsNothing);

    await tester.tap(find.text('TRON Tether'));
    await tester.pumpAndSettle();

    expect(find.text('selected:USDT'), findsOneWidget);
    expect(blockchain.activeNetworkKey, 'tron:mainnet');
  });
}

class _BridgeSelectorHarness extends StatefulWidget {
  const _BridgeSelectorHarness({
    required this.tokens,
    required this.blockchain,
  });

  final List<Token> tokens;
  final BlockchainService blockchain;

  @override
  State<_BridgeSelectorHarness> createState() => _BridgeSelectorHarnessState();
}

class _BridgeSelectorHarnessState extends State<_BridgeSelectorHarness> {
  Token? selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(
          onPressed: () async {
            final value = await showDialog<Object?>(
              context: context,
              builder: (_) => buildBridgeOriginTokenDialog(
                tokens: widget.tokens,
                chainId: widget.blockchain.activeTokenStorageChainId,
                activeNetworkKey: widget.blockchain.activeNetworkKey,
                activeFamily: widget.blockchain.activeFamily,
                nativeSymbol: widget.blockchain.activeNetworkSymbol,
              ),
            );
            if (mounted && value is Token) setState(() => selected = value);
          },
          child: const Text('Choose token'),
        ),
        if (selected != null) Text('selected:${selected!.symbol}'),
      ],
    );
  }
}

class _BridgeBlockchainService extends BlockchainService {
  @override
  String get activeNetworkKey => 'tron:mainnet';

  @override
  ChainFamily get activeFamily => ChainFamily.tron;

  @override
  String get activeNetworkSymbol => 'TRX';

  @override
  int get activeTokenStorageChainId => -195;
}
