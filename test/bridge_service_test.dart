import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/services/bridge_service.dart';

void main() {
  test('parseSteps preserves an EVM approval and deposit in order', () {
    final steps = BridgeService.parseSteps([
      {
        'id': 'approve',
        'description': 'Approve token',
        'items': [
          {
            'data': {
              'to': '0x1111111111111111111111111111111111111111',
              'data': '0x095ea7b3',
              'value': '0',
              'chainId': 137,
              'maxFeePerGas': '0x64',
              'maxPriorityFeePerGas': '10',
            },
          },
        ],
      },
      {
        'id': 'deposit',
        'description': 'Deposit token',
        'items': [
          {
            'data': {
              'to': '0x2222222222222222222222222222222222222222',
              'data': '0xabcdef',
              'value': '0',
              'chainId': 137,
            },
          },
        ],
      },
    ]);

    expect(steps, hasLength(2));
    expect(steps.map((step) => step.stepId), ['approve', 'deposit']);
    expect(steps.every((step) => step.chainId == 137), isTrue);
    expect(steps.first.maxFeePerGas, BigInt.from(100));
    expect(steps.first.maxPriorityFeePerGas, BigInt.from(10));
    expect(steps.every((step) => !step.isSolana), isTrue);
  });
}
