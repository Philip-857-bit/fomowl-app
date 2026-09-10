import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';

void main() {
  test(
    'getWalletTokenState returns empty default state when no cache exists',
    () {
      final service = BlockchainService();

      final state = service.getWalletTokenState(
        '0x0000000000000000000000000000000000000001',
      );

      expect(state.tokens, isEmpty);
      expect(state.source, 'none');
      expect(state.isLoading, isFalse);
      expect(state.isStale, isFalse);
      expect(state.message, isNull);
    },
  );

  test('WalletTokenState copyWith preserves unspecified fields', () {
    const original = WalletTokenState(
      tokens: [
        Token(
          symbol: 'OWL',
          name: 'FOMOwl',
          balance: 1,
          valueUsd: 1,
          changePercent24h: 0,
        ),
      ],
      source: 'cache',
      isLoading: false,
      isStale: true,
      message: 'cached',
    );

    final updated = original.copyWith(isLoading: true, source: 'live');

    expect(updated.tokens, original.tokens);
    expect(updated.source, 'live');
    expect(updated.isLoading, isTrue);
    expect(updated.isStale, isTrue);
    expect(updated.message, 'cached');
  });

  test('live price refresh accepts a recovered sub-micro token price', () {
    final shouldApply = BlockchainService.shouldApplyLivePriceUpdate(
      currentPrice: 0,
      nextPrice: 0.000000000689739,
      currentChange: 0,
      nextChange: 0,
    );

    expect(shouldApply, isTrue);
  });
}
