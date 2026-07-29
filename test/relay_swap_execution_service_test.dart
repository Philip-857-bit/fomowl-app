import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/services/relay_swap_execution_service.dart';

void main() {
  test('maps Relay DiffError reverts to transfer-fee guidance', () {
    const raw =
        'RPCError: execution reverted: '
        '0x9eea691b00000000000000000000000000000000000000000000000000000000'
        '0dd10eb100000000000000000000000000000000000000000000000000000000';

    expect(
      relaySwapExecutionErrorMessage(raw),
      'This token may charge a transfer fee that exceeds the current '
      'slippage tolerance. Increase slippage and try again.',
    );
  });

  test('keeps unrelated Relay execution failures generic', () {
    expect(
      relaySwapExecutionErrorMessage('RPC connection closed'),
      'Relay swap failed. Please try again.',
    );
  });
}
