import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'dapp_permission_record.dart';

class DappPermissionService {
  static const String _storageKey = 'discover_dapp_permissions_v1';

  Future<List<DappPermissionRecord>> loadPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const <DappPermissionRecord>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        return const <DappPermissionRecord>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                DappPermissionRecord.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false);
    } catch (_) {
      return const <DappPermissionRecord>[];
    }
  }

  Future<bool> hasConnectionApproval(
    String origin,
    String walletAddress,
  ) async {
    final normalizedWallet = walletAddress.trim().toLowerCase();
    final permissions = await loadPermissions();
    return permissions.any(
      (record) =>
          record.origin == origin && record.walletAddress == normalizedWallet,
    );
  }

  Future<void> grantConnectionApproval(
    String origin,
    String walletAddress,
  ) async {
    final permissions = (await loadPermissions()).toList(growable: true)
      ..removeWhere(
        (record) =>
            record.origin == origin &&
            record.walletAddress == walletAddress.trim().toLowerCase(),
      )
      ..add(
        DappPermissionRecord(
          origin: origin,
          walletAddress: walletAddress.trim().toLowerCase(),
          connectedAt: DateTime.now().toUtc(),
        ),
      );
    await _savePermissions(permissions);
  }

  Future<void> revokeConnectionApproval(
    String origin,
    String walletAddress,
  ) async {
    final permissions = (await loadPermissions()).toList(growable: true)
      ..removeWhere(
        (record) =>
            record.origin == origin &&
            record.walletAddress == walletAddress.trim().toLowerCase(),
      );
    await _savePermissions(permissions);
  }

  Future<void> _savePermissions(List<DappPermissionRecord> permissions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(permissions.map((record) => record.toJson()).toList()),
    );
  }
}
