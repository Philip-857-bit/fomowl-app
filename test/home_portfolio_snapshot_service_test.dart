import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/screens/home/home_portfolio_data.dart';
import 'package:fomowl_wallet/screens/home/home_portfolio_snapshot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'does not replace a funded snapshot with an empty partial refresh',
    () async {
      final service = HomePortfolioSnapshotService();
      final funded = _snapshot(
        tokens: const [
          Token(
            symbol: 'USDT',
            name: 'Tether',
            balance: 4.37,
            valueUsd: 4.37,
            changePercent24h: 0,
          ),
        ],
      );
      await service.saveSnapshot(funded);

      await service.saveSnapshot(
        _snapshot(tokens: const [], partialFailure: true),
      );

      final loaded = await service.loadSnapshot('0xabc');
      expect(loaded, isNotNull);
      expect(loaded!.sections.single.tokens.single.symbol, 'USDT');
      expect(loaded.sections.single.tokens.single.balance, 4.37);
    },
  );
}

HomeAggregatedPortfolioSnapshot _snapshot({
  required List<Token> tokens,
  bool partialFailure = false,
}) {
  return HomeAggregatedPortfolioSnapshot(
    walletAddress: '0xabc',
    sections: [
      HomePortfolioSection(
        chain: const EvmChain(
          name: 'BNB Smart Chain',
          symbol: 'BNB',
          chainId: 56,
          rpcUrl: 'https://rpc.example',
        ),
        tokens: tokens,
      ),
    ],
    timestamp: DateTime.utc(2026, 9, 11, 15, 50),
    partialFailure: partialFailure,
  );
}
