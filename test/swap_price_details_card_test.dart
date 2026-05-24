import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/screens/swap/widgets/swap_price_details_card.dart';

void main() {
  group('resolveSwapPlatformFeeUsd', () {
    test('uses backend platform fee USD when present', () {
      expect(
        resolveSwapPlatformFeeUsd(
          platformFeeUsd: 1.23,
          platformFeePercent: 2.55,
          swapAmountUsd: 100,
        ),
        1.23,
      );
    });

    test('derives fiat fee from backend fee bps percent', () {
      expect(
        resolveSwapPlatformFeeUsd(
          platformFeeUsd: 0,
          platformFeePercent: 2.55,
          swapAmountUsd: 100,
        ),
        closeTo(2.55, 0.0001),
      );
    });
  });
}
