import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/screens/swap/swap_screen.dart';
import 'package:fomowl_wallet/screens/swap/widgets/bridge_tab_content.dart';
import 'package:fomowl_wallet/services/blockchain/asset_chain_bridge_client.dart';
import 'package:fomowl_wallet/services/blockchain/asset_chain_bridge_contract.dart';
import 'package:fomowl_wallet/services/blockchain/asset_chain_native_bridge_service.dart';
import 'package:fomowl_wallet/services/blockchain/blockchain_catalog.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/evm_transaction_service.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';
import 'package:fomowl_wallet/utils/amount_utils.dart';

const _testWallet = '0x1111111111111111111111111111111111111111';

class _Wallet extends WalletService {
  @override
  Future<String?> getCurrentWalletAddress() async => _testWallet;

  @override
  Future<String?> getWalletAddressForFamily(ChainFamily family) async =>
      family == ChainFamily.evm ? _testWallet : null;
}

class _FakeAssetChainNativeBridgeService extends AssetChainNativeBridgeService {
  _FakeAssetChainNativeBridgeService({
    required super.api,
    required super.wallet,
    this.feeBps = 0,
    this.feeUsd,
    this.feeRecipient,
  });

  final int feeBps;
  final double? feeUsd;
  final String? feeRecipient;
  int quoteCalls = 0;
  AssetChainNativeBridgeRoute? lastRoute;
  double? lastAmountUsd;

  @override
  Future<AssetChainNativeBridgeQuote> quote(
    AssetChainNativeBridgeRoute route,
    String amountText, {
    double? amountUsd,
  }) async {
    quoteCalls++;
    lastRoute = route;
    lastAmountUsd = amountUsd;
    final amount = AmountUtils.parseDecimalToBaseUnits(
      amountText,
      route.source.tokenDecimal,
    );
    final denominator = BigInt.from(10000);
    final sendRate = BigInt.one;
    final sendFee = BigInt.from(25);
    final receiveFee = BigInt.from(15);
    final platformFeeAmount = feeBps > 0
        ? AssetChainNativeBridgeService.calculatePlatformFeeAmount(
            totalAmount: amount,
            feeBps: feeBps,
            sendRate: sendRate,
          )
        : BigInt.zero;
    final bridgeAmount = amount - platformFeeAmount;
    final received = AssetChainNativeBridgeService.calculateReceived(
      amount: bridgeAmount,
      sendRate: sendRate,
      receiveRate: BigInt.one,
      sendFee: sendFee,
      receiveFee: receiveFee,
      denominator: denominator,
    );
    return AssetChainNativeBridgeQuote(
      route: route,
      amount: amount,
      bridgeAmount: bridgeAmount,
      platformFeeAmount: platformFeeAmount,
      platformFeeBps: feeBps,
      platformFeeUsd: feeUsd,
      platformFeeRecipient: feeRecipient,
      amountUsd: amountUsd,
      receivedAmount: received,
      sendRate: sendRate,
      receiveRate: BigInt.one,
      sendFee: sendFee,
      receiveFee: receiveFee,
      denominator: denominator,
    );
  }
}

List<Map<String, dynamic>> _sampleDeployments() => [
  {
    'id': 'ac-42420-usdc',
    'bridgeAddress': '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'chainId': '42420',
    'fees': {'feeFulfill': 15, 'feeSend': 25},
    'tokenId': 'tok-42420-usdc',
    'limitPerSend': '1000000000',
    'tokenDecimal': 6,
    'token': {
      'id': 'tok-42420-usdc',
      'tokenAddress': '0x2b7c1342cc64add10b2a79c8f9767d2667de64b2',
      'decimal': 6,
      'symbol': 'USDC',
      'name': 'USD Coin',
      'chainId': '42420',
    },
  },
  {
    'id': 'eth-1-usdc',
    'bridgeAddress': '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    'chainId': '1',
    'fees': {'feeFulfill': 15, 'feeSend': 25},
    'tokenId': 'tok-1-usdc',
    'limitPerSend': '1000000000',
    'tokenDecimal': 6,
    'token': {
      'id': 'tok-1-usdc',
      'tokenAddress': '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
      'decimal': 6,
      'symbol': 'USDC',
      'name': 'USD Coin',
      'chainId': '1',
    },
  },
];

List<Map<String, dynamic>> _sampleNativeDeployments() => [
  {
    'id': 'ac-42420-rwa',
    'bridgeAddress': '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'chainId': '42420',
    'fees': {'feeFulfill': 15, 'feeSend': 25},
    'tokenId': 'tok-42420-rwa',
    'limitPerSend': '1000000000000000000000',
    'tokenDecimal': 18,
    'token': {
      'id': 'tok-42420-rwa',
      'tokenAddress': AssetChainNativeBridgeService.nativeToken,
      'decimal': 18,
      'symbol': 'RWA',
      'name': 'Asset Chain RWA',
      'chainId': '42420',
    },
  },
  {
    'id': 'eth-1-xrwa',
    'bridgeAddress': '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    'chainId': '1',
    'fees': {'feeFulfill': 15, 'feeSend': 25},
    'tokenId': 'tok-1-xrwa',
    'limitPerSend': '1000000000000000000000',
    'tokenDecimal': 18,
    'token': {
      'id': 'tok-1-xrwa',
      'tokenAddress': '0x2222222222222222222222222222222222222222',
      'decimal': 18,
      'symbol': 'XRWA',
      'name': 'Wrapped RWA',
      'chainId': '1',
    },
  },
];

