import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/mini_apps/mini_app_host_screen.dart';

void main() {
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
