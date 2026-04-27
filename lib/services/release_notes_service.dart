import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_environment.dart';

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.minVersion,
    required this.releaseNotes,
  });

  final String version;
  final String minVersion;
  final List<String> releaseNotes;

  bool get hasNotes => releaseNotes.isNotEmpty;

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['releaseNotes'];
    final notes = rawNotes is List
        ? rawNotes.whereType<String>().where((s) => s.isNotEmpty).toList()
        : const <String>[];
    return AppReleaseInfo(
      version: json['version']?.toString() ?? '',
      minVersion: json['minVersion']?.toString() ?? '',
      releaseNotes: notes,
    );
  }
}

class ReleaseNotesService {
  Future<AppReleaseInfo?> fetchReleaseInfo() async {
    try {
      final response = await http
          .get(AppEnvironment.content('/app-release'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return AppReleaseInfo.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