MockClient _buildMockClient({
  List<Map<String, dynamic>> transactions = const [],
  List<Map<String, dynamic>>? deployments,
}) {
  return MockClient((request) async {
    if (request.url.path == '/bridges') {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': deployments ?? _sampleDeployments(),
        }),
        200,
      );
    }
    if (request.url.path == '/transactions') {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'items': transactions,
            'pagination': {
              'page': 1,
              'limit': 50,
              'totalCount': transactions.length,
              'totalPages': 1,
              'hasNextPage': false,
              'hasPreviousPage': false,
            },
          },
        }),
        200,
      );
    }
    return http.Response(jsonEncode({'error': 'Not found'}), 404);
  });
}

_FakeAssetChainNativeBridgeService _createService({
  List<Map<String, dynamic>> transactions = const [],
  List<Map<String, dynamic>>? deployments,
  int feeBps = 0,
  double? feeUsd,
  String? feeRecipient,
}) {
  final api = AssetChainBridgeClient(
    baseUrl: 'https://corestaging.owlletapp.com',
    clientName: 'test-client',
    clientSecret: 'test-secret',
    httpClient: _buildMockClient(
      transactions: transactions,
      deployments: deployments,
    ),
  );
  return _FakeAssetChainNativeBridgeService(
    api: api,
    wallet: _Wallet(),
    feeBps: feeBps,
    feeUsd: feeUsd,
    feeRecipient: feeRecipient,
  );
}

Finder _assetChainLogoFinder() => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName ==
          'assets/images/chains/assetchain.png',
);

