import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_environment.dart';
import 'http_client_service.dart';

enum RuntimeFeature {
  transfers,
  swaps,
  bridges,
  miniApps,
  cashIn,
  cashOut,
  bills,
  shop,
  legacySystem,
}

RuntimeFeature runtimeFeatureForMiniAppLaunch(
  String miniAppId,
  String? initialUrl,
) {
  if (miniAppId.trim().toLowerCase() != 'owllet_pay') {
    return RuntimeFeature.miniApps;
  }
  final path = Uri.tryParse(initialUrl ?? '')?.path.toLowerCase() ?? '';
  if (path == '/deposit' || path.startsWith('/deposit/')) {
    return RuntimeFeature.cashIn;
  }
  if (path == '/withdraw' || path.startsWith('/withdraw/')) {
    return RuntimeFeature.cashOut;
  }
  if (path == '/pay-bills' || path.startsWith('/pay-bills/')) {
    return RuntimeFeature.bills;
  }
  if (path == '/shop' || path.startsWith('/shop/')) {
    return RuntimeFeature.shop;
  }
  return RuntimeFeature.miniApps;
}

class RuntimePolicySnapshot {
  const RuntimePolicySnapshot({
    this.revision = 0,
    this.maintenanceMode = 'off',
    this.maintenanceMessage = '',
    this.portfolioEnabled = true,
    this.portfolioUiEnabled = true,
    this.scopedBalancesEnabled = true,
    this.legacyAggregateEnabled = true,
    this.refreshQueueEnabled = true,
    this.workerEnabled = true,
    this.refreshOnEntry = true,
    this.refreshOnResume = true,
    this.refreshOnTransaction = true,
    this.transfersEnabled = true,
    this.swapsEnabled = true,
    this.bridgesEnabled = true,
    this.miniAppsEnabled = true,
    this.cashInEnabled = true,
    this.cashOutEnabled = true,
    this.billsEnabled = true,
    this.shopEnabled = true,
    this.legacySystemEnabled = true,
    this.bitcoinEnabled = false,
    this.bitcoinTestnetEnabled = false,
    this.bitcoinRolloutStage = 'off',
    this.bitcoinRolloutPercent = 0,
  });

  final int revision;
  final String maintenanceMode;
  final String maintenanceMessage;
  final bool portfolioEnabled;
  final bool portfolioUiEnabled;
  final bool scopedBalancesEnabled;
  final bool legacyAggregateEnabled;
  final bool refreshQueueEnabled;
  final bool workerEnabled;
  final bool refreshOnEntry;
  final bool refreshOnResume;
  final bool refreshOnTransaction;
  final bool transfersEnabled;
  final bool swapsEnabled;
  final bool bridgesEnabled;
  final bool miniAppsEnabled;
  final bool cashInEnabled;
  final bool cashOutEnabled;
  final bool billsEnabled;
  final bool shopEnabled;
  final bool legacySystemEnabled;
  final bool bitcoinEnabled;
  final bool bitcoinTestnetEnabled;
  final String bitcoinRolloutStage;
  final int bitcoinRolloutPercent;

  bool get fullMaintenance => maintenanceMode == 'full';
  bool get readOnly => maintenanceMode == 'read_only';

  bool allows(RuntimeFeature feature) {
    if (fullMaintenance) return false;
    if (feature == RuntimeFeature.miniApps) return miniAppsEnabled;
    if (readOnly) return false;
    return switch (feature) {
      RuntimeFeature.transfers => transfersEnabled,
      RuntimeFeature.swaps => swapsEnabled,
      RuntimeFeature.bridges => bridgesEnabled,
      RuntimeFeature.miniApps => miniAppsEnabled,
      RuntimeFeature.cashIn => cashInEnabled,
      RuntimeFeature.cashOut => cashOutEnabled,
      RuntimeFeature.bills => billsEnabled,
      RuntimeFeature.shop => shopEnabled,
      RuntimeFeature.legacySystem => legacySystemEnabled,
    };
  }

  bool allowsTradingScreen({required bool limitSupported}) =>
      allows(RuntimeFeature.swaps) ||
      allows(RuntimeFeature.bridges) ||
      (limitSupported && !fullMaintenance && !readOnly);

