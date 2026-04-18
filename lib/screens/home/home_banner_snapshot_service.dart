import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_banner_item.dart';

class HomeBannerSnapshot {
  const HomeBannerSnapshot({required this.feed, required this.timestamp});

  final HomeBannerFeed feed;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'feed': feed.toJson(),
    'timestamp': timestamp.toIso8601String(),
  };

  factory HomeBannerSnapshot.fromJson(Map<String, dynamic> json) {
    return HomeBannerSnapshot(
      feed: HomeBannerFeed.fromJson(
        (json['feed'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      timestamp: _parseTimestamp(json['timestamp']),
    );
  }
}

DateTime _parseTimestamp(Object? rawValue) {
  final raw = rawValue?.toString();
  if (raw == null || raw.isEmpty) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

class HomeBannerSnapshotService {
  static const String _storageKey = 'home_banner_feed_snapshot_v1';

  Future<void> saveSnapshot(HomeBannerFeed feed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snapshot = HomeBannerSnapshot(
        feed: feed,
        timestamp: DateTime.now().toUtc(),
      );
      await prefs.setString(_storageKey, jsonEncode(snapshot.toJson()));
    } catch (error) {
      debugPrint('Error saving home banner snapshot: $error');
    }
  }

  Future<HomeBannerSnapshot?> loadSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return HomeBannerSnapshot.fromJson(decoded);
    } catch (error) {
      debugPrint('Error loading home banner snapshot: $error');
      return null;
    }
  }

  Future<void> clearSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (error) {
      debugPrint('Error clearing home banner snapshot: $error');
    }
  }
}
