import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/services/runtime_config_service.dart';

void main() {
  test('missing runtime fields retain backward-compatible defaults', () {
    final snapshot = RuntimePolicySnapshot.fromJson(const {});

    expect(snapshot.maintenanceMode, 'off');
    expect(snapshot.portfolioEnabled, isTrue);
    expect(snapshot.legacyAggregateEnabled, isTrue);
  });

  test('parses maintenance and independent portfolio migration flags', () {
    final snapshot = RuntimePolicySnapshot.fromJson({
      'policy': {
        'maintenance': {'mode': 'full', 'message': 'Scheduled work'},
        'portfolio': {
          'enabled': true,
          'uiEnabled': false,
          'scopedBalancesEnabled': true,
          'legacyAggregateEnabled': false,
        },
      },
    });

    expect(snapshot.fullMaintenance, isTrue);
    expect(snapshot.portfolioUiEnabled, isFalse);
    expect(snapshot.legacyAggregateEnabled, isFalse);
  });

  test('equivalent policy snapshots do not look like runtime changes', () {
    expect(const RuntimePolicySnapshot(), const RuntimePolicySnapshot());
  });
}
