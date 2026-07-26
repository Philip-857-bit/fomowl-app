import 'dart:convert';

import '../config/app_environment.dart';
import '../utils/app_error_utils.dart';
import 'http_client_service.dart';
import 'storage_service.dart';
import 'wallet_backend_auth_service.dart';
import 'wallet_service.dart';

/// Provides one wallet-authenticated 2FA setup for the whole local app.
///
/// The backend record remains protected by wallet ownership, but the owner is
/// persisted separately from the active wallet. Switching wallets or chains
/// therefore cannot change the 2FA status or authenticator secret.
class WalletTwoFactorService {
  WalletTwoFactorService({
    WalletService? walletService,
    WalletBackendAuthService? walletBackendAuthService,
    HttpClientService? httpClientService,
    StorageService? storageService,
  }) : _walletService = walletService ?? WalletService(),
       _walletBackendAuthService =
           walletBackendAuthService ?? WalletBackendAuthService(),
       _httpClientService = httpClientService ?? HttpClientService(),
       _storageService = storageService ?? StorageService();

  final WalletService _walletService;
  final WalletBackendAuthService _walletBackendAuthService;
  final HttpClientService _httpClientService;
  final StorageService _storageService;

  Future<Map<String, dynamic>> fetchTwoFactorStatus() async {
    final storedAuthority = await _storageService.getTwoFactorAuthorityWallet();
    if (storedAuthority != null) {
      return _fetchStatusFor(storedAuthority);
    }

    // One-time migration for installations that enabled 2FA before it became
    // app-wide. Find the saved wallet that owns the existing setup, preferring
    // the active wallet, then persist it as the permanent authority.
    final candidates = await _authorityCandidates();
    Map<String, dynamic>? firstSuccessful;
    String? firstSuccessfulWallet;
    for (final walletAddress in candidates) {
      final status = await _fetchStatusFor(walletAddress);
      if (status['success'] != true) {
        continue;
      }
      firstSuccessful ??= status;
      firstSuccessfulWallet ??= walletAddress;
      if (status['enabled'] == true || status['pending_setup'] == true) {
        await _storageService.setTwoFactorAuthorityWallet(walletAddress);
        return status;
      }
    }

    if (firstSuccessful != null && firstSuccessfulWallet != null) {
      await _storageService.setTwoFactorAuthorityWallet(firstSuccessfulWallet);
      return firstSuccessful;
    }
    return _missingWallet();
  }

  Future<Map<String, dynamic>> beginTwoFactorSetup() async {
    final walletAddress = await _authorityWallet();
    if (walletAddress == null) {
      return _missingWallet();
    }

    try {
      final response = await _walletBackendAuthService.sendAuthorized(
        walletAddress,
        (headers) => _httpClientService.client.post(
          AppEnvironment.settings('/2fa/setup'),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({'walletAddress': walletAddress}),
        ),
        const <String, String>{'Content-Type': 'application/json'},
      );
      final data = _decodeObject(response.body) ?? <String, dynamic>{};
      if (response.statusCode == 200 && data['success'] == true) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          await _storageService.setTwoFactorAuthorityWallet(walletAddress);
          return {'success': true, ...payload};
        }
      }
      return _error(
        response.body,
        'Unable to start wallet 2FA setup right now.',
      );
    } catch (error) {
      return _exception(error, 'Unable to start wallet 2FA setup right now.');
    }
  }

  Future<Map<String, dynamic>> verifyTwoFactorSetup({required String code}) {
    return _postCode(
      path: '/2fa/verify',
      code: code,
      fallback: 'Unable to activate wallet 2FA right now.',
    );
  }

  Future<Map<String, dynamic>> confirmTwoFactorCode({required String code}) {
    return _postCode(
      path: '/2fa/confirm',
      code: code,
      fallback: 'Unable to verify the authenticator code right now.',
    );
  }

  Future<Map<String, dynamic>> disableTwoFactor({required String code}) {
    return _postCode(
      path: '/2fa/disable',
      code: code,
      fallback: 'Unable to disable wallet 2FA right now.',
    );
  }

  Future<Map<String, dynamic>> _fetchStatusFor(String walletAddress) async {
    try {
      final encodedWallet = Uri.encodeComponent(walletAddress);
      final response = await _walletBackendAuthService.sendAuthorized(
        walletAddress,
        (headers) => _httpClientService.client.get(
          AppEnvironment.settings('/2fa/status/$encodedWallet'),
          headers: headers,
        ),
        const <String, String>{},
      );
      final data = _decodeObject(response.body) ?? <String, dynamic>{};
      if (response.statusCode == 200 && data['success'] == true) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          return {'success': true, ...payload};
        }
      }
      return _error(
        response.body,
        'Unable to load wallet 2FA status right now.',
      );
    } catch (error) {
      return _exception(error, 'Unable to load wallet 2FA status right now.');
    }
  }

  Future<Map<String, dynamic>> _postCode({
    required String path,
    required String code,
    required String fallback,
  }) async {
    final walletAddress = await _authorityWallet();
    if (walletAddress == null) {
      return _missingWallet();
    }
    try {
      final response = await _walletBackendAuthService.sendAuthorized(
        walletAddress,
        (headers) => _httpClientService.client.post(
          AppEnvironment.settings(path),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'walletAddress': walletAddress,
            'code': code.trim(),
          }),
        ),
        const <String, String>{'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return _error(response.body, fallback);
    } catch (error) {
      return _exception(error, fallback);
    }
  }

  Future<String?> _authorityWallet() async {
    final stored = await _storageService.getTwoFactorAuthorityWallet();
    if (stored != null) {
      return stored;
    }
    await fetchTwoFactorStatus();
    return _storageService.getTwoFactorAuthorityWallet();
  }

  Future<List<String>> _authorityCandidates() async {
    final candidates = <String>[];
    void add(String? value) {
      final normalized = value?.trim().toLowerCase();
      if (normalized != null &&
          normalized.isNotEmpty &&
          !candidates.contains(normalized)) {
        candidates.add(normalized);
      }
    }

    add(await _walletService.getCurrentWalletAddress());
    for (final account in await _walletService.getWalletAccounts()) {
      add(account.address);
    }
    return candidates;
  }

  Map<String, dynamic> _missingWallet() => {
    'success': false,
    'error': 'Open a saved wallet, then try again.',
  };

  Map<String, dynamic> _error(String body, String fallback) => {
    'success': false,
    'error': AppErrorUtils.backendMessage(body, fallback: fallback),
  };

  Map<String, dynamic> _exception(Object error, String fallback) => {
    'success': false,
    'error': AppErrorUtils.userMessage(error, fallback: fallback),
  };

  Map<String, dynamic>? _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
