import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'release_notes_service.dart';

class AppReleaseChecker {
  static const String _keyLastSeenVersion = 'last_seen_app_version_v1';
  static const String _keyLastSeenServerUpdate = 'last_seen_server_update_v1';

  final ReleaseNotesService _releaseNotesService;

  AppReleaseChecker({ReleaseNotesService? releaseNotesService})
    : _releaseNotesService = releaseNotesService ?? ReleaseNotesService();

  /// Returns a [WhatsNewResult] when there is something to show the user:
  ///   - A new version the user has not yet seen (local version bump).
  ///   - A newer version available on the server (update available banner).
  /// Returns null when there is nothing to show.
  Future<WhatsNewResult?> checkForWhatsNew() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final installedVersion = packageInfo.version;

    final prefs = await SharedPreferences.getInstance();
    final lastSeenVersion = prefs.getString(_keyLastSeenVersion) ?? '';
    final lastSeenServerUpdate =
        prefs.getString(_keyLastSeenServerUpdate) ?? '';

    // If the installed version is newer than what we last showed, show notes.
    final isNewInstallOrUpdate =
        lastSeenVersion.isEmpty ||
        _compareVersions(installedVersion, lastSeenVersion) > 0;

    // Fetch server release info
    final releaseInfo = await _releaseNotesService.fetchReleaseInfo();

    final serverVersion = releaseInfo?.version ?? '';
    final minVersion = releaseInfo?.minVersion ?? '';

    final isUpdateAvailable =
        serverVersion.isNotEmpty &&
        _compareVersions(serverVersion, installedVersion) > 0;

    final isUpdateRequired =
        minVersion.isNotEmpty &&
        _compareVersions(minVersion, installedVersion) > 0;

    final hasAlreadySeenThisUpdate =
        isUpdateAvailable &&
        _compareVersions(serverVersion, lastSeenServerUpdate) <= 0;

    final shouldShowUpdate =
        isUpdateRequired || (isUpdateAvailable && !hasAlreadySeenThisUpdate);

    if (!isNewInstallOrUpdate && !shouldShowUpdate) return null;

    // Mark this version as seen so the sheet never shows twice.
    if (isNewInstallOrUpdate) {
      await prefs.setString(_keyLastSeenVersion, installedVersion);
    }
    if (shouldShowUpdate && !isUpdateRequired) {
      await prefs.setString(_keyLastSeenServerUpdate, serverVersion);
    }

    return WhatsNewResult(
      installedVersion: installedVersion,
      serverVersion: serverVersion.isNotEmpty
          ? serverVersion
          : installedVersion,
      releaseNotes: releaseInfo?.releaseNotes ?? const [],
      isUpdateAvailable: isUpdateAvailable,
      minVersion: minVersion,
    );
  }

  /// Marks the current installed version as seen without fetching anything.
  Future<void> markCurrentVersionSeen() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSeenVersion, packageInfo.version);
  }

  /// Semantic version compare: returns positive if a > b, negative if a < b, 0 if equal.
  static int _compareVersions(String a, String b) {
    final partsA = _versionParts(a);
    final partsB = _versionParts(b);
    for (int i = 0; i < 3; i++) {
      final diff = partsA[i] - partsB[i];
      if (diff != 0) return diff;
    }
    return 0;
  }

  static List<int> _versionParts(String version) {
    final parts = version
        .split('.')
        .map((p) => int.tryParse(p.trim()) ?? 0)
        .toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts.sublist(0, 3);
  }
}

class WhatsNewResult {
  const WhatsNewResult({
    required this.installedVersion,
    required this.serverVersion,
    required this.releaseNotes,
    required this.isUpdateAvailable,
    required this.minVersion,
  });

  final String installedVersion;
  final String serverVersion;
  final List<String> releaseNotes;
  final bool isUpdateAvailable;
  final String minVersion;

  bool get hasNotes => releaseNotes.isNotEmpty;

  bool get isUpdateRequired {
    if (minVersion.isEmpty) return false;
    return AppReleaseChecker._compareVersions(minVersion, installedVersion) > 0;
  }
}