  String unavailableMessage(RuntimeFeature feature) {
    if (fullMaintenance) {
      return maintenanceMessage.trim().isNotEmpty
          ? maintenanceMessage.trim()
          : 'Owllet is temporarily unavailable for maintenance.';
    }
    if (readOnly && feature != RuntimeFeature.miniApps) {
      return maintenanceMessage.trim().isNotEmpty
          ? maintenanceMessage.trim()
          : 'Owllet is temporarily read-only. Please try again later.';
    }
    return switch (feature) {
      RuntimeFeature.transfers =>
        'Transfers are temporarily unavailable. Please try again later.',
      RuntimeFeature.swaps =>
        'Swaps are temporarily unavailable. Please try again later.',
      RuntimeFeature.bridges =>
        'Bridging is temporarily unavailable. Please try again later.',
      RuntimeFeature.miniApps =>
        'Owllet mini apps are temporarily unavailable. Please try again later.',
      RuntimeFeature.cashIn =>
        'Adding funds in OwlletPay is temporarily unavailable. Please try again later.',
      RuntimeFeature.cashOut =>
        'Withdrawals in OwlletPay are temporarily unavailable. Please try again later.',
      RuntimeFeature.bills =>
        'Bill payments in OwlletPay are temporarily unavailable. Please try again later.',
      RuntimeFeature.shop =>
        'The OwlletPay shop is temporarily unavailable. Please try again later.',
      RuntimeFeature.legacySystem =>
        'This older payment flow is no longer available. Please use OwlletPay.',
    };
  }

  @override
  bool operator ==(Object other) =>
      other is RuntimePolicySnapshot &&
      other.revision == revision &&
      other.maintenanceMode == maintenanceMode &&
      other.maintenanceMessage == maintenanceMessage &&
      other.portfolioEnabled == portfolioEnabled &&
      other.portfolioUiEnabled == portfolioUiEnabled &&
      other.scopedBalancesEnabled == scopedBalancesEnabled &&
      other.legacyAggregateEnabled == legacyAggregateEnabled &&
      other.refreshQueueEnabled == refreshQueueEnabled &&
      other.workerEnabled == workerEnabled &&
      other.refreshOnEntry == refreshOnEntry &&
      other.refreshOnResume == refreshOnResume &&
      other.refreshOnTransaction == refreshOnTransaction &&
      other.transfersEnabled == transfersEnabled &&
      other.swapsEnabled == swapsEnabled &&
      other.bridgesEnabled == bridgesEnabled &&
      other.miniAppsEnabled == miniAppsEnabled &&
      other.cashInEnabled == cashInEnabled &&
      other.cashOutEnabled == cashOutEnabled &&
      other.billsEnabled == billsEnabled &&
      other.shopEnabled == shopEnabled &&
      other.legacySystemEnabled == legacySystemEnabled &&
      other.bitcoinEnabled == bitcoinEnabled &&
      other.bitcoinTestnetEnabled == bitcoinTestnetEnabled &&
      other.bitcoinRolloutStage == bitcoinRolloutStage &&
      other.bitcoinRolloutPercent == bitcoinRolloutPercent;

  @override
  int get hashCode => Object.hashAll([
    revision,
    maintenanceMode,
    maintenanceMessage,
    portfolioEnabled,
    portfolioUiEnabled,
    scopedBalancesEnabled,
    legacyAggregateEnabled,
    refreshQueueEnabled,
    workerEnabled,
    refreshOnEntry,
    refreshOnResume,
    refreshOnTransaction,
    transfersEnabled,
    swapsEnabled,
    bridgesEnabled,
    miniAppsEnabled,
    cashInEnabled,
    cashOutEnabled,
    billsEnabled,
    shopEnabled,
    legacySystemEnabled,
    bitcoinEnabled,
    bitcoinTestnetEnabled,
    bitcoinRolloutStage,
    bitcoinRolloutPercent,
  ]);

