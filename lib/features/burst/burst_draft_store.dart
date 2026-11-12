import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../services/secure_store.dart';

/// Persists only the prepared request and response; never account credentials.
class BurstDraftStore {
  BurstDraftStore({FlutterSecureStorage? storage})
    : _storage =
          storage ?? const FlutterSecureStorage(iOptions: kSecureIosOptions);
  final FlutterSecureStorage _storage;
  String _key(String profile, String wallet, int chainId) =>
      'burst_draft_v1_${sha256.convert(utf8.encode('$profile:${wallet.toLowerCase()}:$chainId'))}';

  Future<Map<String, dynamic>?> read(
    String profile,
    String wallet,
    int chainId,
  ) async {
    final raw = await _storage.read(key: _key(profile, wallet, chainId));
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        decoded['request'] is! Map<String, dynamic>) {
      throw const FormatException('Burst recovery information is invalid.');
    }
    return decoded;
  }

  Future<void> write(
    String profile,
    String wallet,
    int chainId,
    Map<String, dynamic> value,
  ) => _storage.write(
    key: _key(profile, wallet, chainId),
    value: jsonEncode(value),
  );

  Future<void> clear(String profile, String wallet, int chainId) =>
      _storage.delete(key: _key(profile, wallet, chainId));

  Future<void> clearCampaign(
    String profile,
    String wallet,
    int chainId,
    String campaignId,
  ) async {
    final saved = await read(profile, wallet, chainId);
    final prepared = saved?['prepared'];
    final campaign = prepared is Map ? prepared['campaign'] : null;
    if (campaign is Map && campaign['id'] == campaignId) {
      await clear(profile, wallet, chainId);
    }
  }
}
