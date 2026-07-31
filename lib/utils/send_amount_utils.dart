class SendAmountUtils {
  SendAmountUtils._();

  static BigInt percentageOf(BigInt balance, int percentage) {
    if (percentage < 0 || percentage > 100) {
      throw RangeError.range(percentage, 0, 100, 'percentage');
    }
    return (balance * BigInt.from(percentage)) ~/ BigInt.from(100);
  }

  static BigInt maxAfterFeeReserve(BigInt balance, BigInt feeReserve) {
    if (balance <= feeReserve) {
      return BigInt.zero;
    }
    return balance - feeReserve;
  }
}
