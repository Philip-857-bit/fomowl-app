import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomowl_wallet/services/runtime_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing runtime fields retain backward-compatible defaults', () {
    final snapshot = RuntimePolicySnapshot.fromJson(const {});

    expect(snapshot.maintenanceMode, 'off');
    expect(snapshot.portfolioEnabled, isTrue);
    expect(snapshot.legacyAggregateEnabled, isTrue);
    expect(snapshot.revision, 0);
    expect(snapshot.cashInEnabled, isFalse);
    expect(snapshot.transfersEnabled, isFalse);
  });

  test('string false feature flags fail closed', () {
    final snapshot = RuntimePolicySnapshot.fromJson({
      'policy': {
        'features': {'cashInEnabled': 'false', 'cashOutEnabled': 0},
      },
    });
    expect(snapshot.cashInEnabled, isFalse);
    expect(snapshot.cashOutEnabled, isFalse);
  });

  test('parses public revision without exposing provider budgets', () {
    final snapshot = RuntimePolicySnapshot.fromJson({
      'revision': 9,
      'policy': {
        'maintenance': {'mode': 'off', 'message': ''},
        'portfolio': {'enabled': true},
        'features': {'transfersEnabled': true},
        'balanceProviders': {'zerionDailyHardLimit': 2000},
      },
    });
    expect(snapshot.revision, 9);
    expect(snapshot.toJson()['policy'], isNot(contains('balanceProviders')));
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

  test('feature admission respects flags and read-only maintenance', () {
    const enabled = RuntimePolicySnapshot();
    expect(enabled.allows(RuntimeFeature.transfers), isTrue);
    expect(enabled.allows(RuntimeFeature.swaps), isTrue);
    expect(enabled.allows(RuntimeFeature.bridges), isTrue);
    expect(enabled.allows(RuntimeFeature.miniApps), isTrue);
    expect(enabled.allows(RuntimeFeature.cashIn), isTrue);
    expect(enabled.allows(RuntimeFeature.cashOut), isTrue);
    expect(enabled.allows(RuntimeFeature.bills), isTrue);
    expect(enabled.allows(RuntimeFeature.shop), isTrue);
    expect(enabled.allows(RuntimeFeature.legacySystem), isTrue);

    const readOnly = RuntimePolicySnapshot(maintenanceMode: 'read_only');
    expect(readOnly.allows(RuntimeFeature.transfers), isFalse);
    expect(readOnly.allows(RuntimeFeature.swaps), isFalse);
    expect(readOnly.allows(RuntimeFeature.bridges), isFalse);
    expect(readOnly.allows(RuntimeFeature.miniApps), isTrue);
    expect(readOnly.allows(RuntimeFeature.cashIn), isFalse);
    expect(readOnly.allows(RuntimeFeature.cashOut), isFalse);
    expect(readOnly.allows(RuntimeFeature.bills), isFalse);
    expect(readOnly.allows(RuntimeFeature.shop), isFalse);
    expect(readOnly.allows(RuntimeFeature.legacySystem), isFalse);

    const bridgeDisabled = RuntimePolicySnapshot(bridgesEnabled: false);
    expect(bridgeDisabled.allows(RuntimeFeature.swaps), isTrue);
    expect(bridgeDisabled.allows(RuntimeFeature.bridges), isFalse);
  });

  test('disabling swaps does not disable bridging', () {
    const snapshot = RuntimePolicySnapshot(swapsEnabled: false);
    expect(snapshot.allows(RuntimeFeature.swaps), isFalse);
    expect(snapshot.allows(RuntimeFeature.bridges), isTrue);
    expect(snapshot.allowsTradingScreen(limitSupported: false), isTrue);
  });

  test(
    'limit orders keep the trading screen available without swaps or bridges',
    () {
      const snapshot = RuntimePolicySnapshot(
        swapsEnabled: false,
        bridgesEnabled: false,
      );
      expect(snapshot.allowsTradingScreen(limitSupported: true), isTrue);
      expect(snapshot.allowsTradingScreen(limitSupported: false), isFalse);
      expect(
        const RuntimePolicySnapshot(
          maintenanceMode: 'read_only',
          swapsEnabled: false,
          bridgesEnabled: false,
        ).allowsTradingScreen(limitSupported: true),
        isFalse,
      );
    },
  );

  test('parses every OwlletPay and legacy runtime feature flag', () {
    final snapshot = RuntimePolicySnapshot.fromJson({
      'policy': {
        'features': {
          'cashInEnabled': false,
          'cashOutEnabled': false,
          'billsEnabled': false,
          'shopEnabled': false,
          'legacySystemEnabled': false,
        },
      },
    });

    expect(snapshot.cashInEnabled, isFalse);
    expect(snapshot.cashOutEnabled, isFalse);
    expect(snapshot.billsEnabled, isFalse);
    expect(snapshot.shopEnabled, isFalse);
    expect(snapshot.legacySystemEnabled, isFalse);
  });

  test('maps OwlletPay launch paths to their independent feature flags', () {
    expect(
      runtimeFeatureForMiniAppLaunch(
        'owllet_pay',
        'https://pay.owllet.app/deposit',
      ),
      RuntimeFeature.cashIn,
    );
    expect(
      runtimeFeatureForMiniAppLaunch(
        'owllet_pay',
        'https://pay.owllet.app/withdraw/quote',
      ),
      RuntimeFeature.cashOut,
    );
    expect(
      runtimeFeatureForMiniAppLaunch(
        'owllet_pay',
        'https://pay.owllet.app/pay-bills/data',
      ),
      RuntimeFeature.bills,
    );
    expect(
      runtimeFeatureForMiniAppLaunch(
        'owllet_pay',
        'https://pay.owllet.app/shop/products',
      ),
      RuntimeFeature.shop,
    );
    expect(
      runtimeFeatureForMiniAppLaunch('owllet_pay', null),
      RuntimeFeature.miniApps,
    );
    expect(
      runtimeFeatureForMiniAppLaunch(
        'another_app',
        'https://example.com/deposit',
      ),
      RuntimeFeature.miniApps,
    );
  });

  test('hydrate publishes a valid persisted policy exactly once', () async {
    SharedPreferences.setMockInitialValues({
      'owllet.runtime_policy.last_good.v1': jsonEncode({
        'revision': 7,
        'persistedAt': DateTime.now().toUtc().toIso8601String(),
        'policy': {
          'maintenance': {'mode': 'off', 'message': ''},
          'portfolio': {'enabled': true, 'uiEnabled': true},
        },
      }),
      'owllet.runtime_policy.etag.v1': 'W/"runtime-7-test"',
    });
    final service = RuntimeConfigService.forTesting();
    var notifications = 0;
    service.addListener(() => notifications += 1);

    await Future.wait([service.hydrate(), service.hydrate()]);

    expect(service.snapshot.revision, 7);
    expect(service.snapshot.fullMaintenance, isFalse);
    expect(notifications, 1);
  });

  test(
    'invalid persisted policy does not publish a stale etag state',
    () async {
      SharedPreferences.setMockInitialValues({
        'owllet.runtime_policy.last_good.v1': '{not-json',
        'owllet.runtime_policy.etag.v1': 'W/"stale"',
      });
      final service = RuntimeConfigService.forTesting();
      var notifications = 0;
      service.addListener(() => notifications += 1);

      await service.hydrate();

      expect(service.snapshot.fullMaintenance, isFalse);
      expect(service.snapshot.cashOutEnabled, isFalse);
      expect(notifications, 0);
    },
  );
}
