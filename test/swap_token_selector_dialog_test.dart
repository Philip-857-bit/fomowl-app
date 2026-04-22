import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/screens/swap/widgets/swap_token_selector_dialog.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/token_visibility_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const baseChain = EvmChain(
    name: 'Base',
    symbol: 'ETH',
    chainId: 8453,
    rpcUrl: 'https://rpc.base.example',
  );

  const usdc = Token(
    symbol: 'USDC',
    name: 'USD Coin',
    contractAddress: '0x1111111111111111111111111111111111111111',
    balance: 10,
    valueUsd: 10,
    changePercent24h: 0,
    decimals: 6,
  );

  const hiddenToken = Token(
    symbol: 'FOWL',
    name: 'Fomowl',
    contractAddress: '0x2222222222222222222222222222222222222222',
    balance: 0,
    valueUsd: 0,
    changePercent24h: 0,
    decimals: 18,
  );

  const detectedDefinition = CustomTokenDefinition(
    symbol: 'FOWL',
    name: 'Fomowl',
    address: '0x2222222222222222222222222222222222222222',
    decimals: 18,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('filters existing swap tokens locally', (tester) async {
    final blockchain = _FakeBlockchainService(
      active: baseChain,
      initialTokens: const [usdc, hiddenToken],
    );

    await tester.pumpWidget(
      _wrapWithApp(
        blockchain: blockchain,
        child: const SwapTokenSelectorDialog(
          tokens: [usdc, hiddenToken],
          chainId: 8453,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'usd');
    await tester.pumpAndSettle();

    expect(find.text('USD Coin'), findsOneWidget);
    expect(find.text('Fomowl'), findsNothing);
  });

  testWidgets('shows detected token and returns it after add', (tester) async {
    final blockchain = _FakeBlockchainService(
      active: baseChain,
      initialTokens: const [usdc],
    )..registerDetection(detectedDefinition.address, detectedDefinition);

    await tester.pumpWidget(
      _wrapWithApp(
        blockchain: blockchain,
        child: _SwapTokenSelectorHarness(dialogTokens: const [usdc]),
      ),
    );

    await tester.tap(find.text('Open selector'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), detectedDefinition.address);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Fomowl'), findsOneWidget);
    expect(find.text('Add Token'), findsOneWidget);

    await tester.tap(find.text('Add Token'));
    await tester.pumpAndSettle();

    expect(find.text('selected:FOWL'), findsOneWidget);
    expect(blockchain.addCustomTokenCalls, 1);
  });

  testWidgets('restores a hidden token without re-adding it', (tester) async {
    SharedPreferences.setMockInitialValues({
      'hidden_tokens_8453': [hiddenToken.contractAddress!.toLowerCase()],
    });

    final blockchain = _FakeBlockchainService(
      active: baseChain,
      initialTokens: const [hiddenToken],
      initialCustomTokens: const [detectedDefinition],
    )..registerDetection(detectedDefinition.address, detectedDefinition);

    await tester.pumpWidget(
      _wrapWithApp(
        blockchain: blockchain,
        child: _SwapTokenSelectorHarness(dialogTokens: const [usdc]),
      ),
    );

    await tester.tap(find.text('Open selector'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), detectedDefinition.address);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Token'));
    await tester.pumpAndSettle();

    expect(find.text('selected:FOWL'), findsOneWidget);
    expect(blockchain.addCustomTokenCalls, 0);

    final hiddenTokens = await TokenVisibilityService().loadHiddenTokens(8453);
    expect(
      hiddenTokens.contains(detectedDefinition.address.toLowerCase()),
      isFalse,
    );
  });

  testWidgets('does not show add action for an invalid contract query', (
    tester,
  ) async {
    final blockchain = _FakeBlockchainService(
      active: baseChain,
      initialTokens: const [usdc],
    );

    await tester.pumpWidget(
      _wrapWithApp(
        blockchain: blockchain,
        child: const SwapTokenSelectorDialog(tokens: [usdc], chainId: 8453),
      ),
    );

    await tester.enterText(find.byType(TextField), '0x1234');
    await tester.pumpAndSettle();

    expect(find.text('Add Token'), findsNothing);
  });
}

Widget _wrapWithApp({
  required BlockchainService blockchain,
  required Widget child,
}) {
  return ChangeNotifierProvider<BlockchainService>.value(
    value: blockchain,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

class _SwapTokenSelectorHarness extends StatefulWidget {
  const _SwapTokenSelectorHarness({required this.dialogTokens});

  final List<Token> dialogTokens;

  @override
  State<_SwapTokenSelectorHarness> createState() =>
      _SwapTokenSelectorHarnessState();
}

class _SwapTokenSelectorHarnessState extends State<_SwapTokenSelectorHarness> {
  Token? _selectedToken;

  @override
  Widget build(BuildContext context) {
    final chainId = context.watch<BlockchainService>().activeChain.chainId;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () async {
            final token = await showDialog<Token>(
              context: context,
              builder: (_) => SwapTokenSelectorDialog(
                tokens: widget.dialogTokens,
                chainId: chainId,
              ),
            );
            if (!mounted) {
              return;
            }
            setState(() => _selectedToken = token);
          },
          child: const Text('Open selector'),
        ),
        if (_selectedToken != null) Text('selected:${_selectedToken!.symbol}'),
      ],
    );
  }
}

class _FakeBlockchainService extends BlockchainService {
  _FakeBlockchainService({
    required this.active,
    required List<Token> initialTokens,
    List<CustomTokenDefinition> initialCustomTokens = const [],
  }) : _tokens = List<Token>.from(initialTokens),
       _customTokens = List<CustomTokenDefinition>.from(initialCustomTokens);

  final EvmChain active;
  List<Token> _tokens;
  List<CustomTokenDefinition> _customTokens;
  final Map<String, CustomTokenDefinition?> _detections = {};
  int addCustomTokenCalls = 0;

  void registerDetection(String address, CustomTokenDefinition? token) {
    _detections[address.toLowerCase()] = token;
  }

  @override
  EvmChain get activeChain => active;

  @override
  List<Token> get tokens => List<Token>.from(_tokens);

  @override
  List<CustomTokenDefinition> get customTokensForActiveChain =>
      List<CustomTokenDefinition>.from(_customTokens);

  @override
  Future<CustomTokenDefinition?> detectTokenByContract(
    String contractAddress,
  ) async {
    return _detections[contractAddress.toLowerCase()];
  }

  @override
  Future<bool> addCustomToken({
    required int chainId,
    required CustomTokenDefinition token,
  }) async {
    addCustomTokenCalls++;
    if (_customTokens.any(
      (existing) =>
          existing.address.toLowerCase() == token.address.toLowerCase(),
    )) {
      return false;
    }

    _customTokens = [..._customTokens, token];
    _tokens = [
      ..._tokens,
      Token(
        symbol: token.symbol,
        name: token.name,
        contractAddress: token.address,
        balance: 0,
        valueUsd: 0,
        priceUsd: 0,
        changePercent24h: 0,
        decimals: token.decimals,
        imageUrl: token.imageUrl,
        coinGeckoId: token.coinGeckoId,
      ),
    ];
    notifyListeners();
    return true;
  }
}