  Map<String, dynamic> toJson() => {
    'revision': revision,
    'policy': {
      'maintenance': {'mode': maintenanceMode, 'message': maintenanceMessage},
      'portfolio': {
        'enabled': portfolioEnabled,
        'uiEnabled': portfolioUiEnabled,
        'scopedBalancesEnabled': scopedBalancesEnabled,
        'legacyAggregateEnabled': legacyAggregateEnabled,
        'refreshQueueEnabled': refreshQueueEnabled,
        'workerEnabled': workerEnabled,
        'refreshOnEntry': refreshOnEntry,
        'refreshOnResume': refreshOnResume,
        'refreshOnTransaction': refreshOnTransaction,
      },
      'features': {
        'transfersEnabled': transfersEnabled,
        'swapsEnabled': swapsEnabled,
        'bridgesEnabled': bridgesEnabled,
        'miniAppsEnabled': miniAppsEnabled,
        'cashInEnabled': cashInEnabled,
        'cashOutEnabled': cashOutEnabled,
        'billsEnabled': billsEnabled,
        'shopEnabled': shopEnabled,
        'legacySystemEnabled': legacySystemEnabled,
        'bitcoinEnabled': bitcoinEnabled,
        'bitcoinTestnetEnabled': bitcoinTestnetEnabled,
        'bitcoinRolloutStage': bitcoinRolloutStage,
        'bitcoinRolloutPercent': bitcoinRolloutPercent,
      },
    },
  };

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
    final features = policy['features'] is Map
        ? (policy['features'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final revision = json['revision'] ?? json['version'] ?? policy['revision'];
    bool readFlag(
      Map<String, dynamic> source,
      String key, {
      required bool fallback,
    }) {
      final value = source[key];
      if (value is bool) return value;
      if (value == 1 || value == '1' || value == 'true') return true;
      if (value == 0 || value == '0' || value == 'false') return false;
      return fallback;
    }

    return RuntimePolicySnapshot(
      bitcoinEnabled: features['bitcoinEnabled'] == true,
      bitcoinTestnetEnabled: features['bitcoinTestnetEnabled'] == true,
      bitcoinRolloutStage: features['bitcoinRolloutStage'] is String
          ? features['bitcoinRolloutStage'] as String
          : 'off',
      bitcoinRolloutPercent:
          features['bitcoinRolloutPercent'] is int &&
              (features['bitcoinRolloutPercent'] as int) >= 0 &&
              (features['bitcoinRolloutPercent'] as int) <= 100
          ? features['bitcoinRolloutPercent'] as int
          : 0,
      revision: revision is int
          ? revision
          : int.tryParse(revision?.toString() ?? '') ?? 0,
      maintenanceMode: maintenance['mode']?.toString() ?? 'off',
      maintenanceMessage: maintenance['message']?.toString() ?? '',
      portfolioEnabled: readFlag(portfolio, 'enabled', fallback: true),
      portfolioUiEnabled: readFlag(portfolio, 'uiEnabled', fallback: true),
      scopedBalancesEnabled: readFlag(
        portfolio,
        'scopedBalancesEnabled',
        fallback: true,
      ),
      legacyAggregateEnabled: readFlag(
        portfolio,
        'legacyAggregateEnabled',
        fallback: true,
      ),
      refreshQueueEnabled: readFlag(
        portfolio,
        'refreshQueueEnabled',
        fallback: true,
      ),
      workerEnabled: readFlag(portfolio, 'workerEnabled', fallback: true),
      refreshOnEntry: readFlag(portfolio, 'refreshOnEntry', fallback: true),
      refreshOnResume: readFlag(portfolio, 'refreshOnResume', fallback: true),
      refreshOnTransaction: readFlag(
        portfolio,
        'refreshOnTransaction',
        fallback: true,
      ),
      transfersEnabled: readFlag(features, 'transfersEnabled', fallback: false),
      swapsEnabled: readFlag(features, 'swapsEnabled', fallback: false),
      bridgesEnabled: readFlag(features, 'bridgesEnabled', fallback: false),
      miniAppsEnabled: readFlag(features, 'miniAppsEnabled', fallback: false),
      cashInEnabled: readFlag(features, 'cashInEnabled', fallback: false),
      cashOutEnabled: readFlag(features, 'cashOutEnabled', fallback: false),
      billsEnabled: readFlag(features, 'billsEnabled', fallback: false),
      shopEnabled: readFlag(features, 'shopEnabled', fallback: false),
      legacySystemEnabled: readFlag(
        features,
        'legacySystemEnabled',
        fallback: false,
      ),
    );
  }
}

class RuntimeConfigService extends ChangeNotifier {
  RuntimeConfigService._() : _client = null;

  @visibleForTesting
  RuntimeConfigService.forTesting({http.Client? client}) : _client = client;

  static final RuntimeConfigService instance = RuntimeConfigService._();
  static const _persistKey = 'owllet.runtime_policy.last_good.v1';
  static const _etagKey = 'owllet.runtime_policy.etag.v1';
  static const _persistTtl = Duration(hours: 1);

