import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_environment.dart';
import 'http_client_service.dart';

class RuntimePolicySnapshot {
  const RuntimePolicySnapshot({
    this.maintenanceMode = 'off',
    this.maintenanceMessage = '',
    this.portfolioEnabled = true,
    this.portfolioUiEnabled = true,
    this.scopedBalancesEnabled = true,
    this.legacyAggregateEnabled = true,
  });

  final String maintenanceMode;
  final String maintenanceMessage;
  final bool portfolioEnabled;
  final bool portfolioUiEnabled;
  final bool scopedBalancesEnabled;
  final bool legacyAggregateEnabled;

  bool get fullMaintenance => maintenanceMode == 'full';
  bool get readOnly => maintenanceMode == 'read_only';

  @override
  bool operator ==(Object other) =>
      other is RuntimePolicySnapshot &&
      other.maintenanceMode == maintenanceMode &&
      other.maintenanceMessage == maintenanceMessage &&
      other.portfolioEnabled == portfolioEnabled &&
      other.portfolioUiEnabled == portfolioUiEnabled &&
      other.scopedBalancesEnabled == scopedBalancesEnabled &&
      other.legacyAggregateEnabled == legacyAggregateEnabled;

  @override
  int get hashCode => Object.hash(
    maintenanceMode,
    maintenanceMessage,
    portfolioEnabled,
    portfolioUiEnabled,
    scopedBalancesEnabled,
    legacyAggregateEnabled,
  );

  factory RuntimePolicySnapshot.fromJson(Map<String, dynamic> json) {
    final policy = json['policy'] is Map
        ? (json['policy'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final maintenance = policy['maintenance'] is Map
        ? (policy['maintenance'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final portfolio = policy['portfolio'] is Map
        ? (policy['portfolio'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    return RuntimePolicySnapshot(
      maintenanceMode: maintenance['mode']?.toString() ?? 'off',
      maintenanceMessage: maintenance['message']?.toString() ?? '',
      portfolioEnabled: portfolio['enabled'] is bool
          ? portfolio['enabled'] as bool
          : true,
      portfolioUiEnabled: portfolio['uiEnabled'] is bool
          ? portfolio['uiEnabled'] as bool
          : true,
      scopedBalancesEnabled: portfolio['scopedBalancesEnabled'] is bool
          ? portfolio['scopedBalancesEnabled'] as bool
          : true,
      legacyAggregateEnabled: portfolio['legacyAggregateEnabled'] is bool
          ? portfolio['legacyAggregateEnabled'] as bool
          : true,
    );
  }
}

class RuntimeConfigService extends ChangeNotifier {
  RuntimeConfigService._();

  static final RuntimeConfigService instance = RuntimeConfigService._();
  RuntimePolicySnapshot _snapshot = const RuntimePolicySnapshot();
  RuntimePolicySnapshot get snapshot => _snapshot;

  Future<void> refresh() async {
    try {
      final response = await HttpClientService().client
          .get(AppEnvironment.api('/runtime-config'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;
      final next = RuntimePolicySnapshot.fromJson(decoded);
      if (next != _snapshot) {
        _snapshot = next;
        notifyListeners();
      }
    } catch (error) {
      debugPrint(
        '[RuntimeConfig] Refresh failed; retaining current policy: $error',
      );
    }
  }
}
