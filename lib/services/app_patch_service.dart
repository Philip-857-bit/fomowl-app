import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../models/patch_status_snapshot.dart';

class AppPatchService extends ChangeNotifier {
  AppPatchService._({
    ShorebirdUpdater? updater,
    Future<SharedPreferences> Function()? preferencesLoader,
    Future<PackageInfo> Function()? packageInfoLoader,
  }) : _updater = updater ?? ShorebirdUpdater(),
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform;

  static final AppPatchService instance = AppPatchService._();

  static const String _snapshotStorageKey = 'owllet_patch_status_snapshot_v1';
  static const Duration _resumeCheckDebounce = Duration(minutes: 30);

  final ShorebirdUpdater _updater;
  final Future<SharedPreferences> Function() _preferencesLoader;
  final Future<PackageInfo> Function() _packageInfoLoader;

  PatchStatusSnapshot _snapshot = const PatchStatusSnapshot.initial(
    appVersion: '0.0.0',
    buildNumber: '0',
  );
  int? _nextPatchNumber;
  bool _initialized = false;
  Future<void>? _initialization;
  Future<void>? _activeCheck;

  PatchStatusSnapshot get snapshot => _snapshot;
  bool get isUpdaterAvailable => _updater.isAvailable;
  int? get currentPatchNumber => _snapshot.patchNumber;
  int? get nextPatchNumber => _nextPatchNumber;
  String get supportVersionLabel => _snapshot.displayVersionLabel;
  String get reportVersion => _snapshot.reportVersion;
  String get supportStatusLabel {
    final checkedAt = _snapshot.lastCheckedAt;
    final checkedAtLabel = checkedAt == null
        ? null
        : '${checkedAt.toUtc().toIso8601String()} UTC';
    final statusLabel = switch (_snapshot.status) {
      AppPatchStatus.idle => 'OTA idle',
      AppPatchStatus.unavailable => 'OTA unavailable',
      AppPatchStatus.checking => 'OTA checking',
      AppPatchStatus.outdated => 'OTA update ready to download',
      AppPatchStatus.downloading => 'OTA downloading maintenance patch',
      AppPatchStatus.upToDate => 'OTA up to date',
      AppPatchStatus.restartRequired => 'OTA downloaded, restart to apply',
      AppPatchStatus.failed => 'OTA failed',
    };
    if (_snapshot.lastError case final error? when error.isNotEmpty) {
      return '$statusLabel | $error';
    }
    if (checkedAtLabel == null) {
      return statusLabel;
    }
    return '$statusLabel | checked $checkedAtLabel';
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    final existingInitialization = _initialization;
    if (existingInitialization != null) {
      await existingInitialization;
      return;
    }

    _initialization = _initializeInternal();
    try {
      await _initialization;
    } finally {
      _initialization = null;
    }
  }

  Future<void> _initializeInternal() async {
    await _loadBaseSnapshot();
    await _restoreSnapshot();
    await _refreshPatchNumbers();

    if (!_updater.isAvailable) {
      await _setSnapshot(
        _snapshot.copyWith(
          patchNumber: null,
          status: AppPatchStatus.unavailable,
          lastError: null,
        ),
      );
      _initialized = true;
      return;
    }

    _initialized = true;
    unawaited(_runSilentUpdateCheck(force: true));
  }

  Future<Patch?> readCurrentPatch() async {
    try {
      final patch = await _updater.readCurrentPatch();
      await _setSnapshot(
        _snapshot.copyWith(patchNumber: patch?.number, lastError: null),
      );
      return patch;
    } on ReadPatchException catch (error) {
      await _setFailure(error.message);
      return null;
    }
  }

  Future<PatchStatusSnapshot> checkForUpdate({bool force = false}) async {
    await initialize();
    if (!_updater.isAvailable) {
      return _snapshot;
    }
    if (!force && !_shouldCheckNow()) {
      return _snapshot;
    }

    final activeCheck = _activeCheck ??= _performCheckAndMaybeDownload();
    try {
      await activeCheck;
    } finally {
      if (identical(_activeCheck, activeCheck)) {
        _activeCheck = null;
      }
    }
    return _snapshot;
  }

  Future<PatchStatusSnapshot> downloadIfOutdated() async {
    await initialize();
    if (!_updater.isAvailable) {
      return _snapshot;
    }
    if (_snapshot.status != AppPatchStatus.outdated) {
      return _snapshot;
    }

    await _downloadLatestPatch();
    return _snapshot;
  }

  Future<void> handleAppResumed() async {
    await initialize();
    if (!_updater.isAvailable) {
      return;
    }
    unawaited(_runSilentUpdateCheck(force: false));
  }