  // Mini apps and transfers stay available when the first policy fetch fails.
  // A valid cached or fetched policy, including maintenance and explicit
  // disables, overrides this startup default. Swaps, bridges, and cash
  // features wait for a policy.
  RuntimePolicySnapshot _snapshot = const RuntimePolicySnapshot(
    maintenanceMode: 'off',
    maintenanceMessage: '',
    portfolioEnabled: false,
    portfolioUiEnabled: false,
    scopedBalancesEnabled: false,
    legacyAggregateEnabled: false,
    refreshQueueEnabled: false,
    workerEnabled: false,
    refreshOnEntry: false,
    refreshOnResume: false,
    refreshOnTransaction: false,
    transfersEnabled: true,
    swapsEnabled: false,
    bridgesEnabled: false,
    miniAppsEnabled: true,
    cashInEnabled: false,
    cashOutEnabled: false,
    billsEnabled: false,
    shopEnabled: false,
    legacySystemEnabled: false,
  );
  final http.Client? _client;
  bool _hasPolicy = false;
  bool _refreshing = false;
  bool _refreshFailed = false;
  Future<void>? _refreshFuture;
  bool get hasPolicy => _hasPolicy;
  bool get refreshing => _refreshing;
  bool get refreshFailed => _refreshFailed;

  String? _etag;
  bool _hydrated = false;
  Future<void>? _hydrateFuture;

  RuntimePolicySnapshot get snapshot => _snapshot;

  Future<void> hydrate() async {
    if (_hydrated) return;
    final inFlight = _hydrateFuture;
    if (inFlight != null) return inFlight;
    final future = _hydratePersistedPolicy();
    _hydrateFuture = future;
    try {
      await future;
    } finally {
      if (identical(_hydrateFuture, future)) {
        _hydrateFuture = null;
      }
    }
  }

  Future<void> _hydratePersistedPolicy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_persistKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final persistedAt = DateTime.tryParse(
        decoded['persistedAt']?.toString() ?? '',
      )?.toUtc();
      if (persistedAt == null ||
          DateTime.now().toUtc().difference(persistedAt) > _persistTtl) {
        return;
      }
      final hydrated = RuntimePolicySnapshot.fromJson(decoded);
      final hydratedEtag = prefs.getString(_etagKey);
      final changed =
          !_hasPolicy || hydrated != _snapshot || hydratedEtag != _etag;
      _hasPolicy = true;
      _snapshot = hydrated;
      _etag = hydratedEtag;
      if (changed) notifyListeners();
    } catch (error) {
      debugPrint('[RuntimeConfig] Failed to hydrate persisted policy: $error');
    } finally {
      _hydrated = true;
    }
  }

  Future<void> refresh() async {
    final inFlight = _refreshFuture;
    if (inFlight != null) return inFlight;
    final future = _refreshPolicy();
    _refreshFuture = future;
    try {
      await future;
    } finally {
      if (identical(_refreshFuture, future)) _refreshFuture = null;
    }
  }

  Future<void> _refreshPolicy() async {
    await hydrate();
    _refreshing = true;
    _refreshFailed = false;
    notifyListeners();
    try {
      final headers = <String, String>{};
      if (_hasPolicy && _etag != null && _etag!.isNotEmpty) {
        headers['If-None-Match'] = _etag!;
      }
      final response = await (_client ?? HttpClientService().client)
          .get(AppEnvironment.api('/runtime-config'), headers: headers)
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 304 && _hasPolicy) {
        await _persist(_snapshot, _etag);
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw http.ClientException(
          'Availability check returned ${response.statusCode}',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['policy'] is! Map) {
        throw const FormatException('Invalid runtime policy');
      }
      _snapshot = RuntimePolicySnapshot.fromJson(decoded);
      _etag = response.headers['etag'];
      _hasPolicy = true;
      await _persist(_snapshot, _etag);
    } catch (error) {
      _refreshFailed = true;
      debugPrint(
        '[RuntimeConfig] Refresh failed; retaining current policy: $error',
      );
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> _persist(RuntimePolicySnapshot snapshot, String? etag) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = snapshot.toJson();
      payload['persistedAt'] = DateTime.now().toUtc().toIso8601String();
      await prefs.setString(_persistKey, jsonEncode(payload));
      if (etag != null) {
        await prefs.setString(_etagKey, etag);
      }
    } catch (error) {
      debugPrint('[RuntimeConfig] Persist failed: $error');
    }
  }
}
