import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'affiliate_install_referrer_stub.dart'
    if (dart.library.io) 'affiliate_install_referrer_io.dart';
import 'referral_service.dart';
import 'wallet_service.dart';

class AffiliateAttributionService {
  AffiliateAttributionService._();

  static final AffiliateAttributionService instance =
      AffiliateAttributionService._();

  static const _pendingKey = 'owllet.pending_affiliate_code.v1';
  static const _referrerConsumedKey = 'owllet.install_referrer_consumed.v1';

  final ReferralService _referralService = ReferralService();
  final WalletService _walletService = WalletService();
  bool _capturing = false;

  static String? normalizeCode(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().toUpperCase();
    if (normalized.length < 4 || normalized.length > 12) return null;
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(normalized)) return null;
    return normalized;
  }

  static String? parseCodeFromReferrer(String? referrer) {
    if (referrer == null || referrer.trim().isEmpty) return null;
    final decoded = Uri.decodeQueryComponent(referrer.trim());
    final params = Uri.splitQueryString(decoded);
    final fromAffiliateField = normalizeCode(params['affiliate_code']);
    if (fromAffiliateField != null) return fromAffiliateField;

    final medium = (params['utm_medium'] ?? '').toLowerCase();
    if (medium == 'affiliate') {
      return normalizeCode(
        params['utm_campaign'] ?? params['ref'] ?? params['referral_code'],
      );
    }

    // Bare Play referrer strings are a code and nothing else.
    if (!decoded.contains('=')) {
      return normalizeCode(decoded);
    }
    return null;
  }

  static const _affiliateHosts = <String>{
    'affiliates.owlletapp.com',
  };

  static String? parseCodeFromUri(Uri uri) {
    final scheme = uri.scheme.trim().toLowerCase();
    final segments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    if (scheme == 'owllet' && uri.host.toLowerCase() == 'r') {
      return segments.length == 1 ? normalizeCode(segments.single) : null;
    }
    if (scheme == 'owllet' && uri.host.isEmpty && segments.length == 2) {
      return segments.first.toLowerCase() == 'r'
          ? normalizeCode(segments[1])
          : null;
    }
    if ((scheme == 'https' || scheme == 'http') &&
        _affiliateHosts.contains(uri.host.toLowerCase()) &&
        segments.length == 2 &&
        segments.first.toLowerCase() == 'r') {
      return normalizeCode(segments[1]);
    }
    return null;
  }

  Future<String?> pendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    return normalizeCode(prefs.getString(_pendingKey));
  }

  Future<void> rememberCode(String code) async {
    final normalized = normalizeCode(code);
    if (normalized == null) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = normalizeCode(prefs.getString(_pendingKey));
    if (existing != null && existing != normalized) return;
    await prefs.setString(_pendingKey, normalized);
    await prefs.remove('$_pendingKey.retryAt');
  }

  Future<void> captureInstallReferrer({
    Future<String?> Function()? readReferrer,
  }) async {
    if (_capturing) return;
    _capturing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_referrerConsumedKey) == true) return;
      final raw = readReferrer != null
          ? await readReferrer()
          : await _platformInstallReferrer();
      if (raw == null || raw.trim().isEmpty) return;
      final code = parseCodeFromReferrer(raw);
      if (code != null) {
        await rememberCode(code);
      }
      await prefs.setBool(_referrerConsumedKey, true);
    } catch (error) {
      debugPrint('[Affiliate] Install referrer capture failed: $error');
    } finally {
      _capturing = false;
    }
  }

  Future<void> applyPendingToCurrentWallet() async {
    final wallet = await _walletService.getCurrentWalletAddress();
    if (wallet == null || wallet.trim().isEmpty) return;
    await applyToWallet(wallet, source: 'install');
  }

  Future<void> applyToWallet(
    String walletAddress, {
    String source = 'install',
  }) async {
    final code = await pendingCode();
    if (code == null) return;
    final prefs = await SharedPreferences.getInstance();
    final retryAt = prefs.getInt('$_pendingKey.retryAt');
    if (retryAt != null && retryAt > DateTime.now().millisecondsSinceEpoch) {
      return;
    }
    final isAffiliate = await _referralService.lookupAffiliateCode(code);
    if (isAffiliate == false) {
      await prefs.remove(_pendingKey);
      await prefs.remove('$_pendingKey.retryAt');
      return;
    }
    if (isAffiliate != true) {
      await prefs.setInt(
        '$_pendingKey.retryAt',
        DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      );
      return;
    }
    try {
      await _referralService.bindReferralCode(
        walletAddress: walletAddress,
        referralCode: code,
        source: source,
      );
      await prefs.remove(_pendingKey);
      await prefs.remove('$_pendingKey.retryAt');
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('already')) {
        await prefs.remove(_pendingKey);
        await prefs.remove('$_pendingKey.retryAt');
      } else {
        await prefs.setInt(
          '$_pendingKey.retryAt',
          DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch,
        );
      }
      debugPrint('[Affiliate] Pending referral bind failed: $error');
    }
  }

  Future<String?> _platformInstallReferrer() async {
    if (kIsWeb) return null;
    return readPlayInstallReferrer();
  }
}