  Future<void> _runSilentUpdateCheck({required bool force}) async {
    try {
      final status = await checkForUpdate(force: force);
      if (status.status == AppPatchStatus.outdated) {
        await downloadIfOutdated();
      }
    } catch (error, stackTrace) {
      debugPrint('Silent OTA check failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _performCheckAndMaybeDownload() async {
    await _setSnapshot(
      _snapshot.copyWith(status: AppPatchStatus.checking, lastError: null),
    );

    try {
      final status = await _updater.checkForUpdate();
      await _refreshPatchNumbers();
      await _setSnapshot(
        _snapshot.copyWith(
          status: _mapUpdateStatus(status),
          lastCheckedAt: DateTime.now().toUtc(),
          lastError: null,
        ),
      );
    } on ReadPatchException catch (error) {
      await _setFailure(error.message);
    } catch (error) {
      await _setFailure(error.toString());
    }
  }

  Future<void> _downloadLatestPatch() async {
    await _setSnapshot(
      _snapshot.copyWith(status: AppPatchStatus.downloading, lastError: null),
    );

    try {
      await _updater.update();
      await _refreshPatchNumbers();
      await _setSnapshot(
        _snapshot.copyWith(
          status: AppPatchStatus.restartRequired,
          lastCheckedAt: DateTime.now().toUtc(),
          lastError: null,
        ),
      );
    } on ReadPatchException catch (error) {
      await _setFailure(error.message);
    } catch (error) {
      await _setFailure(error.toString());
    }
  }

  Future<void> _loadBaseSnapshot() async {
    try {
      final packageInfo = await _packageInfoLoader();
      _snapshot = _snapshot.copyWith(
        appVersion: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
      );
    } catch (error) {
      debugPrint('Unable to resolve package info for OTA metadata: $error');
    }
  }

  Future<void> _restoreSnapshot() async {
    try {
      final preferences = await _preferencesLoader();
      final encoded = preferences.getString(_snapshotStorageKey);
      if (encoded == null || encoded.isEmpty) {
        return;
      }
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final restored = PatchStatusSnapshot.fromJson(decoded);
      _snapshot = restored.copyWith(
        appVersion: _snapshot.appVersion,
        buildNumber: _snapshot.buildNumber,
      );
    } catch (error) {
      debugPrint('Unable to restore OTA snapshot: $error');
    }
  }

  Future<void> _refreshPatchNumbers() async {
    if (!_updater.isAvailable) {
      _nextPatchNumber = null;
      return;
    }

    try {
      final current = await _updater.readCurrentPatch();
      final next = await _updater.readNextPatch();
      _nextPatchNumber = next?.number;
      _snapshot = _snapshot.copyWith(patchNumber: current?.number);

      if (next != null && next.number != current?.number) {
        _snapshot = _snapshot.copyWith(status: AppPatchStatus.restartRequired);
      }

      await _persistSnapshot();
      notifyListeners();
    } on ReadPatchException catch (error) {
      await _setFailure(error.message);
    }
  }

  Future<void> _setFailure(String message) async {
    final normalized = message.trim().isEmpty
        ? 'Unknown OTA error'
        : message.trim();
    await _setSnapshot(
      _snapshot.copyWith(
        status: AppPatchStatus.failed,
        lastCheckedAt: DateTime.now().toUtc(),
        lastError: normalized,
      ),
    );
  }

  Future<void> _setSnapshot(PatchStatusSnapshot snapshot) async {
    _snapshot = snapshot;
    await _persistSnapshot();
    notifyListeners();
  }

  Future<void> _persistSnapshot() async {
    try {
      final preferences = await _preferencesLoader();
      await preferences.setString(
        _snapshotStorageKey,
        jsonEncode(_snapshot.toJson()),
      );
    } catch (error) {
      debugPrint('Unable to persist OTA snapshot: $error');
    }
  }

  bool _shouldCheckNow() {
    final lastCheckedAt = _snapshot.lastCheckedAt;
    if (lastCheckedAt == null) {
      return true;
    }
    return DateTime.now().toUtc().difference(lastCheckedAt) >=
        _resumeCheckDebounce;
  }

  AppPatchStatus _mapUpdateStatus(UpdateStatus status) {
    switch (status) {
      case UpdateStatus.upToDate:
        return AppPatchStatus.upToDate;
      case UpdateStatus.outdated:
        return AppPatchStatus.outdated;
      case UpdateStatus.restartRequired:
        return AppPatchStatus.restartRequired;
      case UpdateStatus.unavailable:
        return AppPatchStatus.unavailable;
    }
  }
}
