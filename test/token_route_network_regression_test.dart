import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/l10n/app_localizations.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/models/token_market_data.dart';
import 'package:fomowl_wallet/screens/wallet/receive_token_screen.dart';
import 'package:fomowl_wallet/screens/wallet/token_detail_screen.dart';
import 'package:fomowl_wallet/screens/wallet/widgets/token_detail/price_overview.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NetworkDataService extends BlockchainService {
  final marketIds = <String>[];
  final marketRequests = <Completer<TokenMarketData?>>[];
  bool deferMarket = false;
  bool deferMetadata = false;
  final metadataRequests = <Completer<CustomTokenDefinition?>>[];

  @override
  Future<CustomTokenDefinition?> detectTokenByContract(String address) async {
    if (deferMetadata) {
      final request = Completer<CustomTokenDefinition?>();
      metadataRequests.add(request);
      return request.future;
    }
    return CustomTokenDefinition(
      symbol: activeNetworkKey == 'evm:42420' ? 'PROP' : 'WRONG',
      name: activeNetworkKey == 'evm:42420' ? 'Property' : 'Wrong chain token',
      address: address,
      decimals: activeNetworkKey == 'evm:42420' ? 6 : 18,
      imageUrl: 'https://example.com/token.png',
      coinGeckoId: 'property',
      networkKey: activeNetworkKey,
    );
  }

  @override
  Future<TokenMarketData?> getTokenMarketData(String coinId) async {
    marketIds.add(coinId);
    if (deferMarket) {
      final request = Completer<TokenMarketData?>();
      marketRequests.add(request);
      return request.future;
    }
    return const TokenMarketData(priceUsd: 3000);
  }

  @override
  Future<TokenMarketData?> getBackendTokenMarketData(String address) async =>
      null;

  @override
  Future<List<double>> getPriceHistoryForTimeframe(
    String id,
    String timeframe,
  ) async => [];
}

Future<void> _open(
  WidgetTester tester,
  BlockchainService service,
  Token token,
  Widget screen,
) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider<BlockchainService>.value(
      value: service,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: RouteSettings(arguments: token),
          builder: (_) => screen,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const property = Token(
    symbol: 'PROP',
    name: 'Property',
    contractAddress: '0x1234567890abcdef1234567890abcdef12345678',
    balance: 12,
    valueUsd: 0,
    changePercent24h: 0,
    decimals: 6,
    networkKey: 'evm:42420',
  );

  testWidgets('network transition supersedes pending detail metadata', (
    tester,
  ) async {
    final service = _NetworkDataService()..deferMetadata = true;
    service.setActiveChainByChainId(42420);
    await _open(tester, service, property, const TokenDetailScreen());
    final oldest = service.metadataRequests.first;
    service.setActiveChainByChainId(1);
    await tester.pump();
    service.setActiveChainByChainId(42420);
    await tester.pump();
    expect(service.metadataRequests.length, 2);
    service.metadataRequests.last.complete(
      const CustomTokenDefinition(
        symbol: 'FRESH',
        name: 'Current metadata',
        address: '0x1234567890abcdef1234567890abcdef12345678',
        decimals: 6,
        networkKey: 'evm:42420',
        coinGeckoId: 'property',
        imageUrl: 'https://example.com/token.png',
      ),
    );
    await tester.pump();
    oldest.complete(
      const CustomTokenDefinition(
        symbol: 'STALE',
        name: 'Old metadata',
        address: '0x1234567890abcdef1234567890abcdef12345678',
        decimals: 18,
        networkKey: 'evm:42420',
      ),
    );
    await tester.pump();
    expect(find.text('Old metadata'), findsNothing);
    expect(find.text('FRESH'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cross-network receive preserves the requested ERC20', (
    tester,
  ) async {
    final service = BlockchainService();
    service.setActiveChainByChainId(1);
    await _open(tester, service, property, const ReceiveTokenScreen());
    expect(service.activeNetworkKey, 'evm:42420');
    expect(find.text('PROP'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail metadata is fetched from the token network', (
    tester,
  ) async {
    final service = _NetworkDataService();
    service.setActiveChainByChainId(1);
    await _open(tester, service, property, const TokenDetailScreen());
    expect(find.text('Wrong chain token'), findsNothing);
    expect(find.text('PROP'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native RWA never inherits Ethereum market data', (tester) async {
    final service = _NetworkDataService();
    service.setActiveChainByChainId(1);
    const rwa = Token(
      symbol: 'RWA',
      name: 'Asset Chain',
      balance: 1,
      valueUsd: 0,
      changePercent24h: 0,
      networkKey: 'evm:42420',
    );
    await _open(tester, service, rwa, const TokenDetailScreen());
    expect(service.marketIds, isEmpty);
    expect(find.textContaining('3,000'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('older detail market response cannot replace newer data', (
    tester,
  ) async {
    final service = _NetworkDataService()..deferMarket = true;
    service.setActiveChainByChainId(42420);
    await _open(
      tester,
      service,
      property.copyWith(
        coinGeckoId: 'property',
        imageUrl: 'https://example.com/token.png',
      ),
      const TokenDetailScreen(),
    );
    final oldest = service.marketRequests.first;
    service.setActiveChainByChainId(1);
    await tester.pump();
    service.setActiveChainByChainId(42420);
    await tester.pump();
    service.marketRequests.last.complete(const TokenMarketData(priceUsd: 2));
    await tester.pump();
    oldest.complete(const TokenMarketData(priceUsd: 3000));
    await tester.pump();
    expect(
      tester.widget<PriceOverview>(find.byType(PriceOverview)).priceText,
      r'$2.00',
    );
    for (final request in service.marketRequests) {
      if (!request.isCompleted) request.complete(null);
    }
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
