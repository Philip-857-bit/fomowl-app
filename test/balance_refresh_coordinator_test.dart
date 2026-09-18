import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/balance_refresh_coordinator.dart';

void main() {
  setUp(resetBalanceRefreshCoordinatorForTest);

  test(
    'deduplicates in-flight refresh for the same wallet and network',
    () async {
      var runs = 0;
      Future<void> work(int _) async {
        runs += 1;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      await Future.wait([
        BalanceRefreshCoordinator.instance.runExclusive(
          wallet: '0xabc',
          networkKey: 'evm:1',
          reason: 'entry',
          work: work,
        ),
        BalanceRefreshCoordinator.instance.runExclusive(
          wallet: '0xabc',
          networkKey: 'evm:1',
          reason: 'entry',
          work: work,
        ),
      ]);
      expect(runs, 1);
    },
  );

  test(
    'wallet or network changes bump the generation so late results are rejected',
    () async {
      await BalanceRefreshCoordinator.instance.runExclusive(
        wallet: '0xabc',
        networkKey: 'evm:1',
        reason: 'entry',
        work: (_) async {},
      );
      final first = BalanceRefreshCoordinator.instance.generationFor(
        '0xabc',
        'evm:1',
      );
      BalanceRefreshCoordinator.instance.invalidate('0xabc', 'evm:56');
      expect(
        BalanceRefreshCoordinator.instance.isCurrent('0xabc', 'evm:1', first),
        isTrue,
      );
      BalanceRefreshCoordinator.instance.invalidate('0xabc', 'evm:1');
      expect(
        BalanceRefreshCoordinator.instance.isCurrent('0xabc', 'evm:1', first),
        isFalse,
      );
    },
  );

  test(
    'entry and resume reuse scoped cache while manual refresh bypasses it',
    () {
      expect(forceLocalScopedReadForReason('entry'), isFalse);
      expect(forceLocalScopedReadForReason('resume'), isFalse);
      expect(forceLocalScopedReadForReason('manual'), isTrue);
      expect(forceLocalScopedReadForReason('transaction'), isTrue);
    },
  );

  test('normalizes EVM wallet case but preserves Solana and Tron case', () {
    BalanceRefreshCoordinator.instance.invalidate('0xAbC', 'evm:1');
    expect(
      BalanceRefreshCoordinator.instance.generationFor('0xabc', 'EVM:1'),
      1,
    );

    BalanceRefreshCoordinator.instance.invalidate('SoLCase', 'solana:mainnet');
    expect(
      BalanceRefreshCoordinator.instance.generationFor(
        'solcase',
        'solana:mainnet',
      ),
      0,
    );

    BalanceRefreshCoordinator.instance.invalidate('TCase', 'tron:mainnet');
    expect(
      BalanceRefreshCoordinator.instance.generationFor('tcase', 'tron:mainnet'),
      0,
    );
  });
}
