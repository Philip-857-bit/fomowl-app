typedef EvmFeeEstimate = Future<Map<String, dynamic>> Function(BigInt amount);

class EvmFeeEstimationUtils {
  EvmFeeEstimationUtils._();

  static Future<Map<String, dynamic>> estimateTransfer({
    required BigInt requestedAmount,
    required bool isNative,
    required EvmFeeEstimate estimate,
  }) async {
    try {
      return await estimate(requestedAmount);
    } catch (error) {
      if (!isNative ||
          requestedAmount == BigInt.one ||
          !_isBalanceRelatedFailure(error)) {
        rethrow;
      }
      return estimate(BigInt.one);
    }
  }

  static bool _isBalanceRelatedFailure(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('insufficient funds') ||
        message.contains('insufficient balance') ||
        message.contains('funds for gas') ||
        message.contains('gas required exceeds allowance');
  }
}
