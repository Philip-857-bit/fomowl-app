import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/models/token_standard.dart';
import 'package:fomowl_wallet/screens/wallet/widgets/token_detail/balance_summary_card.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/screens/wallet/widgets/token_detail/token_detail_header.dart';
import 'package:fomowl_wallet/screens/wallet/widgets/token_detail/token_info_table.dart';
import 'package:fomowl_wallet/screens/wallet/widgets/token_management/managed_token_tile.dart';
import 'package:fomowl_wallet/screens/wallet/widgets/token_management/contract_import_card.dart';
import 'package:fomowl_wallet/services/blockchain/blockchain_catalog.dart';
import 'package:fomowl_wallet/services/token_visibility_service.dart';
import 'package:flutter/services.dart';
import 'package:fomowl_wallet/features/shell/app_shell_controller.dart';
import 'package:fomowl_wallet/screens/wallet/token_detail_screen.dart';
import 'package:fomowl_wallet/screens/wallet/send_token_screen.dart';
import 'package:fomowl_wallet/services/currency_controller.dart';
import 'package:fomowl_wallet/utils/token_trust_utils.dart';
import 'package:fomowl_wallet/utils/token_visibility_utils.dart';
import 'package:fomowl_wallet/widgets/token_icon.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/screens/wallet/receive_token_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  String? mockClipboardText;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, (_) async => true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        mockClipboardText = (methodCall.arguments as Map)['text'] as String?;
        return null;
      }
      if (methodCall.method == 'Clipboard.getData') {
        return {'text': mockClipboardText};
      }
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AssetChain Token Models and Metadata Parity', () {
    test('native AssetChain token loads all metadata, decimals, and balances accurately', () {
      final assetChain = BlockchainCatalog.findChain(42420);
      expect(assetChain, isNotNull);
      expect(assetChain!.name, 'Asset Chain');
      expect(assetChain.symbol, 'RWA');
      expect(assetChain.chainId, 42420);
      expect(assetChain.networkKey, 'evm:42420');

      final nativeRwa = Token(
        symbol: assetChain.symbol,
        name: assetChain.name,
        contractAddress: null,
        balance: 125.75,
        valueUsd: 0.0,
        priceUsd: 0.0,
        changePercent24h: 0.0,
        decimals: 18,
        imageUrl: assetChain.logoUrl,
        networkKey: assetChain.networkKey,
        tokenStandard: TokenStandard.native,
        isCertified: true,
      );

      expect(nativeRwa.symbol, 'RWA');
      expect(nativeRwa.name, 'Asset Chain');
      expect(nativeRwa.contractAddress, isNull);
      expect(nativeRwa.decimals, 18);
      expect(nativeRwa.balance, 125.75);
      expect(nativeRwa.formattedBalance, '125.75 RWA');
      expect(nativeRwa.effectiveTokenStandard, TokenStandard.native);
      expect(nativeRwa.networkKey, 'evm:42420');
      expect(nativeRwa.isCertified, isTrue);
    });

    test('ERC-20 token on AssetChain loads contract address, decimals, and metadata accurately', () {
      const contractAddress = '0x1234567890abcdef1234567890abcdef12345678';
      const rwaToken = Token(
        symbol: 'PROP',
        name: 'Real Estate Property Token',
        contractAddress: contractAddress,
        balance: 500.0,
        valueUsd: 1250.0,
        priceUsd: 2.50,
        changePercent24h: 3.45,
        decimals: 6,
        imageUrl: 'https://example.com/prop.png',
        networkKey: 'evm:42420',
        tokenStandard: TokenStandard.erc20,
        isCertified: true,
      );

      expect(rwaToken.symbol, 'PROP');
      expect(rwaToken.name, 'Real Estate Property Token');
      expect(rwaToken.contractAddress, contractAddress);
      expect(rwaToken.decimals, 6);
      expect(rwaToken.balance, 500.0);
      expect(rwaToken.formattedBalance, '500.00 PROP');
      expect(rwaToken.formattedPrice, '\$2.50');
      expect(rwaToken.formattedValue, '\$1.25K');
      expect(rwaToken.effectiveTokenStandard, TokenStandard.erc20);
      expect(rwaToken.networkKey, 'evm:42420');
    });

    test('CustomTokenDefinition scopes correctly to AssetChain chainId and networkKey', () {
      const custom = CustomTokenDefinition(
        symbol: 'GOLD',
        name: 'Tokenized Gold RWA',
        address: '0x9999999999999999999999999999999999999999',
        decimals: 18,
        networkKey: 'evm:42420',
        tokenStandard: TokenStandard.erc20,
        isCertified: false,
      );

      expect(custom.symbol, 'GOLD');
      expect(custom.name, 'Tokenized Gold RWA');
      expect(custom.address, '0x9999999999999999999999999999999999999999');
      expect(custom.decimals, 18);
      expect(custom.networkKey, 'evm:42420');
      expect(custom.tokenStandard, TokenStandard.erc20);

      final json = custom.toJson();
      expect(json['symbol'], 'GOLD');
      expect(json['networkKey'], 'evm:42420');
      expect(json['decimals'], 18);

      final revived = CustomTokenDefinition.fromJson(json);
      expect(revived.symbol, 'GOLD');
      expect(revived.networkKey, 'evm:42420');
      expect(revived.decimals, 18);
    });
  });

  group('AssetChain Token Details UI Integration', () {
    testWidgets('TokenDetailHeader renders for AssetChain native RWA token with chainId', (tester) async {
      const token = Token(
        symbol: 'RWA',
        name: 'Asset Chain',
        balance: 10.0,
        valueUsd: 0.0,
        changePercent24h: 0.0,
        decimals: 18,
        networkKey: 'evm:42420',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TokenDetailHeader(
              token: token,
              isFavorite: false,
              chainId: 42420,
              onBack: () {},
              onToggleFavorite: () {},
            ),
          ),
        ),
      );

      expect(find.text('Asset Chain'), findsOneWidget);
      expect(find.text('RWA'), findsOneWidget);
      expect(find.byType(TokenIcon), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TokenInfoTable renders token details (symbol, name, balance, decimals, contract address) accurately for AssetChain', (tester) async {
      const contract = '0x1234567890abcdef1234567890abcdef12345678';
      const token = Token(
        symbol: 'ASSET1',
        name: 'AssetChain Prime Token',
        contractAddress: contract,
        balance: 42.5,
        valueUsd: 85.0,
        priceUsd: 2.0,
        changePercent24h: 1.5,
        decimals: 8,
        networkKey: 'evm:42420',
      );

      final rows = [
        TokenInfoRowData(label: 'Name', value: token.name),
        TokenInfoRowData(label: 'Ticker', value: token.symbol),
        TokenInfoRowData(label: 'Network', value: 'Asset Chain'),
        TokenInfoRowData(label: 'Contract Address', value: contract),
        TokenInfoRowData(label: 'Decimals', value: '${token.decimals}'),
        TokenInfoRowData(label: 'Balance', value: token.formattedBalance),
        const TokenInfoRowData(label: 'Market Cap', value: '\$10M'),
        const TokenInfoRowData(label: 'Total Supply', value: '5,000,000'),
        const TokenInfoRowData(label: 'Circulating Supply', value: '2,500,000'),
        const TokenInfoRowData(label: 'Holders', value: '1,240'),
        const TokenInfoRowData(label: 'Created On', value: 'Nov 6, 2026'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TokenInfoTable(rows: rows),
            ),
          ),
        ),
      );

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('AssetChain Prime Token'), findsOneWidget);
      expect(find.text('Ticker'), findsOneWidget);
      expect(find.text('ASSET1'), findsOneWidget);
      expect(find.text('Network'), findsOneWidget);
      expect(find.text('Asset Chain'), findsOneWidget);
      expect(find.text('Contract Address'), findsOneWidget);
      expect(find.text(contract), findsOneWidget);
      expect(find.text('Decimals'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Balance'), findsOneWidget);
      expect(find.text('42.50 ASSET1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AssetChain Token Management Operations', () {
    test('TokenVisibilityService can hide and unhide tokens on AssetChain chainId 42420', () async {
      final visibilityService = TokenVisibilityService();
      const token = Token(
        symbol: 'CUSTOM',
        name: 'Custom Asset',
        contractAddress: '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
        balance: 10,
        valueUsd: 10,
        changePercent24h: 0,
        networkKey: 'evm:42420',
      );

      final initialHidden = await visibilityService.loadHiddenTokens(42420);
      expect(initialHidden, isEmpty);

      // Hide token on AssetChain
      await visibilityService.setTokenHidden(42420, token, true);
      final hiddenAfterHide = await visibilityService.loadHiddenTokens(42420);
      expect(visibilityService.isHidden(42420, token), isTrue);
      expect(TokenVisibilityUtils.contains(hiddenAfterHide, token), isTrue);

      // Unhide token on AssetChain
      await visibilityService.setTokenHidden(42420, token, false);
      final hiddenAfterUnhide = await visibilityService.loadHiddenTokens(42420);
      expect(visibilityService.isHidden(42420, token), isFalse);
      expect(TokenVisibilityUtils.contains(hiddenAfterUnhide, token), isFalse);
    });

    test('TokenTrustUtils classifies AssetChain tokens according to standard rules', () {
      const nativeRwa = Token(
        symbol: 'RWA',
        name: 'Asset Chain',
        balance: 1,
        valueUsd: 0,
        changePercent24h: 0,
        networkKey: 'evm:42420',
      );
      // Native token is always verified
      expect(TokenTrustUtils.levelFor(nativeRwa, chainId: 42420), TokenTrustLevel.verified);
      expect(TokenTrustUtils.label(nativeRwa, chainId: 42420), 'Verified');

      // Genuine certified token
      const certifiedToken = Token(
        symbol: 'VERIF',
        name: 'Verified Token',
        contractAddress: '0x1111111111111111111111111111111111111111',
        balance: 10,
        valueUsd: 10,
        changePercent24h: 0,
        isCertified: true,
        networkKey: 'evm:42420',
      );
      expect(TokenTrustUtils.levelFor(certifiedToken, chainId: 42420), TokenTrustLevel.verified);

      // Standard unverified token
      const unverifiedToken = Token(
        symbol: 'TEST',
        name: 'Test Token',
        contractAddress: '0x2222222222222222222222222222222222222222',
        balance: 10,
        valueUsd: 10,
        changePercent24h: 0,
        isCertified: false,
        networkKey: 'evm:42420',
      );
      expect(TokenTrustUtils.levelFor(unverifiedToken, chainId: 42420), TokenTrustLevel.unverified);
      expect(TokenTrustUtils.label(unverifiedToken, chainId: 42420), 'Unverified');

      // Spoofed protected stablecoin symbol on AssetChain
      const spoofedUsdt = Token(
        symbol: 'USDT',
        name: 'Fake Tether',
        contractAddress: '0xdeaddeaddeaddeaddeaddeaddeaddeaddeaddead',
        balance: 100,
        valueUsd: 100,
        changePercent24h: 0,
        networkKey: 'evm:42420',
      );
      expect(TokenTrustUtils.levelFor(spoofedUsdt, chainId: 42420), TokenTrustLevel.suspicious);
      expect(TokenTrustUtils.label(spoofedUsdt, chainId: 42420), 'Suspicious stablecoin');
      expect(TokenTrustUtils.blocksDestination(spoofedUsdt, chainId: 42420), isTrue);
    });

    testWidgets('ManagedTokenTile renders AssetChain token with toggle and actions cleanly', (tester) async {
      const token = Token(
        symbol: 'ASSET',
        name: 'AssetChain Token',
        contractAddress: '0x3333333333333333333333333333333333333333',
        balance: 200,
        valueUsd: 400,
        changePercent24h: 0,
        decimals: 18,
        networkKey: 'evm:42420',
      );

      bool toggleState = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManagedTokenTile(
              token: token,
              isEnabled: toggleState,
              isNative: false,
              isProcessing: false,
              chainId: 42420,
              onToggleChanged: (val) {
                toggleState = val;
              },
              trustLabel: 'Unverified',
              isSuspicious: false,
              isVerified: false,
            ),
          ),
        ),
      );

      expect(find.text('AssetChain Token'), findsOneWidget);
      expect(find.text('ASSET'), findsOneWidget);
      expect(find.byType(CupertinoSwitch), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ContractImportCard renders with AssetChain chainId without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContractImportCard(
              isLoading: false,
              onAdd: () {},
              tokenName: 'Real World Asset Token',
              tokenSymbol: 'RWAT',
              tokenImageUrl: null,
              chainId: 42420,
            ),
          ),
        ),
      );

      expect(find.text('Real World Asset Token'), findsOneWidget);
      expect(find.text('RWAT'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('BalanceSummaryCard renders for AssetChain native and custom tokens with chainId 42420', (tester) async {
      const nativeRwa = Token(
        symbol: 'RWA',
        name: 'Asset Chain',
        balance: 50.0,
        valueUsd: 100.0,
        priceUsd: 2.0,
        changePercent24h: 0.0,
        networkKey: 'evm:42420',
      );

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BalanceSummaryCard(
              token: nativeRwa,
              chainId: 42420,
            ),
          ),
        ),
      );

      expect(find.text('Asset Chain'), findsOneWidget);
      expect(find.text('50.00 RWA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('AssetChain token with 0 decimals formats balance cleanly without exceptions', () {
      const zeroDecimalToken = Token(
        symbol: 'LAND',
        name: 'Fractional Real Estate',
        contractAddress: '0x4444444444444444444444444444444444444444',
        balance: 10,
        valueUsd: 500,
        decimals: 0,
        changePercent24h: 0,
        networkKey: 'evm:42420',
      );

      expect(zeroDecimalToken.decimals, 0);
      expect(zeroDecimalToken.formattedBalance, '10.00 LAND');
    });

    test('Rapid consecutive visibility toggling on AssetChain leaves deterministic state', () async {
      final visibilityService = TokenVisibilityService();
      const token = Token(
        symbol: 'RAPID',
        name: 'Rapid Toggle Token',
        contractAddress: '0x5555555555555555555555555555555555555555',
        balance: 1,
        valueUsd: 1,
        changePercent24h: 0,
        networkKey: 'evm:42420',
      );

      for (int i = 0; i < 10; i++) {
        await visibilityService.setTokenHidden(42420, token, i % 2 == 0);
      }

      // After 10 iterations (0..9), i=9 is odd -> hidden = false
      expect(visibilityService.isHidden(42420, token), isFalse);
    });

    test('Network scoping correctly resolves AssetChain network name and matches token by networkKey', () {
      final chain = BlockchainCatalog.findChain(42420);
      expect(chain, isNotNull);
      expect(chain!.name, 'Asset Chain');

      final assetChainToken = const Token(
        symbol: 'RWA',
        name: 'Asset Chain',
        balance: 100,
        valueUsd: 200,
        changePercent24h: 0,
        networkKey: 'evm:42420',
      );

      final otherChainToken = const Token(
        symbol: 'RWA',
        name: 'Other Chain RWA',
        balance: 5,
        valueUsd: 10,
        changePercent24h: 0,
        networkKey: 'evm:1',
      );

      final tokenList = [otherChainToken, assetChainToken];

      // Network-aware lookup matches exact network
      final matched = tokenList.firstWhere(
        (t) =>
            t.symbol == 'RWA' &&
            t.networkKey?.trim().toLowerCase() == 'evm:42420',
      );

      expect(matched.name, 'Asset Chain');
      expect(matched.balance, 100);
      expect(matched.networkKey, 'evm:42420');
    });

    test('TokenDetailScreen explorer URL resolution scopes accurately to AssetChain explorer for chainId 42420', () {
      const contract = '0x1234567890abcdef1234567890abcdef12345678';
      const token = Token(
        symbol: 'PROP',
        name: 'Real Estate Property Token',
        contractAddress: contract,
        balance: 50.0,
        valueUsd: 100.0,
        changePercent24h: 0.0,
        networkKey: 'evm:42420',
      );

      final contractExplorerUrl = TokenDetailScreen.resolveExplorerUrl(token);
      expect(
        contractExplorerUrl,
        'https://scan.assetchain.org/token/0x1234567890abcdef1234567890abcdef12345678',
      );

      final networkExplorerUrl = TokenDetailScreen.resolveNetworkExplorerUrl(token);
      expect(networkExplorerUrl, 'https://scan.assetchain.org');

      const nativeToken = Token(
        symbol: 'RWA',
        name: 'Asset Chain',
        balance: 10.0,
        valueUsd: 20.0,
        changePercent24h: 0.0,
        networkKey: 'evm:42420',
      );
      final nativeExplorerUrl = TokenDetailScreen.resolveExplorerUrl(nativeToken);
      expect(nativeExplorerUrl, 'https://scan.assetchain.org');
    });

    testWidgets('TokenDetailScreen displays contract address, copy button, and explorer button for AssetChain token', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final blockchain = BlockchainService();
      blockchain.setActiveChainByChainId(42420);
      final shellController = AppShellController();

      const contract = '0x1234567890abcdef1234567890abcdef12345678';
      const token = Token(
        symbol: 'PROP',
        name: 'Property RWA',
        contractAddress: contract,
        balance: 15.0,
        valueUsd: 30.0,
        changePercent24h: 0.0,
        decimals: 18,
        imageUrl: 'https://example.com/prop.png',
        coinGeckoId: 'property-rwa',
        networkKey: 'evm:42420',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BlockchainService>.value(value: blockchain),
            ChangeNotifierProvider<AppShellController>.value(value: shellController),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                settings: const RouteSettings(
                  name: '/token-detail',
                  arguments: token,
                ),
                builder: (_) => const TokenDetailScreen(),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Property RWA'), findsWidgets);
      expect(find.text('PROP'), findsWidgets);
      expect(find.text('Contract Address'), findsOneWidget);

      final copyButton = find.byIcon(Icons.copy);
      final explorerButtons = find.byIcon(Icons.open_in_new);
      expect(copyButton, findsOneWidget);
      expect(explorerButtons, findsWidgets);

      await tester.ensureVisible(copyButton);
      await tester.pump();
      await tester.tap(explorerButtons.last);
      await tester.pump();
      expect(
        shellController.pendingDiscoverUrl,
        'https://scan.assetchain.org/token/0x1234567890abcdef1234567890abcdef12345678',
      );

      await tester.tap(copyButton);
      await tester.pump();
      final clipboardData = await Clipboard.getData('text/plain');
      expect(clipboardData?.text, contract);
      expect(tester.takeException(), isNull);
      // Settle the 1-second toast dismissal timer created by Fluttertoast
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('ReceiveTokenScreen automatically switches network to AssetChain when token has evm:42420', (tester) async {
      final blockchain = BlockchainService();
      // Start deliberately on Ethereum (chainId 1)
      blockchain.setActiveChainByChainId(1);
      expect(blockchain.activeNetworkKey, 'evm:1');

      const rwaToken = Token(
        symbol: 'RWA',
        name: 'Asset Chain',
        balance: 100.0,
        valueUsd: 200.0,
        changePercent24h: 0.0,
        decimals: 18,
        networkKey: 'evm:42420',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<BlockchainService>.value(
          value: blockchain,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                settings: const RouteSettings(
                  name: '/receive-token',
                  arguments: rwaToken,
                ),
                builder: (_) => const ReceiveTokenScreen(),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Active network was automatically synchronized to AssetChain
      expect(blockchain.activeNetworkKey, 'evm:42420');
      expect(find.text('RWA'), findsWidgets);
      expect(find.textContaining('Asset Chain'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SendTokenScreen switches active network to AssetChain when navigated with AssetChain token', (tester) async {
      final blockchain = BlockchainService();
      // Start deliberately on Ethereum (chainId 1)
      blockchain.setActiveChainByChainId(1);
      expect(blockchain.activeNetworkKey, 'evm:1');

      final currency = CurrencyController();

      const rwaToken = Token(
        symbol: 'RWA',
        name: 'Asset Chain',
        balance: 45.0,
        valueUsd: 90.0,
        changePercent24h: 0.0,
        decimals: 18,
        networkKey: 'evm:42420',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BlockchainService>.value(value: blockchain),
            ChangeNotifierProvider<CurrencyController>.value(value: currency),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                settings: const RouteSettings(
                  name: '/send-token',
                  arguments: rwaToken,
                ),
                builder: (_) => const SendTokenScreen(),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Active network was synchronized to Asset Chain
      expect(blockchain.activeNetworkKey, 'evm:42420');

      // Advance past receiver step to view token selector and amount
      await tester.enterText(
        find.byType(TextField).first,
        '0x1111111111111111111111111111111111111111',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('RWA'), findsWidgets);
      expect(find.textContaining('45'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TokenDetailScreen automatically aligns active network to evm:42420 when opened with AssetChain token', (tester) async {
      final blockchain = BlockchainService();
      // Start deliberately on Ethereum (chainId 1)
      blockchain.setActiveChainByChainId(1);
      expect(blockchain.activeNetworkKey, 'evm:1');

      const rwaToken = Token(
        symbol: 'RWA',
        name: 'Asset Chain',
        balance: 10.0,
        valueUsd: 20.0,
        changePercent24h: 0.0,
        decimals: 18,
        imageUrl: 'https://scan.assetchain.org/assets/configs/network_icon.png',
        coinGeckoId: 'assetchain',
        networkKey: 'evm:42420',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<BlockchainService>.value(
          value: blockchain,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                settings: const RouteSettings(
                  name: '/token-detail',
                  arguments: rwaToken,
                ),
                builder: (_) => const TokenDetailScreen(),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Active network was synchronized to Asset Chain
      expect(blockchain.activeNetworkKey, 'evm:42420');
      expect(find.text('Asset Chain'), findsWidgets);
      expect(find.text('RWA'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    test('Custom token management on AssetChain chainId 42420 persists correctly in BlockchainService', () async {
      final blockchain = BlockchainService();
      blockchain.setActiveChainByChainId(42420);

      const customDef = CustomTokenDefinition(
        symbol: 'RWAGOLD',
        name: 'RWA Gold Token',
        address: '0x8888888888888888888888888888888888888888',
        decimals: 18,
        networkKey: 'evm:42420',
        tokenStandard: TokenStandard.erc20,
      );

      final added = await blockchain.addCustomToken(
        chainId: 42420,
        token: customDef,
      );
      expect(added, isTrue);

      final customs = blockchain.customTokensForActiveChain;
      expect(customs.any((c) => c.symbol == 'RWAGOLD' && c.address == '0x8888888888888888888888888888888888888888'), isTrue);

      // Verify duplicate addition is rejected safely
      final duplicate = await blockchain.addCustomToken(
        chainId: 42420,
        token: customDef,
      );
      expect(duplicate, isFalse);

      // Verify removal
      await blockchain.removeCustomToken(42420, '0x8888888888888888888888888888888888888888');
      final customsAfterRemove = blockchain.customTokensForActiveChain;
      expect(customsAfterRemove.any((c) => c.address == '0x8888888888888888888888888888888888888888'), isFalse);
    });

    test('Cross-chain token matching strictly respects network scoping and rejects collisions', () {
      const polygonUsdt = Token(
        symbol: 'USDT',
        name: 'Tether USD (Polygon)',
        contractAddress: '0x1111111111111111111111111111111111111111',
        balance: 500,
        valueUsd: 500,
        changePercent24h: 0.0,
        networkKey: 'evm:137',
      );

      const ethUsdt = Token(
        symbol: 'USDT',
        name: 'Tether USD (Ethereum)',
        contractAddress: '0xdac17f958d2ee523a2206206994597c13d831ec7',
        balance: 250,
        valueUsd: 250,
        changePercent24h: 0.0,
        networkKey: 'evm:1',
      );

      final tokenList = [polygonUsdt, ethUsdt];

      const targetNetwork = 'evm:42420';
      Token? matched;
      for (final t in tokenList) {
        if (t.symbol == 'USDT' &&
            (t.networkKey == null ||
                t.networkKey?.trim().toLowerCase() == targetNetwork)) {
          matched = t;
          break;
        }
      }
      expect(matched, isNull);
    });

    testWidgets('SendTokenScreen preserves AssetChain custom token when navigated from non-EVM Bitcoin family', (tester) async {
      final blockchain = BlockchainService();
      // Configure wallet scope and Bitcoin capability to enable Bitcoin family
      blockchain.setActiveWalletContext(
        address: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
        supportedFamilies: {ChainFamily.bitcoin, ChainFamily.evm},
      );
      await blockchain.setEnabledFamilies({ChainFamily.bitcoin, ChainFamily.evm});
      blockchain.configureBitcoinAvailability(available: true);
      blockchain.setActiveNetworkKey('bitcoin:mainnet');
      expect(blockchain.activeFamily, ChainFamily.bitcoin);

      final currency = CurrencyController();

      const customToken = Token(
        symbol: 'RWAX',
        name: 'AssetChain Custom Token',
        contractAddress: '0xabcdef1234567890abcdef1234567890abcdef12',
        balance: 55.0,
        valueUsd: 110.0,
        changePercent24h: 0.0,
        decimals: 18,
        networkKey: 'evm:42420',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BlockchainService>.value(value: blockchain),
            ChangeNotifierProvider<CurrencyController>.value(value: currency),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                settings: const RouteSettings(
                  name: '/send-token',
                  arguments: customToken,
                ),
                builder: (_) => const SendTokenScreen(),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Network transitioned cleanly to AssetChain EVM
      expect(blockchain.activeNetworkKey, 'evm:42420');
      expect(blockchain.activeFamily, ChainFamily.evm);

      // Advance past receiver step to view token selector and amount
      await tester.enterText(
        find.byType(TextField).first,
        '0x1111111111111111111111111111111111111111',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // The selected token is still RWAX, not wiped to native RWA!
      expect(find.text('RWAX'), findsWidgets);
      expect(find.textContaining('55'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    test('TokenDetailScreen preserves 0 decimals when merging resolved metadata', () {
      const current = Token(
        symbol: 'PROP',
        name: 'Property',
        contractAddress: '0x1234567890abcdef1234567890abcdef12345678',
        balance: 10,
        valueUsd: 20,
        changePercent24h: 0,
        decimals: 18,
        networkKey: 'evm:42420',
      );

      const resolved = CustomTokenDefinition(
        symbol: 'PROP',
        name: 'Real Estate Property',
        address: '0x1234567890abcdef1234567890abcdef12345678',
        decimals: 0,
        networkKey: 'evm:42420',
        imageUrl: 'https://scan.assetchain.org/token.png',
      );

      final merged = Token(
        symbol: resolved.symbol.isNotEmpty ? resolved.symbol : current.symbol,
        name: resolved.name.isNotEmpty ? resolved.name : current.name,
        contractAddress: current.contractAddress,
        balance: current.balance,
        valueUsd: current.valueUsd,
        priceUsd: current.priceUsd,
        changePercent24h: current.changePercent24h,
        decimals: resolved.decimals >= 0 ? resolved.decimals : current.decimals,
        imageUrl: (resolved.imageUrl?.trim().isNotEmpty ?? false)
            ? resolved.imageUrl
            : current.imageUrl,
        coinGeckoId: (resolved.coinGeckoId?.trim().isNotEmpty ?? false)
            ? resolved.coinGeckoId
            : current.coinGeckoId,
        isCertified: current.isCertified,
        networkKey: current.networkKey ?? resolved.networkKey,
        tokenStandard: current.tokenStandard != TokenStandard.erc20
            ? current.tokenStandard
            : resolved.tokenStandard,
      );

      expect(merged.decimals, 0);
      expect(merged.name, 'Real Estate Property');
      expect(merged.imageUrl, 'https://scan.assetchain.org/token.png');
      expect(merged.networkKey, 'evm:42420');
    });

    test('TokenDetailScreen.resolveExplorerUrl and resolveNetworkExplorerUrl support EVM AssetChain, Solana, Tron, and Bitcoin', () {
      final assetChainToken = Token(
        symbol: 'PROP',
        name: 'Property',
        contractAddress: '0x1234567890abcdef1234567890abcdef12345678',
        balance: 10,
        valueUsd: 20,
        changePercent24h: 0,
        decimals: 18,
        networkKey: 'evm:42420',
      );
      expect(
        TokenDetailScreen.resolveNetworkExplorerUrl(assetChainToken),
        'https://scan.assetchain.org',
      );
      expect(
        TokenDetailScreen.resolveExplorerUrl(assetChainToken),
        'https://scan.assetchain.org/token/0x1234567890abcdef1234567890abcdef12345678',
      );

      final assetChainTestnetToken = Token(
        symbol: 'TEST',
        name: 'Test Token',
        contractAddress: '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
        balance: 5,
        valueUsd: 0,
        changePercent24h: 0,
        decimals: 18,
        networkKey: 'evm:42421',
      );
      expect(
        TokenDetailScreen.resolveNetworkExplorerUrl(assetChainTestnetToken),
        'https://scan-testnet.assetchain.org',
      );
      expect(
        TokenDetailScreen.resolveExplorerUrl(assetChainTestnetToken),
        'https://scan-testnet.assetchain.org/token/0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
      );

      final solanaToken = Token(
        symbol: 'USDC',
        name: 'USD Coin',
        contractAddress: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
        balance: 100,
        valueUsd: 100,
        changePercent24h: 0,
        decimals: 6,
        networkKey: 'solana:mainnet',
      );
      expect(
        TokenDetailScreen.resolveNetworkExplorerUrl(solanaToken),
        'https://explorer.solana.com',
      );
      expect(
        TokenDetailScreen.resolveExplorerUrl(solanaToken),
        'https://explorer.solana.com/address/EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      );

      final tronToken = Token(
        symbol: 'USDT',
        name: 'Tether USD',
        contractAddress: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        balance: 50,
        valueUsd: 50,
        changePercent24h: 0,
        decimals: 6,
        networkKey: 'tron:mainnet',
      );
      expect(
        TokenDetailScreen.resolveNetworkExplorerUrl(tronToken),
        'https://tronscan.org',
      );
      expect(
        TokenDetailScreen.resolveExplorerUrl(tronToken),
        'https://tronscan.org/#/token20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
      );

      final bitcoinToken = Token(
        symbol: 'BTC',
        name: 'Bitcoin',
        contractAddress: null,
        balance: 0.5,
        valueUsd: 30000,
        changePercent24h: 0,
        decimals: 8,
        networkKey: 'bitcoin:mainnet',
      );
      expect(
        TokenDetailScreen.resolveNetworkExplorerUrl(bitcoinToken),
        'https://mempool.space',
      );
      expect(
        TokenDetailScreen.resolveExplorerUrl(bitcoinToken),
        'https://mempool.space',
      );
    });

    testWidgets('Custom AssetChain token with native symbol RWA is not overwritten by native token', (tester) async {
      final blockchain = BlockchainService();
      await blockchain.init();
      blockchain.setActiveNetworkKey('evm:42420');

      // Custom token deployed with contract address but symbol RWA
      const customRwaToken = Token(
        symbol: 'RWA',
        name: 'Custom RWA ERC20',
        contractAddress: '0x9999999999999999999999999999999999999999',
        balance: 42.0,
        valueUsd: 84.0,
        changePercent24h: 0.0,
        decimals: 18,
        networkKey: 'evm:42420',
        tokenStandard: TokenStandard.erc20,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BlockchainService>.value(value: blockchain),
            ChangeNotifierProvider<AppShellController>(
              create: (_) => AppShellController(),
            ),
            ChangeNotifierProvider<CurrencyController>(
              create: (_) => CurrencyController(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                settings: const RouteSettings(
                  name: '/token-detail',
                  arguments: customRwaToken,
                ),
                builder: (_) => const TokenDetailScreen(),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The screen should display the Custom token name (in header and info table) and contract address,
      // NOT the native Asset Chain token!
      expect(find.text('Custom RWA ERC20'), findsWidgets);
      expect(find.text('0x9999...9999'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
