import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/utils/send_amount_utils.dart';

void main() {
  group('SendAmountUtils', () {
    test('calculates each percentage from the available base units', () {
      final balance = BigInt.from(1000);

      expect(SendAmountUtils.percentageOf(balance, 25), BigInt.from(250));
      expect(SendAmountUtils.percentageOf(balance, 50), BigInt.from(500));
      expect(SendAmountUtils.percentageOf(balance, 75), BigInt.from(750));
      expect(SendAmountUtils.percentageOf(balance, 100), balance);
    });

    test('reserves the network fee from a max native transfer', () {
      expect(
        SendAmountUtils.maxAfterFeeReserve(BigInt.from(1000), BigInt.from(125)),
        BigInt.from(875),
      );
    });

    test('returns zero when the balance cannot cover the fee reserve', () {
      expect(
        SendAmountUtils.maxAfterFeeReserve(BigInt.from(100), BigInt.from(100)),
        BigInt.zero,
      );
      expect(
        SendAmountUtils.maxAfterFeeReserve(BigInt.from(99), BigInt.from(100)),
        BigInt.zero,
      );
    });
  });
}