Widget _wrapWithApp(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  test('supportsSwapBridgeTab enables Bridge tab for Asset Chain', () {
    SharedPreferences.setMockInitialValues({});
    final blockchain = BlockchainService();
    blockchain.setActiveChainByChainId(42420);
    expect(supportsSwapBridgeTab(blockchain), isTrue);
    blockchain.setActiveChainByChainId(42421);
    expect(supportsSwapBridgeTab(blockchain), isTrue);
    blockchain.dispose();
  });

  testWidgets(
    'Asset Chain uses unified Bridge UI, bundled logo, and under-the-hood BridgeAssist quoting',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
      final blockchain = BlockchainService();
      blockchain.setActiveChainByChainId(42420);
      final service = _createService();

      await tester.pumpWidget(
        _wrapWithApp(
          BridgeTabContent(
            blockchain: blockchain,
            walletService: _Wallet(),
            walletAddress: _testWallet,
            tokens: const [
              Token(
                symbol: 'RWA',
                name: 'Asset Chain',
                balance: 50,
                valueUsd: 50,
                priceUsd: 1,
                changePercent24h: 0,
                networkKey: 'evm:42420',
                decimals: 18,
              ),
              Token(
                symbol: 'USDC',
                name: 'USD Coin',
                contractAddress: '0x2b7c1342cc64add10b2a79c8f9767d2667de64b2',
                balance: 50,
                valueUsd: 50,
                priceUsd: 1,
                changePercent24h: 0,
                networkKey: 'evm:42420',
                decimals: 6,
              ),
            ],
            onSelectFromChain: () {},
            assetChainBridgeService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BRIDGE FROM'), findsOneWidget);
      expect(find.text('BRIDGE TO'), findsOneWidget);
      expect(find.text('Bridge'), findsOneWidget);
      expect(find.text('Asset Chain native bridge'), findsNothing);
      expect(find.textContaining("Bridging isn't available"), findsNothing);
      expect(_assetChainLogoFinder(), findsAtLeastNWidgets(1));

      await tester.enterText(find.byType(TextField), '2');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(service.quoteCalls, 1);
      expect(service.lastRoute?.sourceChain.chainId, 42420);
      expect(service.lastRoute?.destinationChain.chainId, 1);
      expect(find.text('Asset Chain Bridge'), findsOneWidget);
      expect(find.text('Claim on Ethereum'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      blockchain.dispose();
    },
  );

  testWidgets(
    'EVM Bridge tab includes Asset Chain with bundled logo in destination picker and routes under the hood',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
      final blockchain = BlockchainService();
      blockchain.setActiveChainByChainId(1);
      final service = _createService();

      await tester.pumpWidget(
        _wrapWithApp(
          BridgeTabContent(
            blockchain: blockchain,
            walletService: _Wallet(),
            walletAddress: _testWallet,
            tokens: const [
              Token(
                symbol: 'ETH',
                name: 'Ethereum',
                balance: 2,
                valueUsd: 4000,
                priceUsd: 2000,
                changePercent24h: 0,
                networkKey: 'evm:1',
                decimals: 18,
              ),
              Token(
                symbol: 'USDC',
                name: 'USD Coin',
                contractAddress: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
                balance: 25,
                valueUsd: 25,
                priceUsd: 1,
                changePercent24h: 0,
                networkKey: 'evm:1',
                decimals: 6,
              ),
            ],
            onSelectFromChain: () {},
            assetChainBridgeService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Asset Chain native bridge'), findsNothing);

      final bridgeToPill = find.descendant(
        of: find.ancestor(
          of: find.text('BRIDGE TO'),
          matching: find.byType(Row),
        ),
        matching: find.byType(GestureDetector),
      );
      expect(bridgeToPill, findsOneWidget);
      await tester.tap(bridgeToPill);
      await tester.pumpAndSettle();

      expect(find.text('Bridge to network'), findsOneWidget);
      final sheetScrollable = find.descendant(
        of: find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(ListView),
        ),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Asset Chain'),
        120,
        scrollable: sheetScrollable,
      );
      await tester.pumpAndSettle();

      final sheetAssetChainLogo = find.descendant(
        of: find.byType(BottomSheet),
        matching: _assetChainLogoFinder(),
      );
      expect(sheetAssetChainLogo, findsAtLeastNWidgets(1));

      await tester.tap(find.text('Asset Chain').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '5');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(service.quoteCalls, 1);
      expect(service.lastRoute?.sourceChain.chainId, 1);
      expect(service.lastRoute?.destinationChain.chainId, 42420);
      expect(find.text('Asset Chain Bridge'), findsOneWidget);
      expect(find.text('Claim on Asset Chain'), findsOneWidget);
      expect(_assetChainLogoFinder(), findsAtLeastNWidgets(1));

      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      blockchain.dispose();
    },
  );

  testWidgets(
    'Unfulfilled Asset Chain self-transfers display Claim button inside unified Bridge UI',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
      final blockchain = BlockchainService();
      blockchain.setActiveChainByChainId(42420);
      final service = _createService(
        transactions: [
          {
            'id': 'tx-unfulfilled-1',
            'amount': '2000000',
            'timestamp': '1710000000',
            'fromUser': _testWallet,
            'toUser': _testWallet,
            'fromChain': '42420',
            'toChain': '1',
            'nonce': 1,
            'symbol': 'USDC',
            'fulfilled': false,
            'index': 1,
            'userAddress': _testWallet,
            'chainId': '42420',
            'transactionHash':
                '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
            'bridgeInfoId': 'ac-42420-usdc',
          },
        ],
      );

      await tester.pumpWidget(
        _wrapWithApp(
          BridgeTabContent(
            blockchain: blockchain,
            walletService: _Wallet(),
            walletAddress: _testWallet,
            tokens: const [
              Token(
                symbol: 'RWA',
                name: 'Asset Chain',
                balance: 50,
                valueUsd: 50,
                priceUsd: 1,
                changePercent24h: 0,
                networkKey: 'evm:42420',
                decimals: 18,
              ),
              Token(
                symbol: 'USDC',
                name: 'USD Coin',
                contractAddress: '0x2b7c1342cc64add10b2a79c8f9767d2667de64b2',
                balance: 50,
                valueUsd: 50,
                priceUsd: 1,
                changePercent24h: 0,
                networkKey: 'evm:42420',
                decimals: 6,
              ),
            ],
            onSelectFromChain: () {},
            assetChainBridgeService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Awaiting destination claim'), findsOneWidget);
      expect(find.text('Claim on Ethereum'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      blockchain.dispose();
    },
  );

  testWidgets(
    'Upstream INTERNAL_ERROR database errors render sanitized unavailable message',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
      final blockchain = BlockchainService();
      blockchain.setActiveChainByChainId(42420);
      final failingClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'INTERNAL_ERROR',
            'message': 'password authentication failed for user "postgres"',
          }),
          400,
        );
      });
      final service = _FakeAssetChainNativeBridgeService(
        api: AssetChainBridgeClient(
          baseUrl: 'https://corestaging.owlletapp.com',
          clientName: 'test-client',
          clientSecret: 'test-secret',
          httpClient: failingClient,
        ),
        wallet: _Wallet(),
      );

      await tester.pumpWidget(
        _wrapWithApp(
          BridgeTabContent(
            blockchain: blockchain,
            walletService: _Wallet(),
            walletAddress: _testWallet,
            tokens: const [
              Token(
                symbol: 'RWA',
                name: 'Asset Chain',
                balance: 50,
                valueUsd: 50,
                priceUsd: 1,
                changePercent24h: 0,
                networkKey: 'evm:42420',
                decimals: 18,
              ),
              Token(
                symbol: 'USDC',
                name: 'USD Coin',
                contractAddress: '0x2b7c1342cc64add10b2a79c8f9767d2667de64b2',
                balance: 50,
                valueUsd: 50,
                priceUsd: 1,
                changePercent24h: 0,
                networkKey: 'evm:42420',
                decimals: 6,
              ),
            ],
            onSelectFromChain: () {},
            assetChainBridgeService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '2');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Asset Chain bridge service is temporarily unavailable',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('postgres'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      blockchain.dispose();
    },
  );

  testWidgets(
    'Destination network picker search bar filters networks by name, symbol, and chain ID',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
      final blockchain = BlockchainService();
      blockchain.setActiveChainByChainId(1);
      final service = _createService();

      await tester.pumpWidget(
        _wrapWithApp(
          BridgeTabContent(
            blockchain: blockchain,
            walletService: _Wallet(),
            walletAddress: _testWallet,
            tokens: const [
              Token(
                symbol: 'ETH',
                name: 'Ethereum',
                balance: 2,
                valueUsd: 4000,
                priceUsd: 2000,
                changePercent24h: 0,
                networkKey: 'evm:1',
                decimals: 18,
              ),
            ],
            onSelectFromChain: () {},
            assetChainBridgeService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bridgeToPill = find.descendant(
        of: find.ancestor(
          of: find.text('BRIDGE TO'),
          matching: find.byType(Row),
        ),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(bridgeToPill);
      await tester.pumpAndSettle();

      final searchField = find.byKey(
        const ValueKey('bridge-chain-search-field'),
      );
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Asset Chain');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Asset Chain'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Optimism'),
        ),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('bridge-chain-search-clear')));
      await tester.pumpAndSettle();

      await tester.enterText(searchField, '42420');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Asset Chain'),
        ),
        findsOneWidget,
      );

      await tester.enterText(searchField, 'rwa');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Asset Chain'),
        ),
        findsOneWidget,
      );

      await tester.enterText(searchField, 'nonexistent-chain-xyz');
      await tester.pumpAndSettle();
      expect(find.text('No matching networks found.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      blockchain.dispose();
    },
  );

  testWidgets(
    'Asset Chain bridge quote displays Platform Fee row when backend fee config applies',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
      final blockchain = BlockchainService();
      blockchain.setActiveChainByChainId(42420);
      final service = _createService(
        feeBps: 200,
        feeUsd: 1.0,
        feeRecipient: '0x9999999999999999999999999999999999999999',
      );

      await tester.pumpWidget(
        _wrapWithApp(
          BridgeTabContent(
            blockchain: blockchain,
            walletService: _Wallet(),
            walletAddress: _testWallet,
            tokens: const [
              Token(
                symbol: 'RWA',
                name: 'Asset Chain',
                balance: 200,
                valueUsd: 200,
                priceUsd: 1,
                changePercent24h: 0,
                networkKey: 'evm:42420',
                decimals: 18,
              ),
              Token(
                symbol: 'USDC',
                name: 'USD Coin',
                contractAddress: '0x2b7c1342cc64add10b2a79c8f9767d2667de64b2',
                balance: 200,
                valueUsd: 200,
                priceUsd: 1,
                changePercent24h: 0,
                networkKey: 'evm:42420',
                decimals: 6,
              ),
            ],
            onSelectFromChain: () {},
            assetChainBridgeService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '50');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(service.quoteCalls, 1);
      expect(service.lastAmountUsd, 50.0);
      expect(find.text('Platform Fee'), findsOneWidget);
      expect(find.text(r'$1.00'), findsOneWidget);
      // 50 USDC - 2.00% ($1.00) platform fee = 49 bridged; after 0.25% send + 0.15% claim fees -> 48.804184 output.
      expect(find.text('48.804184'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      blockchain.dispose();
    },
  );

  test('calculatePlatformFeeAmount honors sendRate alignment and bounds', () {
    expect(
      AssetChainNativeBridgeService.calculatePlatformFeeAmount(
        totalAmount: BigInt.parse('100000000000000000000'),
        feeBps: 100,
        sendRate: BigInt.one,
      ),
      BigInt.parse('1000000000000000000'),
    );

    final sendRate = BigInt.parse('1000000000000');
    final total = BigInt.parse('1000000000000000000');
    final alignedFee = AssetChainNativeBridgeService.calculatePlatformFeeAmount(
      totalAmount: total,
      feeBps: 123,
      sendRate: sendRate,
    );
    expect((total - alignedFee) % sendRate, BigInt.zero);
    expect(alignedFee, BigInt.parse('12300000000000000'));

    expect(
      AssetChainNativeBridgeService.calculatePlatformFeeAmount(
        totalAmount: total,
        feeBps: 0,
        sendRate: sendRate,
      ),
      BigInt.zero,
    );
  });

  test(
    'AssetChainNativeBridgeService splits platform fee from ERC20 bridge send and tolerates fee transfer failure',
    () async {
      SharedPreferences.setMockInitialValues({});
      const feeRecipient = '0x9999999999999999999999999999999999999999';
      const bridgeAddr = '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      const tokenAddr = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
      const acUsdcAddr = '0x2b7c1342cc64add10b2a79c8f9767d2667de64b2';
      const bridgeTxHash =
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

      final routes = AssetChainNativeBridgeService.routes(
        _sampleDeployments().map(AssetChainBridgeDeployment.fromJson).toList(),
        BlockchainCatalog.builtInChains,
      );
      final ethToAc = routes.firstWhere(
        (r) =>
            r.sourceChain.chainId == 1 && r.destinationChain.chainId == 42420,
      );

      final bridgeAbi = ContractAbi.fromJson(
        assetChainBridgeContractAbi,
        'BridgeAssist',
      );
      final erc20Abi = ContractAbi.fromJson('''[
        {"type":"function","name":"balanceOf","stateMutability":"view","inputs":[{"name":"owner","type":"address"}],"outputs":[{"name":"","type":"uint256"}]},
        {"type":"function","name":"allowance","stateMutability":"view","inputs":[{"name":"owner","type":"address"},{"name":"spender","type":"address"}],"outputs":[{"name":"","type":"uint256"}]},
        {"type":"function","name":"approve","stateMutability":"nonpayable","inputs":[{"name":"spender","type":"address"},{"name":"amount","type":"uint256"}],"outputs":[{"name":"","type":"bool"}]},
        {"type":"function","name":"transfer","stateMutability":"nonpayable","inputs":[{"name":"to","type":"address"},{"name":"amount","type":"uint256"}],"outputs":[{"name":"","type":"bool"}]}
      ]''', 'ERC20');
      final srcContract = DeployedContract(
        bridgeAbi,
        EthereumAddress.fromHex(bridgeAddr),
      );
      final erc20Contract = DeployedContract(
        erc20Abi,
        EthereumAddress.fromHex(tokenAddr),
      );

      String? recordedTxHash;
      final api = AssetChainBridgeClient(
        baseUrl: 'https://corestaging.owlletapp.com/api/swap/assetchain/bridge',
        useProxy: true,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/fee-quote')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'enabled': true,
                  'platformFeeBps': 100,
                  'platformFeeUsd': 1.0,
                  'feeRecipient': feeRecipient,
                },
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/transactions') &&
              request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            recordedTxHash = body['transactionHash']?.toString();
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'id': 'tx-1',
                  'amount': '99000000',
                  'fromChain': 'evm.1',
                  'toChain': 'evm.42420',
                  'fromUser': _testWallet,
                  'toUser': _testWallet,
                  'index': 0,
                  'fulfilled': false,
                  'transactionHash': recordedTxHash,
                },
              }),
              201,
            );
          }
          return http.Response(jsonEncode({'error': 'Not found'}), 404);
        }),
      );

      final allowanceAmount = [BigInt.zero];
      final recordedBroadcasts =
          <({String? to, String? data, BigInt? value})>[];
      var throwOnFeeTransfer = false;

      final wallet = _RecordingWalletService((
        toAddress,
        dataHex,
        valueInWei,
      ) async {
        recordedBroadcasts.add((
          to: toAddress?.toLowerCase(),
          data: dataHex?.toLowerCase(),
          value: valueInWei,
        ));
        final approveSel = bytesToHex(
          erc20Contract.function('approve').selector,
          include0x: true,
        );
        final transferSel = bytesToHex(
          erc20Contract.function('transfer').selector,
          include0x: true,
        );
        if (dataHex != null && dataHex.toLowerCase().startsWith(approveSel)) {
          allowanceAmount[0] = BigInt.parse('99000000');
          return '0xapprove1';
        }
        if (dataHex != null && dataHex.toLowerCase().startsWith(transferSel)) {
          if (throwOnFeeTransfer) {
            throw StateError('Simulated fee transfer failure');
          }
          return '0xfee1';
        }
        return bridgeTxHash;
      });

      Web3Client rpcFactory(EvmChain chain) => Web3Client(
        chain.rpcUrl,
        MockClient((request) async {
          final rpc = jsonDecode(request.body) as Map<String, dynamic>;
          final method = rpc['method'] as String;
          final id = rpc['id'];
          if (method == 'eth_chainId') {
            return http.Response(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': id,
                'result': '0x${chain.chainId.toRadixString(16)}',
              }),
              200,
            );
          }
          if (method == 'eth_getTransactionReceipt') {
            return http.Response(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': id,
                'result': {
                  'transactionHash': bridgeTxHash,
                  'transactionIndex': '0x0',
                  'blockHash':
                      '0x1111111111111111111111111111111111111111111111111111111111111111',
                  'blockNumber': '0x64',
                  'cumulativeGasUsed': '0x5208',
                  'gasUsed': '0x5208',
                  'status': '0x1',
                  'logs': <dynamic>[],
                },
              }),
              200,
            );
          }
          if (method == 'eth_call') {
            final params =
                (rpc['params'] as List).first as Map<String, dynamic>;
            final data = (params['data'] as String).toLowerCase();
            final sel = data.substring(0, 10);
            String resultHex;
            if (sel ==
                bytesToHex(
                  srcContract.function('CURRENT_CHAIN').selector,
                  include0x: true,
                )) {
              resultHex = _abiEncodeSingleString('evm.${chain.chainId}');
            } else if (sel ==
                bytesToHex(
                  srcContract.function('TOKEN').selector,
                  include0x: true,
                )) {
              final expectedToken = chain.chainId == 1 ? tokenAddr : acUsdcAddr;
              resultHex = '0x${_padAddress(expectedToken)}';
            } else if (sel ==
                bytesToHex(
                  srcContract.function('paused').selector,
                  include0x: true,
                )) {
              resultHex = '0x${_padUint(BigInt.zero)}';
            } else if (sel ==
                bytesToHex(
                  srcContract.function('isSupportedChain').selector,
                  include0x: true,
                )) {
              resultHex = '0x${_padUint(BigInt.one)}';
            } else if (sel ==
                bytesToHex(
                  srcContract.function('FEE_DENOMINATOR').selector,
                  include0x: true,
                )) {
              resultHex = '0x${_padUint(BigInt.from(10000))}';
            } else if (sel ==
                bytesToHex(
                  srcContract.function('limitPerSend').selector,
                  include0x: true,
                )) {
              resultHex =
                  '0x${_padUint(BigInt.parse('1000000000000000000000'))}';
            } else if (sel ==
                bytesToHex(
                  srcContract.function('exchangeRateFrom').selector,
                  include0x: true,
                )) {
              resultHex = '0x${_padUint(BigInt.one)}';
            } else if (sel ==
                    bytesToHex(
                      srcContract.function('feeSend').selector,
                      include0x: true,
                    ) ||
                sel ==
                    bytesToHex(
                      srcContract.function('feeFulfill').selector,
                      include0x: true,
                    )) {
              resultHex = '0x${_padUint(BigInt.zero)}';
            } else if (sel ==
                bytesToHex(
                  erc20Contract.function('balanceOf').selector,
                  include0x: true,
                )) {
              resultHex = '0x${_padUint(BigInt.parse('100000000'))}';
            } else if (sel ==
                bytesToHex(
                  erc20Contract.function('allowance').selector,
                  include0x: true,
                )) {
              resultHex = '0x${_padUint(allowanceAmount[0])}';
            } else if (sel ==
                bytesToHex(
                  srcContract.function('getUserTransactionsAmount').selector,
                  include0x: true,
                )) {
              resultHex = '0x${_padUint(BigInt.one)}';
            } else if (sel ==
                bytesToHex(
                  srcContract.function('transactions').selector,
                  include0x: true,
                )) {
              resultHex = _abiEncodeBridgeTransaction(
                amount: BigInt.parse('99000000'),
                fromUser: _testWallet,
                toUser: _testWallet,
                fromChain: 'evm.1',
                toChain: 'evm.42420',
                blockNumber: BigInt.from(100),
              );
            } else {
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': id,
                  'error': 'unexpected selector $sel',
                }),
                500,
              );
            }
            return http.Response(
              jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': resultHex}),
              200,
            );
          }
          return http.Response(
            jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': '0x'}),
            200,
          );
        }),
      );

      final service = AssetChainNativeBridgeService(
        api: api,
        wallet: wallet,
        clientFactory: rpcFactory,
      );

      final quote = await service.quote(ethToAc, '100', amountUsd: 100);
      expect(quote.amount, BigInt.parse('100000000'));
      expect(quote.platformFeeAmount, BigInt.parse('1000000'));
      expect(quote.bridgeAmount, BigInt.parse('99000000'));
      expect(quote.receivedAmount, BigInt.parse('99000000'));
      expect(quote.platformFeeBps, 100);
      expect(quote.platformFeeRecipient, feeRecipient);

      final hash = await service.send(
        quote,
        _testWallet,
        isCurrent: () => true,
      );
      expect(hash, bridgeTxHash);
      expect(recordedTxHash, bridgeTxHash);

      expect(recordedBroadcasts, hasLength(3));
      final approveData = bytesToHex(
        erc20Contract.function('approve').encodeCall([
          EthereumAddress.fromHex(bridgeAddr),
          quote.bridgeAmount,
        ]),
        include0x: true,
      ).toLowerCase();
      final sendData = bytesToHex(
        srcContract.function('send').encodeCall([
          quote.bridgeAmount,
          _testWallet,
          'evm.42420',
        ]),
        include0x: true,
      ).toLowerCase();
      final feeData = bytesToHex(
        erc20Contract.function('transfer').encodeCall([
          EthereumAddress.fromHex(feeRecipient),
          quote.platformFeeAmount,
        ]),
        include0x: true,
      ).toLowerCase();

      expect(recordedBroadcasts[0].to, tokenAddr);
      expect(recordedBroadcasts[0].data, approveData);
      expect(recordedBroadcasts[1].to, bridgeAddr);
      expect(recordedBroadcasts[1].data, sendData);
      expect(recordedBroadcasts[1].value, BigInt.zero);
      expect(recordedBroadcasts[2].to, tokenAddr);
      expect(recordedBroadcasts[2].data, feeData);
      expect(recordedBroadcasts[2].value, BigInt.zero);

      // Even if post-bridge ERC-20 fee transfer throws, confirmed bridge succeeds.
      allowanceAmount[0] = BigInt.zero;
      throwOnFeeTransfer = true;
      final hashWhenFeeFails = await service.send(
        quote,
        _testWallet,
        isCurrent: () => true,
      );
      expect(hashWhenFeeFails, bridgeTxHash);

      service.dispose();
    },
  );

  test(
    'AssetChainNativeBridgeService splits platform fee from native send and transfers native fee',
    () async {
      SharedPreferences.setMockInitialValues({});
      const feeRecipient = '0x9999999999999999999999999999999999999999';
      const bridgeAddr = '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const bridgeTxHash =
          '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

      final routes = AssetChainNativeBridgeService.routes(
        _sampleNativeDeployments()
            .map(AssetChainBridgeDeployment.fromJson)
            .toList(),
        BlockchainCatalog.builtInChains,
      );
      final acToEth = routes.firstWhere(
        (r) =>
            r.sourceChain.chainId == 42420 && r.destinationChain.chainId == 1,
      );

      final bridgeAbi = ContractAbi.fromJson(
        assetChainBridgeContractAbi,
        'BridgeAssist',
      );
      final srcContract = DeployedContract(
        bridgeAbi,
        EthereumAddress.fromHex(bridgeAddr),
      );

      final api = AssetChainBridgeClient(
        baseUrl: 'https://corestaging.owlletapp.com/api/swap/assetchain/bridge',
        useProxy: true,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/fee-quote')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'enabled': true,
                  'platformFeeBps': 1000,
                  'platformFeeUsd': 0.2,
                  'feeRecipient': feeRecipient,
                },
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/transactions') &&
              request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'id': 'tx-native-1',
                  'amount': '1800000000000000000',
                  'fromChain': 'evm.42420',
                  'toChain': 'evm.1',
                  'fromUser': _testWallet,
                  'toUser': _testWallet,
                  'index': 0,
                  'fulfilled': false,
                  'transactionHash': bridgeTxHash,
                },
              }),
              201,
            );
          }
          return http.Response(jsonEncode({'error': 'Not found'}), 404);
        }),
      );

      final recordedBroadcasts =
          <({String? to, String? data, BigInt? value})>[];
      final wallet = _RecordingWalletService((
        toAddress,
        dataHex,
        valueInWei,
      ) async {
        recordedBroadcasts.add((
          to: toAddress?.toLowerCase(),
          data: dataHex?.toLowerCase(),
          value: valueInWei,
        ));
        return toAddress?.toLowerCase() == feeRecipient
            ? '0xnativefee'
            : bridgeTxHash;
      });

      Web3Client rpcFactory(EvmChain chain) => Web3Client(
        chain.rpcUrl,
        MockClient((request) async {
          final rpc = jsonDecode(request.body) as Map<String, dynamic>;
          final method = rpc['method'] as String;
          final id = rpc['id'];
          if (method == 'eth_chainId') {
            return http.Response(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': id,
                'result': '0x${chain.chainId.toRadixString(16)}',
              }),
              200,
            );
          }
          if (method == 'eth_getBalance') {
            return http.Response(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': id,
                'result':
                    '0x${BigInt.parse('2500000000000000000').toRadixString(16)}',
              }),
              200,
            );
          }
          if (method == 'eth_getTransactionReceipt') {
            return http.Response(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': id,
                'result': {
                  'transactionHash': bridgeTxHash,
                  'transactionIndex': '0x0',
                  'blockHash':
                      '0x2222222222222222222222222222222222222222222222222222222222222222',
                  'blockNumber': '0x65',
                  'cumulativeGasUsed': '0x5208',
                  'gasUsed': '0x5208',
                  'status': '0x1',
                  'logs': <dynamic>[],
                },
              }),
              200,
            );
          }
          if (method == 'eth_call') {
            final params =
                (rpc['params'] as List).first as Map<String, dynamic>;
            final data = (params['data'] as String).toLowerCase();
            final sel = data.substring(0, 10);
            String resultHex;
            if (sel ==
                bytesToHex(
                  srcContract.function('CURRENT_CHAIN').selector,
                  include0x: true,
                )) {
              resultHex = _abiEncodeSingleString('evm.${chain.chainId}');
            } else if (sel ==
                bytesToHex(
                  srcContract.function('TOKEN').selector,
                  include0x: true,
                )) {
              final expectedToken = chain.chainId == 42420
                  ? AssetChainNativeBridgeService.nativeToken
                  : '0x2222222222222222222222222222222222222222';
              resultHex = '0x${_padAddress(expectedToken)}';
            } else if (sel ==
                bytesToHex(
                  srcContract.function('paused').selector,
                  include0x: true,
                )) {
              resultHex = '0x${_padUint(BigInt.zero)}';
            } else if (sel ==
                bytesToHex(
                  srcContract.function('isSupportedChain').selector,
                  include0x: true,
                )) {
              resultHex = '0x${_padUint(BigInt.one)}';
            } else if (sel ==
                bytesToHex(
                  srcContract.function('FEE_DENOMINATOR').selector,
                  include0x: true,
                )) {
              resultHex = '0x${_padUint(BigInt.from(10000))}';
            } else if (sel ==
                bytesToHex(
                  srcContract.function('limitPerSend').selector,
                  include0x: true,
                )) {
              resultHex =
                  '0x${_padUint(BigInt.parse('1000000000000000000000'))}';
            } else if (sel ==
                bytesToHex(
                  srcContract.function('exchangeRateFrom').selector,
                  include0x: true,
                )) {
              resultHex = '0x${_padUint(BigInt.one)}';
            } else if (sel ==
                    bytesToHex(
                      srcContract.function('feeSend').selector,
                      include0x: true,
                    ) ||
                sel ==
                    bytesToHex(
                      srcContract.function('feeFulfill').selector,
                      include0x: true,
                    )) {
              resultHex = '0x${_padUint(BigInt.zero)}';
            } else if (sel ==
                bytesToHex(
                  srcContract.function('getUserTransactionsAmount').selector,
                  include0x: true,
                )) {
              resultHex = '0x${_padUint(BigInt.one)}';
            } else if (sel ==
                bytesToHex(
                  srcContract.function('transactions').selector,
                  include0x: true,
                )) {
              resultHex = _abiEncodeBridgeTransaction(
                amount: BigInt.parse('1800000000000000000'),
                fromUser: _testWallet,
                toUser: _testWallet,
                fromChain: 'evm.42420',
                toChain: 'evm.1',
                blockNumber: BigInt.from(101),
              );
            } else {
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': id,
                  'error': 'unexpected selector $sel',
                }),
                500,
              );
            }
            return http.Response(
              jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': resultHex}),
              200,
            );
          }
          return http.Response(
            jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': '0x'}),
            200,
          );
        }),
      );

      final service = AssetChainNativeBridgeService(
        api: api,
        wallet: wallet,
        clientFactory: rpcFactory,
      );

      final quote = await service.quote(acToEth, '2', amountUsd: 2);
      expect(quote.platformFeeAmount, BigInt.parse('200000000000000000'));
      expect(quote.bridgeAmount, BigInt.parse('1800000000000000000'));

      final hash = await service.send(
        quote,
        _testWallet,
        isCurrent: () => true,
      );
      expect(hash, bridgeTxHash);
      expect(recordedBroadcasts, hasLength(2));
      expect(recordedBroadcasts[0].to, bridgeAddr);
      expect(recordedBroadcasts[0].value, BigInt.parse('1800000000000000000'));
      expect(recordedBroadcasts[1].to, feeRecipient);
      expect(recordedBroadcasts[1].data, '0x');
      expect(recordedBroadcasts[1].value, BigInt.parse('200000000000000000'));

      service.dispose();
    },
  );

  testWidgets(
    'RWA and WRWA remain hidden in Bridge even when widget.tokens is empty or /bridges returns RWA',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
      final blockchain = BlockchainService();
      blockchain.setActiveChainByChainId(42420);
      final service = _createService(
        deployments: [..._sampleNativeDeployments(), ..._sampleDeployments()],
      );

      await tester.pumpWidget(
        _wrapWithApp(
          BridgeTabContent(
            blockchain: blockchain,
            walletService: _Wallet(),
            walletAddress: _testWallet,
            tokens: const [
              Token(
                symbol: 'RWA',
                name: 'Asset Chain',
                balance: 50,
                valueUsd: 50,
                priceUsd: 1,
                changePercent24h: 0,
                networkKey: 'evm:42420',
                decimals: 18,
              ),
              Token(
                symbol: 'WRWA',
                name: 'Wrapped RWA',
                contractAddress: '0x2584D40B5553E81Bb9deC0b6CD1a2E504AAB1709',
                balance: 25,
                valueUsd: 25,
                priceUsd: 1,
                changePercent24h: 0,
                networkKey: 'evm:42420',
                decimals: 18,
              ),
            ],
            onSelectFromChain: () {},
            assetChainBridgeService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(BridgeTabContent),
          matching: find.text('RWA'),
        ),
        findsNothing,
      );
      expect(find.text('WRWA'), findsNothing);
      expect(find.text('--'), findsWidgets);
      expect(
        find.textContaining('RWA and WRWA cannot be bridged'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '2');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(service.quoteCalls, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      blockchain.dispose();
    },
  );
}

class _RecordingWalletService extends _Wallet {
  final Future<String> Function(
    String? toAddress,
    String? dataHex,
    BigInt? valueInWei,
  )
  _onBroadcast;

  _RecordingWalletService(this._onBroadcast);

  @override
  Future<String> sendRawTransactionRequest({
    required String rpcUrl,
    required int chainId,
    String? expectedFromAddress,
    String? toAddress,
    BigInt? valueInWei,
    String? dataHex,
    BigInt? gasPriceWei,
    BigInt? maxFeePerGasWei,
    BigInt? maxPriorityFeePerGasWei,
    int? gasLimit,
    int? nonce,
    Future<void> Function(EvmSignedTransaction transaction)? beforeBroadcast,
    Future<void> Function()? abortedBeforeBroadcast,
    void Function()? validateBeforeSigning,
  }) => _onBroadcast(toAddress, dataHex, valueInWei);
}

String _padUint(BigInt value) => value.toRadixString(16).padLeft(64, '0');

String _padAddress(String address) =>
    address.toLowerCase().replaceFirst('0x', '').padLeft(64, '0');

String _encodeStringChunk(String value) {
  final raw = utf8.encode(value);
  final lenWord = _padUint(BigInt.from(raw.length));
  final hexBytes = bytesToHex(raw, include0x: false);
  final paddedLen = ((hexBytes.length + 63) ~/ 64) * 64;
  return lenWord + hexBytes.padRight(paddedLen == 0 ? 64 : paddedLen, '0');
}

String _abiEncodeSingleString(String value) =>
    '0x${_padUint(BigInt.from(32))}${_encodeStringChunk(value)}';

String _abiEncodeBridgeTransaction({
  required BigInt amount,
  required String fromUser,
  required String toUser,
  required String fromChain,
  required String toChain,
  required BigInt blockNumber,
}) {
  final toUserChunk = _encodeStringChunk(toUser);
  final fromChainChunk = _encodeStringChunk(fromChain);
  final toChainChunk = _encodeStringChunk(toChain);

  const headBytes = 8 * 32;
  final toUserOffset = headBytes;
  final fromChainOffset = toUserOffset + toUserChunk.length ~/ 2;
  final toChainOffset = fromChainOffset + fromChainChunk.length ~/ 2;

  return '0x'
      '${_padUint(amount)}'
      '${_padUint(BigInt.from(1700000000))}'
      '${_padAddress(fromUser)}'
      '${_padUint(BigInt.from(toUserOffset))}'
      '${_padUint(BigInt.from(fromChainOffset))}'
      '${_padUint(BigInt.from(toChainOffset))}'
      '${_padUint(BigInt.zero)}'
      '${_padUint(blockNumber)}'
      '$toUserChunk$fromChainChunk$toChainChunk';
}
