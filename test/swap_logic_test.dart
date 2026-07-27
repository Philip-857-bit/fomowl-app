import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/screens/swap/logic/limit_order_expiry.dart';
import 'package:fomowl_wallet/screens/swap/logic/limit_order_readiness.dart';
import 'package:fomowl_wallet/screens/swap/logic/non_evm_quote_coordinator.dart';
import 'package:fomowl_wallet/screens/swap/logic/limit_order_draft.dart';
import 'package:fomowl_wallet/screens/swap/logic/swap_price_cache.dart';
import 'package:fomowl_wallet/screens/swap/logic/swap_quote_state.dart';

void main() {
  group('non-EVM quote calculations', () {
    test('applies slippage floor in base units', () {
      final minimum = applySwapSlippageFloor('1000000', 50, 6);
      expect(minimum.raw, '995000');
      expect(minimum.formatted, '0.995');
    });

    test('clamps invalid slippage and malformed output safely', () {
      expect(applySwapSlippageFloor('100', 20000, 0).raw, '0');
      expect(applySwapSlippageFloor('invalid', 50, 6).raw, '0');
    });
  });

  group('limit order readiness', () {
    LimitOrderReadiness resolve({
      bool isBuyMode = false,
      bool isSubmitting = false,
      bool hasWallet = true,
      bool isNetworkSupported = true,
      bool hasTokenPair = true,
      bool hasDistinctTokens = true,
      bool requiresErc20Pair = true,
      bool hasErc20Pair = true,
      bool hasAmount = true,
      bool hasTargetPrice = true,
    }) => resolveLimitOrderReadiness(
      isBuyMode: isBuyMode,
      isSubmitting: isSubmitting,
      hasWallet: hasWallet,
      isNetworkSupported: isNetworkSupported,
      hasTokenPair: hasTokenPair,
      hasDistinctTokens: hasDistinctTokens,
      requiresErc20Pair: requiresErc20Pair,
      hasErc20Pair: hasErc20Pair,
      hasAmount: hasAmount,
      hasTargetPrice: hasTargetPrice,
    );

    test('prioritizes wallet and network blockers', () {
      expect(resolve(hasWallet: false).buttonLabel, 'Connect Wallet');
      expect(
        resolve(isNetworkSupported: false).buttonLabel,
        'Network Unsupported',
      );
    });

    test('uses side-specific amount and submission labels', () {
      expect(
        resolve(isBuyMode: true, hasAmount: false).buttonLabel,
        'Enter Max Spend',
      );
      expect(
        resolve(isBuyMode: true, isSubmitting: true).buttonLabel,
        'Submitting Buy...',
      );
    });

    test('reports a ready sell order', () {
      final readiness = resolve();
      expect(readiness.buttonLabel, 'Place Sell Order');
      expect(readiness.statusMessage, contains('no gas'));
    });
  });

  group('SwapQuoteState', () {
    test('reset clears provider-neutral quote metadata', () {
      final state = SwapQuoteState()
        ..requestId = 4
        ..isCalculating = true
        ..pricing = '1 BNB -> 700 USDT'
        ..statusMessage = 'Quoting'
        ..feeUsd = 1
        ..feeNative = 0.001
        ..platformFeeUsd = 0.5;

      state.reset();

      expect(state.requestId, 5);
      expect(state.pricing, isEmpty);
      expect(state.statusMessage, isNull);
      expect(state.feeUsd, 0);
      expect(state.feeNative, 0);
      expect(state.platformFeeUsd, 0);
    });

    test('reset can preserve request and status during refresh', () {
      final state = SwapQuoteState()
        ..requestId = 9
        ..statusMessage = 'Refreshing';

      state.reset(preserveRequestId: true, clearStatusMessage: false);

      expect(state.requestId, 9);
      expect(state.statusMessage, 'Refreshing');
      expect(state.beginRequest(), 10);
    });
  });

  group('LimitOrderDraft', () {
    test('suggested side cannot override a manual selection', () {
      final draft = LimitOrderDraft();
      expect(draft.applySuggestedSide(true), isTrue);
      expect(draft.isBuyMode, isTrue);

      expect(draft.selectSide(false), isTrue);
      expect(draft.hasManualSideSelection, isTrue);
      expect(draft.applySuggestedSide(true), isFalse);
      expect(draft.isBuyMode, isFalse);
    });

    test('changing side and adjustment direction reset adjustment', () {
      final draft = LimitOrderDraft()..selectedPriceAdjustment = 10;
      draft.selectSide(true);
      expect(draft.selectedPriceAdjustment, 0);

      draft.selectedPriceAdjustment = 5;
      draft.toggleAdjustmentDirection();
      expect(draft.isPositiveAdjustment, isTrue);
      expect(draft.selectedPriceAdjustment, 0);
    });

    test('non-custom expiry clears a stale custom date', () {
      final draft = LimitOrderDraft();
      final custom = DateTime(2026, 8, 4);
      draft.selectExpiry(LimitExpiryOption.custom, customDate: custom);
      expect(draft.customExpiryDate, custom);

      draft.selectExpiry(LimitExpiryOption.days7);
      expect(draft.customExpiryDate, isNull);
    });
  });

  group('SwapPriceCache', () {
    test('returns fresh values and evicts expired values', () {
      var now = DateTime.utc(2026, 7, 27, 12);
      final cache = SwapPriceCache(
        ttl: const Duration(minutes: 2),
        clock: () => now,
      );

      cache.putAll({'solana': 180});
      expect(cache.read('solana'), 180);

      now = now.add(const Duration(minutes: 3));
      expect(cache.read('solana'), isNull);
    });

    test('clear removes all cached values', () {
      final cache = SwapPriceCache();
      cache.putAll({'ethereum': 4000, 'binancecoin': 700});
      cache.clear();
      expect(cache.read('ethereum'), isNull);
      expect(cache.read('binancecoin'), isNull);
    });
  });

  group('limit order expiry', () {
    final now = DateTime.utc(2026, 7, 27, 12);

    test('resolves fixed durations from the supplied clock', () {
      expect(
        resolveLimitExpirySeconds(
          option: LimitExpiryOption.minutes15,
          now: now,
        ),
        now.add(const Duration(minutes: 15)).millisecondsSinceEpoch ~/ 1000,
      );
      expect(
        resolveLimitExpirySeconds(option: LimitExpiryOption.days7, now: now),
        now.add(const Duration(days: 7)).millisecondsSinceEpoch ~/ 1000,
      );
    });

    test('normalizes custom expiry to the selected day end', () {
      final custom = DateTime(2026, 8, 4, 9, 30);
      expect(
        resolveLimitExpirySeconds(
          option: LimitExpiryOption.custom,
          customDate: custom,
          now: now,
        ),
        DateTime(2026, 8, 4, 23, 59).millisecondsSinceEpoch ~/ 1000,
      );
      expect(
        limitExpiryLabel(LimitExpiryOption.custom, customDate: custom),
        '4/8/2026',
      );
    });

    test('OpenOcean duration is clamped to provider bounds', () {
      expect(
        resolveOpenOceanLimitExpiryMs(
          option: LimitExpiryOption.minutes15,
          now: now,
        ),
        const Duration(minutes: 15).inMilliseconds,
      );
      expect(limitExpiryLabel(LimitExpiryOption.never), 'Never');
    });
  });
}
