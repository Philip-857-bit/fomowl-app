import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/utils/evm_fee_estimation_utils.dart';

void main() {
  group('EvmFeeEstimationUtils', () {
    test('uses the requested amount when native estimation succeeds', () async {
      final requested = BigInt.from(500);
      final attempted = <BigInt>[];

      final result = await EvmFeeEstimationUtils.estimateTransfer(
        requestedAmount: requested,
        isNative: true,
        estimate: (amount) async {
          attempted.add(amount);
          return {'totalFeeWei': BigInt.from(21)};
        },
      );

      expect(attempted, [requested]);
      expect(result['totalFeeWei'], BigInt.from(21));
    });

    test('retries a failed native estimate with one wei', () async {
      final requested = BigInt.from(500);
      final attempted = <BigInt>[];

      final result = await EvmFeeEstimationUtils.estimateTransfer(
        requestedAmount: requested,
        isNative: true,
        estimate: (amount) async {
          attempted.add(amount);
          if (amount == requested) {
            throw StateError('insufficient funds for gas');
          }
          return {'totalFeeWei': BigInt.from(21)};
        },
      );

      expect(attempted, [requested, BigInt.one]);
      expect(result['totalFeeWei'], BigInt.from(21));
    });

    test('does not retry failed token-transfer estimation', () async {
      var attempts = 0;

      await expectLater(
        EvmFeeEstimationUtils.estimateTransfer(
          requestedAmount: BigInt.from(500),
          isNative: false,
          estimate: (_) async {
            attempts++;
            throw StateError('execution reverted');
          },
        ),
        throwsStateError,
      );

      expect(attempts, 1);
    });

    test('does not hide a genuine native contract revert', () async {
      var attempts = 0;

      await expectLater(
        EvmFeeEstimationUtils.estimateTransfer(
          requestedAmount: BigInt.from(500),
          isNative: true,
          estimate: (_) async {
            attempts++;
            throw StateError('execution reverted');
          },
        ),
        throwsStateError,
      );

      expect(attempts, 1);
    });
  });
}
