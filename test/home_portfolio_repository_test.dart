import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/screens/home/home_portfolio_data.dart';
import 'package:fomowl_wallet/screens/home/home_portfolio_repository.dart';
import 'package:fomowl_wallet/utils/value_formatter.dart';

void main() {
  const repository = HomePortfolioRepository();

  EvmChain chain({
    required String name,
    required String symbol,
    required int chainId,
  }) {
    return EvmChain(
      name: name,
      symbol: symbol,
      chainId: chainId,
      rpcUrl: 'https://rpc.example/$chainId',
    );
  }

  Token token({
    required String symbol,
    required String name,
    String? contractAddress,
    required double valueUsd,
    required double changePercent24h,
  }) {
    return Token(
      symbol: symbol,
      name: name,
      contractAddress: contractAddress,
      balance: valueUsd == 0 ? 0 : 1,
      valueUsd: valueUsd,
      changePercent24h: changePercent24h,
    );
  }

  group('HomePortfolioRepository', () {
    test(
      'aggregates sections across chains and sorts by subtotal descending',
      () async {
        final data = await repository.loadPortfolio(
          walletAddress: '0xabc',
          chains: [
            chain(name: 'Ethereum', symbol: 'ETH', chainId: 1),
            chain(name: 'BNB Smart Chain', symbol: 'BNB', chainId: 56),
          ],
          fetchTokens: (chainId) async {
            if (chainId == 1) {
              return [
                token(
                  symbol: 'ETH',
                  name: 'Ethereum',
                  contractAddress: '0xeth',
                  valueUsd: 100,
                  changePercent24h: 10,
                ),
              ];
            }
            return [
              token(
                symbol: 'BNB',
                name: 'BNB',
                contractAddress: '0xbnb',
                valueUsd: 250,
                changePercent24h: -20,
              ),
              token(
                symbol: 'USDT',
                name: 'Tether',
                contractAddress: '0xusdt',
                valueUsd: 50,
                changePercent24h: 0,
              ),
            ];
          },
          loadHiddenTokens: (_) async => <String>{},
        );

        expect(data.sections, hasLength(2));
        expect(data.sections.first.chain.chainId, 56);
        expect(
          ValueFormatter.doubleFromDecimal(data.sections.first.totalBalanceUsd),
          closeTo(300, 0.0001),
        );
        expect(
          ValueFormatter.doubleFromDecimal(data.metrics.totalBalanceUsd),
          closeTo(400, 0.0001),
        );
      },
    );

    test('excludes hidden tokens from portfolio sections and totals', () async {
      final data = await repository.loadPortfolio(
        walletAddress: '0xabc',
        chains: [chain(name: 'Ethereum', symbol: 'ETH', chainId: 1)],
        fetchTokens: (_) async => [
          token(
            symbol: 'ETH',
            name: 'Ethereum',
            contractAddress: '0xeth',
            valueUsd: 100,
            changePercent24h: 10,
          ),
          token(
            symbol: 'USDC',
            name: 'USD Coin',
            contractAddress: '0xhidden',
            valueUsd: 200,
            changePercent24h: 5,
          ),
        ],
        loadHiddenTokens: (_) async => {'0xhidden'},
      );

      expect(data.sections, hasLength(1));
      expect(data.sections.first.tokens, hasLength(1));
      expect(data.sections.first.tokens.first.symbol, 'ETH');
      expect(
        ValueFormatter.doubleFromDecimal(data.metrics.totalBalanceUsd),
        closeTo(100, 0.0001),
      );
    });

    test(
      'omits empty sections after filtering hidden and zero tokens',
      () async {
        final data = await repository.loadPortfolio(
          walletAddress: '0xabc',
          chains: [
            chain(name: 'Ethereum', symbol: 'ETH', chainId: 1),
            chain(name: 'Polygon', symbol: 'MATIC', chainId: 137),
          ],
          fetchTokens: (chainId) async {
            if (chainId == 1) {
              return [
                token(
                  symbol: 'ETH',
                  name: 'Ethereum',
                  contractAddress: '0xhidden',
                  valueUsd: 100,
                  changePercent24h: 0,
                ),
              ];
            }
            return const [];
          },
          loadHiddenTokens: (_) async => {'0xhidden'},
        );

        expect(data.sections, isEmpty);
        expect(data.metrics.totalBalanceUsd, Decimal.zero);
        expect(data.metrics.changeAmountUsd24h, Decimal.zero);
      },
    );

    test('filters preloaded remote sections with hidden tokens', () async {
      final data = await repository.filterSections(
        sections: [
          HomePortfolioSection(
            chain: chain(name: 'Ethereum', symbol: 'ETH', chainId: 1),
            tokens: [
              token(
                symbol: 'ETH',
                name: 'Ethereum',
                contractAddress: '0xeth',
                valueUsd: 100,
                changePercent24h: 10,
              ),
              token(
                symbol: 'USDC',
                name: 'USD Coin',
                contractAddress: '0xhidden',
                valueUsd: 200,
                changePercent24h: 0,
              ),
            ],
          ),
        ],
        loadHiddenTokens: (_) async => {'0xhidden'},
      );

      expect(data.sections, hasLength(1));
      expect(data.sections.single.tokens, hasLength(1));
      expect(data.sections.single.tokens.single.symbol, 'ETH');
    });
  });
}
