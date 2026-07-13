import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'release_notes_service.dart';

class AppReleaseChecker {
  static const String _keyLastSeenVersion = 'last_seen_app_version_v1';
  static const String _keyLastSeenServerUpdate = 'last_seen_server_update_v1';

  final ReleaseNotesService _releaseNotesService;

  AppReleaseChecker({ReleaseNotesService? releaseNotesService})
    : _releaseNotesService = releaseNotesService ?? ReleaseNotesService();

  /// Checks the server's minimum supported version without consulting or
  /// mutating the one-time "what's new" preferences. This is used by the app
  /// root so mandatory updates are enforced before a wallet reaches Home.
  Future<WhatsNewResult?> checkForRequiredUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final installedVersion = packageInfo.version;
    final releaseInfo = await _releaseNotesService.fetchReleaseInfo();
    if (releaseInfo == null || releaseInfo.minVersion.trim().isEmpty) {
      return null;
    }

    final result = WhatsNewResult(
      installedVersion: installedVersion,
      serverVersion: releaseInfo.version.trim().isEmpty
          ? releaseInfo.minVersion
          : releaseInfo.version,
      releaseNotes: releaseInfo.releaseNotes,
      isUpdateAvailable:
          compareAppVersions(releaseInfo.version, installedVersion) > 0,
      minVersion: releaseInfo.minVersion,
    );
    return result.isUpdateRequired ? result : null;
  }

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
        compareAppVersions(installedVersion, lastSeenVersion) > 0;

    // Fetch server release info
    final releaseInfo = await _releaseNotesService.fetchReleaseInfo();

    final serverVersion = releaseInfo?.version ?? '';
    final minVersion = releaseInfo?.minVersion ?? '';

    final isUpdateAvailable =
        serverVersion.isNotEmpty &&
        compareAppVersions(serverVersion, installedVersion) > 0;

    final isUpdateRequired =
        minVersion.isNotEmpty &&
        compareAppVersions(minVersion, installedVersion) > 0;

    final hasAlreadySeenThisUpdate =
        isUpdateAvailable &&
        compareAppVersions(serverVersion, lastSeenServerUpdate) <= 0;

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
}

/// Compares app versions while accepting the formats commonly entered in the
/// admin panel or returned by package metadata (`v1.6.2`, `1.6.2+31`, and
/// `1.6.2-beta`). Build metadata and prerelease labels do not affect the
/// minimum-compatible-version decision.
int compareAppVersions(String a, String b) {
  final partsA = _versionParts(a);
  final partsB = _versionParts(b);
  final length = partsA.length > partsB.length ? partsA.length : partsB.length;
  for (var index = 0; index < length; index++) {
    final left = index < partsA.length ? partsA[index] : 0;
    final right = index < partsB.length ? partsB[index] : 0;
    final difference = left - right;
    if (difference != 0) return difference;
  }
  return 0;
}

List<int> _versionParts(String version) {
  var normalized = version.trim().toLowerCase();
  if (normalized.startsWith('v')) {
    normalized = normalized.substring(1);
  }
  normalized = normalized.split('+').first.split('-').first;
  final parts = normalized
      .split('.')
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .toList(growable: true);
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts;
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
    return compareAppVersions(minVersion, installedVersion) > 0;
  }
}
