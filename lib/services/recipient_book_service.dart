import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WalletRecipient {
  const WalletRecipient({
    required this.address,
    required this.walletScope,
    required this.networkKey,
    required this.label,
    required this.lastUsedAt,
    this.saved = false,
  });

  final String address;
  final String walletScope;
  final String networkKey;
  final String label;
  final DateTime lastUsedAt;
  final bool saved;

  WalletRecipient copyWith({String? label, bool? saved, DateTime? lastUsedAt}) {
    return WalletRecipient(
      address: address,
      walletScope: walletScope,
      networkKey: networkKey,
      label: label ?? this.label,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      saved: saved ?? this.saved,
    );
  }

  Map<String, dynamic> toJson() => {
    'address': address,
    'walletScope': walletScope,
    'networkKey': networkKey,
    'label': label,
    'lastUsedAt': lastUsedAt.toIso8601String(),
    'saved': saved,
  };

  static WalletRecipient? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final address = value['address']?.toString().trim() ?? '';
    final walletScope = value['walletScope']?.toString().trim() ?? '';
    final networkKey = value['networkKey']?.toString().trim() ?? '';
    if (address.isEmpty || walletScope.isEmpty || networkKey.isEmpty) {
      return null;
    }
    return WalletRecipient(
      address: address,
      walletScope: walletScope,
      networkKey: networkKey,
      label: value['label']?.toString().trim() ?? '',
      lastUsedAt:
          DateTime.tryParse(value['lastUsedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      saved: value['saved'] == true,
    );
  }
}

class RecipientBookService {
  RecipientBookService({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _storageKey = 'wallet_recipients_v2';
  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? SharedPreferences.getInstance();

  Future<List<WalletRecipient>> all() async {
    final raw = (await _prefs).getString(_storageKey);
    if (raw == null || raw.isEmpty) return <WalletRecipient>[];
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      return values
          .map(WalletRecipient.fromJson)
          .whereType<WalletRecipient>()
          .toList()
        ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    } catch (_) {
      return <WalletRecipient>[];
    }
  }

  Future<List<WalletRecipient>> recent(
    String networkKey, {
    required String walletScope,
  }) async {
    final scope = _normalizeWalletScope(walletScope);
    if (scope.isEmpty) return <WalletRecipient>[];
    return (await all())
        .where(
          (entry) =>
              entry.networkKey == networkKey && entry.walletScope == scope,
        )
        .take(20)
        .toList();
  }

  Future<List<WalletRecipient>> saved(
    String networkKey, {
    required String walletScope,
  }) async {
    final scope = _normalizeWalletScope(walletScope);
    if (scope.isEmpty) return <WalletRecipient>[];
    return (await all())
        .where(
          (entry) =>
              entry.networkKey == networkKey &&
              entry.walletScope == scope &&
              entry.saved,
        )
        .toList();
  }

  Future<void> recordRecent({
    required String networkKey,
    required String walletScope,
    required String address,
    String? label,
  }) async {
    final scope = _normalizeWalletScope(walletScope);
    if (scope.isEmpty) return;
    final entries = await all();
    final normalized = address.trim();
    final index = entries.indexWhere(
      (entry) =>
          entry.networkKey == networkKey &&
          entry.walletScope == scope &&
          entry.address.toLowerCase() == normalized.toLowerCase(),
    );
    final existing = index >= 0 ? entries.removeAt(index) : null;
    entries.insert(
      0,
      WalletRecipient(
        address: normalized,
        walletScope: scope,
        networkKey: networkKey,
        label: label?.trim().isNotEmpty == true
            ? label!.trim()
            : existing?.label ?? '',
        lastUsedAt: DateTime.now(),
        saved: existing?.saved ?? false,
      ),
    );
    await _write(entries.take(60).toList());
  }

  Future<void> save({
    required String networkKey,
    required String walletScope,
    required String address,
    required String label,
  }) async {
    final scope = _normalizeWalletScope(walletScope);
    if (scope.isEmpty) return;
    await recordRecent(
      networkKey: networkKey,
      walletScope: scope,
      address: address,
      label: label,
    );
    final entries = await all();
    final index = entries.indexWhere(
      (entry) =>
          entry.networkKey == networkKey &&
          entry.walletScope == scope &&
          entry.address.toLowerCase() == address.trim().toLowerCase(),
    );
    if (index >= 0) {
      entries[index] = entries[index].copyWith(
        label: label.trim(),
        saved: true,
      );
      await _write(entries);
    }
  }

  Future<void> remove(
    String networkKey,
    String address, {
    required String walletScope,
  }) async {
    final scope = _normalizeWalletScope(walletScope);
    if (scope.isEmpty) return;
    final entries = await all();
    entries.removeWhere(
      (entry) =>
          entry.networkKey == networkKey &&
          entry.walletScope == scope &&
          entry.address.toLowerCase() == address.trim().toLowerCase(),
    );
    await _write(entries);
  }

  Future<void> _write(List<WalletRecipient> entries) async {
    await (await _prefs).setString(
      _storageKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  String _normalizeWalletScope(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('0x') ? trimmed.toLowerCase() : trimmed;
  }
}
