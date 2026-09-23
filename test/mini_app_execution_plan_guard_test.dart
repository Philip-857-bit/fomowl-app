import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/mini_apps/mini_app_host_screen.dart';

void main() {
  test('swap preflight checks CROSS input rather than stablecoin output', () {
    final spend = cashinPreflightTokenSpend({
      'kind': 'transaction',
      'expectedToken': '0x2222222222222222222222222222222222222222',
      'amountCeiling': '9500000000000000000000',
      'payload': {
        'transaction': {'to': '0x3333333333333333333333333333333333333333'},
        'sellToken': '0x1111111111111111111111111111111111111111',
        'sellAmount': '9500000000000000000000',
      },
    });

    expect(spend, (
      '0x1111111111111111111111111111111111111111',
      BigInt.parse('9500000000000000000000'),
    ));
  });

  test('initial preflight skips the future Paycrest stablecoin transfer', () {
    final steps = <Map<String, dynamic>>[
      {
        'kind': 'approval',
        'status': 'pending',
        'payload': {'type': 'erc20Approval'},
      },
      {
        'kind': 'transaction',
        'status': 'pending',
        'payload': {'sellToken': '0x1111111111111111111111111111111111111111'},
      },
      {
        'kind': 'transaction',
        'status': 'pending',
        'payload': {
          'type': 'erc20Transfer',
          'token': '0x2222222222222222222222222222222222222222',
        },
      },
    ];

    expect(cashinInitialPreflightStep(steps), same(steps[1]));
  });

  test('resumed submitted swap is not rechecked before confirmation', () {
    final steps = <Map<String, dynamic>>[
      {'kind': 'transaction', 'status': 'submitted'},
      {
        'kind': 'transaction',
        'status': 'pending',
        'payload': {'type': 'erc20Transfer'},
      },
    ];

    expect(cashinInitialPreflightStep(steps), isNull);
  });

  test('stablecoin transfer is checked when it becomes the current step', () {
    final spend = cashinPreflightTokenSpend({
      'kind': 'transaction',
      'expectedToken': '0x2222222222222222222222222222222222222222',
      'amountCeiling': '28000000',
      'payload': {
        'type': 'erc20Transfer',
        'token': '0x2222222222222222222222222222222222222222',
        'amount': '28000000',
      },
    });

    expect(spend, (
      '0x2222222222222222222222222222222222222222',
      BigInt.from(28000000),
    ));
  });

  test('approval allowance is not mistaken for a token spend', () {
    expect(
      cashinPreflightTokenSpend({
        'kind': 'approval',
        'expectedToken': '0x1111111111111111111111111111111111111111',
        'amountCeiling':
            '115792089237316195423570985008687907853269984665640564039457584007913129639935',
        'payload': {'type': 'erc20Approval'},
      }),
      isNull,
    );
  });

  test('swap spend above the signed ceiling is rejected', () {
    expect(
      () => cashinPreflightTokenSpend({
        'kind': 'transaction',
        'amountCeiling': '9000',
        'payload': {
          'transaction': {'to': '0x3333333333333333333333333333333333333333'},
          'sellToken': '0x1111111111111111111111111111111111111111',
          'sellAmount': '9500',
        },
      }),
      throwsFormatException,
    );
  });

  test('native input does not trigger an ERC20 balance lookup', () {
    expect(
      cashinPreflightTokenSpend({
        'kind': 'transaction',
        'amountCeiling': '1000000000000000',
        'payload': {
          'transaction': {'to': '0x3333333333333333333333333333333333333333'},
          'sellToken': '0x0000000000000000000000000000000000000000',
          'sellAmount': '1000000000000000',
        },
      }),
      isNull,
    );
  });

  test('expired plans cannot authorize a new wallet broadcast', () {
    final now = DateTime.utc(2026, 8, 8, 12);
    final plan = <String, dynamic>{
      'expiresAt': now.subtract(const Duration(seconds: 1)).toIso8601String(),
      'steps': [
        {'status': 'pending'},
      ],
    };

    expect(cashinExecutionPlanIsUsable(plan, now: now), isFalse);
  });

  test('expired plans are accepted only while polling submitted work', () {
    final now = DateTime.utc(2026, 8, 8, 12);
    final plan = <String, dynamic>{
      'expiresAt': now.subtract(const Duration(minutes: 1)).toIso8601String(),
      'steps': [
        {'status': 'submitted'},
      ],
    };

    expect(cashinExecutionPlanIsUsable(plan, now: now), isFalse);
    expect(
      cashinExecutionPlanIsUsable(
        plan,
        now: now,
        allowExpiredForSubmittedSteps: true,
      ),
      isTrue,
    );
  });

  test('direct settlement plans are presented as transfers', () {
    expect(
      cashinExecutionPlanIsTransfer({
        'routeType': 'direct_settlement',
        'settlementToken': '0x55d398326f99059ff775485246999027b3197955',
      }),
      isTrue,
    );
    expect(
      cashinExecutionPlanIsTransfer({'routeType': 'same_chain_swap'}),
      isFalse,
    );
    expect(
      cashinExecutionPlanIsTransfer({'routeType': 'cross_chain'}),
      isFalse,
    );
  });

  test('Burst permits only backend-defined contract selectors', () {
    expect(burstOperationAllowsSelector('approve', '095ea7b3'), isTrue);
    expect(burstOperationAllowsSelector('approve', 'a22cb465'), isTrue);
    expect(burstOperationAllowsSelector('create', 'a4be8afd'), isTrue);
    expect(burstOperationAllowsSelector('create', 'fc50ee32'), isTrue);
    expect(burstOperationAllowsSelector('push', '9ad88796'), isTrue);
    expect(burstOperationAllowsSelector('push', 'c78a7f37'), isTrue);
    expect(burstOperationAllowsSelector('set_root', '7cb64759'), isTrue);
    expect(burstOperationAllowsSelector('push', '095ea7b3'), isFalse);
    expect(burstOperationAllowsSelector('unknown', 'a4be8afd'), isFalse);
  });
}
