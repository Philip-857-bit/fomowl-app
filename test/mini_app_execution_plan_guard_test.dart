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
}
